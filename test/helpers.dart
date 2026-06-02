import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/core/models.dart';
import '../lib/core/tokens.dart';
import '../lib/services/connectivity_service.dart';
import '../lib/services/sync_service.dart';
import '../lib/services/app_logger.dart';
import '../lib/state/app_state.dart';

/// Initialize the logger (idempotent) before any test that uses `log.*`.
void initTestLogger() {
  try {
    log.init();
  } catch (_) {}
}

/// Create a mock business row for use with Business.fromRow.
Map<String, dynamic> mockBusinessRow({
  String? id,
  String name = 'Akwaaba Threads',
  String handle = 'akwaabathreads',
  String industry = 'fashion',
  String city = 'Accra',
  String region = 'Greater Accra',
  String tier = 'lite',
  int sustainabilityScore = 72,
  int creditScore = 684,
  bool verified = true,
  int scoreF = 70,
  int scoreO = 65,
  int scoreG = 80,
  int scoreC = 75,
}) {
  return {
    'id': id ?? 'biz-001',
    'user_id': 'user-001',
    'business_name': name,
    'business_handle': handle,
    'industry': industry,
    'city': city,
    'region': region,
    'subscription_tier': tier,
    'sustainability_score': sustainabilityScore,
    'credit_score': creditScore,
    'tier_status': verified ? 'verified' : 'grey',
    'score_f': scoreF,
    'score_o': scoreO,
    'score_g': scoreG,
    'score_c': scoreC,
  };
}

/// Create a mock customer row.
Map<String, dynamic> mockCustomerRow({
  String id = 'cust-001',
  String name = 'Kente Co.',
  String? phone = '0244000001',
  String? email = 'kente@example.com',
}) {
  return {
    'id': id,
    'full_name': name,
    'phone': phone,
    'email': email,
  };
}

/// Create a mock invoice row.
Map<String, dynamic> mockInvoiceRow({
  String id = 'inv-001',
  String invoiceNumber = 'OPH3F2-INV-0001',
  String clientName = 'Kente Co.',
  String status = 'pending',
  int totalAmount = 2400,
  String? dueDate,
  String? createdAt,
  String? payToken,
  bool onlinePayEnabled = false,
  String? clientEmail,
  String? validUntil,
}) {
  final now = DateTime.now();
  return {
    'id': id,
    'invoice_number': invoiceNumber,
    'client_name': clientName,
    'client_email': clientEmail,
    'line_items': [
      {'description': 'Fabric roll', 'quantity': 2, 'price': 1200}
    ],
    'total_amount': totalAmount,
    'status': status,
    'due_date': dueDate ?? now.add(const Duration(days: 14)).toIso8601String(),
    'created_at': createdAt ?? now.subtract(const Duration(days: 1)).toIso8601String(),
    'pay_token': payToken,
    'online_pay_enabled': onlinePayEnabled,
    'valid_until': validUntil,
  };
}

/// Create a mock receipt row.
Map<String, dynamic> mockReceiptRow({
  String id = 'rct-001',
  String? invoiceId,
  String clientName = 'Kente Co.',
  num totalAmount = 2400,
  String paymentMethod = 'momo',
  String? paidDate,
  String? receiptNumber = 'RCT-0001',
}) {
  return {
    'id': id,
    'receipt_number': receiptNumber,
    'invoice_id': invoiceId,
    'client_name': clientName,
    'total_amount': totalAmount,
    'payment_method': paymentMethod,
    'paid_date': paidDate ?? DateTime.now().toIso8601String(),
  };
}

/// Create a mock expense row.
Map<String, dynamic> mockExpenseRow({
  String id = 'exp-001',
  num amount = 500,
  String category = 'Utilities',
  String mappedCategory = 'opex_utilities',
  bool sustainabilityTagged = false,
  String paymentSource = 'momo',
  String? description = 'ECG bill',
  String? date,
}) {
  return {
    'id': id,
    'amount_ghs': amount,
    'expense_date': date ?? DateTime.now().toIso8601String().substring(0, 10),
    'description': description,
    'category': category,
    'mapped_category': mappedCategory,
    'sustainability_tagged': sustainabilityTagged,
    'payment_source': paymentSource,
  };
}

/// Create a mock inventory product row.
Map<String, dynamic> mockProductRow({
  String id = 'prod-001',
  String name = 'Kente cloth',
  String sku = 'KNT-001',
  String category = 'Fabric',
  int currentStock = 15,
  int? lowStockThreshold = 5,
  double unitPrice = 150.0,
  String type = 'GOODS',
}) {
  return {
    'id': id,
    'business_id': 'biz-001',
    'name': name,
    'sku': sku,
    'category': category,
    'current_stock': currentStock,
    'low_stock_threshold': lowStockThreshold,
    'unit_price': unitPrice,
    'type': type,
  };
}

/// Create a mock staff member row.
Map<String, dynamic> mockStaffRow({
  String id = 'stf-001',
  String name = 'John Doe',
  String role = 'Tailor',
  double salaryMonthly = 1500.0,
  bool isActive = true,
  String? email = 'john@example.com',
  String? phone = '0244000001',
}) {
  return {
    'id': id,
    'business_id': 'biz-001',
    'staff_name': name,
    'staff_email': email,
    'staff_phone': phone,
    'role': role,
    'salary_monthly_ghs': salaryMonthly,
    'hire_date': '2026-01-15',
    'is_active': isActive,
  };
}

/// Create a mock subscription plan row.
Map<String, dynamic> mockSubscriptionPlanRow({
  String id = 'tier-001',
  String tierCode = 'lite',
  String tierName = 'SME Suite Lite',
  int priceMonthly = 49,
  int? priceQuarterly = 129,
  int? priceYearly = 499,
  List<String> features = const ['Invoicing', 'Expenses', 'CRM'],
}) {
  return {
    'id': id,
    'tier_code': tierCode,
    'tier_name': tierName,
    'price_monthly_ghs': priceMonthly,
    'price_quarterly_ghs': priceQuarterly,
    'price_yearly_ghs': priceYearly,
    'description': '$tierName plan',
    'features': features,
  };
}

/// Create a mock subscription row.
Map<String, dynamic> mockSubscriptionRow({
  String id = 'sub-001',
  String businessId = 'biz-001',
  String status = 'active',
  int daysUntilEnd = 30,
  String tierCode = 'lite',
  String tierName = 'SME Suite Lite',
}) {
  final end = DateTime.now().add(Duration(days: daysUntilEnd));
  return {
    'id': id,
    'business_id': businessId,
    'tier_id': 'tier-001',
    'status': status,
    'current_period_end': end.toIso8601String(),
    'tier': {
      'tier_code': tierCode,
      'tier_name': tierName,
    },
  };
}

/// A simple stub connectivity service for tests (always online/offline).
class StubConnectivityService extends ConnectivityService {
  final bool online;
  StubConnectivityService({this.online = true});

  @override
  bool get isOnline => online;

  @override
  bool get initialized => true;
}

/// A simple stub sync service for tests (empty queue).
class StubSyncService extends SyncService {
  @override
  Future<void> restore() async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> enqueue({
    required String domain,
    required String action,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    // no-op for tests
  }
}

/// Create a test AppState with stub services.
AppState createTestAppState({bool online = true}) {
  return AppState(
    connectivity: StubConnectivityService(online: online),
    syncService: StubSyncService(),
  );
}

/// Wrap a widget in all required providers for testing.
/// Allows overriding specific providers by passing [overrides].
Widget wrapWithProviders(
  Widget child, {
  AppState? appState,
  ConnectivityService? connectivity,
  SyncService? syncService,
}) {
  final state = appState ?? createTestAppState();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider.value(
        value: connectivity ?? state.connectivity,
      ),
      ChangeNotifierProvider.value(
        value: syncService ?? state.syncService,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: child,
    ),
  );
}
