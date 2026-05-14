import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';

enum AppTab { home, tools, verify, help }

enum HomeLayout { score, agenda, cards }

enum NavVariant { classic, pill, fab }

class AppState extends ChangeNotifier {
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
    if (!supabaseConfigured) return;
    _user = SupabaseService.currentUser;
    // No notifyListeners — called synchronously before runApp.
    // Profile load is fire-and-forget; it'll notify listeners when it lands.
    if (_user != null) {
      loadBusiness();
    }
  }

  /// Called by the Supabase auth stream listener in main.dart.
  void handleAuthChange(AuthState state) {
    final previousUserId = _user?.id;
    _user = state.session?.user;
    _authLoading = false;
    _authError = null;
    notifyListeners();

    // Reload the business profile on a genuine login (user transition) and
    // clear it on sign-out. Token refreshes don't change _user.id so they're
    // a no-op here — that preserves any in-memory gamification progress.
    final currentUserId = _user?.id;
    if (currentUserId == null && previousUserId != null) {
      _business = null;
      notifyListeners();
    } else if (currentUserId != null && currentUserId != previousUserId) {
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

  /// Load the signed-in user's business profile from Supabase. Idempotent and
  /// safe to call multiple times. If the backend trigger hasn't bootstrapped
  /// a row yet (e.g. signup in flight), keeps _business null so the UI falls
  /// back to the mock. Triggers a financials + invoices reload on success.
  Future<void> loadBusiness() async {
    if (!supabaseConfigured || _user == null) return;
    try {
      final row = await SupabaseService.fetchProfile();
      if (row == null) {
        _business = null;
        _financials = Financials.empty;
        _invoices = [];
      } else {
        _business = Business.fromRow(row);
        // Seed the in-memory sustainability score from the server so the dial
        // shows the user's real progress on first paint. Quest completions are
        // still in-memory only — they'll be lost on next loadBusiness() until
        // we persist them server-side. Document this as a known limitation.
        _score = _business!.sustainabilityScore;
      }
      notifyListeners();
      // Fire-and-forget downstream loads. The UI shows 0/empty until they
      // resolve, then re-renders via notifyListeners.
      if (_business?.id != null) {
        unawaited(loadFinancials());
        unawaited(loadInvoices());
      }
    } catch (e) {
      // Don't fail loudly — keep _business null and let the mock surface.
      // The error path is rare (network blip / RLS misconfiguration) and the
      // UI degrades gracefully via the getter fallback.
      _business = null;
      _financials = Financials.empty;
      _invoices = [];
      notifyListeners();
    }
  }

  // ── Financials (month-to-date aggregation) ─────────────────────────────────
  Financials _financials = Financials.empty;
  Financials get financials => _financials;
  bool _financialsLoading = false;
  bool get financialsLoading => _financialsLoading;

  /// Aggregate revenue / expenses / outstanding for the signed-in business.
  /// Runs five queries in parallel: this-month receipts, this-month expenses,
  /// last-month receipts (for the % change chip), last-month expenses, and
  /// open invoices. Returns Financials.empty if no business is loaded.
  Future<void> loadFinancials() async {
    final bizId = _business?.id;
    if (!supabaseConfigured || bizId == null) {
      _financials = Financials.empty;
      notifyListeners();
      return;
    }
    _financialsLoading = true;
    notifyListeners();

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
      final today = DateTime(now.year, now.month, now.day);
      for (final inv in openInvoices) {
        outstandingTotal += (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final status = (inv['status'] as String?)?.toLowerCase();
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
        // TODO(pipeline): wire proforma_invoices once we decide on semantics.
        // For now pipeline = 0 so the UI doesn't surface a misleading figure.
        pipeline: 0,
        revenueChangePctVsLastMonth: pctChange(revenueNow, revenueLast),
        expensesChangePctVsLastMonth: pctChange(expensesNow, expensesLast),
      );
    } catch (_) {
      _financials = Financials.empty;
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
    _invoicesLoading = true;
    notifyListeners();
    try {
      final rows = await SupabaseService.fetchInvoices(businessId: bizId);
      _invoices = rows.map(Invoice.fromRow).toList();
    } catch (_) {
      _invoices = [];
    } finally {
      _invoicesLoading = false;
      notifyListeners();
    }
  }

  /// Convenience: refresh everything that depends on Supabase data. Use after
  /// mutations (createInvoice, future createExpense, etc.) or from a
  /// pull-to-refresh.
  Future<void> refreshAll() async {
    if (!supabaseConfigured || _user == null) return;
    await loadBusiness();
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (!supabaseConfigured) {
      _mockAuthed = true;
      notifyListeners();
      return true;
    }
    _authLoading = true;
    _authError = null;
    notifyListeners();
    try {
      final res = await SupabaseService.signIn(email: email, password: password);
      _user = res.user;
      _authLoading = false;
      _authError = null;
      notifyListeners();
      return res.user != null;
    } on AuthException catch (e) {
      _authLoading = false;
      _authError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
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
    if (!supabaseConfigured) {
      _mockAuthed = true;
      notifyListeners();
      return true;
    }
    _authLoading = true;
    _authError = null;
    notifyListeners();
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
      return res.user != null;
    } on AuthException catch (e) {
      _authLoading = false;
      _authError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _authLoading = false;
      _authError = 'Sign-up failed. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  void signOut() {
    _mockAuthed = false;
    _user = null;
    if (supabaseConfigured) SupabaseService.signOut();
    notifyListeners();
  }

  void clearAuthError() {
    _authError = null;
    notifyListeners();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  AppTab _tab = AppTab.home;
  AppTab get tab => _tab;
  void setTab(AppTab t) { _tab = t; notifyListeners(); }

  // ── Appearance ─────────────────────────────────────────────────────────────
  bool _darkMode = false;
  bool get darkMode => _darkMode;
  void toggleDark() { _darkMode = !_darkMode; notifyListeners(); }
  void setDark(bool v) { _darkMode = v; notifyListeners(); }

  HomeLayout _homeLayout = HomeLayout.score;
  HomeLayout get homeLayout => _homeLayout;
  void setHomeLayout(HomeLayout l) { _homeLayout = l; notifyListeners(); }

  NavVariant _navVariant = NavVariant.classic;
  NavVariant get navVariant => _navVariant;
  void setNavVariant(NavVariant v) { _navVariant = v; notifyListeners(); }

  // ── Gamification ───────────────────────────────────────────────────────────
  // Seeded from the loaded business profile (or kBusiness as fallback). The
  // score is mutated in-memory by quest completions and is NOT persisted yet
  // — those mutations are lost on next loadBusiness() call.
  int _score = kBusiness.sustainabilityScore;
  int get score => _score;

  final int _streak = 12;
  int get streak => _streak;

  List<Quest> _quests = List.from(kInitialQuests);
  List<Quest> get quests => _quests;

  ScoreUpEvent? _scoreUp;
  ScoreUpEvent? get scoreUp => _scoreUp;

  void completeQuest(Quest q) {
    if (q.done) return;
    _quests = _quests.map((x) => x.id == q.id ? x.copyWith(done: true) : x).toList();
    final from = _score;
    final to = (_score + q.pts).clamp(0, 100);
    _score = to;
    _scoreUp = ScoreUpEvent(pts: q.pts, from: from, to: to);
    notifyListeners();
  }

  void clearScoreUp() { _scoreUp = null; notifyListeners(); }

  void resetQuests() {
    _quests = List.from(kInitialQuests);
    _score = _business?.sustainabilityScore ?? kBusiness.sustainabilityScore;
    notifyListeners();
  }

  void triggerScoreUp(int pts) {
    final from = _score;
    final to = (_score + pts).clamp(0, 100);
    _score = to;
    _scoreUp = ScoreUpEvent(pts: pts, from: from, to: to);
    notifyListeners();
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

  // ── AI model ───────────────────────────────────────────────────────────────
  AIModel _aiModel = AIModel.groqLlama33;
  AIModel get aiModel => _aiModel;
  void setAiModel(AIModel m) {
    _aiModel = m;
    AIService.setModel(m);
    notifyListeners();
  }
}

class ScoreUpEvent {
  final int pts, from, to;
  ScoreUpEvent({required this.pts, required this.from, required this.to});
}
