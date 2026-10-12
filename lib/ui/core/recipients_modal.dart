import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/message.dart';
import '../../domain/draft_inline_tokens.dart';
import '../columns/columns_viewmodel.dart';

/// Modes for [showRecipientsModal]. Only draft is implemented for now.
enum RecipientsModalMode {
  /// Staged recipients on the column draft ([DraftReplySettings.recipients]).
  draft,
}

/// Opens the recipients dialog for [columnId].
void showRecipientsModal(
  BuildContext context, {
  required String columnId,
  RecipientsModalMode mode = RecipientsModalMode.draft,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => _RecipientsModal(columnId: columnId, mode: mode),
  );
}

class _RecipientsModal extends StatelessWidget {
  const _RecipientsModal({
    required this.columnId,
    required this.mode,
  });

  final String columnId;
  final RecipientsModalMode mode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Only draft mode for v1; other modes will branch here later.
    assert(mode == RecipientsModalMode.draft);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.33,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Recipients',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: Consumer<ColumnsViewModel>(
                    builder: (context, vm, _) {
                      final recipients =
                          vm.draftSettingsFor(columnId).recipients;
                      if (recipients.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'No recipients on this draft.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: recipients.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        itemBuilder: (context, index) => _DraftRecipientTile(
                          columnId: columnId,
                          recipient: recipients[index],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftRecipientTile extends StatelessWidget {
  const _DraftRecipientTile({
    required this.columnId,
    required this.recipient,
  });

  final String columnId;
  final DraftRecipient recipient;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tag = recipient.normalizedTag;
    final title = tag != null ? '@$tag' : recipient.recipientId;
    final kindLabel = switch (recipient.kind) {
      RecipientKind.localBot => 'Local bot',
      RecipientKind.cloudUser =>
        recipient.isCloudBot ? 'Cloud bot' : 'Cloud user',
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        kindLabel,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: IconButton(
          tooltip: 'Remove',
          onPressed: () => context.read<ColumnsViewModel>().removeDraftRecipient(
                columnId,
                recipient.recipientId,
              ),
          icon: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
