import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/stitch_log.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/message.dart';
import '../../data/repositories/column_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/services/bot_bridge_service.dart';
import '../../data/services/local_identity_service.dart';
import '../../domain/bot_registry.dart';
import '../../domain/branch_path_service.dart';
import '../../domain/context_chain.dart';
import '../../domain/message_store.dart';
import '../core/adaptive_marker.dart';
import 'column_ui_state.dart';

/// How many hops [ColumnsViewModel.loadInitialWindow] resolves in each
/// direction when a column shows an anchor it hasn't materialized before.
const kDefaultRadius = 20;

/// How many hops [ColumnsViewModel.extendAbove]/[extendBelow]/[revealStitch]
/// resolve per batch.
const kDefaultBatch = 20;

/// Owns the multi-column shell: column CRUD/resize/active-selection, and
/// per-column derivation of the currently-displayed branch plus navigator/
/// marker state, via [BranchPathService]/[MessageStore]/[MessageRepository]/
/// [ColumnRepository]. Per `docs/plans/message-loading-plan.md`, this is
/// where the "hop" primitive ([selectCandidate]) and its batching
/// ([defaultPage]) live — [BranchPathService] stays pure resolution/reads,
/// this class owns persistence and the `ChangeNotifier`/loading-marker
/// state that comes with it.
///
/// When [_botBridge] is non-null and the send content tags a known local bot
/// (e.g. `@chatgpt`), the visible branch through the reply target is sent
/// to the Python bridge; the reply is persisted as a normal message under
/// the trigger. Same path for every column — no special-cased column id.
class ColumnsViewModel extends ChangeNotifier {
  ColumnsViewModel(
    this._messages,
    this._columns,
    this._branchPathService,
    this._store,
    this._identity, {
    BotBridgeService? botBridge,
    NotificationService? notifications,
  })  : _botBridge = botBridge,
        _notifications = notifications;

  final MessageRepository _messages;
  final ColumnRepository _columns;
  final BranchPathService _branchPathService;
  final MessageStore _store;
  final LocalIdentityService _identity;
  final BotBridgeService? _botBridge;
  final NotificationService? _notifications;
  static const _uuid = Uuid();
  static const _cwdWarningFadeDelay = Duration(seconds: 4);

  final List<ColumnUiState> _states = [];
  final Map<String, String?> _anchors = {};
  final Map<String, String> _composerDrafts = {};
  final Map<String, Timer> _cwdWarningFadeTimers = {};

  List<ColumnUiState> get columns => List.unmodifiable(_states);

  /// Who "You" refers to in the UI — resolves to the cloud user id once
  /// cloud auth exists, but is always answerable locally in the meantime.
  String get currentUserId => _identity.currentUserId;

  String? anchorOf(String columnId) => _anchors[columnId];

  Future<void> initialize() async {
    final metas = await _columns.getColumns();
    for (final meta in metas) {
      _anchors[meta.id] = meta.anchorMessageId;
      _states.add(
        ColumnUiState(
          id: meta.id,
          width: meta.width,
          initialScrollOffset: meta.scrollOffset,
          cwd: meta.cwd,
        ),
      );
    }
    if (_states.isNotEmpty) _states.first.isActive = true;
    for (final state in _states) {
      await _refresh(state.id, isFreshAnchor: true);
    }
    notifyListeners();
  }

  Future<void> addColumn({String? anchorMessageId, double? width}) async {
    final meta = await _columns.createColumn(
      anchorMessageId: anchorMessageId,
      width: width,
    );
    _anchors[meta.id] = meta.anchorMessageId;
    for (final state in _states) {
      state.isActive = false;
    }
    _states.add(
      ColumnUiState(id: meta.id, width: meta.width, isActive: true, cwd: meta.cwd),
    );
    notifyListeners();
    await _refresh(meta.id, isFreshAnchor: true);
    notifyListeners();
  }

  Future<void> removeColumn(String id) async {
    await _columns.deleteColumn(id);
    final wasActive = _states.firstWhere((s) => s.id == id).isActive;
    _states.removeWhere((s) => s.id == id);
    _anchors.remove(id);
    if (wasActive && _states.isNotEmpty) {
      _states.first.isActive = true;
    }
    notifyListeners();
  }

  void setActiveColumn(String id) {
    for (final state in _states) {
      state.isActive = state.id == id;
    }
    notifyListeners();
  }

  Future<void> updateColumnWidth(String id, double? width) async {
    await _columns.updateColumnWidth(id, width);
    _stateFor(id).width = width;
    notifyListeners();
  }

  /// Straight-through, non-notifying write for debounced scroll-position
  /// persistence — the caller ([_MessageListState] in column_view.dart) owns
  /// the debounce timer; this is just the atomic (single-row) DB write it
  /// targets. Deliberately skips `notifyListeners()`: scroll position isn't
  /// part of any widget's build output, and firing on every debounced save
  /// would rebuild the whole column tree for nothing.
  Future<void> updateColumnScrollOffset(String id, double? scrollOffset) {
    return _columns.updateColumnScrollOffset(id, scrollOffset);
  }

  /// Persists the column's working-directory tag and keeps [ColumnUiState.cwd]
  /// in sync. Empty / whitespace clears the tag (stored as null).
  Future<void> updateColumnCwd(String id, String? cwd) async {
    final normalized = (cwd == null || cwd.trim().isEmpty) ? null : cwd.trim();
    await _columns.updateColumnCwd(id, normalized);
    _stateFor(id).cwd = normalized;
    notifyListeners();
    await refreshCwdWarning(id);
  }

  /// Called as the composer draft changes so the cwd advisory can track
  /// prospective local-bot recipients (mentions + inherited).
  Future<void> onComposerDraftChanged(String columnId, String draft) {
    _composerDrafts[columnId] = draft;
    return refreshCwdWarning(columnId);
  }

  /// Recomputes the advisory banner above the reply box. No-ops while a
  /// post-send confirmation is still showing.
  Future<void> refreshCwdWarning(String columnId) async {
    final state = _stateFor(columnId);
    if (state.cwdWarningPhase == CwdWarningPhase.sent) return;

    final cwdOk = state.cwd != null && state.cwd!.isNotEmpty;
    if (cwdOk) {
      _clearCwdWarning(state);
      notifyListeners();
      return;
    }

    final bots = await _botsNeedingCwd(
      columnId,
      _composerDrafts[columnId] ?? '',
    );
    if (bots.isEmpty) {
      _clearCwdWarning(state);
    } else {
      state.cwdWarningBotIds = List.unmodifiable(bots);
      state.cwdWarningPhase = CwdWarningPhase.advisory;
    }
    notifyListeners();
  }

  /// The single hop primitive — the only function that ever moves a branch
  /// pointer (`docs/plans/message-loading-plan.md` §3). Sets the direction's
  /// loading marker, hydrates [chosenId] via [MessageStore], persists the
  /// pointer, then clears the marker. Used identically by [defaultPage]'s
  /// automatic hops, [revealStitch]'s forced hop, and navigator-driven
  /// explicit picks ([navigateOutgoing]/[navigateIncoming]) — only how
  /// [chosenId] was picked differs per caller.
  Future<void> selectCandidate(
    String columnId,
    String boundaryId,
    String chosenId,
    Direction direction,
  ) async {
    final state = _stateFor(columnId);
    _setLoading(state, direction, true);
    notifyListeners();
    await _store.load(chosenId);
    if (direction == Direction.outgoing) {
      await _columns.setBranchPointer(columnId, boundaryId, chosenId);
    } else {
      await _columns.setVisibleIncoming(columnId, boundaryId, chosenId);
    }
    _setLoading(state, direction, false);
    notifyListeners();
  }

  /// The only DB-loading/batching primitive. Resolves up to [batchSize] hops
  /// from [boundaryId] in [direction]: walks any already-persisted pointer
  /// for free, and only invokes [BranchPathService.resolveDefaultCandidate]
  /// (persisting via [selectCandidate]) once the walk reaches genuinely
  /// unset territory. Stops early at a stitch boundary (`hasMore: false`,
  /// `stitchCount` set — never auto-triggered, this is what "Load stitches
  /// (N)" renders) or a true end (`stitchCount: 0`).
  Future<PageResult> defaultPage(
    String columnId,
    String boundaryId,
    Direction direction,
    int batchSize,
  ) async {
    final messages = <Message>[];
    for (var i = 0; i < batchSize; i++) {
      final existing = direction == Direction.outgoing
          ? await _columns.getVisibleOutgoing(columnId, boundaryId)
          : await _columns.getVisibleIncoming(columnId, boundaryId);
      if (existing != null) {
        final message = await _store.load(existing);
        if (message == null) break;
        messages.add(message);
        boundaryId = message.id;
        continue;
      }

      final replyCandidate = await _branchPathService.resolveDefaultCandidate(
        boundaryId,
        direction,
      );
      if (replyCandidate == null) {
        final stitches = (await _branchPathService.candidatesAt(
          boundaryId,
          direction,
        )).stitchCandidates;
        return PageResult(
          messages: messages,
          hasMore: false,
          stitchCount: stitches.length,
        );
      }

      await selectCandidate(columnId, boundaryId, replyCandidate.id, direction);
      messages.add(replyCandidate);
      boundaryId = replyCandidate.id;
    }
    return PageResult(messages: messages, hasMore: true, stitchCount: 0);
  }

  /// Establishes the initial windowed view for a column showing an anchor
  /// it hasn't materialized before: [kDefaultRadius] hops of [defaultPage]
  /// in each direction from [anchorId]. Not a separate traversal — pure
  /// composition, kept as a named entry point only because it's a distinct
  /// `_refresh` trigger condition (a fresh anchor with nothing materialized).
  Future<void> loadInitialWindow(String columnId, String anchorId) async {
    await _store.load(anchorId);
    await defaultPage(columnId, anchorId, Direction.incoming, kDefaultRadius);
    await defaultPage(columnId, anchorId, Direction.outgoing, kDefaultRadius);
  }

  /// One forced hop across a stitch boundary (`AdaptiveMarker`'s "Load
  /// stitches (N)" action), then resumes the ordinary [defaultPage] loop
  /// from the new boundary to fill out the rest of the batch. Not a
  /// separate mode — one resolution override, then falls back into the
  /// ordinary loop.
  Future<void> revealStitch(
    String columnId,
    String boundaryId,
    Direction direction,
  ) async {
    final state = _stateFor(columnId);
    _setError(state, direction, null);
    try {
      final stitch = await _branchPathService.resolveForcedStitchCandidate(
        boundaryId,
        direction,
      );
      if (stitch == null) return;
      await selectCandidate(columnId, boundaryId, stitch.id, direction);
      await defaultPage(columnId, stitch.id, direction, kDefaultBatch);
    } catch (e) {
      _setError(state, direction, e.toString());
    } finally {
      await _refresh(columnId);
      notifyListeners();
    }
  }

  /// `AdaptiveMarker`'s scroll-proximity auto-trigger for the top/bottom
  /// "waiting" state: one [defaultPage] batch from the column's current
  /// top/bottom boundary.
  Future<void> extendAbove(String columnId) =>
      _extend(columnId, Direction.incoming);
  Future<void> extendBelow(String columnId) =>
      _extend(columnId, Direction.outgoing);

  Future<void> _extend(String columnId, Direction direction) async {
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    final boundaryId = direction == Direction.incoming
        ? state.rows.first.message.id
        : state.rows.last.message.id;
    _setError(state, direction, null);
    try {
      await defaultPage(columnId, boundaryId, direction, kDefaultBatch);
    } catch (e) {
      _setError(state, direction, e.toString());
    } finally {
      await _refresh(columnId);
      notifyListeners();
    }
  }

  void _setLoading(ColumnUiState state, Direction direction, bool value) {
    if (direction == Direction.incoming) {
      state.topLoading = value;
    } else {
      state.bottomLoading = value;
    }
  }

  void _setError(ColumnUiState state, Direction direction, String? message) {
    if (direction == Direction.incoming) {
      state.topError = message;
    } else {
      state.bottomError = message;
    }
  }

  /// Re-derives the column's branch from [parentId] itself rather than the
  /// column's original anchor once navigation has moved past it: [parentId]
  /// is safe to anchor on directly because its own upward context is
  /// untouched by this call, and its downward pointer was *just* set to the
  /// new child by [selectCandidate], so re-deriving from here (via
  /// `_refresh`'s ordinary `materializedTrajectory` walk) picks up that
  /// fresh pointer instead of recomputing a stale default.
  Future<void> navigateOutgoing(
    String columnId,
    String parentId, {
    required bool forward,
  }) async {
    final chosenId = await _branchPathService.resolveExplicitOutgoing(
      columnId,
      parentId,
      forward: forward,
    );
    if (chosenId != null) {
      await selectCandidate(columnId, parentId, chosenId, Direction.outgoing);
    }
    await _columns.updateColumnAnchor(columnId, parentId);
    _anchors[columnId] = parentId;
    await _refresh(columnId);
    notifyListeners();
  }

  /// Mirrors [navigateOutgoing]'s anchor-move for the upward direction:
  /// [childId] is safe to re-anchor on because its own downward pointer is
  /// untouched and [selectCandidate] just set its upward pointer to the new
  /// parent, so re-deriving from [childId] follows that fresh pointer
  /// instead of walking back down from the column's stale original anchor.
  Future<void> navigateIncoming(
    String columnId,
    String childId, {
    required bool forward,
  }) async {
    final chosenId = await _branchPathService.resolveExplicitIncoming(
      columnId,
      childId,
      forward: forward,
    );
    if (chosenId != null) {
      await selectCandidate(columnId, childId, chosenId, Direction.incoming);
    }
    await _columns.updateColumnAnchor(columnId, childId);
    _anchors[columnId] = childId;
    await _refresh(columnId);
    notifyListeners();
  }

  /// Marks [messageId] as the parent the next [sendMessage] call in
  /// [columnId] should reply under, overriding the default bottom-row
  /// target — set by a message's "reply to" action. Pass `null` to cancel
  /// and fall back to the default. Also activates [columnId]: replying is
  /// only actionable through the active column's composer, so triggering it
  /// from a non-active column (another visible branch) must switch focus
  /// there, same as clicking the column itself would.
  void setReplyTarget(String columnId, String? messageId) {
    for (final state in _states) {
      state.isActive = state.id == columnId;
    }
    _stateFor(columnId).replyingToMessageId = messageId;
    notifyListeners();
    unawaited(refreshCwdWarning(columnId));
  }

  /// Sends [content] as a reply under [columnId]'s pending reply target
  /// ([ColumnUiState.replyingToMessageId], set via [setReplyTarget]) if one
  /// is set, otherwise under the column's current bottom message (or as a
  /// fresh root if the column has no messages yet). Forking under a
  /// non-terminal target is a single [ColumnRepository.setBranchPointer]
  /// call away from also becoming the visible branch: that table is
  /// uniquely keyed on `(columnId, parentId)`, so pointing the fork
  /// message's pointer at the new message atomically both creates the
  /// branch and switches the column to it — no separate rewrite step is
  /// needed for ancestors, which are untouched, or for the new leaf, which
  /// has no descendants yet. Advances the column's persisted anchor to the
  /// new message either way — per column-ui-impl-plan.md §3, "the anchor is
  /// a persisted, moving reference point."
  ///
  /// When the content tags (or inherits) a known local bot, the visible
  /// branch through the reply target is sent to [_botBridge] and the reply
  /// is persisted under the trigger.
  Future<void> sendMessage(String columnId, String content) async {
    if (content.trim().isEmpty) return;
    final state = _stateFor(columnId);
    final parentId =
        state.replyingToMessageId ??
        (state.rows.isNotEmpty ? state.rows.last.message.id : null);
    final visibleBranch = state.rows.map((row) => row.message).toList(growable: false);
    final contextMessages = contextThroughReplyTarget(
      visibleBranch,
      replyTargetId: parentId,
    );
    final mentions = (_botBridge?.registry ?? const BotRegistry.empty()).parseMentions(content);

    StitchLog.hop(
      'dart.column',
      'send column=$columnId reply_to=$parentId visible=${visibleBranch.length} context=${contextMessages.length} mentions=${mentions.map((m) => m.botId).join(",")}',
    );

    final newMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      authorId: _identity.currentUserId,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
    await _messages.saveMessage(newMessage);

    if (parentId != null) {
      await _messages.addReplyEdge(parentId, newMessage.id);
      await _columns.setBranchPointer(columnId, parentId, newMessage.id);
    }

    // A reply inherits its parent's addressees (author + parent's own
    // recipients) so the whole thread stays addressed without requiring an
    // explicit @mention for everyone already in it — mirrors
    // stitch-frontend's syncReplySettings, minus its notify/ancestor-cascade
    // semantics, which this app doesn't model.
    final inherited = <String, RecipientKind>{};
    if (parentId != null) {
      Message? parentMessage;
      for (final row in state.rows) {
        if (row.message.id == parentId) {
          parentMessage = row.message;
          break;
        }
      }
      parentMessage ??= await _messages.getMessage(parentId);

      final parentAuthorId = parentMessage?.authorId;
      if (parentAuthorId != null && parentAuthorId != _identity.currentUserId) {
        inherited[parentAuthorId] =
            parentMessage!.role == MessageRole.localBot ? RecipientKind.localBot : RecipientKind.cloudUser;
      }
      for (final recipient in await _messages.getRecipients(parentId)) {
        if (recipient.recipientId != _identity.currentUserId) {
          inherited[recipient.recipientId] = recipient.kind;
        }
      }
      for (final entry in inherited.entries) {
        await _messages.addRecipientEdge(newMessage.id, entry.key, entry.value);
      }
    }

    for (final mention in mentions) {
      await _messages.addRecipientEdge(
        newMessage.id,
        mention.botId,
        RecipientKind.localBot,
      );
    }

    state.replyingToMessageId = null;
    await _columns.updateColumnAnchor(columnId, newMessage.id);
    _anchors[columnId] = newMessage.id;
    await _refresh(columnId);
    notifyListeners();
    StitchLog.hop('dart.column', 'persisted trigger id=${newMessage.id} parent=$parentId');

    // Dispatch is driven by the message's authoritative recipient set, not
    // by re-parsing the text — same principle as stitch-frontend (recipients
    // are the source of truth for who gets notified, not the literal
    // @mention string). This picks up bots inherited as recipients (e.g. the
    // parent message's bot author) even when this reply doesn't retype
    // "@bot".
    final botRecipientIds = <String>{
      ...mentions.map((m) => m.botId),
      for (final entry in inherited.entries)
        if (entry.value == RecipientKind.localBot) entry.key,
    };

    final bridge = _botBridge;
    if (bridge == null || botRecipientIds.isEmpty) {
      StitchLog.hop('dart.column', 'no bot dispatch bridge=${bridge != null} recipients=${botRecipientIds.length}');
      return;
    }

    final contextWindow = contextWindowIncludingTrigger(contextMessages, newMessage);
    final contextNodes = contextWindow.map(messageToContextNode).toList(growable: false);
    final cwd = state.cwd;
    final cwdMissing = cwd == null || cwd.isEmpty;
    final skippedForCwd = [
      for (final botId in botRecipientIds)
        if (cwdMissing && bridge.registry.requiresCwd(botId)) botId,
    ];
    if (skippedForCwd.isNotEmpty) {
      _showCwdSentWarning(state, skippedForCwd);
    } else {
      _composerDrafts[columnId] = '';
      unawaited(refreshCwdWarning(columnId));
    }

    for (final botId in botRecipientIds) {
      StitchLog.hop(
        'dart.column',
        '→bridge bot=$botId trigger=${newMessage.id} cwd=${cwd ?? "-"} context=${contextNodes.length}',
      );
      try {
        final reply = await bridge.invoke(
          botId: botId,
          triggerMessageId: newMessage.id,
          context: contextNodes,
          cwd: cwd,
        );
        if (reply.skipped) {
          StitchLog.hop(
            'dart.column',
            'bridge skipped bot=$botId reason=${reply.skipReason}',
          );
          continue;
        }
        await _persistBotReply(columnId, triggerId: newMessage.id, reply: reply);
        StitchLog.hop(
          'dart.column',
          'persisted bot reply id=${reply.messageId} parent=${newMessage.id} chars=${reply.content.length}',
        );
      } catch (e, st) {
        StitchLog.error(
          'column=$columnId bot=$botId failed',
          tag: 'dart.column',
          error: e,
          stackTrace: st,
        );
        _notifications?.showError('Bot $botId failed: $e');
      }
    }
  }

  Future<List<String>> _botsNeedingCwd(String columnId, String draft) async {
    final registry = _botBridge?.registry ?? const BotRegistry.empty();
    final state = _stateFor(columnId);
    final parentId =
        state.replyingToMessageId ?? (state.rows.isNotEmpty ? state.rows.last.message.id : null);

    final botIds = <String>{
      ...registry.parseMentions(draft).map((m) => m.botId),
    };

    if (parentId != null) {
      Message? parentMessage;
      for (final row in state.rows) {
        if (row.message.id == parentId) {
          parentMessage = row.message;
          break;
        }
      }
      parentMessage ??= await _messages.getMessage(parentId);
      final parentAuthorId = parentMessage?.authorId;
      if (parentAuthorId != null &&
          parentAuthorId != _identity.currentUserId &&
          parentMessage?.role == MessageRole.localBot) {
        botIds.add(parentAuthorId);
      }
      for (final recipient in await _messages.getRecipients(parentId)) {
        if (recipient.kind == RecipientKind.localBot &&
            recipient.recipientId != _identity.currentUserId) {
          botIds.add(recipient.recipientId);
        }
      }
    }

    return [
      for (final botId in botIds)
        if (registry.requiresCwd(botId)) botId,
    ];
  }

  void _clearCwdWarning(ColumnUiState state) {
    state.cwdWarningBotIds = const [];
    state.cwdWarningPhase = CwdWarningPhase.none;
  }

  void _showCwdSentWarning(ColumnUiState state, List<String> bots) {
    _cwdWarningFadeTimers[state.id]?.cancel();
    state.cwdWarningBotIds = List.unmodifiable(bots);
    state.cwdWarningPhase = CwdWarningPhase.sent;
    _composerDrafts[state.id] = '';
    notifyListeners();
    _cwdWarningFadeTimers[state.id] = Timer(_cwdWarningFadeDelay, () {
      if (!_states.any((s) => identical(s, state))) return;
      if (state.cwdWarningPhase != CwdWarningPhase.sent) return;
      _clearCwdWarning(state);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    for (final timer in _cwdWarningFadeTimers.values) {
      timer.cancel();
    }
    _cwdWarningFadeTimers.clear();
    super.dispose();
  }

  Future<void> _persistBotReply(
    String columnId, {
    required String triggerId,
    required BotBridgeReply reply,
  }) async {
    final botMessage = Message(
      id: reply.messageId,
      role: MessageRole.localBot,
      authorId: reply.botId,
      content: reply.content,
      createdAt: DateTime.now().toUtc(),
    );
    await _messages.saveMessage(botMessage);
    await _messages.addReplyEdge(triggerId, botMessage.id);
    await _columns.setBranchPointer(columnId, triggerId, botMessage.id);
    await _columns.updateColumnAnchor(columnId, botMessage.id);
    _anchors[columnId] = botMessage.id;
    await _refresh(columnId);
    notifyListeners();
  }

  ColumnUiState _stateFor(String id) => _states.firstWhere((s) => s.id == id);

  Future<void> _refresh(String columnId, {bool isFreshAnchor = false}) async {
    final state = _stateFor(columnId);
    final anchorId = _anchors[columnId];

    if (anchorId == null) {
      state.rows = const [];
      state.topMarker = MarkerVisualState.end;
      state.bottomMarker = MarkerVisualState.end;
      state.topStitchCount = 0;
      state.bottomStitchCount = 0;
      return;
    }

    if (isFreshAnchor) {
      await loadInitialWindow(columnId, anchorId);
    }

    final branch = await _branchPathService.materializedTrajectory(
      columnId,
      anchorId,
    );

    final rows = <MessageRowData>[];
    for (var i = 0; i < branch.length; i++) {
      final message = branch[i];

      // The outgoing pool belongs to the parent (previous row) — this
      // message just occupies one slot in it — but per stitch-frontend's
      // SiblingNavigator (mounted on the child with the parent passed in
      // only for lookup), the navigator itself attaches to *this* row.
      OutgoingEdges? outgoing;
      var outgoingIndex = -1;
      String? outgoingAnchorId;
      if (i > 0) {
        final parent = branch[i - 1];
        outgoing = await _messages.getOutgoing(parent.id);
        outgoingIndex = outgoing.all.indexWhere((m) => m.id == message.id);
        outgoingAnchorId = parent.id;
      }

      IncomingEdges? incoming;
      var incomingIndex = -1;
      if (i > 0) {
        incoming = await _messages.getIncoming(message.id);
        incomingIndex = incoming.all.indexWhere(
          (m) => m.id == branch[i - 1].id,
        );
      }

      rows.add(
        MessageRowData(
          message: message,
          outgoing: outgoing,
          outgoingCurrentIndex: outgoingIndex,
          outgoingAnchorId: outgoingAnchorId,
          incoming: incoming,
          incomingCurrentIndex: incomingIndex,
        ),
      );
    }
    state.rows = rows;

    if (branch.isEmpty) {
      state.topMarker = MarkerVisualState.end;
      state.bottomMarker = MarkerVisualState.end;
      state.topStitchCount = 0;
      state.bottomStitchCount = 0;
      return;
    }

    final top = await _branchPathService.candidatesAt(
      branch.first.id,
      Direction.incoming,
    );
    state.topStitchCount = top.stitchCandidates.length;
    state.topMarker = top.replyCandidate != null
        ? MarkerVisualState.waiting
        : MarkerVisualState.end;

    final bottom = await _branchPathService.candidatesAt(
      branch.last.id,
      Direction.outgoing,
    );
    state.bottomStitchCount = bottom.stitchCandidates.length;
    state.bottomMarker = bottom.replyCandidate != null
        ? MarkerVisualState.waiting
        : MarkerVisualState.end;
  }
}

/// Result of one [ColumnsViewModel.defaultPage] batch.
class PageResult {
  final List<Message> messages;
  final bool hasMore;
  final int stitchCount;
  const PageResult({
    required this.messages,
    required this.hasMore,
    required this.stitchCount,
  });
}
