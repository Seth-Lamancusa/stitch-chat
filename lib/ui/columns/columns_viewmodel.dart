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
import '../../data/services/mock_typing_cue.dart';
import '../../data/services/typing_cue_store.dart';
import '../../data/models/cloud_sync_status.dart';
import '../../data/models/message_tag.dart';
import '../../data/models/participant_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/cloud_message_api.dart';
import '../../data/services/cloud_user_directory.dart';
import '../../domain/bot_registry.dart';
import '../../domain/branch_path_service.dart';
import '../../domain/cloud_edge_reconciler.dart';
import '../../domain/cloud_send_guard.dart';
import '../../domain/context_chain.dart';
import '../../domain/draft_inline_tokens.dart';
import '../../domain/message_store.dart';
import '../core/adaptive_marker.dart';
import 'column_ui_state.dart';
import 'columns_display_mode.dart';

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
    TypingCueStore? typingCues,
    AuthRepository? auth,
    CloudMessageApi? cloudMessages,
    CloudUserDirectory? cloudUsers,
    this.mockTypingCues = false,
  }) : _botBridge = botBridge,
       _notifications = notifications,
       _auth = auth,
       _cloudMessages = cloudMessages,
       _cloudUsers = cloudUsers,
       typingCues = typingCues ?? TypingCueStore() {
    final bridge = _botBridge;
    if (bridge != null) {
      _cueSubscription = bridge.cues.listen(this.typingCues.apply);
      bridge.authStates.addListener(_onBridgeAuth);
    }
    this.typingCues.addListener(notifyListeners);
  }

  final MessageRepository _messages;
  final ColumnRepository _columns;
  final BranchPathService _branchPathService;
  final MessageStore _store;
  final LocalIdentityService _identity;
  final BotBridgeService? _botBridge;
  final NotificationService? _notifications;
  final AuthRepository? _auth;
  final CloudMessageApi? _cloudMessages;
  final CloudUserDirectory? _cloudUsers;
  final TypingCueStore typingCues;

  /// When true, honor `[[mockTyping:…]]` markers on message content as
  /// sticky typing chrome (see [MockTypingCue] / `STITCH_MOCK_TYPING_CUES`).
  final bool mockTypingCues;

  StreamSubscription<TypingCueEvent>? _cueSubscription;
  static const _uuid = Uuid();
  static const _cwdWarningFadeDelay = Duration(seconds: 4);

  final List<ColumnUiState> _states = [];
  final Map<String, String?> _anchors = {};
  final Map<String, String> _composerDrafts = {};
  final Map<String, Timer> _cwdWarningFadeTimers = {};
  final List<_HeldBotInvoke> _heldInvokes = [];

  /// Bots kept on the sign-in banner from the moment of send until the
  /// invoke is recorded. The composer clears first; without this the banner
  /// drops for the gap before a held invoke exists.
  final Map<String, Set<String>> _authPromptPins = {};
  bool _replayingHeld = false;
  final Map<String, DraftReplySettings> _draftSettings = {};
  final Map<String, _OutboundSend> _outboundSends = {};
  bool _closed = false;

  List<ColumnUiState> get columns => List.unmodifiable(_states);

  /// Absolute thread roots for the threads menu (reactive).
  Stream<List<Message>> watchThreadRoots() => _messages.watchThreadRoots();

  /// Stub — wire to open/navigate a column anchored at [root] later.
  void onThreadRootPreviewTap(Message root) {}

  ColumnsDisplayMode _displayMode = ColumnsDisplayMode.multi;

  ColumnsDisplayMode get displayMode => _displayMode;

  void setDisplayMode(ColumnsDisplayMode mode) {
    if (_displayMode == mode) return;
    _displayMode = mode;
    if (mode == ColumnsDisplayMode.single && _states.isNotEmpty) {
      setActiveColumn(_states.first.id);
    }
    notifyListeners();
  }

  void toggleDisplayMode() {
    setDisplayMode(
      _displayMode == ColumnsDisplayMode.multi
          ? ColumnsDisplayMode.single
          : ColumnsDisplayMode.multi,
    );
  }

  /// Authors currently typing a reply under [messageId] (live bridge cues).
  List<String> authorsTypingAt(String messageId) =>
      typingCues.authorsTypingAt(messageId);

  /// Live cues plus, when [mockTypingCues] is on, authors from a
  /// `[[mockTyping:…]]` marker on [message] content.
  List<String> typingAuthorsFor(Message message) {
    final live = authorsTypingAt(message.id);
    if (!mockTypingCues) return live;
    final mock = MockTypingCue.authorsOf(message.content);
    if (mock.isEmpty) return live;
    if (live.isEmpty) return List<String>.from(mock)..sort();
    return {...live, ...mock}.toList()..sort();
  }

  /// Who "You" refers to in the UI — cloud uid when signed in or after a prior
  /// login; otherwise the device-local uid until the user signs in once.
  String get currentUserId => _identity.currentUserId;

  bool get cloudFeaturesEnabled =>
      _auth?.state.isAuthenticated == true &&
      _cloudMessages != null &&
      _cloudUsers != null;

  BotRegistry get botRegistry =>
      _botBridge?.registry ?? const BotRegistry.empty();

  Future<ParticipantProfile?> participantProfile(String? uid) async {
    if (uid == null || uid.isEmpty) return null;
    return _messages.getParticipantProfile(uid);
  }

  /// Column-level cloud sync aggregate for the reply-connected tree.
  Future<ColumnCloudSyncState> cloudSyncStateFor(String columnId) async {
    final anchor = _anchors[columnId];
    if (anchor == null || !cloudFeaturesEnabled) {
      return ColumnCloudSyncState.idle;
    }
    final treeIds = await _branchPathService.replyTreeIds(anchor);
    var pending = false;
    var failed = false;
    for (final id in treeIds) {
      final msg = await _messages.getMessage(id);
      if (msg == null) continue;
      if (msg.syncStatus == CloudSyncStatus.pending) pending = true;
      if (msg.syncStatus == CloudSyncStatus.failed) failed = true;
    }
    if (failed) return ColumnCloudSyncState.failed;
    if (pending) return ColumnCloudSyncState.pending;
    return ColumnCloudSyncState.idle;
  }

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
      await refreshAuthPrompt(state.id);
    }
    notifyListeners();
  }

  /// Reloads every column's visible branch from storage — used after
  /// identity stamps change (local→cloud author promotion) so "You" labels
  /// and in-memory rows pick up the rewritten [Message.authorId]s.
  ///
  /// When signed in, also reconciles reply/stitch edges for every
  /// already-synced message on each column's visible branch (toolbar Refresh
  /// / post-auth catch-up). Bottom marker shows [ColumnUiState.bottomLoading]
  /// while that cloud pull runs.
  ///
  /// [reason] is a hop-log label (`auth`, `toolbar`, …).
  Future<void> reloadAll({String reason = 'reload'}) async {
    StitchLog.hop(
      'dart.cloud',
      'reloadAll start reason=$reason columns=${_states.length} '
          'cloud=${cloudFeaturesEnabled}',
    );
    for (final state in _states) {
      await _reloadColumn(state.id, reason: reason);
    }
    StitchLog.hop('dart.cloud', 'reloadAll done reason=$reason');
    notifyListeners();
  }

  Future<void> _reloadColumn(String columnId, {required String reason}) async {
    final state = _stateFor(columnId);
    final api = _cloudMessages;
    final anchorId = _anchors[columnId];
    final canReconcile =
        cloudFeaturesEnabled && api != null && anchorId != null;

    if (!cloudFeaturesEnabled) {
      StitchLog.hop(
        'dart.cloud',
        'reload column=$columnId reason=$reason skip=not-authenticated',
      );
    } else if (anchorId == null) {
      StitchLog.hop(
        'dart.cloud',
        'reload column=$columnId reason=$reason skip=no-anchor',
      );
    } else if (canReconcile) {
      final branch = await _branchPathService.materializedTrajectory(
        columnId,
        anchorId,
      );
      final syncedCount = branch
          .where(
            (m) =>
                m.syncStatus == CloudSyncStatus.synced &&
                m.cloudMessageId != null &&
                m.cloudMessageId!.isNotEmpty,
          )
          .length;
      StitchLog.hop(
        'dart.cloud',
        'reload column=$columnId reason=$reason branch=${branch.length} '
            'synced=$syncedCount',
      );
      if (syncedCount > 0) {
        state.bottomLoading = true;
        state.bottomError = null;
        notifyListeners();
        try {
          final reconciler = CloudEdgeReconciler(
            messages: _messages,
            fetchMessage: api.fetchMessage,
          );
          final changed = await reconciler.reconcileBranch(
            branch,
            columnId: columnId,
          );
          StitchLog.hop(
            'dart.cloud',
            'reload column=$columnId reason=$reason reconcileChanged=$changed',
          );
        } catch (e, st) {
          StitchLog.error(
            'cloud edge reconcile failed column=$columnId reason=$reason: $e',
            tag: 'cloud',
            error: e,
            stackTrace: st,
          );
          _notifications?.show(e.toString(), title: 'Cloud refresh failed');
        } finally {
          state.bottomLoading = false;
        }
      }
    }

    await _refresh(columnId);
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
      ColumnUiState(
        id: meta.id,
        width: meta.width,
        isActive: true,
        cwd: meta.cwd,
      ),
    );
    notifyListeners();
    await _refresh(meta.id, isFreshAnchor: true);
    await refreshAuthPrompt(meta.id);
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
    var changed = false;
    for (final state in _states) {
      final next = state.id == id;
      if (state.isActive != next) {
        state.isActive = next;
        changed = true;
      }
    }
    if (changed) notifyListeners();
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

  /// Per-column draft tags/recipients (list SSoT for compose + send).
  DraftReplySettings draftSettingsFor(String columnId) =>
      _draftSettings.putIfAbsent(columnId, DraftReplySettings.new);

  /// Highlight sets for the composer overlay (list-authoritative).
  Set<String> draftHighlightTags(String columnId) =>
      draftSettingsFor(columnId).tagSet;

  Set<String> draftHighlightMentions(String columnId) =>
      draftSettingsFor(columnId).mentionTagSet;

  /// Called as the composer draft changes: stage/reconcile tag & mention
  /// lists, then refresh the cwd advisory from prospective local-bot
  /// recipients (draft list + inherited).
  Future<void> onComposerDraftChanged(String columnId, String draft) {
    _composerDrafts[columnId] = draft;
    final registry = _botBridge?.registry ?? const BotRegistry.empty();
    applyDraftContentChange(
      draftSettingsFor(columnId),
      draft,
      botIdForTag: registry.botIdForTag,
    );
    notifyListeners();
    return Future.wait([
      refreshCwdWarning(columnId),
      refreshAuthPrompt(columnId),
    ]);
  }

  /// Autocomplete pick: insert already happened in the composer; stage the
  /// recipient into the draft list (cloud or local).
  void ensureComposerMention({
    required String columnId,
    required String recipientId,
    required RecipientKind kind,
    String? userTag,
    bool isCloudBot = false,
    ParticipantProfile? profile,
  }) {
    if (profile != null) {
      unawaited(_messages.upsertParticipantProfile(profile));
    }
    ensureDraftRecipient(
      draftSettingsFor(columnId),
      DraftRecipient(
        recipientId: recipientId,
        kind: kind,
        userTag: userTag ?? profile?.userTag,
        isCloudBot: isCloudBot || (profile?.isBot ?? false),
      ),
    );
    notifyListeners();
    unawaited(refreshCwdWarning(columnId));
  }

  /// Drop a staged draft recipient. Content is not rewritten (same as
  /// stitch-frontend ReplyBox / [DraftReplySettings] contract).
  void removeDraftRecipient(String columnId, String recipientId) {
    final draft = draftSettingsFor(columnId);
    final index = draft.recipients.indexWhere(
      (r) => r.recipientId == recipientId,
    );
    if (index < 0) return;
    final removed = draft.recipients.removeAt(index);
    final tag = removed.normalizedTag;
    if (tag != null) {
      draft.inlineTrackedRecipientTags.remove(tag);
    }
    noteReplyParentRecipientRemoved(draft, recipientId);
    notifyListeners();
    unawaited(refreshCwdWarning(columnId));
  }

  /// Effective reply parent for [columnId]: explicit target, else column tip.
  String? _effectiveReplyParentId(String columnId) {
    final state = _stateFor(columnId);
    return state.replyingToMessageId ??
        (state.rows.isNotEmpty ? state.rows.last.message.id : null);
  }

  /// Reply-parent id to keep visually fixed across a mid-thread fork send, or
  /// `null` when send will not relocate the scroll center onto a junction
  /// (tip append / empty column). Mirrors [navigateOutgoing]'s pin target so
  /// the UI can wrap [sendMessage] in the same viewport-Y correction.
  String? scrollPinParentForSend(String columnId) {
    final parentId = _effectiveReplyParentId(columnId);
    if (parentId == null) return null;
    final state = _stateFor(columnId);
    final parentIndex = state.rows.indexWhere(
      (row) => row.message.id == parentId,
    );
    if (parentIndex < 0 || parentIndex >= state.rows.length - 1) {
      return null;
    }
    return parentId;
  }

  /// Fold the reply-parent author into [DraftReplySettings.recipients] so the
  /// Recipients pill shows them before send (same list send reads).
  Future<void> _syncReplyParentDraftRecipient(String columnId) async {
    final draft = draftSettingsFor(columnId);
    final parentId = _effectiveReplyParentId(columnId);

    Message? parentMessage;
    if (parentId != null) {
      for (final row in _stateFor(columnId).rows) {
        if (row.message.id == parentId) {
          parentMessage = row.message;
          break;
        }
      }
      parentMessage ??= await _messages.getMessage(parentId);
    }

    final authorId = parentMessage?.authorId;
    var kind = RecipientKind.cloudUser;
    String? userTag;
    var isCloudBot = false;
    if (parentMessage != null &&
        authorId != null &&
        authorId != _identity.currentUserId) {
      if (parentMessage.role == MessageRole.localBot) {
        kind = RecipientKind.localBot;
        userTag = authorId;
      } else {
        final profile = await _messages.getParticipantProfile(authorId);
        userTag = profile?.userTag;
        isCloudBot = profile?.isBot ?? false;
      }
    }

    syncReplyParentAuthor(
      draft,
      parentMessageId: parentId,
      authorId: authorId,
      currentUserId: _identity.currentUserId,
      kind: kind,
      userTag: userTag,
      isCloudBot: isCloudBot,
    );
  }

  /// Keeps the current sign-in banner up across the composer clear that
  /// happens before [sendMessage] records a held invoke.
  void retainAuthPromptsAcrossSend(String columnId) {
    if (!_states.any((s) => s.id == columnId)) return;
    final bots = {
      for (final prompt in _stateFor(columnId).authPrompts) prompt.botId,
    };
    if (bots.isEmpty) {
      _authPromptPins.remove(columnId);
      return;
    }
    _authPromptPins[columnId] = bots;
  }

  /// Recomputes the advisory banner above the reply box. No-ops while a
  /// post-send confirmation is still showing.
  Future<void> refreshCwdWarning(String columnId) async {
    if (_closed || !_states.any((s) => s.id == columnId)) return;
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
    if (_closed) return;
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
    await _refresh(columnId, anchorMessageId: parentId);
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
    await _refresh(columnId, anchorMessageId: childId);
    notifyListeners();
  }

  /// Marker entry point for a stitch boundary above the current top row.
  Future<void> loadStitchAbove(String columnId) async {
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    await revealStitch(
      columnId,
      state.rows.first.message.id,
      Direction.incoming,
    );
  }

  /// Marker entry point for a stitch boundary below the current bottom row.
  Future<void> loadStitchBelow(String columnId) async {
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    await revealStitch(
      columnId,
      state.rows.last.message.id,
      Direction.outgoing,
    );
  }

  /// Reveal the first hidden-reply parent above the top boundary.
  Future<void> loadHiddenAbove(String columnId) =>
      _revealHidden(columnId, Direction.incoming);

  /// Reveal the first hidden-reply child below the bottom boundary.
  Future<void> loadHiddenBelow(String columnId) =>
      _revealHidden(columnId, Direction.outgoing);

  /// One forced hop across a hidden-reply boundary, then a normal
  /// [defaultPage] batch from the newly revealed node. Mirrors
  /// [revealStitch] for hidden edges, which [defaultPage] never auto-follows.
  Future<void> _revealHidden(String columnId, Direction direction) async {
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    final boundaryId = direction == Direction.incoming
        ? state.rows.first.message.id
        : state.rows.last.message.id;
    _setError(state, direction, null);
    try {
      final hidden = direction == Direction.incoming
          ? (await _messages.getIncoming(boundaryId)).hiddenReplyIncoming
          : (await _messages.getOutgoing(boundaryId)).hiddenReplyOutgoing;
      if (hidden.isEmpty) return;
      final chosen = hidden.first;
      await selectCandidate(columnId, boundaryId, chosen.id, direction);
      await defaultPage(columnId, chosen.id, direction, kDefaultBatch);
    } catch (e) {
      _setError(state, direction, e.toString());
    } finally {
      await _refresh(columnId);
      notifyListeners();
    }
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
    unawaited(() async {
      if (_closed) return;
      await _syncReplyParentDraftRecipient(columnId);
      if (_closed) return;
      notifyListeners();
      await refreshCwdWarning(columnId);
      await refreshAuthPrompt(columnId);
    }());
  }

  /// Sends [content] as a reply under [columnId]'s pending reply target
  /// ([ColumnUiState.replyingToMessageId], set via [setReplyTarget]) if one
  /// is set, otherwise under the column's current bottom message (or as a
  /// fresh root if the column has no messages yet).
  ///
  /// Optimistically appends the trigger ([Message.isSending]), then persists
  /// locally and notifies cloud. Returns `true` when the local row was kept.
  /// Returns `false` when send was blocked or rolled back — draft lists stay
  /// intact so the composer can restore the field.
  ///
  /// A bot that still needs sign-in is held and replayed by [_invokeBot]
  /// after `agent login` completes.
  Future<bool> sendMessage(String columnId, String content) async {
    try {
      return await _sendMessage(columnId, content);
    } finally {
      if (_authPromptPins.remove(columnId) != null) {
        await refreshAuthPrompt(columnId);
      }
    }
  }

  Future<bool> _sendMessage(String columnId, String content) async {
    if (content.trim().isEmpty) return false;
    final state = _stateFor(columnId);
    final parentId = _effectiveReplyParentId(columnId);
    final visibleBranch = state.rows
        .map((row) => row.message)
        .toList(growable: false);
    final contextMessages = contextThroughReplyTarget(
      visibleBranch,
      replyTargetId: parentId,
    );
    final registry = _botBridge?.registry ?? const BotRegistry.empty();
    final draft = draftSettingsFor(columnId);
    applyDraftContentChange(
      draft,
      content,
      botIdForTag: registry.botIdForTag,
      allowTerminalBoundary: true,
    );
    _stageReplyParentAuthorFromRows(columnId);
    final tagNames = List<String>.from(draft.tags);
    final draftRecipients = List<DraftRecipient>.from(draft.recipients);

    final parentIndex = parentId == null
        ? -1
        : state.rows.indexWhere((r) => r.message.id == parentId);
    final forksVisibleChild =
        parentIndex >= 0 && parentIndex < state.rows.length - 1;

    Message? parentMessage;
    ParticipantProfile? parentAuthorProfile;
    if (parentId != null && parentIndex >= 0) {
      parentMessage = state.rows[parentIndex].message;
      parentAuthorProfile = state.rows[parentIndex].authorProfile;
    }

    final newMessage = Message(
      id: _uuid.v4(),
      role: MessageRole.user,
      authorId: _identity.currentUserId,
      content: content,
      createdAt: DateTime.now().toUtc(),
      isSending: true,
    );
    final highlightMentions = <String>{
      for (final d in draftRecipients)
        if (d.userTag != null && d.userTag!.trim().isNotEmpty)
          d.userTag!.trim(),
    };
    final highlightTags = tagNames.toSet();
    _beginOutboundSend(
      _OutboundSend(
        columnId: columnId,
        parentId: parentId,
        message: newMessage,
        highlightMentions: highlightMentions,
        highlightTags: highlightTags,
      ),
    );
    notifyListeners();

    parentMessage ??= parentId == null
        ? null
        : await _messages.getMessage(parentId);

    final recipientById = <String, RecipientRef>{};
    if (parentId != null) {
      for (final recipient in await _messages.getRecipients(parentId)) {
        if (recipient.recipientId == _identity.currentUserId) continue;
        recipientById[recipient.recipientId] = RecipientRef(
          recipientId: recipient.recipientId,
          kind: recipient.kind,
          isCloudBot: recipient.isCloudBot,
          isPublic: recipient.isPublic,
          notify: recipient.notify,
          addedBy: _identity.currentUserId,
        );
      }
    }

    for (final d in draftRecipients) {
      if (d.kind == RecipientKind.cloudUser) {
        var profile = await _messages.getParticipantProfile(d.recipientId);
        if (profile == null && d.userTag != null) {
          final directory = _cloudUsers;
          if (directory != null) {
            profile = await directory.findByUserTag(d.userTag!);
          }
          await _messages.upsertParticipantProfile(
            profile ??
                ParticipantProfile(
                  uid: d.recipientId,
                  userTag: d.userTag,
                  isBot: d.isCloudBot,
                ),
          );
        }
      }
      recipientById[d.recipientId] = RecipientRef(
        recipientId: d.recipientId,
        kind: d.kind,
        isCloudBot: d.isCloudBot,
        isPublic: d.isPublic,
        notify: d.notify,
        addedBy: _identity.currentUserId,
      );
    }

    final recipientRefs = recipientById.values.toList(growable: false);

    StitchLog.hop(
      'dart.column',
      'send column=$columnId reply_to=$parentId visible=${visibleBranch.length} '
          'context=${contextMessages.length} '
          'recipients=${recipientRefs.map((r) => r.recipientId).join(",")} '
          'tags=${tagNames.join(",")}',
    );

    final addressesCloudBot = CloudSendGuard.addressesCloudBot(recipientRefs);
    final guardError = CloudSendGuard.blockReasonForCloudBotReply(
      parentLocalId: parentId,
      parentMessage: parentMessage,
      addressesCloudBot: addressesCloudBot,
    );
    if (guardError != null) {
      _cancelOutboundSend(newMessage.id);
      _notifications?.showError(guardError);
      notifyListeners();
      return false;
    }

    final cloudNotify = CloudSendGuard.cloudNotifyRecipients(recipientRefs);
    final needsCloudPost = cloudFeaturesEnabled && cloudNotify.isNotEmpty;
    if (needsCloudPost && _auth!.state.cloudUserId == null) {
      _cancelOutboundSend(newMessage.id);
      _notifications?.showError('Sign in to notify Stitch cloud recipients.');
      notifyListeners();
      return false;
    }

    String? parentCloudId;
    if (needsCloudPost && parentId != null) {
      parentCloudId = parentMessage?.cloudMessageId;
      if (parentCloudId == null || parentCloudId.isEmpty) {
        _cancelOutboundSend(newMessage.id);
        _notifications?.showError(
          'Reply parent is not synced to Stitch cloud.',
        );
        notifyListeners();
        return false;
      }
    }

    final persistMessage = newMessage.copyWith(
      isSending: false,
      syncStatus: needsCloudPost
          ? CloudSyncStatus.pending
          : CloudSyncStatus.none,
    );
    await _messages.saveMessage(persistMessage);

    if (parentId != null) {
      await _messages.addReplyEdge(parentId, newMessage.id);
      await _columns.setBranchPointer(columnId, parentId, newMessage.id);
    }

    final now = DateTime.now().toUtc();
    await _messages.setMessageTags(newMessage.id, [
      for (final name in tagNames)
        MessageTag(
          name: name,
          createdAt: now,
          addedBy: _identity.currentUserId,
        ),
    ]);

    for (final ref in recipientRefs) {
      await _messages.addRecipientEdge(
        newMessage.id,
        ref.recipientId,
        ref.kind,
        isCloudBot: ref.isCloudBot,
        isPublic: ref.isPublic,
        notify: ref.notify,
        addedBy: ref.addedBy,
      );
    }

    if (needsCloudPost) {
      final cloudInputs = [
        for (final r in cloudNotify)
          CloudRecipientInput(
            uid: r.recipientId,
            notify: r.notify,
            isPublic: r.isPublic,
          ),
      ];
      final profileByAuthor = <String, ParticipantProfile?>{};
      for (final m in contextMessages) {
        final authorId = m.authorId;
        if (authorId == null || authorId.isEmpty) continue;
        if (profileByAuthor.containsKey(authorId)) continue;
        profileByAuthor[authorId] = await _messages.getParticipantProfile(
          authorId,
        );
      }
      final parentAuthorId = parentMessage?.authorId;
      if (parentAuthorId != null &&
          parentAuthorId.isNotEmpty &&
          !profileByAuthor.containsKey(parentAuthorId)) {
        profileByAuthor[parentAuthorId] =
            parentAuthorProfile ??
            await _messages.getParticipantProfile(parentAuthorId);
      }
      final cloudContext = messagesToCloudContext(
        contextMessages,
        profileFor: (authorId) => profileByAuthor[authorId],
      );
      final result = await _cloudMessages!.createMessage(
        content: content,
        parentCloudMessageId: parentCloudId,
        cloudRecipients: cloudInputs,
        tags: tagNames,
        context: cloudContext,
      );
      if (!result.success) {
        _outboundSends.remove(newMessage.id);
        await _messages.deleteMessage(newMessage.id);
        _notifications?.showError(result.error ?? 'Cloud notification failed.');
        await _refresh(columnId);
        notifyListeners();
        return false;
      }
      await _messages.updateCloudSync(
        localMessageId: newMessage.id,
        syncStatus: CloudSyncStatus.synced,
        cloudMessageId: result.cloudMessageId,
        syncError: null,
      );
    }

    _outboundSends.remove(newMessage.id);
    draft.clear();
    _composerDrafts[columnId] = '';

    state.replyingToMessageId = null;
    if (_anchors[columnId] == null) {
      await _columns.updateColumnAnchor(columnId, newMessage.id);
      await _refresh(columnId, anchorMessageId: newMessage.id);
    } else if (forksVisibleChild) {
      await _columns.updateColumnAnchor(columnId, parentId!);
      await _refresh(columnId, anchorMessageId: parentId);
    } else {
      await _refresh(columnId);
    }
    notifyListeners();
    StitchLog.hop(
      'dart.column',
      'persisted trigger id=${newMessage.id} parent=$parentId',
    );

    final botRecipientIds = <String>{
      for (final ref in recipientRefs)
        if (ref.kind == RecipientKind.localBot) ref.recipientId,
    };

    final bridge = _botBridge;
    if (bridge == null || botRecipientIds.isEmpty) {
      StitchLog.hop(
        'dart.column',
        'no bot dispatch bridge=${bridge != null} recipients=${botRecipientIds.length}',
      );
      return true;
    }

    final contextWindow = contextWindowIncludingTrigger(
      contextMessages,
      newMessage,
    );
    final contextNodes = contextWindow
        .map(messageToContextNode)
        .toList(growable: false);
    final cwd = state.cwd;
    final cwdMissing = cwd == null || cwd.isEmpty;
    final skippedForCwd = [
      for (final botId in botRecipientIds)
        if (cwdMissing && bridge.registry.requiresCwd(botId)) botId,
    ];
    if (skippedForCwd.isNotEmpty) {
      _showCwdSentWarning(state, skippedForCwd);
    } else {
      unawaited(refreshCwdWarning(columnId));
    }

    for (final botId in botRecipientIds) {
      await _invokeBot(
        columnId: columnId,
        botId: botId,
        triggerId: newMessage.id,
        context: contextNodes,
        cwd: cwd,
      );
    }
    return true;
  }

  Future<void> _invokeBot({
    required String columnId,
    required String botId,
    required String triggerId,
    required List<Map<String, dynamic>> context,
    required String? cwd,
  }) async {
    final bridge = _botBridge;
    if (bridge == null) return;
    StitchLog.hop(
      'dart.column',
      '→bridge bot=$botId trigger=$triggerId cwd=${cwd ?? "-"} context=${context.length}',
    );
    try {
      final reply = await bridge.invoke(
        botId: botId,
        triggerMessageId: triggerId,
        context: context,
        cwd: cwd,
        onPart: (part) async {
          await _persistBotPart(columnId, part: part);
          StitchLog.hop(
            'dart.column',
            'persisted bot part id=${part.messageId} parent=${part.parentMessageId} role=${part.role.name} final=${part.isFinal}',
          );
        },
      );
      if (reply.skipped && reply.skipReason == 'requires_auth') {
        _heldInvokes.removeWhere(
          (held) => held.triggerId == triggerId && held.botId == botId,
        );
        _heldInvokes.add(
          _HeldBotInvoke(
            columnId: columnId,
            triggerId: triggerId,
            botId: botId,
            context: context,
            cwd: cwd,
          ),
        );
        StitchLog.hop(
          'dart.column',
          'held invoke bot=$botId trigger=$triggerId reason=requires_auth',
        );
        await refreshAuthPrompt(columnId);
        return;
      }
      if (reply.skipped) {
        StitchLog.hop(
          'dart.column',
          'bridge skipped bot=$botId reason=${reply.skipReason}',
        );
      }
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

  /// Asks the bridge to run [botId]'s own sign-in. The handler decides the
  /// command; for Cursor that is `agent login`, which opens the system browser.
  void beginBotAuth(String botId) {
    final bridge = _botBridge;
    if (bridge == null) return;
    try {
      bridge.beginAuth(botId);
    } catch (e) {
      _notifications?.showError('Could not start sign-in: $e');
    }
  }

  void _onBridgeAuth() {
    unawaited(_replayHeldInvokes());
    for (final state in _states) {
      unawaited(refreshAuthPrompt(state.id));
    }
  }

  Future<void> _replayHeldInvokes() async {
    if (_replayingHeld) return;
    final bridge = _botBridge;
    if (bridge == null) return;
    final ready = [
      for (final held in List<_HeldBotInvoke>.of(_heldInvokes))
        if (bridge.authStates.value[held.botId]?.state == 'authenticated') held,
    ];
    if (ready.isEmpty) return;
    _replayingHeld = true;
    try {
      for (final held in ready) {
        _heldInvokes.remove(held);
      }
      for (final held in ready) {
        await _invokeBot(
          columnId: held.columnId,
          botId: held.botId,
          triggerId: held.triggerId,
          context: held.context,
          cwd: held.cwd,
        );
      }
      for (final columnId in ready.map((held) => held.columnId).toSet()) {
        await refreshAuthPrompt(columnId);
      }
    } finally {
      _replayingHeld = false;
    }
  }

  /// Recomputes the sign-in banner for bots this column is addressing that
  /// are not authenticated. Held invokes keep the banner up after the draft
  /// is cleared.
  Future<void> refreshAuthPrompt(String columnId) async {
    if (_closed || !_states.any((s) => s.id == columnId)) return;
    final state = _stateFor(columnId);
    final registry = _botBridge?.registry ?? const BotRegistry.empty();
    final draft = _composerDrafts[columnId] ?? '';
    final addressed = await _addressedBotIds(columnId, draft);
    for (final held in _heldInvokes) {
      if (held.columnId == columnId) addressed.add(held.botId);
    }
    for (final botId in _authPromptPins[columnId] ?? const <String>{}) {
      addressed.add(botId);
    }
    final snapshots = _botBridge?.authStates.value ?? const {};
    final prompts = <BotAuthPrompt>[
      for (final botId in addressed)
        if (registry.requiresAuth(botId))
          if (snapshots[botId] case final snap?)
            if (snap.needsPrompt)
              BotAuthPrompt(
                botId: botId,
                state: snap.state,
                detail: snap.detail,
              ),
    ];
    state.authPrompts = List.unmodifiable(prompts);
    if (_closed) return;
    notifyListeners();
  }

  Future<List<String>> _botsNeedingCwd(String columnId, String draft) async {
    final registry = _botBridge?.registry ?? const BotRegistry.empty();
    final botIds = await _addressedBotIds(columnId, draft);
    for (final recipient in draftSettingsFor(columnId).recipients) {
      if (recipient.kind == RecipientKind.localBot) {
        botIds.add(recipient.recipientId);
      }
    }
    return [
      for (final botId in botIds)
        if (registry.requiresCwd(botId)) botId,
    ];
  }

  /// Mentions in [draft] plus local bots inherited from the reply parent.
  Future<Set<String>> _addressedBotIds(String columnId, String draft) async {
    final registry = _botBridge?.registry ?? const BotRegistry.empty();
    final state = _stateFor(columnId);
    final parentId =
        state.replyingToMessageId ??
        (state.rows.isNotEmpty ? state.rows.last.message.id : null);

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

    return botIds;
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
    _closed = true;
    for (final timer in _cwdWarningFadeTimers.values) {
      timer.cancel();
    }
    _cwdWarningFadeTimers.clear();
    _cueSubscription?.cancel();
    _botBridge?.authStates.removeListener(_onBridgeAuth);
    typingCues.removeListener(notifyListeners);
    typingCues.dispose();
    super.dispose();
  }

  /// Persists a bot part into the message graph and refreshes the column.
  /// A non-hidden reply that is the default child of the current tip is
  /// materialized via [defaultPage] so the column shows it without a scroll.
  /// An already-chosen fork is left alone (and may toast). The scroll-center
  /// anchor is not moved.
  Future<void> _persistBotPart(
    String columnId, {
    required BotBridgePart part,
  }) async {
    final botMessage = Message(
      id: part.messageId,
      role: part.role,
      authorId: part.botId,
      content: part.content,
      createdAt: DateTime.now().toUtc(),
    );
    await ingestIncomingMessage(
      columnId: columnId,
      message: botMessage,
      parentId: part.parentMessageId,
      hidden: part.hidden,
    );
  }

  /// Shared ingest for local-bot parts and (later) cloud WS arrivals.
  /// Toasts when an eligible reply (`user` / `localBot`) attaches under the
  /// column's reply tree but would not appear on the current visible branch
  /// — thinking/tool roles stay silent.
  ///
  /// A non-hidden reply that is the default child of this column's current
  /// tip is materialized here, before that check, via [defaultPage]. Hidden
  /// side-fork roots are not candidates, and an existing outgoing pointer is
  /// left alone.
  Future<void> ingestIncomingMessage({
    required String columnId,
    required Message message,
    required String parentId,
    bool hidden = false,
    bool notifyIfOffPath = true,
  }) async {
    await _messages.saveMessage(message);
    await _messages.addReplyEdge(parentId, message.id, hidden: hidden);
    await _materializeIncomingTip(
      columnId,
      parentId: parentId,
      messageId: message.id,
      hidden: hidden,
    );

    if (notifyIfOffPath && _isToastEligibleRole(message.role)) {
      final anchorId = _anchors[columnId];
      if (anchorId != null) {
        final treeIds = await _branchPathService.replyTreeIds(anchorId);
        // Parent was already in the tree before this edge; the new child is
        // not required to be — we're notifying about its arrival.
        final parentInTree = treeIds.contains(parentId);
        final landsOnVisible =
            parentInTree &&
            await _branchPathService.wouldLandOnVisibleBranch(
              columnId,
              anchorId,
              parentId,
              message.id,
            );
        if (parentInTree && !landsOnVisible) {
          final author = message.authorId ?? 'Someone';
          final content = message.content;
          final preview = content.length > 60
              ? '${content.substring(0, 60)}...'
              : content;
          _notifications?.show(
            preview.isEmpty ? 'New message' : preview,
            title: 'New message from $author',
            onTap: () => _jumpToOffPathMessage(
              columnId: columnId,
              parentId: parentId,
              messageId: message.id,
            ),
          );
        }
      }
    }

    await _refresh(columnId);
    notifyListeners();
  }

  /// Writes the visible outgoing pointer when [messageId] is the default
  /// non-hidden reply under this column's materialized tip.
  ///
  /// [defaultPage] is the same hop [extendBelow] takes on scroll: it follows
  /// an existing pointer, selects [BranchPathService.resolveDefaultCandidate]
  /// only in unset territory, and continues along already-saved default
  /// children up to [kDefaultBatch]. A hidden part never enters that
  /// candidate pool, so a side fork stays behind "Reveal hidden thread"
  /// until a normal reply occupies the slot.
  Future<void> _materializeIncomingTip(
    String columnId, {
    required String parentId,
    required String messageId,
    required bool hidden,
  }) async {
    if (hidden) return;
    final state = _stateFor(columnId);
    if (state.rows.isEmpty) return;
    if (state.rows.last.message.id != parentId) return;
    if (await _columns.getVisibleOutgoing(columnId, parentId) != null) return;

    final candidate = await _branchPathService.resolveDefaultCandidate(
      parentId,
      Direction.outgoing,
    );
    if (candidate?.id != messageId) return;

    await defaultPage(columnId, parentId, Direction.outgoing, kDefaultBatch);
  }

  static bool _isToastEligibleRole(MessageRole role) =>
      role == MessageRole.user || role == MessageRole.localBot;

  Future<void> _jumpToOffPathMessage({
    required String columnId,
    required String parentId,
    required String messageId,
  }) async {
    await _columns.setBranchPointer(columnId, parentId, messageId);
    await _columns.updateColumnAnchor(columnId, messageId);
    await _refresh(columnId, anchorMessageId: messageId);
    notifyListeners();
  }

  ColumnUiState _stateFor(String id) => _states.firstWhere((s) => s.id == id);

  /// Re-derives [columnId]'s rows from [anchorMessageId] (or the current
  /// in-memory anchor). All awaits finish first; `_anchors` and `state.rows`
  /// flip together in one synchronous commit so a cue-driven rebuild never
  /// sees a new anchor against stale rows.
  ///
  /// [isFreshAnchor] materializes the initial window before the pointer walk
  /// — a column showing an anchor it has not materialized before.
  Future<void> _refresh(
    String columnId, {
    String? anchorMessageId,
    bool isFreshAnchor = false,
  }) async {
    final state = _stateFor(columnId);
    final anchorId = anchorMessageId ?? _anchors[columnId];

    if (anchorId == null) {
      state.rows = const [];
      state.columnCloudSync = ColumnCloudSyncState.idle;
      state.topMarker = MarkerVisualState.end;
      state.bottomMarker = MarkerVisualState.end;
      state.topStitchCount = 0;
      state.bottomStitchCount = 0;
      state.topHiddenCount = 0;
      state.bottomHiddenCount = 0;
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

      final mentionTags = cloudFeaturesEnabled
          ? await validMentionTagsFor(message)
          : const <String>{};
      final hashTags = cloudFeaturesEnabled
          ? await validHashTagsFor(message)
          : const <String>{};
      final authorProfile = await participantProfile(message.authorId);

      rows.add(
        MessageRowData(
          message: message,
          outgoing: outgoing,
          outgoingCurrentIndex: outgoingIndex,
          outgoingAnchorId: outgoingAnchorId,
          incoming: incoming,
          incomingCurrentIndex: incomingIndex,
          highlightMentions: mentionTags,
          highlightTags: hashTags,
          authorProfile: authorProfile,
        ),
      );
    }

    var topStitchCount = 0;
    var bottomStitchCount = 0;
    var topHiddenCount = 0;
    var bottomHiddenCount = 0;
    var topMarker = MarkerVisualState.end;
    var bottomMarker = MarkerVisualState.end;
    if (branch.isNotEmpty) {
      // A reply candidate means the window can still extend (waiting).
      // Stitch and hidden counts surface only at a reply dead-end.
      final top = await _branchPathService.candidatesAt(
        branch.first.id,
        Direction.incoming,
      );
      topStitchCount = top.stitchCandidates.length;
      topMarker = top.replyCandidate != null
          ? MarkerVisualState.waiting
          : MarkerVisualState.end;
      if (top.replyCandidate == null) {
        topHiddenCount = (await _messages.getIncoming(
          branch.first.id,
        )).hiddenReplyIncoming.length;
      }

      final bottom = await _branchPathService.candidatesAt(
        branch.last.id,
        Direction.outgoing,
      );
      bottomStitchCount = bottom.stitchCandidates.length;
      bottomMarker = bottom.replyCandidate != null
          ? MarkerVisualState.waiting
          : MarkerVisualState.end;
      if (bottom.replyCandidate == null) {
        bottomHiddenCount = (await _messages.getOutgoing(
          branch.last.id,
        )).hiddenReplyOutgoing.length;
      }
    }

    if (anchorMessageId != null) {
      _anchors[columnId] = anchorMessageId;
    }
    state.rows = rows;
    _reapplyOutboundSends(columnId);
    state.columnCloudSync = cloudFeaturesEnabled
        ? await _computeColumnCloudSync(anchorId)
        : ColumnCloudSyncState.idle;
    await _syncReplyParentDraftRecipient(columnId);
    state.topMarker = topMarker;
    state.bottomMarker = bottomMarker;
    state.topStitchCount = topStitchCount;
    state.bottomStitchCount = bottomStitchCount;
    state.topHiddenCount = topHiddenCount;
    state.bottomHiddenCount = bottomHiddenCount;
  }

  /// Ingest a Stitch cloud WS/API message into the best-matching column.
  Future<void> handleCloudWireMessage(Map<String, dynamic> json) async {
    final cloudId = json['id'] as String?;
    if (cloudId == null || cloudId.isEmpty) return;

    if (await _messages.getMessage(cloudId) != null) return;
    if (await _messages.getMessageByCloudId(cloudId) != null) return;

    final profile = CloudMessageMapper.authorProfileFromWire(json);
    if (profile != null) {
      await _messages.upsertParticipantProfile(profile);
    }

    final parentCloud = json['parent_id'] as String?;
    String? parentGraphId;
    if (parentCloud != null && parentCloud.isNotEmpty) {
      parentGraphId = await _messages.resolveGraphMessageId(parentCloud);
      if (parentGraphId == null) {
        StitchLog.hop(
          'dart.cloud',
          'skip ingest id=$cloudId unknown parent=$parentCloud',
        );
        return;
      }
    }

    final columnId = parentGraphId == null
        ? (_activeColumnId ?? (_states.isNotEmpty ? _states.first.id : null))
        : await _columnForIncomingParent(parentGraphId);
    if (columnId == null) return;

    final message = CloudMessageMapper.messageFromWire(json);
    // Persist message + list enrichment before any refresh so highlights
    // derive from tags/recipients on first paint.
    await _messages.saveMessage(message);
    await _persistWireEnrichment(message.id, json);

    if (parentGraphId == null) {
      await _columns.updateColumnAnchor(columnId, message.id);
      await _refresh(columnId, anchorMessageId: message.id);
      notifyListeners();
      return;
    }

    await ingestIncomingMessage(
      columnId: columnId,
      message: message,
      parentId: parentGraphId,
    );
  }

  /// Persist list-authoritative tags + recipients from a cloud wire payload.
  Future<void> _persistWireEnrichment(
    String messageId,
    Map<String, dynamic> json,
  ) async {
    final tags = CloudMessageMapper.tagsFromWire(json);
    if (tags.isNotEmpty) {
      await _messages.setMessageTags(messageId, tags);
    }
    for (final entry in CloudMessageMapper.recipientsFromWire(json)) {
      await _messages.upsertParticipantProfile(entry.profile!);
      await _messages.addRecipientEdge(
        messageId,
        entry.edge.recipientId,
        entry.edge.kind,
        isCloudBot: entry.edge.isCloudBot,
        isPublic: entry.edge.isPublic,
        notify: entry.edge.notify,
        addedBy: entry.edge.addedBy,
        addedAt: entry.edge.addedAt,
      );
    }
  }

  Future<String?> _columnForIncomingParent(String parentGraphId) async {
    String? fallback;
    for (final state in _states) {
      final anchor = _anchors[state.id];
      if (anchor == null) continue;
      final tree = await _branchPathService.replyTreeIds(anchor);
      if (!tree.contains(parentGraphId)) continue;
      if (state.isActive) return state.id;
      fallback ??= state.id;
    }
    return fallback ?? (_states.isNotEmpty ? _states.first.id : null);
  }

  String? get _activeColumnId {
    for (final s in _states) {
      if (s.isActive) return s.id;
    }
    return null;
  }

  /// Posted `@` highlight allow-set from recipients (+ author tag), not content.
  Future<Set<String>> validMentionTagsFor(Message message) async {
    final tags = <String>{};
    if (message.authorId != null) {
      final author = await _messages.getParticipantProfile(message.authorId!);
      final tag = author?.userTag;
      if (tag != null) tags.add(tag.toLowerCase());
    }
    final registry = _botBridge?.registry ?? const BotRegistry.empty();
    for (final recipient in await _messages.getRecipients(message.id)) {
      if (recipient.kind == RecipientKind.cloudUser) {
        final profile = await _messages.getParticipantProfile(
          recipient.recipientId,
        );
        final tag = profile?.userTag;
        if (tag != null) tags.add(tag.toLowerCase());
      } else if (recipient.kind == RecipientKind.localBot) {
        // Prefer a content token that maps to this bot id; else the bot id.
        for (final mention in registry.parseMentions(message.content)) {
          if (mention.botId == recipient.recipientId) {
            tags.add(mention.raw.toLowerCase());
          }
        }
        tags.add(recipient.recipientId.toLowerCase());
        for (final alias
            in registry.bots
                .where((b) => b.id == recipient.recipientId)
                .expand((b) => b.aliases)) {
          tags.add(alias.toLowerCase());
        }
      }
    }
    return tags;
  }

  /// Posted `#` highlight allow-set from persisted message tags.
  Future<Set<String>> validHashTagsFor(Message message) async {
    final tags = await _messages.getMessageTags(message.id);
    return {for (final t in tags) t.name.toLowerCase()};
  }

  Future<ColumnCloudSyncState> _computeColumnCloudSync(String anchorId) async {
    final treeIds = await _branchPathService.replyTreeIds(anchorId);
    var pending = false;
    var failed = false;
    for (final id in treeIds) {
      final msg = await _messages.getMessage(id);
      if (msg == null) continue;
      if (msg.syncStatus == CloudSyncStatus.pending) pending = true;
      if (msg.syncStatus == CloudSyncStatus.failed) failed = true;
    }
    if (failed) return ColumnCloudSyncState.failed;
    if (pending) return ColumnCloudSyncState.pending;
    return ColumnCloudSyncState.idle;
  }

  /// Stage the reply-parent author onto the draft from the visible row only
  /// (no awaits). Used at send kickoff so the recipient snapshot is complete
  /// before the composer clear can race the event loop.
  void _stageReplyParentAuthorFromRows(String columnId) {
    final draft = draftSettingsFor(columnId);
    final parentId = _effectiveReplyParentId(columnId);
    if (parentId == null) {
      syncReplyParentAuthor(
        draft,
        parentMessageId: null,
        authorId: null,
        currentUserId: _identity.currentUserId,
        kind: RecipientKind.cloudUser,
      );
      return;
    }

    MessageRowData? parentRow;
    for (final row in _stateFor(columnId).rows) {
      if (row.message.id == parentId) {
        parentRow = row;
        break;
      }
    }
    if (parentRow == null) return;

    final parentMessage = parentRow.message;
    final authorId = parentMessage.authorId;
    var kind = RecipientKind.cloudUser;
    String? userTag;
    var isCloudBot = false;
    if (authorId != null && authorId != _identity.currentUserId) {
      if (parentMessage.role == MessageRole.localBot) {
        kind = RecipientKind.localBot;
        userTag = authorId;
      } else {
        userTag = parentRow.authorProfile?.userTag;
        isCloudBot = parentRow.authorProfile?.isBot ?? false;
      }
    }

    syncReplyParentAuthor(
      draft,
      parentMessageId: parentId,
      authorId: authorId,
      currentUserId: _identity.currentUserId,
      kind: kind,
      userTag: userTag,
      isCloudBot: isCloudBot,
    );
  }

  void _beginOutboundSend(_OutboundSend send) {
    _outboundSends[send.message.id] = send;
    _applyOutboundSendToState(_stateFor(send.columnId), send);
  }

  void _cancelOutboundSend(String messageId) {
    final send = _outboundSends.remove(messageId);
    if (send == null) return;
    final state = _stateFor(send.columnId);
    state.rows = [
      for (final row in state.rows)
        if (row.message.id != messageId) row,
    ];
  }

  void _reapplyOutboundSends(String columnId) {
    for (final send in _outboundSends.values) {
      if (send.columnId != columnId) continue;
      _applyOutboundSendToState(_stateFor(columnId), send);
    }
  }

  void _applyOutboundSendToState(ColumnUiState state, _OutboundSend send) {
    final sending = send.message.copyWith(isSending: true);
    final existingIndex = state.rows.indexWhere(
      (r) => r.message.id == send.message.id,
    );
    if (existingIndex >= 0) {
      final row = state.rows[existingIndex];
      final rows = List<MessageRowData>.from(state.rows);
      rows[existingIndex] = MessageRowData(
        message: sending.copyWith(
          syncStatus: row.message.syncStatus,
          cloudMessageId: row.message.cloudMessageId,
          syncError: row.message.syncError,
        ),
        outgoing: row.outgoing,
        outgoingCurrentIndex: row.outgoingCurrentIndex,
        outgoingAnchorId: row.outgoingAnchorId,
        incoming: row.incoming,
        incomingCurrentIndex: row.incomingCurrentIndex,
        highlightMentions: row.highlightMentions.isNotEmpty
            ? row.highlightMentions
            : send.highlightMentions,
        highlightTags: row.highlightTags.isNotEmpty
            ? row.highlightTags
            : send.highlightTags,
        authorProfile: row.authorProfile,
      );
      state.rows = rows;
      return;
    }

    final optimistic = MessageRowData(
      message: sending,
      outgoing: null,
      outgoingCurrentIndex: -1,
      outgoingAnchorId: send.parentId,
      incoming: null,
      incomingCurrentIndex: -1,
      highlightMentions: send.highlightMentions,
      highlightTags: send.highlightTags,
    );

    final parentId = send.parentId;
    if (parentId != null) {
      final parentIndex = state.rows.indexWhere(
        (r) => r.message.id == parentId,
      );
      if (parentIndex >= 0) {
        state.rows = [...state.rows.sublist(0, parentIndex + 1), optimistic];
        return;
      }
    }
    state.rows = [...state.rows, optimistic];
  }
}

/// In-memory optimistic outbound send until persist (+ optional cloud notify)
/// settles. Not a DB row.
class _OutboundSend {
  final String columnId;
  final String? parentId;
  final Message message;
  final Set<String> highlightMentions;
  final Set<String> highlightTags;

  const _OutboundSend({
    required this.columnId,
    required this.parentId,
    required this.message,
    this.highlightMentions = const {},
    this.highlightTags = const {},
  });
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

class _HeldBotInvoke {
  const _HeldBotInvoke({
    required this.columnId,
    required this.triggerId,
    required this.botId,
    required this.context,
    required this.cwd,
  });

  final String columnId;
  final String triggerId;
  final String botId;
  final List<Map<String, dynamic>> context;
  final String? cwd;
}
