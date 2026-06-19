import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'helpers.dart';
import '../lib/core/models.dart';
import '../lib/screens/customers_screen.dart';
import '../lib/screens/customer_detail_screen.dart';
import '../lib/screens/finance_screen.dart';
import '../lib/screens/settings_screen.dart';
import '../lib/screens/tools/crm_screen.dart';
import '../lib/screens/tools/documents_screen.dart';
import '../lib/screens/tools/invoices_screen.dart';
import '../lib/screens/tools/receipts_screen.dart';
import '../lib/screens/tools/expenses_screen.dart';

/// Smoke tests for screens that are pushed via Navigator.push.
///
/// These ensure each screen's build() method doesn't throw a
/// "No Material widget found" error when used outside of AppShell's
/// Scaffold context. Each test wraps the screen in the provider tree
/// and MaterialApp, then pumps it to verify it builds without errors.
void main() {
  initTestLogger();

  group('Route-pushed screens: Material ancestor check', () {
    testWidgets('FinanceScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const FinanceScreen()),
      );
      await tester.pump();
      expect(find.text('Finance'), findsOneWidget);
    });

    testWidgets('SettingsScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const SettingsScreen()),
      );
      await tester.pump();
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('CrmScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const CrmScreen()),
      );
      await tester.pump();
      expect(find.text('CRM'), findsOneWidget);
    });

    testWidgets('DocumentsScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const DocumentsScreen()),
      );
      await tester.pump();
      expect(find.text('Document Vault'), findsOneWidget);
    });

    testWidgets('InvoicesScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const InvoicesScreen()),
      );
      await tester.pump();
      // InvoicesScreen shows empty/loading state; verify it renders
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ReceiptsScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const ReceiptsScreen()),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ExpensesScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const ExpensesScreen()),
      );
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('CustomerDetailScreen builds without Material error', (tester) async {
      final customer = Customer(
        id: 'test-cust-1',
        fullName: 'Test Customer',
        phone: '0244000000',
        email: 'test@example.com',
      );
      await tester.pumpWidget(
        wrapWithProviders(CustomerDetailScreen(customer: customer)),
      );
      await tester.pump();
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Test Customer'), findsOneWidget);
    });

    testWidgets('CustomersScreen builds without Material error', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(const CustomersScreen()),
      );
      await tester.pump();
      expect(find.text('Customers'), findsOneWidget);
    });
  });
}
