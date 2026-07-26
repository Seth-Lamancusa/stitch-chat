import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/notification_service.dart';
import 'chat_viewmodel.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(ChatViewModel viewModel) {
    viewModel.sendMessage(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final notifications = context.read<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stitch — hello world'),
        actions: [
          TextButton(
            onPressed: () => notifications.showError(
              'Something went badly wrong (test blocking error)',
              blocking: true,
            ),
            child: const Text('Test blocking error'),
          ),
          TextButton(
            onPressed: () => notifications.showToast(
              'Heads up — this is a toast (test)',
              severity: NotificationSeverity.warning,
            ),
            child: const Text('Test toast'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: viewModel.messages.length,
              itemBuilder: (context, index) {
                final message = viewModel.messages[index];
                final isUser = message.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message.content.isEmpty ? '…' : message.content),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Say hello...'),
                    onSubmitted: (_) => _send(viewModel),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _send(viewModel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
