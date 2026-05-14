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
  }

  /// Called by the Supabase auth stream listener in main.dart.
  void handleAuthChange(AuthState state) {
    _user = state.session?.user;
    _authLoading = false;
    _authError = null;
    notifyListeners();
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
        data: {'business_name': businessName, 'phone': phone, 'industry': industry},
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
    _score = kBusiness.sustainabilityScore;
    notifyListeners();
  }

  void triggerScoreUp(int pts) {
    final from = _score;
    final to = (_score + pts).clamp(0, 100);
    _score = to;
    _scoreUp = ScoreUpEvent(pts: pts, from: from, to: to);
    notifyListeners();
  }

  // ── AI model ───────────────────────────────────────────────────────────────
  AIModel _aiModel = AIModel.geminiFlash;
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
