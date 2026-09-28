import 'package:flutter/material.dart';

import '../../data/models/message.dart';
import 'theme/app_colors.dart';

/// Slide-over panel listing absolute thread roots as compact previews.
class ThreadRootsPanel extends StatelessWidget {
  const ThreadRootsPanel({
    super.key,
    required this.roots,
    required this.onClose,
    required this.onRootTap,
  });

  final List<Message> roots;
  final VoidCallback onClose;
  final void Function(Message root) onRootTap;

  static const panelWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Material(
      elevation: 8,
      color: appColors.appBarSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thread roots',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outline),
            Expanded(
              child: roots.isEmpty
                  ? Center(
                      child: Text(
                        'No thread roots yet.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: roots.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colorScheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) {
                        final root = roots[index];
                        return _ThreadRootPreviewTile(
                          root: root,
                          onTap: () => onRootTap(root),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadRootPreviewTile extends StatelessWidget {
  const _ThreadRootPreviewTile({
    required this.root,
    required this.onTap,
  });

  final Message root;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = _singleLinePreview(root.content);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _roleLabel(root.role),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              preview.isEmpty ? '(empty message)' : preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (root.createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatWhen(root.createdAt!),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _singleLinePreview(String content) {
    return content.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _roleLabel(MessageRole role) {
    return switch (role) {
      MessageRole.user => 'User',
      MessageRole.localBot => 'Bot',
      MessageRole.functionCall => 'Function call',
      MessageRole.functionResult => 'Function result',
      MessageRole.thinking => 'Thinking',
    };
  }

  static String _formatWhen(DateTime when) {
    final local = when.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
