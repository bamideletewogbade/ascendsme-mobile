import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'app_logger.dart';

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
      client.auth.resetPasswordForEmail(
        email,
        redirectTo: AppConfig.oauthRedirectUrl,
      );

  /// Start the Google OAuth flow. Launches the system browser, the user signs
  /// in with Google, and the redirect URL (`ascendsme://auth-callback`) bounces
  /// back into the app — supabase_flutter automatically captures the callback
  /// and emits a `signedIn` event on the auth stream.
  ///
  /// Returns `true` if the browser launched successfully. The actual sign-in
  /// completion happens asynchronously via the auth stream listener wired in
  /// main.dart.
  static Future<bool> signInWithGoogle() =>
      client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

  // ── Profile ────────────────────────────────────────────────────────────────

  /// Fetch the business profile for the currently signed-in user.
  /// Backend column is `user_id` (see Collinlar/ascendsme-b
  /// 20251109132813_create_initial_schema.sql). The handle_new_user trigger
  /// (20260514220000) auto-creates a row from auth.signUp metadata, so this
  /// should return non-null on the first call after signup.
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    log.debug('fetchProfile — uid=$uid');
    final sw = Stopwatch()..start();
    final res = await client
        .from('businesses')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    log.debug('fetchProfile — ${res == null ? 'null (no row yet)' : 'got row id=${res['id']}'} (${sw.elapsedMilliseconds}ms)');
    return res;
  }

  /// Create or update the business profile row. Backend uses `user_id`.
  static Future<void> upsertProfile(Map<String, dynamic> data) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    log.info('upsertProfile — uid=$uid keys=${data.keys.toList()}');
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

  // ── Quick sale (direct cash/MoMo receipt) ──────────────────────────────────

  /// Insert a "direct sale" — money received without an invoice intermediary.
  /// Used for cash sales, MoMo payments at point of sale, anything where a
  /// customer pays in the moment and walks away.
  ///
  /// Goes into the same `receipts` table that `markInvoicePaid` writes to, so
  /// the row counts as revenue immediately via `sumReceipts`. The key
  /// difference: `invoice_id` is null because there's no invoice behind it.
  ///
  /// [paymentMethod] must be one of 'cash' | 'momo' | 'bank' — same validation
  /// as `markInvoicePaid`.
  static Future<Map<String, dynamic>> createSale({
    required String businessId,
    required num amount,
    required String paymentMethod,
    DateTime? paidDate,
    String? customerName,
    String? description,
  }) async {
    assert(['cash', 'momo', 'bank'].contains(paymentMethod),
        'paymentMethod must be cash, momo, or bank');
    log.info('createSale — bizId=$businessId amount=$amount method=$paymentMethod');
    final sw = Stopwatch()..start();

    final receiptNumberRaw = await client.rpc(
      'get_next_document_number',
      params: {
        'p_business_id': businessId,
        'p_document_type': 'receipt',
      },
    );
    final receiptNumber = receiptNumberRaw.toString();

    final desc = (description ?? '').trim();
    final lineItems = [
      {
        'description': desc.isNotEmpty
            ? desc
            : (customerName?.trim().isNotEmpty == true
                ? 'Sale to ${customerName!.trim()}'
                : 'Cash sale'),
        'amount': amount,
      }
    ];

    final paid = paidDate ?? DateTime.now();

    final row = await client
        .from('receipts')
        .insert({
          'business_id': businessId,
          'invoice_id': null,
          'receipt_number': receiptNumber,
          'client_name': customerName?.trim().isNotEmpty == true
              ? customerName!.trim()
              : null,
          'line_items': lineItems,
          'total_amount': amount,
          'payment_method': paymentMethod,
          'paid_date': paid.toUtc().toIso8601String(),
        })
        .select()
        .single();

    log.info('createSale — done receipt=${row['receipt_number']} (${sw.elapsedMilliseconds}ms)');
    return Map<String, dynamic>.from(row);
  }

  // ── Expense mutation ───────────────────────────────────────────────────────

  /// Insert a new expense for [businessId]. Mirrors the columns the
  /// sumExpenses aggregate already reads (`amount_ghs`, `expense_date`,
  /// `business_id`). Description is optional. Date defaults to today.
  ///
  /// Returns the persisted row so callers can confirm + refresh financials.
  /// Throws [PostgrestException] on RLS / validation failure — caller should
  /// catch and surface a friendly error.
  static Future<Map<String, dynamic>> createExpense({
    required String businessId,
    required num amount,
    DateTime? date,
    String? description,
  }) async {
    log.info('createExpense — bizId=$businessId amount=$amount');
    final sw = Stopwatch()..start();
    final d = date ?? DateTime.now();
    final dateIso = d.toIso8601String().substring(0, 10); // YYYY-MM-DD

    final row = await client
        .from('expenses')
        .insert({
          'business_id': businessId,
          'amount_ghs': amount,
          'expense_date': dateIso,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        })
        .select()
        .single();

    log.info('createExpense — done id=${row['id']} (${sw.elapsedMilliseconds}ms)');
    return Map<String, dynamic>.from(row);
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
    log.info('markInvoicePaid — invoiceId=$invoiceId method=$paymentMethod');
    final sw = Stopwatch()..start();

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

    log.info('markInvoicePaid — done receipt=${receiptRow['receipt_number']} (${sw.elapsedMilliseconds}ms)');
    return Map<String, dynamic>.from(receiptRow);
  }

  /// Mark an invoice as void (cancelled/invalidated). Accrual ledger reversal
  /// is left to the web app; from the mobile side we just flip the status.
  static Future<void> voidInvoice({required String invoiceId}) async {
    log.info('voidInvoice — invoiceId=$invoiceId');
    await client
        .from('invoices')
        .update({'status': 'void'})
        .eq('id', invoiceId);
    log.info('voidInvoice — done');
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
    log.info('enableInvoicePayLink — invoiceId=$invoiceId');
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
    log.info('enableInvoicePayLink — done token=${AppLogger.maskToken(token)}');
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
    log.info('createInvoice — bizId=$businessId customer="$customerName" amount=$totalAmount');
    final sw = Stopwatch()..start();
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

    log.info('createInvoice — done invoiceNumber=${row['invoice_number']} (${sw.elapsedMilliseconds}ms)');
    return Map<String, dynamic>.from(row);
  }
}
