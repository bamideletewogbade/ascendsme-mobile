import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import '../services/app_logger.dart';
import '../services/supabase_service.dart';
import '../services/inventory_service.dart';
import '../services/subscription_service.dart';
import '../services/hrm_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/project_service.dart';
import '../services/payroll_service.dart';
import '../services/booking_service.dart' as svc;

enum AppTab { home, finance, tools, profile, askAscend }

enum NavVariant { classic, pill, fab }

class AppState extends ChangeNotifier {
  // ── Offline infrastructure ─────────────────────────────────────────────────
  final ConnectivityService connectivity;
  final SyncService syncService;

  AppState({
    required this.connectivity,
    required this.syncService,
  }) {
    _initOfflineListeners();
    unawaited(_loadPeriod());
    unawaited(_loadNotifyPrefs());
    unawaited(_loadDarkMode());
  }

  bool _connectivityInitialized = false;

  void _initOfflineListeners() {
    // When connectivity status initializes, restore the mutation queue
    // and auto-process if online.
    connectivity.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    if (!connectivity.initialized) return;
    if (!_connectivityInitialized) {
      _connectivityInitialized = true;
      // Restore queue on first init, then process if online
      syncService.restore().then((_) {
        if (connectivity.isOnline && syncService.hasPending) {
          unawaited(processPendingMutations());
        }
      });
    } else if (connectivity.isOnline && syncService.hasPending) {
      // Came back online with pending mutations — process them
      unawaited(processPendingMutations());
    }
  }

  /// Process all pending mutations from the sync queue. Called automatically
  /// when connectivity is restored or on first init.
  Future<void> processPendingMutations() async {
    final mutations = syncService.dequeueAll();
    if (mutations.isEmpty) return;
    syncService.setProcessing(true);

    var successCount = 0;
    for (final mutation in mutations) {
      try {
        await _executeMutation(mutation);
        successCount++;
      } catch (e, st) {
        log.error('processPendingMutations — failed ${mutation.action} ${mutation.domain}',
            error: e, stackTrace: st);
        final remaining = mutations.sublist(successCount);
        await syncService.reenqueue(remaining);
        syncService.setFailedCount(remaining.length);
        syncService.setProcessing(false);
        return;
      }
    }

    syncService.setFailedCount(0);
    syncService.setProcessing(false);
    // Refresh data after successful sync
    unawaited(refreshAll());
  }

  /// Execute a single pending mutation against Supabase.
  Future<void> _executeMutation(PendingMutation m) async {
    switch ((m.domain, m.action)) {
      case ('expenses', 'create'):
        await SupabaseService.createExpense(
          businessId: m.payload['business_id'] as String,
          amount: m.payload['amount_ghs'] as num,
          date: m.payload['expense_date'] != null
              ? DateTime.tryParse(m.payload['expense_date'] as String)
              : null,
          description: m.payload['description'] as String?,
          category: m.payload['category'] as String? ?? 'Other',
          paymentSource: m.payload['payment_source'] as String? ?? 'cash',
        );
      case ('receipts', 'create'):
        await SupabaseService.createSale(
          businessId: m.payload['business_id'] as String,
          amount: m.payload['total_amount'] as num,
          paymentMethod: m.payload['payment_method'] as String,
          paidDate: m.payload['paid_date'] != null
              ? DateTime.tryParse(m.payload['paid_date'] as String)
              : null,
          customerName: m.payload['client_name'] as String?,
          description: m.payload['description'] as String?,
        );
      case ('invoices', 'create'):
        await SupabaseService.createInvoice(
          businessId: m.payload['business_id'] as String,
          customerName: m.payload['client_name'] as String,
          totalAmount: m.payload['total_amount'] as num,
          description: m.payload['description'] as String?,
          customerEmail: m.payload['client_email'] as String?,
          customerId: m.payload['customer_id'] as String?,
          isProforma: m.payload['is_proforma'] as bool? ?? false,
        );
      case ('invoices', 'mark_paid'):
        await SupabaseService.markInvoicePaid(
          invoiceId: m.id!,
          businessId: m.payload['business_id'] as String,
          paymentMethod: m.payload['payment_method'] as String,
        );
      default:
        log.warning('_executeMutation — unknown: ${m.action} ${m.domain}');
    }
  }

  /// Get a CacheService instance for a given domain, scoped to the current business.
  CacheService _cache(String domain) => CacheService(domain, businessId: _business?.id);

  // ── Auth ───────────────────────────────────────────────────────────────────
  User? _user;
  bool _authLoading = false;
  String? _authError;

  // Fallback for when Supabase keys aren't configured
  bool _mockAuthed = false;

  User? get user => _user;
  bool get authed => _user != null || _mockAuthed;
  bool get authLoading => _authLoading;
  String? get authError => _authError;

  bool get supabaseConfigured =>
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty;

  /// Called once after SupabaseService.initialize() to restore a persisted session.
  void initFromSession() {
    log.info('initFromSession — supabaseConfigured=$supabaseConfigured');
    if (!supabaseConfigured) {
      log.warning('initFromSession — Supabase not configured, running in mock mode');
      return;
    }
    _user = SupabaseService.currentUser;
    log.info('initFromSession — userId=${_user?.id ?? 'none'}');
    if (_user != null) {
      loadBusiness();
    }
  }

  /// Called by the Supabase auth stream listener in main.dart.
  void handleAuthChange(AuthState state) {
    final previousUserId = _user?.id;
    log.info('handleAuthChange — event=${state.event.name} previousUserId=${previousUserId ?? 'none'}');
    _user = state.session?.user;
    _authLoading = false;
    _authError = null;
    notifyListeners();

    final currentUserId = _user?.id;
    log.info('handleAuthChange resolved — now userId=${currentUserId ?? 'signed-out'}');

    if (currentUserId == null && previousUserId != null) {
      log.info('handleAuthChange — user signed out, clearing business profile');
      _business = null;
      notifyListeners();
    } else if (currentUserId != null && currentUserId != previousUserId) {
      log.info('handleAuthChange — new login detected, triggering loadBusiness');
      loadBusiness();
    }
  }

  // ── Business profile (loaded from Supabase via fetchProfile) ───────────────
  Business? _business;

  /// Real business profile when loaded, falls back to the mock for unsigned-in
  /// or pre-load states so UI never has to null-check.
  Business get business => _business ?? kBusiness;

  /// True if the displayed business is the real Supabase row, false if mock.
  bool get hasRealBusiness => _business != null;

  /// Cache key for SharedPreferences, scoped to the current user so switching
  /// accounts never shows stale data from the previous user.
  String get _cacheKey => 'ascend_business_profile_${_user?.id ?? 'anon'}';

  /// Load the signed-in user's business profile from Supabase. Idempotent and
  /// safe to call multiple times.
  ///
  /// Performance strategy — two-phase load:
  ///   1. **Cache-first**: if a profile was previously saved to SharedPreferences,
  ///      restore it immediately so the UI never shows a skeleton. This is
  ///      effectively instant (local read, no network).
  ///   2. **Fresh fetch**: try `fetchProfile()` directly (1 query). If that
  ///      returns null (new user whose businesses row hasn't been created yet),
  ///      run `ensureProfileBootstrapped()` and re-fetch. The bootstrap path
  ///      is rare — only for first-sign-in Google OAuth or deferred signups.
  ///      On success, the cache is updated so the next cold start skips the
  ///      skeleton entirely.
  ///
  /// Triggers financials + invoices + receipts + expenses reload in parallel
  /// once the business id is known.
  Future<void> loadBusiness() async {
    if (!supabaseConfigured || _user == null) return;
    log.debug('loadBusiness — userId=${_user!.id}');
    final sw = Stopwatch()..start();

    // Phase 1 — instant restore from local cache so the skeleton never shows.
    await _restoreFromCache();

    // Phase 2 — fetch fresh data from Supabase.
    try {
      // Fast path: most returning users already have a businesses row, so
      // fetch it directly. This saves 2 SELECT queries from the bootstrapper.
      var row = await SupabaseService.fetchProfile();

      if (row == null) {
        // No profile yet — bootstrap (creates users + businesses rows) then
        // re-fetch. This runs once per new account.
        log.info('loadBusiness — no profile row, bootstrapping');
        await SupabaseService.ensureProfileBootstrapped();
        row = await SupabaseService.fetchProfile();
      }

      if (row == null) {
        log.warning('loadBusiness — fetchProfile returned null after bootstrap');
        _business = null;
        _financials = Financials.empty;
        _invoices = [];
      } else {
        _business = Business.fromRow(row);
        // Persist to cache for instant boot on next cold start.
        _cacheProfile(row);
        // Subscribe to real-time updates for all data domains
        _subscribeAllChannels();
        log.info('loadBusiness — loaded: id=${_business!.id} name="${_business!.name}" (${sw.elapsedMilliseconds}ms)');
      }
      notifyListeners();
      if (_business?.id != null) {
        unawaited(loadFinancials());
        unawaited(loadInvoices());
        unawaited(loadReceipts());
        unawaited(loadExpenses());
        unawaited(loadInventory());
        unawaited(loadVerificationStatus());
      }
    } catch (e, st) {
      log.error('loadBusiness failed', error: e, stackTrace: st);
      // If cache restored a profile in phase 1, keep it rather than
      // reverting to the skeleton — the user sees stale data briefly
      // instead of a frozen-looking loading screen.
      if (_business == null) {
        _financials = Financials.empty;
        _invoices = [];
        _receipts = [];
        _expenses = [];
        notifyListeners();
      }
    }
  }

  /// If a cached profile exists, hydrate `_business` from it and notify.
  Future<void> _restoreFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>?;
      if (decoded == null || decoded.isEmpty) return;
      _business = Business.fromRow(decoded);
      log.debug('loadBusiness — restored from cache: ${_business!.name}');
      notifyListeners();
    } catch (e, st) {
      log.warning('loadBusiness — cache restore failed', error: e, stackTrace: st);
      // Non-fatal — we'll fetch from network next.
    }
  }

  /// Persist the raw [row] to SharedPreferences for next cold start.
  void _cacheProfile(Map<String, dynamic> row) {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_cacheKey, jsonEncode(row));
      });
    } catch (_) {
      // Best-effort; not worth crashing over.
    }
  }

  /// If cached financials exist, hydrate `_financials` from them and notify.
  Future<void> _restoreFinancialsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_financialsCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>?;
      if (decoded == null || decoded.isEmpty) return;
      _financials = Financials.fromMap(decoded);
      log.debug('loadFinancials — restored from cache');
      notifyListeners();
    } catch (e, st) {
      log.warning('loadFinancials — cache restore failed', error: e, stackTrace: st);
      // Non-fatal — we'll fetch from network next.
    }
  }

  /// Persist current `_financials` to SharedPreferences.
  void _cacheFinancials() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_financialsCacheKey, jsonEncode(_financials.toMap()));
      });
    } catch (_) {
      // Best-effort; not worth crashing over.
    }
  }

  /// Compute aggregated financials for a custom period from already-loaded
  /// receipt and expense lists. Instant — no network calls. Use [months]=0
  /// for YTD (year-to-date from January 1).
  PeriodSummary computePeriodSummary(int months) {
    final now = DateTime.now();
    final periodEnd = DateTime(now.year, now.month + 1, 1);
    final DateTime periodStart;

    if (months <= 0) {
      // YTD — from January 1 of this year
      periodStart = DateTime(now.year, 1, 1);
    } else {
      periodStart = DateTime(now.year, now.month - months + 1, 1);
    }

    double sumInRange(
      Iterable<Map<String, dynamic>> items,
      String dateField,
      String amountField,
      DateTime start,
      DateTime end,
    ) {
      return items
          .where((r) {
            final dateStr = r[dateField] as String?;
            if (dateStr == null) return false;
            final date = DateTime.tryParse(dateStr);
            if (date == null) return false;
            return !date.isBefore(start) && date.isBefore(end);
          })
          .fold(0.0,
              (sum, r) => sum + ((r[amountField] as num?)?.toDouble() ?? 0));
    }

    final revenue = sumInRange(
        _receipts, 'paid_date', 'total_amount', periodStart, periodEnd);
    final expenses = sumInRange(
        _expenses, 'expense_date', 'amount_ghs', periodStart, periodEnd);

    return PeriodSummary(
      startDate: periodStart,
      endDate: periodEnd,
      revenue: revenue,
      expenses: expenses,
    );
  }

  // ── Financials (month-to-date aggregation) ─────────────────────────────────
  Financials _financials = Financials.empty;
  Financials get financials => _financials;
  bool _financialsLoading = false;
  bool get financialsLoading => _financialsLoading;

  /// Cache key for financials, scoped to business + month so we never show
  /// stale data from a previous period or a different business.
  String get _financialsCacheKey {
    final now = DateTime.now();
    return 'ascend_financials_${_business?.id ?? 'anon'}_${now.year}-${now.month}';
  }

  /// Aggregate revenue / expenses / outstanding for the signed-in business.
  /// Two-phase load:
  ///   1. Restore from local cache (instant) so home screen cards populate
  ///      immediately with last-fetched values.
  ///   2. Run three Supabase queries in parallel (this-month receipts,
  ///      this-month expenses, open invoices), then update cache.
  ///   On network failure the cached data persists — no regression to zeros.
  Future<void> loadFinancials() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _financials = Financials.empty;
      notifyListeners();
      return;
    }
    log.debug('loadFinancials — bizId=$bizId');

    // Phase 1 — instant restore from local cache.
    await _restoreFinancialsFromCache();
    final restoredFromCache = _financials != Financials.empty;

    // Phase 2 — network fetch. Skip the loading spinner if we already have
    // data to show (cache hit); the background refresh will replace silently.
    if (!restoredFromCache) {
      _financialsLoading = true;
      notifyListeners();
    }

    final sw = Stopwatch()..start();
    try {
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final nextMonthStart = DateTime(now.year, now.month + 1, 1);

      final results = await Future.wait([
        SupabaseService.sumReceipts(
            businessId: bizId, start: thisMonthStart, end: nextMonthStart),
        SupabaseService.sumExpenses(
            businessId: bizId, start: thisMonthStart, end: nextMonthStart),
        SupabaseService.fetchOpenInvoices(businessId: bizId),
      ]);

      final revenueNow = results[0] as double;
      final expensesNow = results[1] as double;
      final openInvoices = results[2] as List<Map<String, dynamic>>;

      // Outstanding sum + counts (overdue = past due_date OR status='overdue')
      var outstandingTotal = 0.0;
      var overdueCount = 0;
      var pipelineTotal = 0.0;
      final today = DateTime(now.year, now.month, now.day);
      for (final inv in openInvoices) {
        final status = (inv['status'] as String?)?.toLowerCase();
        // Proforma invoices count toward pipeline, not outstanding
        if (status == 'proforma') {
          pipelineTotal += (inv['total_amount'] as num?)?.toDouble() ?? 0;
          continue;
        }
        outstandingTotal += (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final dueRaw = inv['due_date'] as String?;
        DateTime? due;
        if (dueRaw != null) {
          due = DateTime.tryParse(dueRaw);
        }
        if (status == 'overdue' ||
            (due != null && due.isBefore(today))) {
          overdueCount += 1;
        }
      }

      // Simple 30-day Outlook: Outstanding + 80% of current month's revenue (as proxy for next month)
      // minus 110% of current month's expenses.
      final projected = outstandingTotal + (revenueNow * 0.8) - (expensesNow * 1.1);
      final isAtRisk = projected < 0 && (revenueNow + outstandingTotal) < expensesNow;

      _financials = Financials(
        revenueThisMonth: revenueNow.round(),
        expensesThisMonth: expensesNow.round(),
        outstanding: outstandingTotal.round(),
        outstandingCount: openInvoices.length,
        outstandingOverdueCount: overdueCount,
        pipeline: pipelineTotal.round(),
        projectedCash30Days: projected,
        isAtRisk: isAtRisk,
      );
      log.info('loadFinancials — revenue=${revenueNow.round()} expenses=${expensesNow.round()} outstanding=${outstandingTotal.round()} openInvoices=${openInvoices.length} overdue=$overdueCount (${sw.elapsedMilliseconds}ms)');
      // Persist to cache for instant load on next cold start.
      _cacheFinancials();
    } catch (e, st) {
      log.error('loadFinancials failed', error: e, stackTrace: st);
      // If cache restored data in phase 1, keep it rather than flashing zeros.
      if (_financials.isEmpty) {
        _financials = Financials.empty;
      }
    } finally {
      _financialsLoading = false;
      notifyListeners();
    }
  }

  // ── Invoices list (real, from Supabase) ────────────────────────────────────
  List<Invoice> _invoices = [];
  bool _invoicesLoading = false;

  /// Real invoices for the signed-in business, newest first. When no business
  /// is loaded yet (pre-login / pre-bootstrap) this returns an empty list and
  /// the UI should fall back to its mock or show an empty state.
  List<Invoice> get invoices => _invoices;
  bool get hasRealInvoices => _business != null;
  bool get invoicesLoading => _invoicesLoading;

  /// Most recent up-to-[count] invoices for compact UI surfaces like the
  /// Cards-layout invoicing card. Falls back to the kInvoices mock when no
  /// real business is loaded (pre-login / mock dev mode).
  List<Invoice> recentInvoices({int count = 3}) {
    if (!hasRealInvoices) return kInvoices.take(count).toList();
    return _invoices.take(count).toList();
  }

  Future<void> loadInvoices() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _invoices = [];
      notifyListeners();
      return;
    }
    log.debug('loadInvoices — bizId=$bizId');
    _invoicesLoading = true;
    notifyListeners();

    // Phase 1 — restore from cache (instant, no network)
    final cached = await _cache('invoices').getOrEmpty();
    if (cached.isNotEmpty) {
      _invoices = cached.map(Invoice.fromRow).toList();
      log.debug('loadInvoices — restored ${_invoices.length} from cache');
      notifyListeners();
      _invoicesLoading = false;
    }

    // Phase 2 — network fetch (silent refresh if cache was available)
    final sw = Stopwatch()..start();
    try {
      final rows = await SupabaseService.fetchInvoices(businessId: bizId);
      _invoices = rows.map(Invoice.fromRow).toList();
      await _cache('invoices').put(rows);
      log.info('loadInvoices — loaded ${_invoices.length} invoices (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadInvoices failed', error: e, stackTrace: st);
      // Keep cache data if network fails and cache was empty
      if (_invoices.isEmpty) {
        _invoices = cached.map(Invoice.fromRow).toList();
      }
    } finally {
      _invoicesLoading = false;
      notifyListeners();
    }
  }

  // ── Receipts list (real, from Supabase) ────────────────────────────────────
  // Used by the home activity feed and the receipts screen. Each receipt
  // represents money received — either an invoice payment (invoice_id present)
  // or a direct sale logged via LogSaleSheet (invoice_id null).
  List<Map<String, dynamic>> _receipts = [];
  List<Map<String, dynamic>> get receipts => _receipts;

  /// Typed receipt list derived from the raw [_receipts] maps. Used by the
  /// receipts screen for clean display without duplicating data.
  List<Receipt> get receiptList =>
      _receipts.map(Receipt.fromRow).toList();

  Future<void> loadReceipts() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _receipts = [];
      notifyListeners();
      return;
    }
    log.debug('loadReceipts — bizId=$bizId');

    // Phase 1 — restore from cache
    final cached = await _cache('receipts').getOrEmpty();
    if (cached.isNotEmpty) {
      _receipts = cached;
      log.debug('loadReceipts — restored ${_receipts.length} from cache');
      notifyListeners();
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      _receipts = await SupabaseService.fetchReceipts(businessId: bizId);
      await _cache('receipts').put(_receipts);
      log.info('loadReceipts — loaded ${_receipts.length} receipts (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadReceipts failed', error: e, stackTrace: st);
      if (_receipts.isEmpty) _receipts = cached;
    } finally {
      notifyListeners();
    }
  }

  // ── Expenses list (real, from Supabase) ────────────────────────────────────
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> get expenses => _expenses;

  /// Typed expense list derived from the raw [_expenses] maps.
  List<Expense> get expenseList =>
      _expenses.map(Expense.fromRow).toList();

  Future<void> loadExpenses() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _expenses = [];
      notifyListeners();
      return;
    }
    log.debug('loadExpenses — bizId=$bizId');

    // Phase 1 — restore from cache
    final cached = await _cache('expenses').getOrEmpty();
    if (cached.isNotEmpty) {
      _expenses = cached;
      log.debug('loadExpenses — restored ${_expenses.length} from cache');
      notifyListeners();
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      _expenses = await SupabaseService.fetchExpenses(businessId: bizId);
      await _cache('expenses').put(_expenses);
      log.info('loadExpenses — loaded ${_expenses.length} expenses (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadExpenses failed', error: e, stackTrace: st);
      if (_expenses.isEmpty) _expenses = cached;
    } finally {
      notifyListeners();
    }
  }

  // ── Inventory ──────────────────────────────────────────────────────────────
  List<InventoryItem> _inventory = [];
  bool _inventoryLoading = false;
  RealtimeChannel? _inventoryChannel;

  List<InventoryItem> get inventory => _inventory;
  bool get inventoryLoading => _inventoryLoading;

  /// Products with stock at or below their low_stock_threshold.
  List<InventoryItem> get lowStockItems =>
      _inventory.where((p) => p.lowStock).toList();

  /// Subscribe to real-time changes on `user_products` so inventory levels
  /// update automatically. Call once after loadBusiness succeeds.
  void _subscribeInventoryChannel() {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) return;
    _inventoryChannel?.unsubscribe();
    _inventoryChannel = SupabaseService.client.channel('inventory-changes');
    _inventoryChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'user_products',
          schema: 'public',
          callback: (payload) {
            log.debug('_subscribeInventoryChannel — event=${payload.eventType}');
            unawaited(loadInventory());
          },
        )
        .subscribe();
    log.debug('_subscribeInventoryChannel — subscribed for bizId=$bizId');
  }

  /// Tear down the real-time channel on dispose.
  void _unsubscribeInventoryChannel() {
    _inventoryChannel?.unsubscribe();
    _inventoryChannel = null;
  }

  // ── Realtime subscriptions (invoices, receipts, expenses) ───────────────────
  RealtimeChannel? _invoicesChannel;
  RealtimeChannel? _receiptsChannel;
  RealtimeChannel? _expensesChannel;

  void _subscribeAllChannels() {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) return;

    _subscribeInventoryChannel();
    _subscribeVerificationChannel();

    // Invoices channel
    _invoicesChannel?.unsubscribe();
    _invoicesChannel = SupabaseService.client.channel('invoices-changes');
    _invoicesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'invoices',
          schema: 'public',
          callback: (payload) {
            log.debug('realtime invoices — event=${payload.eventType}');
            unawaited(loadInvoices());
          },
        )
        .subscribe();

    // Receipts channel
    _receiptsChannel?.unsubscribe();
    _receiptsChannel = SupabaseService.client.channel('receipts-changes');
    _receiptsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'receipts',
          schema: 'public',
          callback: (payload) {
            log.debug('realtime receipts — event=${payload.eventType}');
            unawaited(loadReceipts());
          },
        )
        .subscribe();

    // Expenses channel
    _expensesChannel?.unsubscribe();
    _expensesChannel = SupabaseService.client.channel('expenses-changes');
    _expensesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'expenses',
          schema: 'public',
          callback: (payload) {
            log.debug('realtime expenses — event=${payload.eventType}');
            unawaited(loadExpenses());
          },
        )
        .subscribe();

    log.debug('_subscribeAllChannels — subscribed for bizId=$bizId');
  }

  void _unsubscribeAllChannels() {
    _unsubscribeInventoryChannel();
    _unsubscribeVerificationChannel();
    _invoicesChannel?.unsubscribe();
    _receiptsChannel?.unsubscribe();
    _expensesChannel?.unsubscribe();
    _invoicesChannel = null;
    _receiptsChannel = null;
    _expensesChannel = null;
  }

  Future<void> loadInventory() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _inventory = [];
      notifyListeners();
      return;
    }
    log.debug('loadInventory — bizId=$bizId');
    _inventoryLoading = true;
    notifyListeners();

    // Phase 1 — restore from cache
    final cached = await _cache('inventory').getOrEmpty();
    if (cached.isNotEmpty) {
      _inventory = cached.map(InventoryItem.fromRow).toList();
      log.debug('loadInventory — restored ${_inventory.length} from cache');
      notifyListeners();
      _inventoryLoading = false;
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      final rows = await InventoryService.fetchProducts(businessId: bizId);
      _inventory = rows.map(InventoryItem.fromRow).toList();
      await _cache('inventory').put(rows);
      log.info('loadInventory — loaded ${_inventory.length} items (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadInventory failed', error: e, stackTrace: st);
      if (_inventory.isEmpty) {
        _inventory = cached.map(InventoryItem.fromRow).toList();
      }
    } finally {
      _inventoryLoading = false;
      notifyListeners();
    }
  }

  // ── Subscription ───────────────────────────────────────────────────────────
  SubscriptionInfo? _subscription;
  bool _subscriptionLoading = false;
  List<SubscriptionPlan> _availablePlans = [];
  bool _subscriptionExpired = false;
  String? _subscriptionExpiredTier;

  SubscriptionInfo? get subscription => _subscription;
  bool get subscriptionLoading => _subscriptionLoading;
  List<SubscriptionPlan> get availablePlans => _availablePlans;
  /// True when the business had a paid subscription that has expired.
  bool get subscriptionExpired => _subscriptionExpired;
  /// The tier code (e.g. 'lite', 'plus', 'elite') of the expired subscription.
  String? get subscriptionExpiredTier => _subscriptionExpiredTier;

  Future<void> loadSubscription() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _subscription = null;
      _subscriptionExpired = false;
      _subscriptionExpiredTier = null;
      notifyListeners();
      return;
    }
    log.debug('loadSubscription — bizId=$bizId');
    _subscriptionLoading = true;
    notifyListeners();
    final sw = Stopwatch()..start();
    try {
      final result = await SubscriptionService.getCurrentSubscription(businessId: bizId);
      _subscription = result.subscription;
      _subscriptionExpired = result.expired;
      _subscriptionExpiredTier = result.expiredTierCode;
      log.info('loadSubscription — ${result.subscription != null ? 'tier=${result.subscription!.tierCode}' : result.expired ? 'expired=${result.expiredTierCode}' : 'free'} (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadSubscription failed', error: e, stackTrace: st);
      _subscription = null;
      _subscriptionExpired = false;
      _subscriptionExpiredTier = null;
    } finally {
      _subscriptionLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAvailablePlans() async {
    if (!supabaseConfigured) {
      _availablePlans = [];
      notifyListeners();
      return;
    }
    log.debug('loadAvailablePlans');
    try {
      _availablePlans = await SubscriptionService.fetchTiers();
      log.info('loadAvailablePlans — ${_availablePlans.length} plans');
    } catch (e, st) {
      log.error('loadAvailablePlans failed', error: e, stackTrace: st);
      _availablePlans = [];
    } finally {
      notifyListeners();
    }
  }

  // ── Staff / HRM ────────────────────────────────────────────────────────────
  List<StaffMember> _staff = [];
  bool _staffLoading = false;

  List<StaffMember> get staff => _staff;
  bool get staffLoading => _staffLoading;

  Future<void> loadStaff() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _staff = [];
      notifyListeners();
      return;
    }
    log.debug('loadStaff — bizId=$bizId');
    _staffLoading = true;
    notifyListeners();

    // Phase 1 — restore from cache
    final cached = await _cache('staff').getOrEmpty();
    if (cached.isNotEmpty) {
      _staff = cached.map(StaffMember.fromRow).toList();
      log.debug('loadStaff — restored ${_staff.length} from cache');
      notifyListeners();
      _staffLoading = false;
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      final rows = await HrmService.fetchStaff(businessId: bizId, activeOnly: true);
      _staff = rows.map(StaffMember.fromRow).toList();
      await _cache('staff').put(rows);
      log.info('loadStaff — loaded ${_staff.length} staff (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadStaff failed', error: e, stackTrace: st);
      if (_staff.isEmpty) {
        _staff = cached.map(StaffMember.fromRow).toList();
      }
    } finally {
      _staffLoading = false;
      notifyListeners();
    }
  }

  // ── Customers ──────────────────────────────────────────────────────────────
  List<Customer> _customers = [];
  bool _customersLoading = false;

  List<Customer> get customers => _customers;
  bool get customersLoading => _customersLoading;

  /// Fetch customers for this business from the shared `customers` table.
  /// When [query] is non-empty, filters by name (ILIKE); otherwise returns
  /// the most recent 30 rows.
  Future<void> loadCustomers({String? query}) async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _customers = [];
      notifyListeners();
      return;
    }
    log.debug('loadCustomers — bizId=$bizId query="$query"');
    _customersLoading = true;
    notifyListeners();

    // Phase 1 — restore from cache (only when no query, cache is full list)
    if (query == null || query.trim().isEmpty) {
      final cached = await _cache('customers').getOrEmpty();
      if (cached.isNotEmpty) {
        _customers = cached.map(Customer.fromRow).toList();
        log.debug('loadCustomers — restored ${_customers.length} from cache');
        notifyListeners();
        _customersLoading = false;
      }
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      final rows = await SupabaseService.fetchCustomers(
        businessId: bizId,
        query: query,
      );
      _customers = rows.map(Customer.fromRow).toList();
      // Only cache full (non-query) loads
      if (query == null || query.trim().isEmpty) {
        await _cache('customers').put(rows);
      }
      log.info('loadCustomers — loaded ${_customers.length} customers (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadCustomers failed', error: e, stackTrace: st);
      // _customers is already populated from Phase 1 cache if available;
      // if both cache and network failed, leave empty.
    } finally {
      _customersLoading = false;
      notifyListeners();
    }
  }

  // ── Recurring Invoices ────────────────────────────────────────────────────
  List<RecurringTemplate> _recurringTemplates = [];
  bool _recurringTemplatesLoading = false;

  List<RecurringTemplate> get recurringTemplates => _recurringTemplates;
  bool get recurringTemplatesLoading => _recurringTemplatesLoading;

  Future<void> loadRecurringTemplates() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _recurringTemplates = [];
      notifyListeners();
      return;
    }
    log.debug('loadRecurringTemplates — bizId=$bizId');
    _recurringTemplatesLoading = true;
    notifyListeners();

    // Phase 1 — restore from cache
    final cached = await _cache('recurring').getOrEmpty();
    if (cached.isNotEmpty) {
      _recurringTemplates = cached.map(RecurringTemplate.fromRow).toList();
      log.debug('loadRecurringTemplates — restored ${_recurringTemplates.length} from cache');
      notifyListeners();
      _recurringTemplatesLoading = false;
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      final rows = await SupabaseService.fetchRecurringTemplates(businessId: bizId);
      _recurringTemplates = rows.map(RecurringTemplate.fromRow).toList();
      await _cache('recurring').put(rows);
      log.info('loadRecurringTemplates — loaded ${_recurringTemplates.length} (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadRecurringTemplates failed', error: e, stackTrace: st);
      if (_recurringTemplates.isEmpty) {
        _recurringTemplates = cached.map(RecurringTemplate.fromRow).toList();
      }
    } finally {
      _recurringTemplatesLoading = false;
      notifyListeners();
    }
  }

  /// Convenience: refresh everything that depends on Supabase data. Use after
  /// mutations (createInvoice, createExpense, createSale, etc.) or from a
  /// pull-to-refresh.
  /// Whether the device is offline — convenience for UI to show banners.
  bool get isOffline => connectivity.initialized && !connectivity.isOnline;

  Future<void> refreshAll() async {
    if (!supabaseConfigured || _user == null) return;
    if (isOffline) {
      log.info('refreshAll — offline, loading from cache only');
      // Load from cache instead of network
      final bizId = _business?.id;
      if (bizId != null) {
        await _loadInvoicesFromCache();
        await _loadReceiptsFromCache();
        await _loadExpensesFromCache();
        unawaited(_loadInventoryFromCache());
        unawaited(_loadStaffFromCache());
        unawaited(_loadCustomersFromCache());
        unawaited(_loadRecurringFromCache());
        unawaited(_loadMilestonesFromCache());
        unawaited(_loadPayrollFromCache());
        unawaited(_loadShopFromCache());
        unawaited(_loadBookingsFromCache());
        unawaited(_loadVerificationFromCache());
      }
      return;
    }
    log.info('refreshAll — userId=${_user!.id}');
    await loadBusiness();
    // loadBusiness() already fires financials/invoices/receipts/expenses
    // as unawaited — only fire the data domains it doesn't cover.
    if (_business?.id != null) {
      unawaited(loadInventory());
      unawaited(loadSubscription());
      unawaited(loadStaff());
      unawaited(loadCustomers());
      unawaited(loadRecurringTemplates());
      unawaited(loadMilestones());
      unawaited(loadPayrollRuns());
      unawaited(loadShop());
      unawaited(loadBookings());
      unawaited(loadVerificationStatus());
    }
  }

  // ── Offline cache-only loaders (used when no network) ──────────────────────

  Future<void> _loadInvoicesFromCache() async {
    final cached = await _cache('invoices').getOrEmpty();
    _invoices = cached.map(Invoice.fromRow).toList();
    _invoicesLoading = false;
    notifyListeners();
  }

  Future<void> _loadReceiptsFromCache() async {
    _receipts = await _cache('receipts').getOrEmpty();
    notifyListeners();
  }

  Future<void> _loadExpensesFromCache() async {
    _expenses = await _cache('expenses').getOrEmpty();
    notifyListeners();
  }

  Future<void> _loadInventoryFromCache() async {
    final cached = await _cache('inventory').getOrEmpty();
    _inventory = cached.map(InventoryItem.fromRow).toList();
    _inventoryLoading = false;
    notifyListeners();
  }

  Future<void> _loadStaffFromCache() async {
    final cached = await _cache('staff').getOrEmpty();
    _staff = cached.map(StaffMember.fromRow).toList();
    _staffLoading = false;
    notifyListeners();
  }

  Future<void> _loadCustomersFromCache() async {
    final cached = await _cache('customers').getOrEmpty();
    _customers = cached.map(Customer.fromRow).toList();
    _customersLoading = false;
    notifyListeners();
  }

  Future<void> _loadRecurringFromCache() async {
    final cached = await _cache('recurring').getOrEmpty();
    _recurringTemplates = cached.map(RecurringTemplate.fromRow).toList();
    _recurringTemplatesLoading = false;
    notifyListeners();
  }

  // ── Project Management ──────────────────────────────────────────────────
  List<ProjectMilestone> _milestones = [];
  bool _milestonesLoading = false;

  List<ProjectMilestone> get milestones => _milestones;
  bool get milestonesLoading => _milestonesLoading;

  Future<void> loadMilestones() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _milestones = [];
      notifyListeners();
      return;
    }
    log.debug('loadMilestones — bizId=$bizId');
    _milestonesLoading = true;
    notifyListeners();

    // Phase 1 — restore from cache
    final cached = await _cache('projects').getOrEmpty();
    if (cached.isNotEmpty) {
      _milestones = cached.map(ProjectMilestone.fromRow).toList();
      log.debug('loadMilestones — restored ${_milestones.length} from cache');
      notifyListeners();
      _milestonesLoading = false;
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      final rows = await ProjectService.fetchMilestones(businessId: bizId);
      _milestones = rows.map(ProjectMilestone.fromRow).toList();
      await _cache('projects').put(rows);
      log.info('loadMilestones — loaded ${_milestones.length} projects (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadMilestones failed', error: e, stackTrace: st);
      if (_milestones.isEmpty) {
        _milestones = cached.map(ProjectMilestone.fromRow).toList();
      }
    } finally {
      _milestonesLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMilestonesFromCache() async {
    final cached = await _cache('projects').getOrEmpty();
    _milestones = cached.map(ProjectMilestone.fromRow).toList();
    _milestonesLoading = false;
    notifyListeners();
  }

  // ── Payroll ─────────────────────────────────────────────────────────────
  List<PayrollRun> _payrollRuns = [];
  bool _payrollLoading = false;
  Map<String, dynamic>? _delegationMetrics;

  List<PayrollRun> get payrollRuns => _payrollRuns;
  bool get payrollLoading => _payrollLoading;
  Map<String, dynamic>? get delegationMetrics => _delegationMetrics;

  double get ytdPayrollTotal => _payrollRuns
      .where((r) => r.status == 'logged_to_finance')
      .fold(0.0, (sum, r) => sum + r.totalPayrollGhs);

  Future<void> loadPayrollRuns() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _payrollRuns = [];
      notifyListeners();
      return;
    }
    log.debug('loadPayrollRuns — bizId=$bizId');
    _payrollLoading = true;
    notifyListeners();

    // Parallel load payroll history and delegation metrics
    try {
      final results = await Future.wait([
        PayrollService.fetchPayrollRuns(businessId: bizId),
        HrmService.calculateDelegationIndex(bizId),
      ]);

      _payrollRuns = (results[0] as List).map((r) => PayrollRun.fromRow(r as Map<String, dynamic>)).toList();
      _delegationMetrics = results[1] as Map<String, dynamic>;
      
      await _cache('payroll').put(results[0] as List<Map<String, dynamic>>);
      log.info('loadPayrollRuns — loaded ${_payrollRuns.length} runs, index=${_delegationMetrics?['index']}');
    } catch (e, st) {
      log.error('loadPayrollRuns failed', error: e, stackTrace: st);
    } finally {
      _payrollLoading = false;
      notifyListeners();
    }
  }

  Future<void> initiateCurrentMonthPayroll() async {
    final bizId = _business?.id;
    if (bizId == null) return;
    
    try {
      await PayrollService.ensurePayrollRunForCurrentMonth(bizId);
      await loadPayrollRuns();
    } catch (e, st) {
      log.error('initiateCurrentMonthPayroll failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> processPayroll({
    required String payrollRunId,
    required String paymentSource,
  }) async {
    final bizId = _business?.id;
    if (bizId == null) return;

    try {
      await PayrollService.processPayrollToFinance(
        businessId: bizId,
        payrollRunId: payrollRunId,
        paymentSource: paymentSource,
      );
      // Refresh both domains
      unawaited(loadPayrollRuns());
      unawaited(loadFinancials());
    } catch (e, st) {
      log.error('processPayroll failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _loadPayrollFromCache() async {
    final cached = await _cache('payroll').getOrEmpty();
    _payrollRuns = cached.map(PayrollRun.fromRow).toList();
    _payrollLoading = false;
    notifyListeners();
  }

  // ── Bookings ──────────────────────────────────────────────────────────────
  List<Booking> _bookings = [];
  List<BookingService> _bookingServices = [];
  bool _bookingsLoading = false;

  List<Booking> get bookings => _bookings;
  List<BookingService> get bookingServices => _bookingServices;
  bool get bookingsLoading => _bookingsLoading;

  Future<void> loadBookings() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _bookings = [];
      _bookingServices = [];
      notifyListeners();
      return;
    }
    log.debug('loadBookings — bizId=$bizId');
    _bookingsLoading = true;
    notifyListeners();

    // Phase 1 — restore from cache
    final cachedBookings = await _cache('bookings').getOrEmpty();
    final cachedServices = await _cache('booking_services').getOrEmpty();
    if (cachedBookings.isNotEmpty) {
      _bookings = cachedBookings.map(Booking.fromRow).toList();
      log.debug('loadBookings — restored ${_bookings.length} bookings from cache');
      notifyListeners();
      _bookingsLoading = false;
    }
    if (cachedServices.isNotEmpty) {
      _bookingServices = cachedServices.map(BookingService.fromRow).toList();
    }

    // Phase 2 — network fetch
    final sw = Stopwatch()..start();
    try {
      final results = await Future.wait([
        // Use BookingService's fetch method which has the correct join query
        svc.BookingService.fetchBookings(businessId: bizId),
        (() async {
          final rows = await SupabaseService.client
              .from('booking_services')
              .select('*')
              .eq('business_id', bizId)
              .order('service_name', ascending: true);
          return List<Map<String, dynamic>>.from(rows as List);
        })(),
      ]);
      _bookings = (results[0]).map(Booking.fromRow).toList();
      _bookingServices = (results[1]).map(BookingService.fromRow).toList();
      await _cache('bookings').put(results[0]);
      await _cache('booking_services').put(results[1]);
      log.info('loadBookings — loaded ${_bookings.length} bookings, ${_bookingServices.length} services (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadBookings failed', error: e, stackTrace: st);
      if (_bookings.isEmpty) {
        _bookings = cachedBookings.map(Booking.fromRow).toList();
        _bookingServices = cachedServices.map(BookingService.fromRow).toList();
      }
    } finally {
      _bookingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadBookingsFromCache() async {
    final cachedBookings = await _cache('bookings').getOrEmpty();
    final cachedServices = await _cache('booking_services').getOrEmpty();
    _bookings = cachedBookings.map(Booking.fromRow).toList();
    _bookingServices = cachedServices.map(BookingService.fromRow).toList();
    _bookingsLoading = false;
    notifyListeners();
  }

  // ── Shop ────────────────────────────────────────────────────────────────
  Shop? _shop;
  bool _shopLoading = false;

  Shop? get shop => _shop;
  bool get shopLoading => _shopLoading;

  Future<void> loadShop() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) return;
    _shopLoading = true;
    notifyListeners();

    try {
      final res = await SupabaseService.fetchShop(businessId: bizId);
      
      if (res != null) {
        _shop = Shop.fromRow(res);
        await _cache('shop').put([res]);
      }
    } catch (e, st) {
      log.error('loadShop failed', error: e, stackTrace: st);
    } finally {
      _shopLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadShopFromCache() async {
    final cached = await _cache('shop').getOrEmpty();
    if (cached.isNotEmpty) {
      _shop = Shop.fromRow(cached.first);
    }
    _shopLoading = false;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    log.info('signIn — email=${AppLogger.maskEmail(email)} supabaseConfigured=$supabaseConfigured');
    if (!supabaseConfigured) {
      _mockAuthed = true;
      notifyListeners();
      return true;
    }
    _authLoading = true;
    _authError = null;
    notifyListeners();
    final sw = Stopwatch()..start();
    try {
      final res = await SupabaseService.signIn(email: email, password: password);
      _user = res.user;
      _authLoading = false;
      _authError = null;
      notifyListeners();
      final success = res.user != null;
      log.info('signIn — ${success ? 'success userId=${_user?.id}' : 'no user returned'} (${sw.elapsedMilliseconds}ms)');
      return success;
    } on AuthException catch (e) {
      log.warning('signIn — AuthException: ${e.message} (${sw.elapsedMilliseconds}ms)');
      _authLoading = false;
      _authError = e.message;
      notifyListeners();
      return false;
    } catch (e, st) {
      log.error('signIn failed', error: e, stackTrace: st);
      _authLoading = false;
      final msg = e.toString();
      final clean = _extractErrorMessage(msg);
      _authError = clean ?? 'Sign-in failed. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String businessName,
    required String phone,
    required String fullName,
    String industry = '',
  }) async {
    log.info('signUp — email=${AppLogger.maskEmail(email)} business="$businessName" industry="$industry" supabaseConfigured=$supabaseConfigured');
    if (!supabaseConfigured) {
      _mockAuthed = true;
      notifyListeners();
      return true;
    }
    _authLoading = true;
    _authError = null;
    notifyListeners();
    final sw = Stopwatch()..start();
    try {
      final res = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'business_name': businessName,
          'phone': phone,
          'industry': industry,
        },
      );
      // Only set _user when a session exists (email confirmation not required).
      // If email confirmation is required, res.session is null and the user
      // must confirm before signing in — we leave _user null so authed stays
      // false and the sign-up screen shows the "check your inbox" step.
      _user = res.session?.user;
      _authLoading = false;
      _authError = null;
      notifyListeners();
      final hasUser = res.user != null;
      final hasSession = res.session != null;
      log.info('signUp — hasUser=$hasUser hasSession=$hasSession userId=${res.user?.id ?? 'none'} (${sw.elapsedMilliseconds}ms)');
      return hasUser;
    } on AuthException catch (e) {
      log.warning('signUp — AuthException: ${e.message} (${sw.elapsedMilliseconds}ms)');
      _authLoading = false;
      _authError = e.message;
      notifyListeners();
      return false;
    } catch (e, st) {
      log.error('signUp failed', error: e, stackTrace: st);
      _authLoading = false;
      // Surface the actual error message to help debugging.
      final msg = e.toString();
      // Extract a clean message from PostgrestException or generic errors
      final clean = _extractErrorMessage(msg);
      _authError = clean ?? 'Sign-up failed. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  /// Start the Google OAuth flow. Launches the system browser; the actual
  /// session lands via the auth stream listener (handleAuthChange) once the
  /// `ascendsme://auth-callback` deep link fires. Returns true if the browser
  /// successfully launched.
  Future<bool> signInWithGoogle() async {
    log.info('signInWithGoogle — supabaseConfigured=$supabaseConfigured');
    if (!supabaseConfigured) {
      // Mock mode — flip the local flag so the UI advances. Real OAuth needs
      // Supabase keys + dashboard provider config.
      _mockAuthed = true;
      notifyListeners();
      return true;
    }
    _authLoading = true;
    _authError = null;
    notifyListeners();
    try {
      final launched = await SupabaseService.signInWithGoogle();
      log.info('signInWithGoogle — browser launched=$launched');
      // _authLoading stays true until the auth stream fires signedIn (which
      // clears it via handleAuthChange) or the user cancels. We don't know
      // here which happened; cancellation is recovered by tapping Sign in
      // again, which calls clearAuthError.
      return launched;
    } catch (e, st) {
      log.error('signInWithGoogle failed', error: e, stackTrace: st);
      _authLoading = false;
      _authError = 'Google sign-in failed. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  void signOut() {
    log.info('signOut — userId=${_user?.id ?? 'none'}');
    _mockAuthed = false;
    _user = null;
    if (supabaseConfigured) SupabaseService.signOut();
    // Clear all caches
    unawaited(clearAllCaches());
    notifyListeners();
  }

  Future<void> clearAllCaches() async {
    await Future.wait([
      _cache('invoices').clear(),
      _cache('receipts').clear(),
      _cache('expenses').clear(),
      _cache('inventory').clear(),
      _cache('customers').clear(),
      _cache('staff').clear(),
      _cache('recurring').clear(),
      _cache('projects').clear(),
      _cache('payroll').clear(),
      _cache('shop').clear(),
      _cache('bookings').clear(),
      _cache('booking_services').clear(),
      _cache('verification_tasks').clear(),
    ]);
    await syncService.clear();
  }

  void clearAuthError() {
    _authError = null;
    notifyListeners();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  AppTab _tab = AppTab.home;
  AppTab get tab => _tab;
  void setTab(AppTab t) { _tab = t; notifyListeners(); }

  /// Pending AI prompt to auto-send when AskAscend tab opens.
  String? _pendingAiPrompt;
  String? get pendingAiPrompt => _pendingAiPrompt;
  /// Set a prompt that AskAscendScreen should auto-send on next activation.
  void setAiPrompt(String? prompt) { _pendingAiPrompt = prompt; notifyListeners(); }
  /// Consume (clear) the pending prompt after reading.
  String? consumeAiPrompt() { final p = _pendingAiPrompt; _pendingAiPrompt = null; return p; }

  // ── Business info updates ───────────────────────────────────────────────────

  /// Update business profile fields (name, phone, city) via Supabase.
  /// Triggers a profile reload on success. No-op when not authenticated.
  Future<void> updateBusinessInfo({
    String? name,
    String? phone,
    String? city,
  }) async {
    if (!supabaseConfigured || _user == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['business_name'] = name.trim();
    if (phone != null) data['phone'] = phone.trim();
    if (city != null) data['city'] = city.trim();
    if (data.isEmpty) return;

    log.info('updateBusinessInfo — keys=${data.keys.toList()}');
    try {
      await SupabaseService.upsertProfile(data);
      unawaited(loadBusiness());
    } catch (e, st) {
      log.error('updateBusinessInfo failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Upload a business logo image, update the profile, and reload.
  /// Returns the new logo URL on success, null on failure.
  Future<String?> uploadBusinessLogo({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
  }) async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) return null;

    final url = await SupabaseService.uploadBusinessLogo(
      businessId: bizId,
      fileBytes: fileBytes,
      fileName: fileName,
      fileType: fileType,
    );

    if (url != null) {
      try {
        await SupabaseService.upsertProfile({'logo_url': url});
        // Immediately update local state so the UI shows the logo right away,
        // without waiting for the network round-trip in loadBusiness().
        if (_business != null) {
          _business = _business!.copyWith(logoUrl: url);
          notifyListeners();
        }
        unawaited(loadBusiness());
      } catch (e, st) {
        log.error('uploadBusinessLogo — profile update failed', error: e, stackTrace: st);
      }
    }
    return url;
  }

  /// Remove the business logo by clearing `logo_url` on the profile.
  /// Triggers a profile reload on success.
  Future<void> removeBusinessLogo() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) return;

    log.info('removeBusinessLogo — bizId=$bizId');
    try {
      await SupabaseService.removeBusinessLogo(businessId: bizId);
      unawaited(loadBusiness());
    } catch (e, st) {
      log.error('removeBusinessLogo failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  // ── Notification badge (last-seen tracking) ───────────────────────────────
  int? _lastSeenEpochMs;

  /// Notification count (computed from live data) for the bell badge.
  /// Respects notification preferences so disabled categories don't contribute.
  int get notificationsCount {
    final now = DateTime.now();
    var count = 0;
    if (_notifyExpiringQuotes) {
      count += invoices.where((i) =>
          i.isProforma &&
          i.validUntil != null &&
          i.validUntil!.isAfter(now) &&
          i.validUntil!.difference(now).inDays <= 3).length;
    }
    if (_notifyOverdueInvoices) {
      count += invoices.where((i) =>
          i.status == 'overdue' && i.days >= 7).length;
    }
    if (_notifyLowStock) {
      count += _inventory.where((i) => i.lowStock).length;
    }
    return count;
  }

  /// Mark all current notifications as seen — resets the badge to 0
  /// until new events appear.
  void markNotificationsSeen() {
    _lastSeenEpochMs = DateTime.now().millisecondsSinceEpoch;
    _persistLastSeen();
    notifyListeners();
  }

  /// Timestamp (epoch ms) of when the user last opened the notifications sheet.
  /// Used by [buildNotifications] to filter items newer than last review.
  int? get lastSeenNotificationEpochMs => _lastSeenEpochMs;

  void _persistLastSeen() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        if (_lastSeenEpochMs != null) {
          prefs.setInt('ascend_last_seen_notifications', _lastSeenEpochMs!);
        }
      });
    } catch (_) {}
  }

  // ── Notification preferences (stored locally, used when push infra is added) ──
  bool _notifyInvoiceReminders = true;
  bool _notifyPaymentReceived = true;
  bool _notifyExpenseReminders = true;
  bool _notifyExpiringQuotes = true;
  bool _notifyOverdueInvoices = true;
  bool _notifyLowStock = true;

  bool get notifyInvoiceReminders => _notifyInvoiceReminders;
  bool get notifyPaymentReceived => _notifyPaymentReceived;
  bool get notifyExpenseReminders => _notifyExpenseReminders;
  bool get notifyExpiringQuotes => _notifyExpiringQuotes;
  bool get notifyOverdueInvoices => _notifyOverdueInvoices;
  bool get notifyLowStock => _notifyLowStock;

  void setNotifyInvoiceReminders(bool v) {
    _notifyInvoiceReminders = v;
    _persistNotifyPrefs();
    notifyListeners();
  }

  void setNotifyPaymentReceived(bool v) {
    _notifyPaymentReceived = v;
    _persistNotifyPrefs();
    notifyListeners();
  }

  void setNotifyExpenseReminders(bool v) {
    _notifyExpenseReminders = v;
    _persistNotifyPrefs();
    notifyListeners();
  }

  void setNotifyExpiringQuotes(bool v) {
    _notifyExpiringQuotes = v;
    _persistNotifyPrefs();
    notifyListeners();
  }

  void setNotifyOverdueInvoices(bool v) {
    _notifyOverdueInvoices = v;
    _persistNotifyPrefs();
    notifyListeners();
  }

  void setNotifyLowStock(bool v) {
    _notifyLowStock = v;
    _persistNotifyPrefs();
    notifyListeners();
  }

  void _persistNotifyPrefs() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('ascend_notify_invoice_reminders', _notifyInvoiceReminders);
        prefs.setBool('ascend_notify_payment_received', _notifyPaymentReceived);
        prefs.setBool('ascend_notify_expense_reminders', _notifyExpenseReminders);
        prefs.setBool('ascend_notify_expiring_quotes', _notifyExpiringQuotes);
        prefs.setBool('ascend_notify_overdue_invoices', _notifyOverdueInvoices);
        prefs.setBool('ascend_notify_low_stock', _notifyLowStock);
      });
    } catch (_) {}
  }

  Future<void> _loadNotifyPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notifyInvoiceReminders = prefs.getBool('ascend_notify_invoice_reminders') ?? true;
      _notifyPaymentReceived = prefs.getBool('ascend_notify_payment_received') ?? true;
      _notifyExpenseReminders = prefs.getBool('ascend_notify_expense_reminders') ?? true;
      _notifyExpiringQuotes = prefs.getBool('ascend_notify_expiring_quotes') ?? true;
      _notifyOverdueInvoices = prefs.getBool('ascend_notify_overdue_invoices') ?? true;
      _notifyLowStock = prefs.getBool('ascend_notify_low_stock') ?? true;
    } catch (_) {}
    // Also restore last-seen timestamp
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSeenEpochMs = prefs.getInt('ascend_last_seen_notifications');
    } catch (_) {}
  }

  // ── Appearance ─────────────────────────────────────────────────────────────
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  void toggleDark() {
    _darkMode = !_darkMode;
    _persistDarkMode();
    notifyListeners();
  }
  void setDark(bool v) {
    _darkMode = v;
    _persistDarkMode();
    notifyListeners();
  }

  static const _kDarkModePrefKey = 'ascend_dark_mode';

  void _persistDarkMode() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(_kDarkModePrefKey, _darkMode);
      });
    } catch (_) {}
  }

  Future<void> _loadDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kDarkModePrefKey);
      if (saved != null) {
        _darkMode = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  NavVariant _navVariant = NavVariant.classic;
  NavVariant get navVariant => _navVariant;
  void setNavVariant(NavVariant v) { _navVariant = v; notifyListeners(); }

  @override
  void dispose() {
    _unsubscribeAllChannels();
    connectivity.removeListener(_onConnectivityChange);
    super.dispose();
  }

  // ── Conversion events (for activity feed — ephemeral, in-memory) ───────────
  /// Tracks proforma-to-invoice conversions so the activity feed can surface
  /// "Quote for X converted" events. Ephemeral (not persisted) — lost on
  /// app restart, which is acceptable since the converted quote now lives as
  /// a regular invoice and older sessions' conversion events are replaced by
  /// the invoice's creation event.
  final List<Map<String, dynamic>> _conversionEvents = [];

  /// Record a proforma-to-invoice conversion for the activity feed.
  void recordConversion(String customerName, num amount, {String? invoiceId}) {
    _conversionEvents.add({
      'customerName': customerName,
      'amount': amount,
      'time': DateTime.now().toIso8601String(),
      'invoiceId': invoiceId,
    });
    // Keep only the last 20 to prevent unbounded growth.
    while (_conversionEvents.length > 20) {
      _conversionEvents.removeAt(0);
    }
    notifyListeners();
  }

  /// Read-only view of recorded conversion events for `buildActivityFeed()`.
  List<Map<String, dynamic>> get conversionEvents =>
      List.unmodifiable(_conversionEvents);

  // ── Verification progress (real data from verification_tasks table) ──────────
  //
  // Why this lives in AppState:
  //   1. Single source of truth — every screen reads from one place.
  //   2. Follows the existing two-phase pattern (cache → network).
  //   3. When the data source changes, only AppState changes — no widget edits.
  //
  // Strategy:
  //   - The step definitions (what documents are needed) come from kVerificationSteps.
  //   - The STATUS of each step comes from verification_tasks in Supabase.
  //     (Web creates a verification_task per document type per business.)
  //   - A verified task → 'verified' status
  //   - A pending-review task → 'pending' status
  //   - No task or EMPTY status → 'todo' status
  //   - Falls back to mock statuses when no Supabase data is available.

  /// Raw verification task rows fetched from Supabase.
  List<Map<String, dynamic>> _verificationTaskRows = [];

  /// Whether verification status has been loaded at least once.
  bool _verificationLoaded = false;

  /// The full list of verification steps with current status.
  /// Merges the step definitions (kVerificationSteps) with real task statuses
  /// from Supabase. Falls back to mock statuses when real data hasn't loaded.
  List<VerificationStep> get verificationSteps {
    if (!_verificationLoaded) return kVerificationSteps;

    // Build a lookup: step id → task row
    // Uses a clean dictionary instead of fragile string matching.
    final taskMap = <String, Map<String, dynamic>>{};
    for (final task in _verificationTaskRows) {
      final taskType = (task['task_type'] as String?)?.toLowerCase().trim() ?? '';
      final stepId = _kTaskTypeToStepId[taskType];
      if (stepId != null) {
        taskMap[stepId] = task;
      }
    }

    return kVerificationSteps.map((step) {
      final task = taskMap[step.id];
      if (task == null) {
        // No task exists for this step — it's still to-do
        return VerificationStep(
          id: step.id,
          label: step.label,
          status: 'todo',
          detail: step.detail,
          tier: step.tier,
        );
      }
      final taskStatus = (task['status'] as String?) ?? 'EMPTY';
      final mappedStatus = switch (taskStatus) {
        'VERIFIED' || 'RECOMMENDED' => 'verified',
        'PENDING_REVIEW'            => 'pending',
        'REJECTED'                  => 'todo', // re-upload needed
        _                           => 'todo', // EMPTY or unknown → to-do
      };
      return VerificationStep(
        id: step.id,
        label: step.label,
        status: mappedStatus,
        detail: _buildStepDetail(step, taskStatus, task),
        tier: step.tier,
      );
    }).toList();
  }

  /// Direct mapping from Supabase `verification_tasks.task_type` to the
  /// step IDs in `kVerificationSteps`. Each entry pairs the exact task_type
  /// value (as stored by web's verification-integration-service) with the
  /// corresponding step id. No string matching — just a clean lookup.
  static const _kTaskTypeToStepId = <String, String>{
    'ghana_card': 'v2_ghana_card',
    'rgd_certificate': 'v2_rgd',
    'tin_certificate': 'v3_tin',
    'proof_of_address': 'v3_address',
    'bank_statements': 'v3_bank',
  };

  /// Build a human-readable detail string that includes the real verification
  /// status from Supabase (instead of always showing the mock detail).
  String _buildStepDetail(VerificationStep step, String taskStatus, Map<String, dynamic> task) {
    switch (taskStatus) {
      case 'VERIFIED':
        final verifiedAt = task['verified_at'] as String?;
        if (verifiedAt != null) {
          final d = DateTime.tryParse(verifiedAt);
          if (d != null) return 'Verified ${formatLongDate(d)}';
        }
        return 'Verified';
      case 'PENDING_REVIEW':
        return 'Document uploaded — awaiting review';
      case 'REJECTED':
        final reason = task['rejection_reason'] as String? ?? 'Document was rejected';
        return reason;
      default:
        return step.detail;
    }
  }

  /// Number of steps marked as 'verified'.
  int get verificationDone =>
      verificationSteps.where((s) => s.status == 'verified').length;

  /// Total verification steps.
  int get verificationTotal => verificationSteps.length;

  /// Progress as a 0.0–1.0 fraction.
  double get verificationProgress =>
      verificationTotal > 0 ? verificationDone / verificationTotal : 0.0;

  /// Whether verification status is currently being loaded.
  bool _verificationLoading = false;
  bool get verificationLoading => _verificationLoading;

  /// Set when the network fetch fails — null means no error.
  String? _verificationError;
  String? get verificationError => _verificationError;

  /// Whether the verification status loaded successfully at least once (from
  /// cache or network). Used by the ring to know if it should show real data
  /// or fall back to mock with a loading indicator.
  bool get verificationLoaded => _verificationLoaded;

  /// Load verification task statuses from Supabase.
  /// Two-phase: cache → network, same pattern as invoices/receipts/expenses.
  Future<void> loadVerificationStatus() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _verificationLoaded = false;
      _verificationError = null;
      notifyListeners();
      return;
    }
    log.debug('loadVerificationStatus — bizId=$bizId');
    _verificationLoading = true;
    _verificationError = null;
    notifyListeners();

    // Phase 1 — restore from cache (so the ring never shows zeros)
    final cached = await _cache('verification_tasks').getOrEmpty();
    if (cached.isNotEmpty) {
      _verificationTaskRows = cached;
      _verificationLoaded = true;
      _verificationError = null;
      log.debug('loadVerificationStatus — restored ${cached.length} tasks from cache');
      notifyListeners();
      _verificationLoading = false;
    }

    // Phase 2 — network fetch (silent refresh if cache was available)
    final sw = Stopwatch()..start();
    try {
      _verificationTaskRows = await SupabaseService.fetchVerificationTasks(businessId: bizId);
      _verificationLoaded = true;
      _verificationError = null;
      await _cache('verification_tasks').put(_verificationTaskRows);
      log.info('loadVerificationStatus — loaded ${_verificationTaskRows.length} tasks (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.warning('loadVerificationStatus failed', error: e, stackTrace: st);
      _verificationError = 'Could not load verification data';
      // Keep cache data if network fails
    } finally {
      _verificationLoading = false;
      notifyListeners();
    }
  }

  /// Cache-only fallback for offline mode.
  Future<void> _loadVerificationFromCache() async {
    final cached = await _cache('verification_tasks').getOrEmpty();
    if (cached.isNotEmpty) {
      _verificationTaskRows = cached;
      _verificationLoaded = true;
      _verificationError = null;
      _verificationLoading = false;
      notifyListeners();
    }
  }

  /// Real-time channel for verification_tasks changes.
  /// When an admin verifies/rejects a document on the web, the ring updates
  /// automatically without a manual pull-to-refresh.
  RealtimeChannel? _verificationChannel;

  void _subscribeVerificationChannel() {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) return;
    _verificationChannel?.unsubscribe();
    _verificationChannel = SupabaseService.client.channel('verification-changes');
    _verificationChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'verification_tasks',
          schema: 'public',
          callback: (payload) {
            log.debug('realtime verification_tasks — event=${payload.eventType}');
            unawaited(loadVerificationStatus());
          },
        )
        .subscribe();
    log.debug('_subscribeVerificationChannel — subscribed for bizId=$bizId');
  }

  void _unsubscribeVerificationChannel() {
    _verificationChannel?.unsubscribe();
    _verificationChannel = null;
  }

  // ── Identity helpers ───────────────────────────────────────────────────────

  // ── Period selection (persisted, shared across screens) ────────────────
  int _periodIndex = 0;

  /// 0=1M, 1=3M, 2=6M, 3=YTD
  int get selectedPeriodIndex => _periodIndex;

  /// Convert the index to a month count (0=YTD returns current month number).
  int get effectivePeriodMonths {
    if (_periodIndex >= 3) return DateTime.now().month; // YTD
    return [1, 3, 6][_periodIndex];
  }

  void setSelectedPeriod(int index) {
    _periodIndex = index;
    _persistPeriod();
    notifyListeners();
  }

  void _persistPeriod() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('ascend_selected_period', _periodIndex);
      });
    } catch (_) {}
  }

  Future<void> _loadPeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('ascend_selected_period');
      if (saved != null && saved >= 0 && saved <= 3) {
        _periodIndex = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Extract a clean user-facing error message from a raw exception string.
  /// Strips PostgrestException wrapper noise, Supabase API error prefixes,
  /// and long stack traces so the user sees the actionable part.
  /// Extract a clean user-facing error message from a raw exception string.
  /// Strips PostgrestException wrapper noise, Supabase API error prefixes,
  /// and long stack traces so the user sees the actionable part.
  static String? _extractErrorMessage(String raw) {
    // PostgrestException: 'PostgrestException(message: 'actual error', code: ...)'
    final pgMatch = RegExp(r"message:\s*'([^']+)'").firstMatch(raw);
    if (pgMatch != null) {
      final msg = pgMatch.group(1)!.trim();
      if (msg.isNotEmpty && msg.length < 200) return msg;
    }
    // Fallback: grab text after 'message:' up to a comma or closing bracket
    final genericMatch = RegExp(r'message:\s*([^,)}\)]+)').firstMatch(raw);
    if (genericMatch != null) {
      final msg = genericMatch.group(1)!.trim();
      if (msg.isNotEmpty && msg.length < 200) return msg;
    }
    // Generic HTTP/network errors
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return 'Could not reach the server. Check your internet connection.';
    }
    if (raw.contains('TimeoutException')) {
      return 'Request timed out. Check your internet connection and try again.';
    }
    return null; // caller provides fallback
  }

  /// First name pulled from auth metadata (set at signup). Returns null when
  /// no full_name was captured — in that case the greeting should omit the
  /// personal salutation rather than fall back to something cringey like the
  /// business name.
  String? get firstName {
    final raw = _user?.userMetadata?['full_name'] as String?;
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // If full_name happens to equal the business name (older accounts that
    // never captured a personal name and got the trigger's fallback), don't
    // greet them by it — feels wrong.
    if (_business != null &&
        trimmed.toLowerCase() == _business!.name.toLowerCase()) {
      return null;
    }
    final first = trimmed.split(RegExp(r'\s+')).first;
    return first.isEmpty ? null : first;
  }
}
