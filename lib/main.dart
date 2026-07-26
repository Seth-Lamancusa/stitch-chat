import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/notifications/notification_overlay.dart';
import 'core/notifications/notification_service.dart';
import 'data/repositories/chat_repository_impl.dart';
import 'data/services/python_process_service.dart';
import 'data/services/stitch_ws_client.dart';
import 'ui/chat/chat_view.dart';
import 'ui/chat/chat_viewmodel.dart';

final _pythonProcess = PythonProcessService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ProcessSignal.sigint.watch().listen((_) {
    _pythonProcess.stop();
    exit(0);
  });

  await _pythonProcess.start();
  final wsClient = StitchWsClient(Uri.parse('ws://127.0.0.1:8765'));
  final repository = ChatRepositoryImpl(wsClient);
  final notificationService = NotificationService();
  final viewModel = ChatViewModel(repository, notificationService);
  await viewModel.initialize();

  runApp(StitchApp(viewModel: viewModel, notificationService: notificationService));
}

class StitchApp extends StatefulWidget {
  final ChatViewModel viewModel;
  final NotificationService notificationService;
  const StitchApp({super.key, required this.viewModel, required this.notificationService});

  @override
  State<StitchApp> createState() => _StitchAppState();
}

class _StitchAppState extends State<StitchApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _pythonProcess.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationService>.value(value: widget.notificationService),
        ChangeNotifierProvider<ChatViewModel>.value(value: widget.viewModel),
      ],
      child: MaterialApp(
        title: 'Stitch Desktop',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        home: const NotificationOverlay(child: ChatView()),
      ),
    );
  }
}
