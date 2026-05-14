import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'state/app_state.dart';
import 'core/tokens.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  final appState = AppState();
  appState.initFromSession();

  if (AppConfig.supabaseUrl.isNotEmpty) {
    SupabaseService.authStream.listen(appState.handleAuthChange);
  }

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const _AscendApp(),
    ),
  );
}

class _AscendApp extends StatelessWidget {
  const _AscendApp();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'AscendSME',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const _AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AuthGate — single stateful widget that owns the full screen lifecycle:
//   1. Shows SplashScreen for 2.4 s
//   2. After that, returns AppShell or SignInScreen based on auth state.
//
// No Navigator.pushReplacement — just setState so Flutter replaces the widget
// tree in the same frame with a fully-opaque Scaffold. This avoids the
// transparent-frame flash that transitional routes can produce.
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
    if (!_splashDone) return const SplashScreen();

    final authed = context.select<AppState, bool>((s) => s.authed);
    return authed ? const AppShell() : const SignInScreen();
  }
}
