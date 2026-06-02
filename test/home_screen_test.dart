import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import '../lib/screens/home_screen.dart';
import '../lib/state/app_state.dart';
import '../lib/core/models.dart';
import '../lib/core/mock_data.dart';

void main() {
  setUpAll(() {
    initTestLogger();
  });

  group('HomeScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(onAction: (_) {}, onOpenDrawer: () {}),
      ));
      await tester.pumpAndSettle();

      // The greeting should be shown
      expect(find.textContaining('Good'), findsWidgets);

      // Quick actions should be rendered
      expect(find.text('Log sale'), findsOneWidget);
      expect(find.text('New invoice'), findsOneWidget);
      expect(find.text('Log expense'), findsOneWidget);
      expect(find.text('All tools'), findsOneWidget);
    });

    testWidgets('shows cash flow hero section', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(onAction: (_) {}, onOpenDrawer: () {}),
      ));
      await tester.pumpAndSettle();

      // The "THIS MONTH" label in the cash flow section
      expect(find.textContaining('THIS MONTH'), findsWidgets);

      // Avatars should be present
      expect(find.byIcon(Icons.auto_awesome), findsWidgets);
    });

    testWidgets('quick action tap triggers onAction', (tester) async {
      String? actionId;
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(
          onAction: (id) => actionId = id,
          onOpenDrawer: () {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log sale'));
      expect(actionId, 'sale');
    });

    testWidgets('renders activity feed section', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(onAction: (_) {}, onOpenDrawer: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Recent activity'), findsOneWidget);
    });

    testWidgets('renders notification bell', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(onAction: (_) {}, onOpenDrawer: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('avatar is tappable (opens drawer)', (tester) async {
      bool drawerOpened = false;
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(
          onAction: (_) {},
          onOpenDrawer: () => drawerOpened = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the avatar area
      await tester.tap(find.text('AT')); // initials from mock business
      expect(drawerOpened, true);
    });

    testWidgets('shows Ascend AI daily brief section', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(onAction: (_) {}, onOpenDrawer: () {}),
      ));
      await tester.pumpAndSettle();

      // Should show AI brief card with rotating tip first
      expect(find.text('Ascend AI'), findsOneWidget);
      expect(find.text('Daily brief'), findsOneWidget);
    });

    testWidgets('shows recommendations section', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        HomeScreen(onAction: (_) {}, onOpenDrawer: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Top actions'), findsOneWidget);
    });
  });
}
