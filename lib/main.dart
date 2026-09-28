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
import 'data/repositories/auth_repository.dart';
import 'data/repositories/drift_column_repository.dart';
import 'data/repositories/drift_message_repository.dart';
import 'data/repositories/stitch_auth_repository.dart';
import 'data/services/app_database.dart';
import 'data/services/auth_api_client.dart';
import 'data/services/author_id_promotion.dart';
import 'data/services/bot_bridge_service.dart';
import 'data/services/local_identity_service.dart';
import 'data/services/mock_hidden_reply_seed.dart';
import 'data/services/mock_stitch_sibling_seed.dart';
import 'data/services/mock_typing_seed.dart';
import 'data/services/python_process_service.dart';
import 'data/services/session_vault.dart';
import 'data/services/stitch_http_client.dart';
import 'data/services/stitch_ws_client.dart';
import 'domain/branch_path_service.dart';
import 'ui/auth/login_viewmodel.dart';
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

  final sessionVault = SecureSessionVault();
  final authApi = AuthApiClient(baseUrl: stitchEnv.apiBaseUrl);
  final stitchHttp = StitchHttpClient(
    baseUrl: stitchEnv.apiBaseUrl,
    vault: sessionVault,
  );
  final authRepository = StitchAuthRepository(
    vault: sessionVault,
    api: authApi,
    httpClient: stitchHttp,
  );
  identityService.bindAuthRepository(authRepository);

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
  final branchPathService = BranchPathService(messageRepository, columnRepository);

  if (stitchEnv.mockTypingCues) {
    await seedMockTypingFixtures(
      messages: messageRepository,
      columns: columnRepository,
      currentUserId: identityService.currentUserId,
    );
    StitchLog.info('mock typing cue fixtures enabled', tag: 'main');
  }

  if (stitchEnv.mockStitchSibling) {
    await seedMockStitchSiblingFixtures(
      messages: messageRepository,
      columns: columnRepository,
      currentUserId: identityService.currentUserId,
    );
    StitchLog.info('mock stitch-sibling fixtures enabled', tag: 'main');
  }

  if (stitchEnv.mockHiddenReply) {
    await seedMockHiddenReplyFixtures(
      messages: messageRepository,
      columns: columnRepository,
      currentUserId: identityService.currentUserId,
    );
    StitchLog.info('mock hidden-reply fixtures enabled', tag: 'main');
  }

  final columnsViewModel = ColumnsViewModel(
    messageRepository,
    columnRepository,
    branchPathService,
    identityService,
    botBridge: _botBridge,
    notifications: notificationService,
    mockTypingCues: stitchEnv.mockTypingCues,
  );
  await columnsViewModel.initialize();

  Future<void> promoteLocalAuthorship() async {
    final n = await AuthorIdPromotion.promoteLocalToCloud(
      identity: identityService,
      messages: messageRepository,
    );
    if (n > 0) await columnsViewModel.reloadAll();
  }

  final loginViewModel = LoginViewModel(
    authRepository: authRepository,
    notifications: notificationService,
    onAuthenticated: promoteLocalAuthorship,
  );
  // Soft restore: never block local chat on network. Runs after the local
  // message store is up so a restored session can promote local→cloud
  // author stamps before the first frame.
  await loginViewModel.init();

  runApp(StitchApp(
    columnsViewModel: columnsViewModel,
    notificationService: notificationService,
    themeService: themeService,
    authRepository: authRepository,
    loginViewModel: loginViewModel,
    stitchHttpClient: stitchHttp,
  ));
}

class StitchApp extends StatefulWidget {
  final ColumnsViewModel columnsViewModel;
  final NotificationService notificationService;
  final ThemeService themeService;
  final AuthRepository authRepository;
  final LoginViewModel loginViewModel;
  final StitchHttpClient stitchHttpClient;

  const StitchApp({
    super.key,
    required this.columnsViewModel,
    required this.notificationService,
    required this.themeService,
    required this.authRepository,
    required this.loginViewModel,
    required this.stitchHttpClient,
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
    widget.loginViewModel.dispose();
    widget.authRepository.dispose();
    widget.stitchHttpClient.close();
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
        ChangeNotifierProvider<NotificationService>.value(value: widget.notificationService),
        ChangeNotifierProvider<ColumnsViewModel>.value(value: widget.columnsViewModel),
        ChangeNotifierProvider<ThemeService>.value(value: widget.themeService),
        ChangeNotifierProvider<AuthRepository>.value(value: widget.authRepository),
        ChangeNotifierProvider<LoginViewModel>.value(value: widget.loginViewModel),
        Provider<StitchHttpClient>.value(value: widget.stitchHttpClient),
      ],
      child: Consumer2<ThemeService, AuthRepository>(
        builder: (context, themeService, auth, _) {
          // Keep LocalIdentityService's cloud overlay in sync when auth changes.
          // (bindAuthRepository already listens; this rebuild is for UI chrome.)
          return MaterialApp(
            title: 'Stitch',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const NotificationOverlay(child: ColumnsView()),
          );
        },
      ),
    );
  }
}
