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
      // (Note: when the screen is empty, the empty-state CTA also renders
      // "Log sale"/"Expense", so we expect at least one match.)
      expect(find.text('Log sale'), findsAtLeastNWidgets(1));
      expect(find.text('Invoice'), findsAtLeastNWidgets(1));
      expect(find.text('Expense'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows net cash hero header', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // The hero card should have "NET THIS PERIOD" label
      expect(find.text('NET THIS PERIOD'), findsOneWidget);

      // Inflows and Outflows labels should be present
      expect(find.text('Inflows'), findsOneWidget);
      expect(find.text('Outflows'), findsOneWidget);
    });

    testWidgets('shows transactions tab by default', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // The Transactions label appears twice: tab bar + section header
      expect(find.text('Transactions'), findsWidgets);

      // Filter chips should be visible
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
    });

    testWidgets('shows tab bar with all tabs', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Transactions appears in both tab bar and section header
      expect(find.text('Transactions'), findsWidgets);
      // Other tab labels appear only in the tab bar
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Forecast'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('shows empty state when no data in transactions', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('tap on Log sale opens bottom sheet', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Tap the first "Log sale" (the quick-action tile, not the empty-state CTA)
      await tester.tap(find.text('Log sale').first);
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

      // Tap the first Expense quick action (avoid the empty-state duplicate)
      await tester.tap(find.text('Expense').first);
      await tester.pumpAndSettle();

      // Should open the expense sheet (its title is "Log expense")
      expect(find.text('Log expense'), findsAtLeastNWidgets(1));
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

      // All three quick action icons should be present (outlined variants)
      expect(find.byIcon(Icons.payments_outlined), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.description_outlined), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.receipt_long_outlined), findsAtLeastNWidgets(1));
    });

    testWidgets('header shows avatar', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Business avatar initials (from mock business 'Akwaaba Threads' = 'AT')
      expect(find.text('AT'), findsOneWidget);
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
      expect(find.text('Log sale'), findsAtLeastNWidgets(1));
    });

    testWidgets('logs sale flow: opens sheet and shows form', (tester) async {
      final state = createTestAppState();
      await tester.pumpWidget(wrapWithProviders(
        const FinanceScreen(),
        appState: state,
      ));
      await tester.pumpAndSettle();

      // Tap the first Log sale (quick-action tile)
      await tester.tap(find.text('Log sale').first);
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

      // Tap the first Expense (quick-action tile)
      await tester.tap(find.text('Expense').first);
      await tester.pumpAndSettle();

      // Expense form should be visible
      expect(find.text('Log expense'), findsAtLeastNWidgets(1));
      expect(find.text('Amount (GHS)'), findsWidgets); // present in multiple sheets
      expect(find.text('Save expense'), findsOneWidget);
    });
  });
}
