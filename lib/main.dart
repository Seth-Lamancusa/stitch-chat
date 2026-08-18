import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/notifications/notification_overlay.dart';
import 'core/notifications/notification_service.dart';
import 'data/repositories/drift_column_repository.dart';
import 'data/repositories/drift_message_repository.dart';
import 'data/services/app_database.dart';
import 'data/services/local_identity_service.dart';
import 'data/services/python_process_service.dart';
import 'domain/branch_path_service.dart';
import 'ui/columns/columns_view.dart';
import 'ui/columns/columns_viewmodel.dart';

final _pythonProcess = PythonProcessService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  void handleTerminationSignal(_) {
    _pythonProcess.stop();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(handleTerminationSignal);
  if (!Platform.isWindows) {
    // SIGTERM isn't supported by ProcessSignal.watch on Windows.
    ProcessSignal.sigterm.watch().listen(handleTerminationSignal);
  }

  await _pythonProcess.start();

  final identityService = LocalIdentityService();
  await identityService.initialize();

  final db = AppDatabase();
  final messageRepository = DriftMessageRepository(db);
  final columnRepository = DriftColumnRepository(db);
  final branchPathService = BranchPathService(messageRepository, columnRepository);

  final columnsViewModel = ColumnsViewModel(messageRepository, columnRepository, branchPathService, identityService);
  await columnsViewModel.initialize();

  final notificationService = NotificationService();

  runApp(StitchApp(columnsViewModel: columnsViewModel, notificationService: notificationService));
}

class StitchApp extends StatefulWidget {
  final ColumnsViewModel columnsViewModel;
  final NotificationService notificationService;
  const StitchApp({super.key, required this.columnsViewModel, required this.notificationService});

  @override
  State<StitchApp> createState() => _StitchAppState();
}

class _StitchAppState extends State<StitchApp> with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // On desktop, this fires when the window close button is pressed, before
    // the app actually exits — a more reliable signal than
    // didChangeAppLifecycleState(detached), which some window managers never
    // deliver on close.
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        _pythonProcess.stop();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleListener.dispose();
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
        ChangeNotifierProvider<ColumnsViewModel>.value(value: widget.columnsViewModel),
      ],
      child: MaterialApp(
        title: 'Stitch Chat',
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const NotificationOverlay(child: ColumnsView()),
      ),
    );
  }
}
