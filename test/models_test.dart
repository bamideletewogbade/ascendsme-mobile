import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import '../lib/core/models.dart';

void main() {
  group('formatGHS', () {
    test('formats positive amounts with commas', () {
      expect(formatGHS(18420), 'GHS 18,420');
      expect(formatGHS(1000), 'GHS 1,000');
      expect(formatGHS(500), 'GHS 500');
      expect(formatGHS(999), 'GHS 999');
      expect(formatGHS(1000000), 'GHS 1,000,000');
    });

    test('formats zero', () {
      expect(formatGHS(0), 'GHS 0');
    });

    test('formats negative amounts', () {
      expect(formatGHS(-500), '-GHS 500');
      expect(formatGHS(-18420), '-GHS 18,420');
    });
  });

  group('formatChangePct', () {
    test('returns null for null', () {
      expect(formatChangePct(null), isNull);
    });

    test('formats positive with + prefix', () {
      expect(formatChangePct(12.3), '+12%');
      expect(formatChangePct(0.5), '+1%');
    });

    test('formats negative with - prefix', () {
      expect(formatChangePct(-5.8), '-6%');
    });

    test('formats zero', () {
      expect(formatChangePct(0.0), '0%');
    });
  });

  group('Business.fromRow', () {
    test('parses a full business row correctly', () {
      final row = mockBusinessRow();
      final biz = Business.fromRow(row);

      expect(biz.id, 'biz-001');
      expect(biz.name, 'Akwaaba Threads');
      expect(biz.handle, '@akwaabathreads');
      expect(biz.industry, 'Fashion');
      expect(biz.city, 'Accra');
      expect(biz.region, 'Greater Accra');
      expect(biz.tier, 'SME Suite Lite');
      expect(biz.initials, 'AT');
      expect(biz.sustainabilityScore, 72);
      expect(biz.creditScore, 684);
      expect(biz.verified, true);
      expect(biz.monthlyRevenue, 0); // Not stored on businesses table
      expect(biz.scoreF, 70);
      expect(biz.scoreO, 65);
      expect(biz.scoreG, 80);
      expect(biz.scoreC, 75);
    });

    test('handles missing industry gracefully', () {
      final row = mockBusinessRow(industry: '');
      expect(Business.fromRow(row).industry, 'Business');
    });

    test('handles null industry gracefully', () {
      final row = mockBusinessRow();
      row['industry'] = null;
      expect(Business.fromRow(row).industry, 'Business');
    });

    test('maps canonical industries to display labels', () {
      final cases = {
        'retail_trade': 'Retail',
        'services_consulting': 'Services & Consulting',
        'food_catering': 'Food & Beverage',
        'salon_barber': 'Beauty & Wellness',
        'fashion': 'Fashion',
        'other': 'Other',
      };
      for (final entry in cases.entries) {
        final row = mockBusinessRow(industry: entry.key);
        expect(Business.fromRow(row).industry, entry.value);
      }
    });

    test('maps null city/region to —', () {
      final row = mockBusinessRow(city: '', region: '');
      final biz = Business.fromRow(row);
      expect(biz.city, '—');
      expect(biz.region, '—');
    });

    test('determines verified from tier_status', () {
      final v = mockBusinessRow(verified: true);
      expect(Business.fromRow(v).verified, true);

      final nv = mockBusinessRow(verified: false);
      expect(Business.fromRow(nv).verified, false);
    });

    test('verified from verification_tier', () {
      final row = mockBusinessRow()..remove('tier_status');
      row['verification_tier'] = 'tier1';
      expect(Business.fromRow(row).verified, true);
    });

    test('verified from verification_status', () {
      final row = mockBusinessRow()..remove('tier_status');
      row['verification_status'] = 'bronze';
      expect(Business.fromRow(row).verified, true);
    });
  });

  group('Customer.fromRow', () {
    test('parses a full customer row', () {
      final c = Customer.fromRow(mockCustomerRow());
      expect(c.id, 'cust-001');
      expect(c.fullName, 'Kente Co.');
      expect(c.phone, '0244000001');
      expect(c.email, 'kente@example.com');
    });

    test('handles null phone and email', () {
      final c = Customer.fromRow(mockCustomerRow(phone: null, email: null));
      expect(c.phone, isNull);
      expect(c.email, isNull);
    });

    test('handles empty name', () {
      final c = Customer.fromRow(mockCustomerRow(name: ''));
      expect(c.fullName, 'Unnamed customer');
    });

    test('handles null name', () {
      final row = mockCustomerRow();
      row['full_name'] = null;
      final c = Customer.fromRow(row);
      expect(c.fullName, 'Unnamed customer');
    });
  });

  group('Invoice.fromRow', () {
    test('parses a full invoice row', () {
      final inv = Invoice.fromRow(mockInvoiceRow());
      expect(inv.id, 'OPH3F2-INV-0001');
      expect(inv.customer, 'Kente Co.');
      expect(inv.amount, 2400);
      expect(inv.status, 'pending');
      expect(inv.lineItems.length, 1);
      expect(inv.lineItems[0].description, 'Fabric roll');
      expect(inv.isProforma, false);
    });

    test('promotes pending past-due to overdue', () {
      final pastDue = DateTime.now().subtract(const Duration(days: 5));
      final inv = Invoice.fromRow(
        mockInvoiceRow(dueDate: pastDue.toIso8601String()),
      );
      expect(inv.status, 'overdue');
      expect(inv.days, 5);
    });

    test('leaves proforma status unchanged', () {
      final inv = Invoice.fromRow(mockInvoiceRow(status: 'proforma'));
      expect(inv.status, 'proforma');
      expect(inv.isProforma, true);
    });

    test('parses paid status', () {
      final inv = Invoice.fromRow(mockInvoiceRow(status: 'paid'));
      expect(inv.status, 'paid');
    });

    test('has pay link when enabled and token present', () {
      final inv = Invoice.fromRow(
        mockInvoiceRow(
          status: 'pending',
          payToken: 'abc123token',
          onlinePayEnabled: true,
        ),
      );
      expect(inv.hasPayLink, true);
    });

    test('does not have pay link when disabled', () {
      final inv = Invoice.fromRow(
        mockInvoiceRow(status: 'pending', payToken: 'abc123'),
      );
      expect(inv.hasPayLink, false);
    });

    test('parses valid_until for proformas', () {
      final until = DateTime.now().add(const Duration(days: 14));
      final inv = Invoice.fromRow(
        mockInvoiceRow(status: 'proforma', validUntil: until.toIso8601String()),
      );
      expect(inv.validUntil, isNotNull);
      expect(inv.validUntil!.difference(DateTime.now()).inDays, closeTo(14, 1));
    });
  });

  group('InvoiceLineItem.fromJson', () {
    test('parses web canonical format (description, quantity, price)', () {
      final item = InvoiceLineItem.fromJson({
        'description': 'Fabric roll',
        'quantity': 3,
        'price': 150,
      });
      expect(item.description, 'Fabric roll');
      expect(item.quantity, 3);
      expect(item.unitPrice, 150);
      expect(item.amount, 450);
    });

    test('parses legacy format (description, amount)', () {
      final item = InvoiceLineItem.fromJson({
        'description': 'Service fee',
        'amount': 500,
      });
      expect(item.description, 'Service fee');
      expect(item.amount, 500);
      expect(item.quantity, isNull);
      expect(item.unitPrice, isNull);
    });

    test('falls back with empty/invalid input', () {
      final item = InvoiceLineItem.fromJson(null);
      expect(item.description, 'Item');
      expect(item.amount, 0);
    });

    test('shows qty label when both quantity and price present', () {
      final item = InvoiceLineItem.fromJson({
        'description': 'Fabric',
        'quantity': 3,
        'price': 150,
      });
      expect(item.qtyLabel, '3 × GHS 150');
    });

    test('qty label null when missing quantity/price', () {
      final item = InvoiceLineItem.fromJson({'description': 'Fee', 'amount': 500});
      expect(item.qtyLabel, isNull);
    });
  });

  group('Financials', () {
    test('empty constant has all zeros', () {
      expect(Financials.empty.isEmpty, true);
      expect(Financials.empty.revenueThisMonth, 0);
    });

    test('toMap and fromMap round-trip', () {
      final f = Financials(
        revenueThisMonth: 15000,
        expensesThisMonth: 8000,
        outstanding: 4200,
        outstandingCount: 3,
        outstandingOverdueCount: 1,
        pipeline: 5000,
        revenueChangePctVsLastMonth: 12.5,
        expensesChangePctVsLastMonth: -3.2,
      );
      final map = f.toMap();
      final restored = Financials.fromMap(map);
      expect(restored.revenueThisMonth, 15000);
      expect(restored.expensesThisMonth, 8000);
      expect(restored.outstanding, 4200);
      expect(restored.revenueChangePctVsLastMonth, 12.5);
      expect(restored.expensesChangePctVsLastMonth, -3.2);
    });

    test('isEmpty detects zero fields', () {
      expect(Financials.empty.isEmpty, true);
      expect(
        Financials(revenueThisMonth: 100, expensesThisMonth: 0, outstanding: 0,
            outstandingCount: 0, outstandingOverdueCount: 0, pipeline: 0).isEmpty,
        false,
      );
    });
  });

  group('InventoryItem.fromRow', () {
    test('parses a full product row', () {
      final item = InventoryItem.fromRow(mockProductRow());
      expect(item.id, 'prod-001');
      expect(item.name, 'Kente cloth');
      expect(item.sku, 'KNT-001');
      expect(item.currentStock, 15);
      expect(item.lowStock, false);
      expect(item.isGoods, true);
    });

    test('detects low stock', () {
      final item = InventoryItem.fromRow(
        mockProductRow(currentStock: 3, lowStockThreshold: 5),
      );
      expect(item.lowStock, true);
    });

    test('handles SERVICE type', () {
      final item = InventoryItem.fromRow(mockProductRow(type: 'SERVICE'));
      expect(item.isGoods, false);
    });

    test('handles null name', () {
      final item = InventoryItem.fromRow(
        mockProductRow(name: ''),
      );
      expect(item.name, 'Unnamed product');
    });
  });

  group('StaffMember.fromRow', () {
    test('parses a full staff row', () {
      final s = StaffMember.fromRow(mockStaffRow());
      expect(s.staffName, 'John Doe');
      expect(s.role, 'Tailor');
      expect(s.salaryMonthly, 1500.0);
      expect(s.isActive, true);
    });

    test('handles null name', () {
      final s = StaffMember.fromRow(mockStaffRow(name: ''));
      expect(s.staffName, 'Unnamed staff');
    });

    test('defaults isActive to true', () {
      final row = mockStaffRow();
      row.remove('is_active');
      expect(StaffMember.fromRow(row).isActive, true);
    });
  });

  group('Expense.fromRow', () {
    test('parses a full expense row', () {
      final e = Expense.fromRow(mockExpenseRow());
      expect(e.amount, 500);
      expect(e.category, 'Utilities');
      expect(e.mappedCategory, 'opex_utilities');
      expect(e.sustainabilityTagged, false);
      expect(e.paymentSource, 'momo');
    });

    test('category icon maps correctly', () {
      final checks = {
        'cogs': 'inventory_2',
        'opex_rent': 'home',
        'opex_utilities': 'bolt',
        'labor': 'people',
        'marketing': 'campaign',
        'logistics': 'local_shipping',
        'compliance': 'balance',
        'other': 'receipt',
      };
      for (final entry in checks.entries) {
        final e = Expense(
          id: 'e1', amount: 100, expenseDate: DateTime.now(),
          category: 'Test', mappedCategory: entry.key,
        );
        expect(e.categoryIcon, entry.value);
      }
    });
  });

  group('Receipt.fromRow', () {
    test('parses a receipt with invoice link', () {
      final r = Receipt.fromRow(mockReceiptRow(invoiceId: 'inv-001'));
      expect(r.isInvoicePayment, true);
      expect(r.invoiceId, 'inv-001');
    });

    test('parses a direct sale receipt', () {
      final r = Receipt.fromRow(mockReceiptRow());
      expect(r.isInvoicePayment, false);
      expect(r.invoiceId, isNull);
    });

    test('methodLabel maps correctly', () {
      expect(Receipt.fromRow(mockReceiptRow(paymentMethod: 'momo')).methodLabel, 'Mobile Money');
      expect(Receipt.fromRow(mockReceiptRow(paymentMethod: 'bank')).methodLabel, 'Bank transfer');
      expect(Receipt.fromRow(mockReceiptRow(paymentMethod: 'paystack')).methodLabel, 'Card');
      expect(Receipt.fromRow(mockReceiptRow(paymentMethod: 'cash')).methodLabel, 'Cash');
    });
  });

  group('RecurringTemplate.fromRow', () {
    test('parses monthly template', () {
      final row = {
        'id': 'rec-001',
        'business_id': 'biz-001',
        'customer_name': 'Kente Co.',
        'customer_email': 'kente@example.com',
        'description': 'Monthly retainer',
        'total_amount': 2000,
        'frequency': 'monthly',
        'day_of_month': 1,
        'next_invoice_date': DateTime.now().add(const Duration(days: 15)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      };
      final t = RecurringTemplate.fromRow(row);
      expect(t.customerName, 'Kente Co.');
      expect(t.frequency, RecurringFrequency.monthly);
      expect(t.frequencyLabel, 'Monthly');
      expect(t.amount, 2000);
      expect(t.isActive, true);
    });

    test('parses weekly template', () {
      final row = {
        'id': 'rec-002',
        'business_id': 'biz-001',
        'customer_name': 'Weekly Client',
        'description': 'Weekly service',
        'total_amount': 500,
        'frequency': 'weekly',
        'day_of_week': 1,
        'next_invoice_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      };
      final t = RecurringTemplate.fromRow(row);
      expect(t.frequency, RecurringFrequency.weekly);
      expect(t.frequencyLabel, 'Weekly');
    });
  });

  group('ScoreTier / getTier', () {
    test('returns seedling for score < 30', () {
      expect(getTier(0).label, 'Seedling');
      expect(getTier(29).label, 'Seedling');
    });

    test('returns sprout for 30-49', () {
      expect(getTier(30).label, 'Sprout');
      expect(getTier(49).label, 'Sprout');
    });

    test('returns gold for 85-94', () {
      expect(getTier(85).label, 'Gold');
      expect(getTier(94).label, 'Gold');
    });

    test('returns indigo for 95+', () {
      expect(getTier(95).label, 'Indigo');
      expect(getTier(100).label, 'Indigo');
    });
  });

  group('getNextTier', () {
    test('returns next tier above current score', () {
      expect(getNextTier(0)!.label, 'Sprout');
      expect(getNextTier(30)!.label, 'Bronze');
      expect(getNextTier(70)!.label, 'Gold');
    });

    test('returns null at max tier', () {
      expect(getNextTier(100), isNull);
    });
  });

  group('CrmProfile.smartSegments', () {
    test('identifies at-risk customers', () {
      final p = CrmProfile(
        id: '1', businessId: 'biz-1', customerName: 'Test',
        churnRiskScore: 0.7,
      );
      expect(p.smartSegments, contains('At-risk'));
    });

    test('identifies high-value customers', () {
      final p = CrmProfile(
        id: '1', businessId: 'biz-1', customerName: 'Test',
        totalSpentGhs: 1500,
      );
      expect(p.smartSegments, contains('High value'));
    });

    test('identifies inactive customers', () {
      final longAgo = DateTime.now().subtract(const Duration(days: 100));
      final p = CrmProfile(
        id: '1', businessId: 'biz-1', customerName: 'Test',
        lastInteractionDate: longAgo.toIso8601String(),
      );
      expect(p.smartSegments, contains('Inactive 90d+'));
    });

    test('identifies open leads', () {
      final p = CrmProfile(
        id: '1', businessId: 'biz-1', customerName: 'Test',
        leadStatus: 'proposal_sent',
      );
      expect(p.smartSegments, contains('Open lead'));
    });
  });

  group('Booking', () {
    Booking _booking({String status = 'pending'}) => Booking(
      id: '1', businessId: 'biz-1', serviceName: 'Haircut',
      customerName: 'Adwoa', status: status,
      startTime: DateTime(2026, 6, 10, 10, 0),
      durationMinutes: 60,
      createdAt: DateTime(2026, 6, 9),
    );

    test('endTime is startTime + duration', () {
      final b = _booking();
      expect(b.endTime.hour, 11);
      expect(b.endTime.minute, 0);
    });

    test('statusLabel maps correctly', () {
      expect(_booking(status: 'confirmed').statusLabel, 'Confirmed');
      expect(_booking(status: 'cancelled').statusLabel, 'Cancelled');
      expect(_booking(status: 'fulfilled').statusLabel, 'Fulfilled');
      expect(_booking(status: 'pending').statusLabel, 'Pending');
    });
  });

  group('CrmInteraction', () {
    test('typeLabel maps correctly', () {
      final base = (String id, String type) => CrmInteraction(
        id: id, businessId: 'biz-1', interactionType: type,
        interactionDate: DateTime.now().toIso8601String(),
        description: 'Test',
      );
      expect(base('1', 'voice_call').typeLabel, 'Phone call');
      expect(base('2', 'whatsapp').typeLabel, 'WhatsApp');
      expect(base('3', 'email').typeLabel, 'Email');
      expect(base('4', 'meeting').typeLabel, 'Meeting');
      expect(base('5', 'note').typeLabel, 'Note');
    });
  });

  group('SubscriptionPlan', () {
    test('parses plan row correctly', () {
      final p = SubscriptionPlan.fromRow(mockSubscriptionPlanRow());
      expect(p.tierCode, 'lite');
      expect(p.priceMonthly, 49);
      expect(p.features.length, 3);
    });
  });

  group('SubscriptionInfo', () {
    test('parses subscription with tier join', () {
      final info = SubscriptionInfo.fromRow(mockSubscriptionRow());
      expect(info.tierCode, 'lite');
      expect(info.status, 'active');
    });
  });

  group('canonicalIndustry', () {
    test('maps mobile labels to canonical snake_case', () {
      expect(canonicalIndustry('Retail'), 'retail_trade');
      expect(canonicalIndustry('Food & Beverage'), 'food_catering');
      expect(canonicalIndustry('Fashion'), 'fashion');
      expect(canonicalIndustry('Beauty & Wellness'), 'salon_barber');
      expect(canonicalIndustry('Services'), 'services_consulting');
      expect(canonicalIndustry('Technology'), 'other');
      expect(canonicalIndustry(''), '');
    });
  });

  group('monthLabel / formatLongDate', () {
    test('monthLabel formats correctly', () {
      expect(monthLabel(2026, 6), 'Jun 2026');
      expect(monthLabel(2026, 1), 'Jan 2026');
    });

    test('formatLongDate formats correctly', () {
      final d = DateTime(2026, 6, 2);
      expect(formatLongDate(d), 'Jun 2, 2026');
    });
  });
}
