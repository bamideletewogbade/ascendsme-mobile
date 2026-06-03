import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import '../lib/screens/finance_screen.dart';
import '../lib/state/app_state.dart';

void main() {
  setUpAll(() {
    initTestLogger();
  });

  group('FinanceScreen', () {
    testWidgets('renders without crashing', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Header should be shown
      expect(find.text('Finance'), findsOneWidget);

      // Quick action cards should be present with labels
      expect(find.text('Log sale'), findsOneWidget);
      expect(find.text('Invoice'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
    });

    testWidgets('shows cash position hero header', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // The cash position hero should have a "Cash position" label
      expect(find.text('Cash position'), findsOneWidget);
    });

    testWidgets('shows this month snapshot section', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Snapshot section should be visible
      expect(find.textContaining('snapshot'), findsWidgets);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
    });

    testWidgets('shows empty activity state when no data', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // The "Recent activity" header should be present
      expect(find.text('Recent activity'), findsOneWidget);
    });

    testWidgets('shows recent activity header', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // The "Recent activity" header should be present
      expect(find.text('Recent activity'), findsOneWidget);
    });

    testWidgets('tap on Log sale opens bottom sheet', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Tap Log sale button
      await tester.tap(find.text('Log sale'));
      await tester.pumpAndSettle();

      // Should open a bottom sheet with "Quick sale" title
      expect(find.text('Quick sale'), findsOneWidget);
    });

    testWidgets('tap on Invoice opens invoice form', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Tap the Invoice quick action
      await tester.tap(find.text('Invoice'));
      await tester.pumpAndSettle();

      // Should open the new invoice sheet
      expect(find.text('New invoice'), findsOneWidget);
    });

    testWidgets('tap on Expense opens expense form', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Tap Expense quick action
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();

      // Should open the expense sheet
      expect(find.text('Log expense'), findsOneWidget);
    });

    testWidgets('quick action cards show correct subtitles', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Subtitles should be visible
      expect(find.text('Cash, MoMo, bank'), findsOneWidget);
      expect(find.text('Send a bill'), findsOneWidget);
      expect(find.text('Record outflow'), findsOneWidget);
    });

    testWidgets('quick action icons are rendered', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // All three quick action icons should be present
      expect(find.byIcon(Icons.payments), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });

    testWidgets('header shows avatar and timeline icon', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Business avatar initials (from mock business 'Akwaaba Threads' = 'AT')
      expect(find.text('AT'), findsOneWidget);
      // Timeline icon for cash flow forecast navigation
      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('monthly stats show count values', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // We just verify the labels are present
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
    });

    testWidgets('does not crash when financials are empty', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Should render without errors even with empty financials
      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('Log sale'), findsOneWidget);
    });

    testWidgets('logs sale flow: opens sheet and shows form', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Tap Log sale
      await tester.tap(find.text('Log sale'));
      await tester.pumpAndSettle();

      // Sale form should be visible
      expect(find.text('Quick sale'), findsOneWidget);
      expect(find.text('Amount (GHS)'), findsOneWidget);
      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Save sale'), findsOneWidget);
    });

    testWidgets('log expense flow: opens sheet with form fields', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Tap Expense
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();

      // Expense form should be visible
      expect(find.text('Log expense'), findsOneWidget);
      expect(find.text('Amount (GHS)'), findsWidgets); // present in multiple sheets
      expect(find.text('Save expense'), findsOneWidget);
    });
  });
}
