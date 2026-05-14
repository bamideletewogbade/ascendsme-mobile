import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupabaseService — thin wrapper around supabase_flutter.
// Shared with the AscendSME web platform (same project / same DB schema).
// ─────────────────────────────────────────────────────────────────────────────
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Call once in main() before runApp.
  static Future<void> initialize() async {
    if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty) {
      return; // keys not set yet — run in mock mode
    }
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static User? get currentUser => client.auth.currentUser;

  static Session? get currentSession => client.auth.currentSession;

  static Stream<AuthState> get authStream => client.auth.onAuthStateChange;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      client.auth.signInWithPassword(email: email, password: password);

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data, // e.g. business_name, phone
  }) =>
      client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );

  static Future<void> signOut() => client.auth.signOut();

  static Future<void> resetPassword(String email) =>
      client.auth.resetPasswordForEmail(email);

  // ── Profile ────────────────────────────────────────────────────────────────

  /// Fetch the business profile for the currently signed-in user.
  /// Backend column is `user_id` (see Collinlar/ascendsme-b
  /// 20251109132813_create_initial_schema.sql). The handle_new_user trigger
  /// (20260514220000) auto-creates a row from auth.signUp metadata, so this
  /// should return non-null on the first call after signup.
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final res = await client
        .from('businesses')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    return res;
  }

  /// Create or update the business profile row. Backend uses `user_id`.
  static Future<void> upsertProfile(Map<String, dynamic> data) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await client.from('businesses').upsert({
      'user_id': uid,
      ...data,
    });
  }

  // ── Financials ─────────────────────────────────────────────────────────────
  // Roll-up queries against receipts / expenses / invoices. RLS scopes every
  // row to the signed-in user's businesses already, so we just filter by
  // business_id and a date range and sum client-side. Volumes are SME-scale
  // (typically <1000 rows/month), so this is plenty fast.

  /// Sum `receipts.total_amount` between [start] and [end) for the given business.
  static Future<double> sumReceipts({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await client
        .from('receipts')
        .select('total_amount')
        .eq('business_id', businessId)
        .gte('paid_date', start.toIso8601String())
        .lt('paid_date', end.toIso8601String());
    var total = 0.0;
    for (final r in rows as List) {
      total += ((r as Map)['total_amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  /// Sum `expenses.amount_ghs` between [start] and [end) for the given business.
  static Future<double> sumExpenses({
    required String businessId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await client
        .from('expenses')
        .select('amount_ghs')
        .eq('business_id', businessId)
        .gte('expense_date', start.toIso8601String().substring(0, 10))
        .lt('expense_date', end.toIso8601String().substring(0, 10));
    var total = 0.0;
    for (final r in rows as List) {
      total += ((r as Map)['amount_ghs'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  /// Fetch open invoices (status != 'paid') for the business. Returns a
  /// list of {total_amount, status, due_date} maps suitable for both summing
  /// and counting overdue items.
  static Future<List<Map<String, dynamic>>> fetchOpenInvoices({
    required String businessId,
  }) async {
    final rows = await client
        .from('invoices')
        .select('total_amount, status, due_date')
        .eq('business_id', businessId)
        .neq('status', 'paid');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Fetch all invoices for the business, ordered most-recent-first.
  /// Used to populate the Cards-layout invoicing card and the full invoices
  /// list screen. Bound by [limit] (default 200) since SME volume is low and
  /// we'd rather load everything in one round-trip than paginate.
  static Future<List<Map<String, dynamic>>> fetchInvoices({
    required String businessId,
    int limit = 200,
  }) async {
    final rows = await client
        .from('invoices')
        .select(
            'id, invoice_number, client_name, client_email, line_items, '
            'total_amount, status, due_date, created_at, '
            'pay_token, online_pay_enabled')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  // ── Invoice lifecycle mutations ────────────────────────────────────────────

  /// Mark a manually-paid invoice as paid: insert a receipts row referencing
  /// the invoice, then update the invoice's status. NOT atomic (no RPC yet);
  /// if the second UPDATE fails, the receipt still exists (creates a phantom
  /// receipt) — callers should refresh state and let the user retry. A future
  /// migration could wrap this in a `mark_invoice_paid_manual` SECURITY
  /// DEFINER function for atomicity.
  ///
  /// [paymentMethod] must be one of 'cash' | 'momo' | 'bank' (the 'paystack'
  /// option is reserved for the webhook-driven finalize_invoice_paystack_payment
  /// flow).
  static Future<Map<String, dynamic>> markInvoicePaid({
    required String invoiceId,
    required String businessId,
    required String paymentMethod,
  }) async {
    assert(['cash', 'momo', 'bank'].contains(paymentMethod),
        'paymentMethod must be cash, momo, or bank');

    // Fetch the invoice so we can copy the snapshot into the receipt.
    final invRow = await client
        .from('invoices')
        .select(
            'id, business_id, invoice_number, client_name, client_email, '
            'line_items, total_amount')
        .eq('id', invoiceId)
        .single();

    final receiptNumberRaw = await client.rpc(
      'get_next_document_number',
      params: {
        'p_business_id': businessId,
        'p_document_type': 'receipt',
      },
    );
    final receiptNumber = receiptNumberRaw.toString();

    final receiptRow = await client
        .from('receipts')
        .insert({
          'business_id': businessId,
          'invoice_id': invoiceId,
          'receipt_number': receiptNumber,
          'client_name': invRow['client_name'],
          'client_email': invRow['client_email'],
          'line_items': invRow['line_items'],
          'total_amount': invRow['total_amount'],
          'payment_method': paymentMethod,
          'paid_date': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    await client
        .from('invoices')
        .update({'status': 'paid'})
        .eq('id', invoiceId);

    return Map<String, dynamic>.from(receiptRow);
  }

  /// Mark an invoice as void (cancelled/invalidated). Accrual ledger reversal
  /// is left to the web app; from the mobile side we just flip the status.
  static Future<void> voidInvoice({required String invoiceId}) async {
    await client
        .from('invoices')
        .update({'status': 'void'})
        .eq('id', invoiceId);
  }

  /// Enable the hosted Paystack pay page for this invoice by generating a
  /// 32-character opaque token and setting online_pay_enabled = true.
  /// Returns the generated token so the caller can build the share URL.
  ///
  /// The token must be ≥16 chars (validated by get_public_invoice_for_pay).
  /// We use 24 random bytes → 32 base64url chars; well above the floor.
  static Future<String> enableInvoicePayLink({
    required String invoiceId,
  }) async {
    final token = _generatePayToken();
    await client
        .from('invoices')
        .update({
          'pay_token': token,
          'pay_token_created_at':
              DateTime.now().toUtc().toIso8601String(),
          'online_pay_enabled': true,
        })
        .eq('id', invoiceId);
    return token;
  }

  static String _generatePayToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(24, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // ── Invoice mutation ──────────────────────────────────────────────────────

  /// Create a new invoice for [businessId]. Generates the invoice number via
  /// the `get_next_document_number` Postgres function (returns formatted
  /// strings like `OPH3F2-INV-0001` — see
  /// 20260122000001_business_document_prefix_and_profile.sql) and INSERTs.
  ///
  /// Returns the persisted row so callers can show the invoice number on a
  /// confirmation screen. Status defaults to 'pending'; due_date defaults to
  /// 30 days out (net-30) if not provided.
  ///
  /// Throws [PostgrestException] on RLS / validation failure — caller should
  /// catch and surface a friendly error.
  static Future<Map<String, dynamic>> createInvoice({
    required String businessId,
    required String customerName,
    required num totalAmount,
    String? description,
    String? customerEmail,
    DateTime? dueDate,
  }) async {
    final invoiceNumberRaw = await client.rpc(
      'get_next_document_number',
      params: {
        'p_business_id': businessId,
        'p_document_type': 'invoice',
      },
    );
    final invoiceNumber = invoiceNumberRaw.toString();

    final desc = (description ?? '').trim();
    final lineItems = [
      {
        'description': desc.isNotEmpty ? desc : 'Invoice for $customerName',
        'amount': totalAmount,
      }
    ];

    final due = dueDate ?? DateTime.now().add(const Duration(days: 30));
    final dueIso = due.toIso8601String().substring(0, 10); // YYYY-MM-DD

    final row = await client
        .from('invoices')
        .insert({
          'business_id': businessId,
          'invoice_number': invoiceNumber,
          'client_name': customerName,
          'client_email': customerEmail,
          'line_items': lineItems,
          'total_amount': totalAmount,
          'status': 'pending',
          'due_date': dueIso,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }
}
