import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/logging/stitch_env.dart';
import 'core/logging/stitch_log.dart';
import 'core/notifications/notification_overlay.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings/theme_service.dart';
import 'data/repositories/drift_column_repository.dart';
import 'data/repositories/drift_message_repository.dart';
import 'data/services/app_database.dart';
import 'data/services/bot_bridge_service.dart';
import 'data/services/local_identity_service.dart';
import 'data/services/python_process_service.dart';
import 'data/services/stitch_ws_client.dart';
import 'domain/branch_path_service.dart';
import 'domain/message_store.dart';
import 'ui/columns/columns_view.dart';
import 'ui/columns/columns_viewmodel.dart';
import 'ui/core/theme/app_theme.dart';

final _pythonProcess = PythonProcessService();
BotBridgeService? _botBridge;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setTitle('Stitch');

  final stitchEnv = StitchEnv.load();
  await StitchLog.initialize(logDir: stitchEnv.logDir, level: stitchEnv.logLevel);

  void handleTerminationSignal(_) {
    _botBridge?.close();
    _pythonProcess.stop();
    StitchLog.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(handleTerminationSignal);
  if (!Platform.isWindows) {
    // SIGTERM isn't supported by ProcessSignal.watch on Windows.
    ProcessSignal.sigterm.watch().listen(handleTerminationSignal);
  }

  await _pythonProcess.start(env: stitchEnv);

  final identityService = LocalIdentityService();
  await identityService.initialize();

  final themeService = ThemeService();
  await themeService.initialize();

  final notificationService = NotificationService();

  final botBridge = BotBridgeService(
    StitchWsClient(Uri.parse('ws://127.0.0.1:8765')),
  );
  try {
    await botBridge.connect();
    _botBridge = botBridge;
    StitchLog.info('bot bridge connected', tag: 'main');
  } catch (e, st) {
    StitchLog.error('bot bridge connect failed', tag: 'main', error: e, stackTrace: st);
    notificationService.showError(
      'Could not connect to local bot bridge: $e',
      blocking: true,
    );
  }

  final db = AppDatabase();
  final messageRepository = DriftMessageRepository(db);
  final columnRepository = DriftColumnRepository(db);
  final messageStore = MessageStore(messageRepository);
  final branchPathService = BranchPathService(
    messageRepository,
    columnRepository,
    messageStore,
  );

  final columnsViewModel = ColumnsViewModel(
    messageRepository,
    columnRepository,
    branchPathService,
    messageStore,
    identityService,
    botBridge: _botBridge,
    notifications: notificationService,
  );
  await columnsViewModel.initialize();

  runApp(
    StitchApp(
      columnsViewModel: columnsViewModel,
      notificationService: notificationService,
      themeService: themeService,
    ),
  );
}

class StitchApp extends StatefulWidget {
  final ColumnsViewModel columnsViewModel;
  final NotificationService notificationService;
  final ThemeService themeService;
  const StitchApp({
    super.key,
    required this.columnsViewModel,
    required this.notificationService,
    required this.themeService,
  });

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
        await _botBridge?.close();
        _pythonProcess.stop();
        await StitchLog.close();
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
      _botBridge?.close();
      _pythonProcess.stop();
      StitchLog.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationService>.value(
          value: widget.notificationService,
        ),
        ChangeNotifierProvider<ColumnsViewModel>.value(
          value: widget.columnsViewModel,
        ),
        ChangeNotifierProvider<ThemeService>.value(value: widget.themeService),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) => MaterialApp(
          title: 'Stitch',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const NotificationOverlay(child: ColumnsView()),
        ),
      ),
    );
  }
}
