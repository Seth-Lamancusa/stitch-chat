import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/bot_registry.dart';
import '../columns/columns_viewmodel.dart';

/// Lists local bots from the Python bridge `ready` registry
/// ([ColumnsViewModel.botRegistry]).
void showLocalBotsModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
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
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Local bots',
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
                        final bots = vm.botRegistry.bots;
                        if (bots.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'No local bots advertised by the bridge yet.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: bots.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          itemBuilder: (context, index) =>
                              _LocalBotTile(bot: bots[index]),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
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
    },
  );
}

class _LocalBotTile extends StatelessWidget {
  const _LocalBotTile({required this.bot});

  final BotSpec bot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final aliases = bot.aliases.toList()..sort();
    final aliasLabels = aliases.map((a) => '@$a').join(', ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        bot.id,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        aliasLabels,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: bot.requiresCwd
          ? Tooltip(
              message: 'Requires a column working directory',
              child: Chip(
                label: const Text('cwd'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: colorScheme.outlineVariant),
                labelStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                padding: EdgeInsets.zero,
              ),
            )
          : null,
    );
  }
}
