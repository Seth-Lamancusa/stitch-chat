import '../data/models/message.dart';
import '../data/repositories/message_repository.dart';

/// In-memory hydration cache for message content. Per the message-loading
/// plan's "resolving a candidate vs. acting on it" split, edge/candidate
/// pools are never deferred (`getOutgoing`/`getIncoming` already return
/// full `Message` objects for every candidate) — only single-message
/// content benefits from caching. Deliberately not persisted: nothing needs
/// to survive restart except what's already durable in
/// `ColumnBranchPointers`, so this is allowed to start cold every launch.
class MessageStore {
  MessageStore(this._messages);

  final MessageRepository _messages;
  final Map<String, Message> _cache = {};

  /// Ensures [id]'s content is cached, returning it. Cache-checked; only
  /// hits [MessageRepository] if absent. Returns null (without caching) if
  /// no such message exists.
  Future<Message?> load(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;
    final message = await _messages.getMessage(id);
    if (message != null) _cache[id] = message;
    return message;
  }

  /// Synchronous, cache-only — no fetch.
  Message? peek(String id) => _cache[id];
}
