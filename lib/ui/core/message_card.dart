import 'package:flutter/material.dart';

import '../../data/models/message.dart';

/// A single message, free-floating (no background box), full width of its
/// column. Darkens slightly on hover. Role only distinguishes function
/// call/result (a small chip) from everything else — stitch-frontend has no
/// per-role bubble coloring at all (confirmed against `main`), and
/// collapsing function call/result into indistinguishable bot messages
/// would hide real structure, so this is a deliberately small,
/// non-load-bearing exception to otherwise uniform styling.
///
/// [MessageRole.user] alone doesn't say *which* human sent it — multiple
/// human users share that role (`docs/plans/message-tree-data-model.md`
/// §2: `authorId` is the identity field, `role` only the kind). "Is this
/// me" is an `authorId == currentUserId` comparison, not a role check: the
/// author label is bold only for the current user, plain for every other
/// author (human or bot) — the same visual treatment regardless of role.
class MessageCard extends StatelessWidget {
  final Message message;
  final String currentUserId;

  const MessageCard({super.key, required this.message, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return _MessageBubble(message: message, currentUserId: currentUserId);
  }
}

class _MessageBubble extends StatefulWidget {
  final Message message;
  final String currentUserId;

  const _MessageBubble({required this.message, required this.currentUserId});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = widget.message;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _hovering ? colorScheme.onSurface.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.role == MessageRole.functionCall || message.role == MessageRole.functionResult)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.role == MessageRole.functionCall ? 'FUNCTION CALL' : 'FUNCTION RESULT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Text(message.content.isEmpty ? '…' : message.content),
          ],
        ),
      ),
    );
  }
}
