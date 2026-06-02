import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'state/app_state.dart';
import 'core/tokens.dart';
import 'services/supabase_service.dart';
import 'services/app_logger.dart';
import 'services/app_router_observer.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'screens/splash_screen.dart';
import 'screens/app_shell.dart';
import 'screens/sign_in_screen.dart';

Future<void> main() async {
  // Phase 1: logger must be available before anything else.
  log.init();
  log.info('main() — app starting');

  WidgetsFlutterBinding.ensureInitialized();

  // ── Global error wiring ───────────────────────────────────────────────────
  // Without these, a build/render exception in any post-splash screen
  // surfaces in release mode as a blank white page (Flutter's default
  // release-mode ErrorWidget renders empty). With them, every error reaches
  // the logger AND a visible on-screen error widget.

  // Framework-level errors (build, layout, paint exceptions).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    log.error(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Async errors that bypass FlutterError (platform channel callbacks,
  // microtasks). Returning true marks them handled so the isolate stays up.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    log.error('PlatformDispatcher error', error: error, stackTrace: stack);
    return true;
  };

  // Replace the default release-mode blank ErrorWidget with a visible one.
  // This is the change that turns "white page" into "see the stack trace".
  ErrorWidget.builder = (FlutterErrorDetails details) {
    log.error(
      'ErrorWidget shown: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFFFFEBEE),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                'Build error:\n\n'
                '${details.exceptionAsString()}\n\n'
                '${details.stack}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  };

  // Phase 2: attach file output now that the binding is ready.
  await log.initFileOutput();

  final connectivityService = ConnectivityService();
  final syncService = SyncService();
  final appState = AppState(
    connectivity: connectivityService,
    syncService: syncService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider.value(value: syncService),
      ],
      child: const _AscendApp(),
    ),
  );

  // Defer Supabase init until after the first frame paints so the splash
  // screen is visible immediately. Supabase.initialize() has synchronous
  // startup work (JWT parsing, SharedPrefs reads) that blocks the event loop
  // for 10-17 s on cold start — addPostFrameCallback guarantees frame 1 is
  // committed to the screen before any of that runs.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    log.info('Frame 1 painted — starting Supabase init');
    final sw = Stopwatch()..start();
    try {
      await SupabaseService.initialize();
      log.info('Supabase init complete (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('Supabase init failed', error: e, stackTrace: st);
    }

    // Guard the post-init wiring: initFromSession() reads
    // SupabaseService.currentUser which throws if Supabase failed to
    // initialize. A silent throw here would break the auth stream
    // subscription and leave the app permanently unauthed.
    try {
      // Persisted-session restore happens via this listener: Supabase emits
      // an `initialSession` event on subscribe carrying the saved session (or
      // null if signed out). handleAuthChange sets _user from it and triggers
      // loadBusiness, so returning users land on AppShell after the splash.
      // Subsequent signIn/signOut/refreshed events flow through the same path.
      if (AppConfig.supabaseUrl.isNotEmpty) {
        SupabaseService.authStream.listen((state) {
          log.debug('Auth stream event: ${state.event.name}');
          appState.handleAuthChange(state);
        });
      }
    } catch (e, st) {
      log.error('Post-init wiring failed', error: e, stackTrace: st);
    }
  });
}

final _appRouterObserver = AppRouterObserver();

class _AscendApp extends StatelessWidget {
  const _AscendApp();

  @override
  Widget build(BuildContext context) {
    // Select only darkMode — watching full AppState rebuilds MaterialApp on
    // every notifyListeners() (auth, business loads, etc.) which interrupts
    // Navigator pop animations mid-flight and produces a blank white frame.
    final darkMode = context.select<AppState, bool>((s) => s.darkMode);
    return MaterialApp(
      title: 'AscendSME',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      navigatorObservers: [_appRouterObserver],
      home: const _AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AuthGate — shows SplashScreen for 2.4 s, then always navigates to
// SignInScreen. After a successful sign-in, AppState.authed flips to true
// and the build method switches to AppShell.
// ─────────────────────────────────────────────────────────────────────────────

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_splashDone) {
      child = const SplashScreen(key: ValueKey('splash'));
    } else {
      final authed = context.select<AppState, bool>((s) => s.authed);
      child = authed
          ? const AppShell(key: ValueKey('shell'))
          : const SignInScreen(key: ValueKey('signin'));
    }
    // Cross-fade between splash → signin/shell, and between signin ↔ shell on
    // auth flips. ValueKey on each child triggers the switcher to animate.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}