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
        // Subscribe to real-time inventory updates
        _subscribeInventoryChannel();
        log.info('loadBusiness — loaded: id=${_business!.id} name="${_business!.name}" (${sw.elapsedMilliseconds}ms)');
      }
      notifyListeners();
      if (_business?.id != null) {
        unawaited(loadFinancials());
        unawaited(loadInvoices());
        unawaited(loadReceipts());
        unawaited(loadExpenses());
        unawaited(loadInventory());
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
  ///   2. Run five Supabase queries in parallel (this-month receipts & expenses,
  ///      last-month receipts & expenses, open invoices), then update cache.
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
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);

      final results = await Future.wait([
        SupabaseService.sumReceipts(
            businessId: bizId, start: thisMonthStart, end: nextMonthStart),
        SupabaseService.sumExpenses(
            businessId: bizId, start: thisMonthStart, end: nextMonthStart),
        SupabaseService.sumReceipts(
            businessId: bizId, start: lastMonthStart, end: thisMonthStart),
        SupabaseService.sumExpenses(
            businessId: bizId, start: lastMonthStart, end: thisMonthStart),
        SupabaseService.fetchOpenInvoices(businessId: bizId),
      ]);

      final revenueNow = results[0] as double;
      final expensesNow = results[1] as double;
      final revenueLast = results[2] as double;
      final expensesLast = results[3] as double;
      final openInvoices = results[4] as List<Map<String, dynamic>>;

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

      double? pctChange(double now_, double last) {
        if (last == 0) return null; // can't divide; hide the chip
        return ((now_ - last) / last) * 100;
      }

      _financials = Financials(
        revenueThisMonth: revenueNow.round(),
        expensesThisMonth: expensesNow.round(),
        outstanding: outstandingTotal.round(),
        outstandingCount: openInvoices.length,
        outstandingOverdueCount: overdueCount,
        pipeline: pipelineTotal.round(),
        revenueChangePctVsLastMonth: pctChange(revenueNow, revenueLast),
        expensesChangePctVsLastMonth: pctChange(expensesNow, expensesLast),
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
            // Reload inventory in the background on any change
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

  SubscriptionInfo? get subscription => _subscription;
  bool get subscriptionLoading => _subscriptionLoading;
  List<SubscriptionPlan> get availablePlans => _availablePlans;

  Future<void> loadSubscription() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _subscription = null;
      notifyListeners();
      return;
    }
    log.debug('loadSubscription — bizId=$bizId');
    _subscriptionLoading = true;
    notifyListeners();
    final sw = Stopwatch()..start();
    try {
      _subscription = await SubscriptionService.getCurrentSubscription(businessId: bizId);
      log.info('loadSubscription — ${_subscription != null ? 'tier=${_subscription!.tierCode}' : 'free/expired'} (${sw.elapsedMilliseconds}ms)');
    } catch (e, st) {
      log.error('loadSubscription failed', error: e, stackTrace: st);
      _subscription = null;
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
      _authError = 'Sign-in failed. Check your connection and try again.';
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
      _authError = 'Sign-up failed. Check your connection and try again.';
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
    unawaited(_clearAllCaches());
    notifyListeners();
  }

  Future<void> _clearAllCaches() async {
    await Future.wait([
      _cache('invoices').clear(),
      _cache('receipts').clear(),
      _cache('expenses').clear(),
      _cache('inventory').clear(),
      _cache('customers').clear(),
      _cache('staff').clear(),
      _cache('recurring').clear(),
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

  // ── Appearance ─────────────────────────────────────────────────────────────
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  void toggleDark() { _darkMode = !_darkMode; notifyListeners(); }
  void setDark(bool v) { _darkMode = v; notifyListeners(); }

  NavVariant _navVariant = NavVariant.classic;
  NavVariant get navVariant => _navVariant;
  void setNavVariant(NavVariant v) { _navVariant = v; notifyListeners(); }

  @override
  void dispose() {
    _unsubscribeInventoryChannel();
    connectivity.removeListener(_onConnectivityChange);
    super.dispose();
  }

  // ── Identity helpers ───────────────────────────────────────────────────────

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
