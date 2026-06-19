// Copy this file to lib/config.dart and fill in your keys.
// lib/config.dart is git-ignored — never commit real credentials.
//
// ── AI Providers ────────────────────────────────────────────────────────────
// The app uses a fallback chain across multiple models and providers:
//
//   1. Vertex AI (Firebase) → console.firebase.google.com  (GCP free quota)
//      Enables Gemini models through your GCP project. No API key needed —
//      Firebase Auth + App Check handle authentication.
//
//   2. Groq           → console.groq.com/keys        (free dev tier)
//   3. OpenRouter     → openrouter.ai/settings/keys  (free :free models)
//
// Each provider can have MULTIPLE model attempts. If the first model fails
// (rate limit, timeout, down), the next model in the chain runs automatically.
// See `lib/services/ai_service.dart` for the full model list — reorder or
// add/remove entries freely.
//
// One key is enough for the app to work. Add more for extra fallback resilience.
//
// ── To set up Vertex AI ─────────────────────────────────────────────────────
//   1. Go to console.firebase.google.com and add your GCP project (ascendsme)
//   2. Enable Vertex AI: Firebase Console → Build → AI → Vertex AI
//   3. Enable the Vertex AI API in GCP Console → APIs & Services
//   4. Run `flutterfire configure` to generate firebase_options.dart
//   5. Ensure Firebase Auth is enabled (at least Anonymous or Email/Password)
//
// ── Supabase ────────────────────────────────────────────────────────────────
// Dashboard → Settings → API
//
// ─────────────────────────────────────────────────────────────────────────────

class AppConfig {
  // ── AI keys ───────────────────────────────────────────────────────────────
  // Vertex AI uses Firebase Auth — no API key needed.
  static const String groqApiKey       = ''; // Llama 3.3 / Llama 3.1 (fast LPU, free)
  static const String openRouterApiKey = ''; // :free models + openrouter/free router
  static const String opencodeApiKey   = ''; // opencode.ai/zen — Nemotron 3 Ultra + DeepSeek V4 Flash (free)

  // ── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl      = ''; // e.g. https://xxxx.supabase.co
  static const String supabaseAnonKey  = ''; // public anon key

  // ── Payment links ─────────────────────────────────────────────────────────
  static const String payLinkBaseUrl   = 'https://pay.ascendsme.app/inv/';

  // ── Auth deep-link redirect ───────────────────────────────────────────────
  // Used by Supabase OAuth + password reset emails. Must match the scheme in
  // AndroidManifest.xml, ios/Runner/Info.plist, and Supabase Dashboard's
  // Auth → URL Config allow-list.
  static const String oauthRedirectUrl = 'ascendsme://auth-callback';
}
