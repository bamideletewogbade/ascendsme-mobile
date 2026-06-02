import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import '../lib/core/expense_mapping.dart';
import '../lib/core/activity.dart';
import '../lib/core/recommendations.dart';
import '../lib/core/models.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────────
  // Expense Mapping
  // ─────────────────────────────────────────────────────────────────────────────

  group('detectExpenseCategoryFromDescription', () {
    test('detects rent from description', () {
      expect(detectExpenseCategoryFromDescription('Shop rent March'), 'Rent');
      expect(detectExpenseCategoryFromDescription('Lease payment'), 'Rent');
    });

    test('detects utilities from description', () {
      expect(detectExpenseCategoryFromDescription('ECG bill'), 'Utilities');
      expect(detectExpenseCategoryFromDescription('Internet subscription'), 'Utilities');
    });

    test('detects marketing from description', () {
      expect(detectExpenseCategoryFromDescription('Facebook ads'), 'Marketing');
      expect(detectExpenseCategoryFromDescription('Instagram promotion'), 'Marketing');
    });

    test('detects wages from description', () {
      expect(detectExpenseCategoryFromDescription('Staff salary'), 'Wages');
      expect(detectExpenseCategoryFromDescription('Commission payment'), 'Wages');
    });

    test('detects transport from description', () {
      expect(detectExpenseCategoryFromDescription('Fuel for delivery'), 'Transport');
      expect(detectExpenseCategoryFromDescription('Vehicle maintenance'), 'Transport');
    });

    test('detects inventory from description', () {
      expect(detectExpenseCategoryFromDescription('Kente fabric'), 'Inventory/Stock');
      expect(detectExpenseCategoryFromDescription('Raw materials'), 'Inventory/Stock');
    });

    test('returns null for empty description', () {
      expect(detectExpenseCategoryFromDescription(''), isNull);
      expect(detectExpenseCategoryFromDescription('   '), isNull);
    });

    test('returns null for unknown description', () {
      expect(detectExpenseCategoryFromDescription('Miscellaneous expense'), isNull);
    });
  });

  group('mapExpense', () {
    test('maps Rent to opex_rent', () {
      final m = mapExpense(manualCategory: 'Rent');
      expect(m.mappedCategory, 'opex_rent');
      expect(m.manualCategory, 'Rent');
    });

    test('promotes Other with detected category from description', () {
      final m = mapExpense(
        manualCategory: 'Other',
        description: 'ECG bill for the shop',
      );
      expect(m.manualCategory, 'Utilities');
      expect(m.mappedCategory, 'opex_utilities');
    });

    test('tag compliance expenses correctly', () {
      final m = mapExpense(
        manualCategory: 'Other',
        description: 'GRA tax filing for 2025',
      );
      expect(m.mappedCategory, 'compliance');
    });

    test('auto-tags sustainability keywords', () {
      final m = mapExpense(
        manualCategory: 'Inventory/Stock',
        description: 'Eco-friendly packaging material',
      );
      expect(m.sustainabilityTagged, true);
    });

    test('does not tag non-sustainable expenses', () {
      final m = mapExpense(
        manualCategory: 'Rent',
        description: 'Shop rent',
      );
      expect(m.sustainabilityTagged, false);
    });

    test('compliance overrides other mapped categories', () {
      final m = mapExpense(
        manualCategory: 'Marketing',
        description: 'Compliance registration fee',
      );
      expect(m.mappedCategory, 'compliance');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Activity Feed
  // ─────────────────────────────────────────────────────────────────────────────

  group('buildActivityFeed', () {
    test('returns empty feed for empty inputs', () {
      final events = buildActivityFeed(
        invoices: [],
        receipts: [],
        expenses: [],
      );
      expect(events, isEmpty);
    });

    test('includes paid invoices as invoicePaid events', () {
      final inv = Invoice.fromRow(mockInvoiceRow(status: 'paid'));
      final events = buildActivityFeed(
        invoices: [inv],
        receipts: [],
        expenses: [],
      );
      expect(events.length, 1);
      expect(events[0].kind, ActivityKind.invoicePaid);
    });

    test('includes pending invoices as invoiceSent events', () {
      final inv = Invoice.fromRow(mockInvoiceRow(status: 'pending'));
      final events = buildActivityFeed(
        invoices: [inv],
        receipts: [],
        expenses: [],
      );
      expect(events.length, 1);
      expect(events[0].kind, ActivityKind.invoiceSent);
    });

    test('skips void invoices', () {
      final inv = Invoice.fromRow(mockInvoiceRow(status: 'void'));
      final events = buildActivityFeed(
        invoices: [inv],
        receipts: [],
        expenses: [],
      );
      expect(events, isEmpty);
    });

    test('includes direct sales (no invoice_id)', () {
      final events = buildActivityFeed(
        invoices: [],
        receipts: [mockReceiptRow(invoiceId: null)],
        expenses: [],
      );
      expect(events.length, 1);
      expect(events[0].kind, ActivityKind.saleLogged);
    });

    test('deduplicates invoice-paid receipts', () {
      final paidInv = Invoice.fromRow(mockInvoiceRow(
        id: 'inv-001', status: 'paid',
      ));
      final receipt = mockReceiptRow(invoiceId: 'inv-001');
      final events = buildActivityFeed(
        invoices: [paidInv],
        receipts: [receipt],
        expenses: [],
      );
      // Only one event — invoicePaid from the invoice, receipt skipped
      expect(events.length, 1);
      expect(events[0].kind, ActivityKind.invoicePaid);
    });

    test('includes expenses', () {
      final events = buildActivityFeed(
        invoices: [],
        receipts: [],
        expenses: [mockExpenseRow()],
      );
      expect(events.length, 1);
      expect(events[0].kind, ActivityKind.expenseLogged);
    });

    test('sorts newest first', () {
      final oldInv = Invoice.fromRow(mockInvoiceRow(
        id: 'inv-001',
        createdAt: DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        status: 'paid',
      ));
      final recentExp = mockExpenseRow(
        date: DateTime.now().toIso8601String().substring(0, 10),
      );
      final events = buildActivityFeed(
        invoices: [oldInv],
        receipts: [],
        expenses: [recentExp],
      );
      expect(events.length, 2);
      expect(events[0].kind, ActivityKind.expenseLogged); // most recent first
      expect(events[1].kind, ActivityKind.invoicePaid);
    });

    test('respects limit parameter', () {
      final invoices = List.generate(10, (i) => Invoice.fromRow(mockInvoiceRow(
        id: 'inv-$i', status: 'paid',
        createdAt: DateTime.now().subtract(Duration(days: i)).toIso8601String(),
      )));
      final events = buildActivityFeed(
        invoices: invoices,
        receipts: [],
        expenses: [],
        limit: 3,
      );
      expect(events.length, 3);
    });

    test('returns overdue subtitle for overdue invoices', () {
      final inv = Invoice.fromRow(mockInvoiceRow(
        status: 'overdue',
        dueDate: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      ));
      final events = buildActivityFeed(invoices: [inv], receipts: [], expenses: []);
      expect(events.length, 1);
      expect(events[0].subtitle, 'Overdue');
    });
  });

  group('formatRelativeTime', () {
    test('shows "now" for < 60 seconds', () {
      final t = DateTime.now().subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(t), 'now');
    });

    test('shows minutes for < 60 min', () {
      final t = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(t), '5m');
    });

    test('shows hours for < 24 h', () {
      final t = DateTime.now().subtract(const Duration(hours: 3));
      expect(formatRelativeTime(t), '3h');
    });

    test('shows "yesterday" for 1 day', () {
      final t = DateTime.now().subtract(const Duration(days: 1));
      expect(formatRelativeTime(t), 'yesterday');
    });

    test('shows days for < 7 days', () {
      final t = DateTime.now().subtract(const Duration(days: 4));
      expect(formatRelativeTime(t), '4d');
    });

    test('shows month/day for older events', () {
      final t = DateTime(2026, 5, 12);
      expect(formatRelativeTime(t), 'May 12');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Recommendations
  // ─────────────────────────────────────────────────────────────────────────────

  group('buildRecommendations', () {
    test('suggests first invoice when invoices empty', () {
      final biz = Business.fromRow(mockBusinessRow());
      final recs = buildRecommendations(
        business: biz,
        financials: Financials.empty,
        invoices: [],
      );
      final firstInv = recs.where((r) => r.id == 'rec_first_invoice');
      expect(firstInv, isNotEmpty);
      expect(firstInv.first.priority, 'urgent');
    });

    test('suggests follow-up when overdue invoices exist', () {
      final biz = Business.fromRow(mockBusinessRow());
      final fin = Financials(
        revenueThisMonth: 5000,
        expensesThisMonth: 3000,
        outstanding: 2400,
        outstandingCount: 1,
        outstandingOverdueCount: 1,
        pipeline: 0,
      );
      final recs = buildRecommendations(business: biz, financials: fin, invoices: []);
      final followup = recs.where((r) => r.id == 'rec_followup_overdue');
      expect(followup, isNotEmpty);
      expect(followup.first.priority, 'urgent');
    });

    test('suggests expense logging when no expenses', () {
      final biz = Business.fromRow(mockBusinessRow());
      final fin = Financials(
        revenueThisMonth: 5000, expensesThisMonth: 0,
        outstanding: 0, outstandingCount: 0, outstandingOverdueCount: 0, pipeline: 0,
      );
      final recs = buildRecommendations(business: biz, financials: fin, invoices: []);
      expect(recs.where((r) => r.id == 'rec_first_expense'), isNotEmpty);
    });

    test('suggests profile completion when industry/city missing', () {
      final row = mockBusinessRow(industry: '', city: '');
      final biz = Business.fromRow(row);
      final recs = buildRecommendations(
        business: biz, financials: Financials.empty, invoices: [],
      );
      expect(recs.where((r) => r.id == 'rec_profile'), isNotEmpty);
    });

    test('suggests verification when unverified with data', () {
      final row = mockBusinessRow(verified: false);
      final biz = Business.fromRow(row);
      final inv = Invoice.fromRow(mockInvoiceRow());
      final recs = buildRecommendations(
        business: biz, financials: Financials.empty, invoices: [inv],
      );
      expect(recs.where((r) => r.id == 'rec_verify'), isNotEmpty);
    });

    test('shows all-clear when everything is covered', () {
      final biz = Business.fromRow(mockBusinessRow());
      final fin = Financials(
        revenueThisMonth: 10000, expensesThisMonth: 5000,
        outstanding: 0, outstandingCount: 0, outstandingOverdueCount: 0, pipeline: 0,
      );
      final inv = Invoice.fromRow(mockInvoiceRow());
      final recs = buildRecommendations(
        business: biz, financials: fin, invoices: [inv],
      );
      expect(recs.where((r) => r.id == 'rec_all_clear'), isNotEmpty);
    });

    test('sorts by priority (urgent first)', () {
      final biz = Business.fromRow(mockBusinessRow(verified: false));
      final fin = Financials(
        revenueThisMonth: 5000, expensesThisMonth: 3000,
        outstanding: 2400, outstandingCount: 1, outstandingOverdueCount: 1, pipeline: 0,
      );
      final inv = Invoice.fromRow(mockInvoiceRow());
      final recs = buildRecommendations(business: biz, financials: fin, invoices: [inv]);
      expect(recs.first.priority, 'urgent');
    });
  });
}
