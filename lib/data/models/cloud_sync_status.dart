/// Cloud replica state for a locally persisted message.
///
/// See `docs/cloud-sync.md`. Distinct from notify delivery — v1 ties
/// `synced` to a successful create POST when cloud recipients require notify.
enum CloudSyncStatus {
  /// No cloud POST attempted (local-only thread).
  none,

  /// Outbound POST in flight (UI may show briefly).
  pending,

  /// Cloud id recorded; inbound WS dedupes on [Message.cloudMessageId].
  synced,

  /// Notify/create failed; user message may still exist locally if rolled back.
  failed,
}
