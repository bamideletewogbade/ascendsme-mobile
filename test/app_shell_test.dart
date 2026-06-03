import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'helpers.dart';
import '../lib/screens/app_shell.dart';
import '../lib/state/app_state.dart';
import '../lib/services/sync_service.dart';
import '../lib/services/connectivity_service.dart';
import '../lib/core/tokens.dart';

void main() {
  setUpAll(() {
    initTestLogger();
  });

  group('AppShell', () {
    testWidgets('renders bottom navigation bar', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AppShell()));
      await tester.pumpAndSettle();

      // All four tabs should be visible
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Ask Ascend'), findsOneWidget);
    });

    testWidgets('renders Ask Ascend tab button', (tester) async {
      await tester.pumpWidget(wrapWithProviders(const AppShell()));
      await tester.pumpAndSettle();

      expect(find.text('Ask Ascend'), findsOneWidget);
    });

    testWidgets('tab navigation switches IndexedStack', (tester) async {
      final appState = createTestAppState();

      await tester.pumpWidget(wrapWithProviders(
        const AppShell(),
        appState: appState,
      ));
      await tester.pumpAndSettle();

      // Initially on Home tab
      expect(appState.tab, AppTab.home);

      // Tap Tools tab
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      expect(appState.tab, AppTab.tools);
    });

    testWidgets('shows offline banner when offline', (tester) async {
      final connectivity = StubConnectivityService(online: false);
      final syncService = StubSyncService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: AppState(connectivity: connectivity, syncService: syncService),
            ),
            ChangeNotifierProvider.value(value: connectivity),
            ChangeNotifierProvider.value(value: syncService),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("You're offline"), findsOneWidget);
    });

    testWidgets('shows syncing banner when processing mutations', (tester) async {
      final syncService = StubSyncService();
      final connectivity = StubConnectivityService(online: true);

      // Manually trigger processing state
      syncService.setProcessing(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: AppState(connectivity: connectivity, syncService: syncService),
            ),
            ChangeNotifierProvider.value(value: connectivity),
            ChangeNotifierProvider.value(value: syncService),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Syncing changes…'), findsOneWidget);
    });
  });

  group('ToolStubScreen', () {
    testWidgets('renders with tool name', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ToolStubScreen(toolId: 'projects'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget); // first letter uppercased
    });
  });
}
