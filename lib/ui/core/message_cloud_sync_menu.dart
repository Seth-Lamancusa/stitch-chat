import 'package:flutter/material.dart';

import '../../data/models/cloud_sync_status.dart';
import '../../data/models/message.dart';

/// Per-message cloud sync status for the contextual (...) menu.
class MessageCloudSyncMenu {
  MessageCloudSyncMenu._();

  /// Non-interactive status row, or `null` when [CloudSyncStatus.none].
  static PopupMenuEntry<String>? maybeItem(
    BuildContext context,
    Message message,
  ) {
    final scheme = Theme.of(context).colorScheme;
    switch (message.syncStatus) {
      case CloudSyncStatus.none:
        return null;
      case CloudSyncStatus.pending:
        return PopupMenuItem<String>(
          enabled: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Syncing to Stitch cloud…'),
            ],
          ),
        );
      case CloudSyncStatus.synced:
        return PopupMenuItem<String>(
          enabled: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done, size: 14, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('Synced to Stitch cloud'),
            ],
          ),
        );
      case CloudSyncStatus.failed:
        final detail = message.syncError ?? 'Cloud sync failed';
        return PopupMenuItem<String>(
          enabled: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 14, color: scheme.error),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                child: Text(
                  detail,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
    }
  }
}
