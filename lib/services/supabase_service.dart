import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../core/expense_mapping.dart';
import '../core/models.dart' show canonicalIndustry;
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

  /// Sign up a new SME user. Mirrors the web platform's signup flow exactly
  /// ([ascendsme-b/src/contexts/AuthContext.tsx](signUp)): create the auth
  /// row, then explicitly INSERT into `users` and `businesses`. There is no
  /// `handle_new_user` Postgres trigger — RLS migration
  /// 20251112093402_fix_rls_policies_for_signup.sql grants INSERT to the
  /// authenticated role, and the client is expected to do the writes.
  ///
  /// If either insert fails we roll back (delete the users row if it was
  /// created, then sign out) so we don't leave an orphan auth user. Returns
  /// the original AuthResponse so callers can inspect `session` (email
  /// confirmation case has null session).
  ///
  /// [data] keys consumed: full_name, business_name, phone, industry. Anything
  /// else is forwarded to auth.raw_user_meta_data for future recovery.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    final res = await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );

    final newUser = res.user;
    if (newUser == null) return res;

    // Web sleeps 500ms here "for auth to propagate" — without it the RLS
    // policies that gate on auth.uid() may not see the new session yet.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (res.session == null) {
      // Email confirmation required: no live session, so we can't INSERT
      // under the authenticated role. The user will sign in later and we
      // bootstrap then via `ensureProfileBootstrapped`.
      log.info('signUp — no session (email confirmation pending); deferring profile bootstrap');
      return res;
    }

    final fullName = (data['full_name'] as String?)?.trim();
    final businessName = (data['business_name'] as String?)?.trim();
    final phone = (data['phone'] as String?)?.trim();
    final industry = (data['industry'] as String?)?.trim();

    try {
      await client.from('users').insert({
        'id': newUser.id,
        'email': email,
        'phone': (phone?.isNotEmpty ?? false) ? phone : null,
        'full_name': (fullName?.isNotEmpty ?? false) ? fullName : email,
        'user_type': 'sme',
      });
    } catch (e, st) {
      log.error('signUp — users INSERT failed, signing out', error: e, stackTrace: st);
      await client.auth.signOut();
      rethrow;
    }

    try {
      final canonical = canonicalIndustry(industry);
      await client.from('businesses').insert({
        'user_id': newUser.id,
        'business_name': (businessName?.isNotEmpty ?? false)
            ? businessName
            : 'My business',
        if (canonical.isNotEmpty) 'industry': canonical,
      });
    } catch (e, st) {
      log.error('signUp — businesses INSERT failed, rolling back users row', error: e, stackTrace: st);
      try {
        await client.from('users').delete().eq('id', newUser.id);
      } catch (_) {
        // Best effort — RLS shouldn't block self-delete but if it does we
        // accept the orphan rather than leave the user signed in.
      }
      await client.auth.signOut();
      rethrow;
    }

    log.info('signUp — bootstrap complete for userId=${newUser.id}');
    return res;
  }

  /// Idempotent recovery: make sure the signed-in user has matching rows in
  /// `users` and `businesses`. Call after any successful sign-in (password,
  /// Google OAuth, magic link) to heal accounts that signed up before this
  /// fix shipped, or whose Google OAuth callback brought them in without a
  /// business_name in metadata.
  ///
  /// Reads auth.raw_user_meta_data for fallback values (full_name,
  /// business_name) so a Google-OAuth-only user gets sensible defaults
  /// derived from their Google profile. Safe to call multiple times: each
  /// SELECT-then-INSERT is guarded so we never duplicate.
  static Future<void> ensureProfileBootstrapped() async {
    final u = currentUser;
    if (u == null) return;

    final existingUser = await client
        .from('users')
        .select('id')
        .eq('id', u.id)
        .maybeSingle();

    if (existingUser == null) {
      final meta = u.userMetadata ?? const <String, dynamic>{};
      final fullName = (meta['full_name'] as String?)?.trim();
      final phone = (meta['phone'] as String?)?.trim();
      log.info('ensureProfileBootstrapped — creating users row for ${u.id}');
      try {
        await client.from('users').insert({
          'id': u.id,
          'email': u.email ?? '',
          'phone': (phone?.isNotEmpty ?? false) ? phone : null,
          'full_name': (fullName?.isNotEmpty ?? false)
              ? fullName
              : (u.email ?? 'New user'),
          'user_type': 'sme',
        });
      } catch (e, st) {
        log.error('ensureProfileBootstrapped — users INSERT failed', error: e, stackTrace: st);
        return; // Don't try to create the business row without a users row.
      }
    }

    final existingBiz = await client
        .from('businesses')
        .select('id')
        .eq('user_id', u.id)
        .maybeSingle();

    if (existingBiz == null) {
      final meta = u.userMetadata ?? const <String, dynamic>{};
      final businessName = (meta['business_name'] as String?)?.trim();
      final canonical = canonicalIndustry(meta['industry'] as String?);
      log.info('ensureProfileBootstrapped — creating businesses row for ${u.id}');
      try {
        await client.from('businesses').insert({
          'user_id': u.id,
          'business_name': (businessName?.isNotEmpty ?? false)
              ? businessName
              : 'My business',
          if (canonical.isNotEmpty) 'industry': canonical,
        });
      } catch (e, st) {
        log.error('ensureProfileBootstrapped — businesses INSERT failed', error: e, stackTrace: st);
      }
    }
  }

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
  /// Backend column is `user_id` (see ascendsme-b
  /// 20251109132813_create_initial_schema.sql). There is NO Postgres trigger
  /// that auto-creates this row — the signup flow (`signUp` /
  /// `ensureProfileBootstrapped`) is responsible for the INSERT, mirroring
  /// the web platform's AuthContext.signUp.
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

  /// Fetch the business's most recent receipts (paid invoices + direct sales
  /// from Quick Sale). Used to derive the home activity feed and the eventual
  /// receipts list screen.
  static Future<List<Map<String, dynamic>>> fetchReceipts({
    required String businessId,
    int limit = 50,
  }) async {
    final rows = await client
        .from('receipts')
        .select(
            'id, receipt_number, invoice_id, client_name, line_items, '
            'total_amount, payment_method, paid_date')
        .eq('business_id', businessId)
        .order('paid_date', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Fetch the business's most recent expenses. Used to derive the home
  /// activity feed and the eventual expenses list screen.
  static Future<List<Map<String, dynamic>>> fetchExpenses({
    required String businessId,
    int limit = 50,
  }) async {
    final rows = await client
        .from('expenses')
        .select('id, amount_ghs, expense_date, description, '
            'category, mapped_category, sustainability_tagged, payment_source')
        .eq('business_id', businessId)
        .order('expense_date', ascending: false)
        .limit(limit);
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
            'pay_token, online_pay_enabled, valid_until')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  // ── Customers ──────────────────────────────────────────────────────────────
  // Minimal CRM surface for mobile. We read/write only `customers` — never
  // `crm_profiles` — so web's lifetime-value / churn-risk triggers remain the
  // single source of those rollups. We capture name + phone only; everything
  // else (lead_status, address, tags, …) has a server default or doesn't
  // belong in a one-tap inline add flow on mobile.

  /// Fetch customers for this business. When [query] is non-empty, filters by
  /// `full_name ILIKE %query%`; otherwise returns the most-recently-updated
  /// rows so the UI can show a "recent customers" list before the user types.
  static Future<List<Map<String, dynamic>>> fetchCustomers({
    required String businessId,
    String? query,
    int limit = 30,
  }) async {
    final q = (query ?? '').trim();
    var builder = client
        .from('customers')
        .select('id, full_name, phone, email')
        .eq('business_id', businessId);
    if (q.isNotEmpty) {
      builder = builder.ilike('full_name', '%$q%');
    }
    final rows = await builder
        .order('updated_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Create a customer for this business, or return the existing one if a row
  /// with the same `(business_id, full_name)` already exists (the unique
  /// constraint on the customers table — see
  /// ascendsme-b/20250115000000_add_customers_table.sql).
  ///
  /// Returns the row map (new or pre-existing). Throws on RLS / network
  /// failures — callers should catch and surface friendly errors.
  static Future<Map<String, dynamic>> createCustomer({
    required String businessId,
    required String fullName,
    String? phone,
    String? email,
  }) async {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('fullName cannot be empty');
    }
    log.info('createCustomer — bizId=$businessId name="$trimmedName"');
    final sw = Stopwatch()..start();

    try {
      final row = await client
          .from('customers')
          .insert({
            'business_id': businessId,
            'full_name': trimmedName,
            if (phone != null && phone.trim().isNotEmpty)
              'phone': phone.trim(),
            if (email != null && email.trim().isNotEmpty)
              'email': email.trim(),
          })
          .select()
          .single();
      log.info('createCustomer — created id=${row['id']} (${sw.elapsedMilliseconds}ms)');
      return Map<String, dynamic>.from(row);
    } on PostgrestException catch (e) {
      // 23505 = unique_violation. Name already used for this business — fetch
      // and return the existing row instead of bubbling up the error. This
      // makes "add customer" idempotent which is what the user expects: typing
      // a name that already exists should select it, not error.
      if (e.code == '23505') {
        log.info('createCustomer — name exists, returning existing row');
        final existing = await client
            .from('customers')
            .select()
            .eq('business_id', businessId)
            .eq('full_name', trimmedName)
            .maybeSingle();
        if (existing != null) return Map<String, dynamic>.from(existing);
      }
      rethrow;
    }
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
    String? customerId,
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
    // Same shape as createInvoice — quantity * price so the receipt renders
    // consistently in the web PDF generator.
    final lineItems = [
      {
        'description': desc.isNotEmpty
            ? desc
            : (customerName?.trim().isNotEmpty == true
                ? 'Sale to ${customerName!.trim()}'
                : 'Cash sale'),
        'quantity': 1,
        'price': amount,
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
          if (customerId != null && customerId.isNotEmpty)
            'customer_id': customerId,
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

  /// Insert a new expense for [businessId]. The web schema
  /// (20250124000001_create_expenses_table.sql) requires `category`,
  /// `mapped_category`, and `payment_source` NOT NULL — earlier versions of
  /// this method omitted them and would fail against a fresh DB.
  ///
  /// [category] is one of [kManualExpenseCategories]; we run it through
  /// [mapExpense] to derive `mapped_category` and `sustainability_tagged`,
  /// matching web's ascendsme-b/src/lib/expense-mapping.ts exactly. The
  /// description is fed into the same keyword scan, so an "Other / GRA
  /// filing" expense lands in `mapped_category='compliance'` and counts in
  /// pillar C. Eco/green/recycled descriptions auto-tag for pillar G (3 pts
  /// each, max 15).
  ///
  /// [paymentSource] must be one of 'cash' | 'momo' | 'bank' (CHECK
  /// constraint). Defaults to 'cash' for legacy callers.
  ///
  /// Returns the persisted row so callers can confirm + refresh financials.
  /// Throws [PostgrestException] on RLS / validation failure — caller should
  /// catch and surface a friendly error.
  static Future<Map<String, dynamic>> createExpense({
    required String businessId,
    required num amount,
    DateTime? date,
    String? description,
    String category = 'Other',
    String paymentSource = 'cash',
  }) async {
    assert(['cash', 'momo', 'bank'].contains(paymentSource),
        'paymentSource must be cash, momo, or bank');
    log.info('createExpense — bizId=$businessId amount=$amount category=$category source=$paymentSource');
    final sw = Stopwatch()..start();
    final d = date ?? DateTime.now();
    final dateIso = d.toIso8601String().substring(0, 10); // YYYY-MM-DD

    final mapping = mapExpense(
      manualCategory: category,
      description: description,
    );

    final row = await client
        .from('expenses')
        .insert({
          'business_id': businessId,
          'amount_ghs': amount,
          'expense_date': dateIso,
          'category': mapping.manualCategory,
          'mapped_category': mapping.mappedCategory,
          'payment_source': paymentSource,
          'sustainability_tagged': mapping.sustainabilityTagged,
          // `source` has a DEFAULT 'manual' so omitting is fine.
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        })
        .select()
        .single();

    log.info('createExpense — done id=${row['id']} mapped=${mapping.mappedCategory} sustainable=${mapping.sustainabilityTagged} (${sw.elapsedMilliseconds}ms)');
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
  /// When [lineItems] is provided (as a list of `{description, quantity, price}`
  /// maps), [totalAmount] still takes precedence for the invoice total — the
  /// line items are for display / PDF rendering only. When [lineItems] is null
  /// a single-line fallback is generated from [description].
  ///
  /// [customerId] is optional — pass it when the customer has a real row in the
  /// `customers` table so the CRM links correctly.
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
    String? customerId,
    DateTime? dueDate,
    List<Map<String, dynamic>>? lineItems,
    bool isProforma = false,
    DateTime? validUntil,
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

    // Build line_items: use caller-provided items, or fall back to a single
    // line. Each item must have {description, quantity, price} for web's PDF
    // renderer (ascendsme-b/src/utils/invoicePdf.ts).
    final computedItems = lineItems ?? [
      {
        'description': (description ?? '').trim().isNotEmpty
            ? description!.trim()
            : 'Invoice for $customerName',
        'quantity': 1,
        'price': totalAmount,
      }
    ];

    final due = dueDate ?? DateTime.now().add(const Duration(days: 30));
    final dueIso = due.toIso8601String().substring(0, 10); // YYYY-MM-DD

    final insertPayload = <String, dynamic>{
      'business_id': businessId,
      'invoice_number': invoiceNumber,
      'client_name': customerName,
      'line_items': computedItems,
      'total_amount': totalAmount,
      'status': isProforma ? 'proforma' : 'pending',
      'due_date': dueIso,
    };
    if (isProforma && validUntil != null) {
      insertPayload['valid_until'] =
          validUntil.toIso8601String().substring(0, 10);
    }
    if (customerEmail != null && customerEmail.trim().isNotEmpty) {
      insertPayload['client_email'] = customerEmail.trim();
    }
    if (customerId != null && customerId.isNotEmpty) {
      insertPayload['customer_id'] = customerId;
    }

    final row = await client
        .from('invoices')
        .insert(insertPayload)
        .select()
        .single();

    log.info('createInvoice — done invoiceNumber=${row['invoice_number']} ${computedItems.length} items (${sw.elapsedMilliseconds}ms)');
    return Map<String, dynamic>.from(row);
  }

  // ── Proforma invoices ───────────────────────────────────────────────────────

  /// Update a proforma quote's details (customer, amount, description).
  /// Only sends non-null fields to the backend. When [description] is provided,
  /// line_items is rebuilt with the new description; otherwise existing line
  /// items are left untouched so multi-item proformas aren't collapsed.
  static Future<void> updateInvoice({
    required String invoiceId,
    String? customerName,
    String? description,
    num? totalAmount,
  }) async {
    log.info('updateInvoice — invoiceId=$invoiceId');
    final payload = <String, dynamic>{};
    if (customerName != null) payload['client_name'] = customerName.trim();
    if (description != null) {
      payload['line_items'] = [
        {
          'description': description.trim(),
          'quantity': 1,
          'price': totalAmount ?? 0,
        }
      ];
    }
    if (totalAmount != null) payload['total_amount'] = totalAmount;
    if (payload.isEmpty) return;
    await client.from('invoices').update(payload).eq('id', invoiceId);
    log.info('updateInvoice — done keys=${payload.keys.toList()}');
  }

  /// Convert a proforma quote to a real invoice by flipping status from
  /// 'proforma' to 'pending'. The invoice retains all existing fields;
  /// only the status changes.
  static Future<void> convertProformaToInvoice({
    required String invoiceId,
  }) async {
    log.info('convertProformaToInvoice — invoiceId=$invoiceId');
    await client
        .from('invoices')
        .update({'status': 'pending', 'valid_until': null})
        .eq('id', invoiceId);
    log.info('convertProformaToInvoice — done');
  }

  // ── Recurring Invoices ─────────────────────────────────────────────────────

  /// Fetch all recurring invoice templates for this business.
  static Future<List<Map<String, dynamic>>> fetchRecurringTemplates({
    required String businessId,
  }) async {
    log.debug('fetchRecurringTemplates — bizId=$businessId');
    final rows = await client
        .from('recurring_invoice_templates')
        .select()
        .eq('business_id', businessId)
        .order('next_invoice_date', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Create a recurring invoice template. Returns the persisted row.
  static Future<Map<String, dynamic>> createRecurringTemplate({
    required String businessId,
    required String customerName,
    required num totalAmount,
    required String frequency,
    required DateTime nextInvoiceDate,
    String? customerId,
    String? customerEmail,
    String? description,
    int? dayOfMonth,
    int? dayOfWeek,
    List<Map<String, dynamic>>? lineItems,
  }) async {
    log.info('createRecurringTemplate — bizId=$businessId customer="$customerName" freq=$frequency');
    final computedItems = lineItems ?? [
      {
        'description': (description ?? '').trim().isNotEmpty
            ? description!.trim()
            : 'Recurring invoice for $customerName',
        'quantity': 1,
        'price': totalAmount,
      }
    ];
    final row = await client
        .from('recurring_invoice_templates')
        .insert({
          'business_id': businessId,
          'customer_name': customerName.trim(),
          if (customerId != null && customerId.isNotEmpty)
            'customer_id': customerId,
          if (customerEmail != null && customerEmail.trim().isNotEmpty)
            'customer_email': customerEmail.trim(),
          'description': (description ?? '').trim(),
          'total_amount': totalAmount,
          'frequency': frequency,
          'day_of_month': dayOfMonth,
          'day_of_week': dayOfWeek,
          'next_invoice_date': nextInvoiceDate.toIso8601String().substring(0, 10),
          'line_items': computedItems,
          'is_active': true,
        })
        .select()
        .single();
    log.info('createRecurringTemplate — done id=${row['id']}');
    return Map<String, dynamic>.from(row);
  }

  /// Update an existing recurring template (e.g. change amount, pause).
  static Future<void> updateRecurringTemplate({
    required String templateId,
    String? customerName,
    String? description,
    num? totalAmount,
    String? frequency,
    DateTime? nextInvoiceDate,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
  }) async {
    log.info('updateRecurringTemplate — id=$templateId');
    final payload = <String, dynamic>{};
    if (customerName != null) payload['customer_name'] = customerName.trim();
    if (description != null) payload['description'] = description.trim();
    if (totalAmount != null) payload['total_amount'] = totalAmount;
    if (frequency != null) payload['frequency'] = frequency;
    if (nextInvoiceDate != null) {
      payload['next_invoice_date'] =
          nextInvoiceDate.toIso8601String().substring(0, 10);
    }
    if (dayOfMonth != null) payload['day_of_month'] = dayOfMonth;
    if (dayOfWeek != null) payload['day_of_week'] = dayOfWeek;
    if (isActive != null) payload['is_active'] = isActive;

    if (payload.isEmpty) return;
    await client
        .from('recurring_invoice_templates')
        .update(payload)
        .eq('id', templateId);
    log.info('updateRecurringTemplate — done');
  }

  /// Delete a recurring template.
  static Future<void> deleteRecurringTemplate({
    required String templateId,
  }) async {
    log.info('deleteRecurringTemplate — id=$templateId');
    await client
        .from('recurring_invoice_templates')
        .delete()
        .eq('id', templateId);
    log.info('deleteRecurringTemplate — done');
  }

  /// Trigger immediate generation of an invoice from a recurring template
  /// (RPC call). This also updates next_invoice_date on the template.
  static Future<Map<String, dynamic>?> generateRecurringInvoice({
    required String templateId,
  }) async {
    log.info('generateRecurringInvoice — templateId=$templateId');
    try {
      final result = await client.rpc(
        'generate_invoice_from_recurring_template',
        params: {'p_template_id': templateId},
      );
      if (result != null && result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e, st) {
      log.error('generateRecurringInvoice failed', error: e, stackTrace: st);
      return null;
    }
  }
}
