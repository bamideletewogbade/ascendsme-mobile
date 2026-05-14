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
  /// Expects a `businesses` (or `profiles`) table in Supabase.
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final res = await client
        .from('businesses')
        .select()
        .eq('owner_id', uid)
        .maybeSingle();
    return res;
  }

  /// Create or update the business profile row.
  static Future<void> upsertProfile(Map<String, dynamic> data) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await client.from('businesses').upsert({
      'owner_id': uid,
      ...data,
    });
  }
}
