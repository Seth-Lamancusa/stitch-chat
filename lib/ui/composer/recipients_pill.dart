import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../columns/columns_viewmodel.dart';
import '../core/recipients_modal.dart';
import '../core/theme/app_colors.dart';

/// Toolbar pill opening the draft recipients modal — mirrors stitch-frontend
/// ReplyBox `Recipients (N)` meta-pill.
class RecipientsPill extends StatelessWidget {
  const RecipientsPill({super.key, required this.columnId});

  final String columnId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chrome = context.appColors.columnHeaderSurface;
    return Consumer<ColumnsViewModel>(
      builder: (context, vm, _) {
        final count = vm.draftSettingsFor(columnId).recipients.length;
        // IntrinsicWidth: Material/InkWell otherwise expand under stretchy parents.
        // Avoid Container.alignment — that also forces max-width expansion.
        return IntrinsicWidth(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              color: chrome,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => showRecipientsModal(
                  context,
                  columnId: columnId,
                  mode: RecipientsModalMode.draft,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '👥',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Recipients ($count)',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
