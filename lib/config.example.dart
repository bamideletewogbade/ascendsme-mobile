// Copy this file to lib/config.dart and fill in your keys.
// lib/config.dart is git-ignored — never commit real credentials.
//
// Gemini    → https://aistudio.google.com/apikey          (1,500 req/day free)
// Groq      → https://console.groq.com/keys               (fast LPU, generous free tier)
// OpenRouter→ https://openrouter.ai/settings/keys         (free Llama models)
// Supabase  → Dashboard → Settings → API

class AppConfig {
  // ── AI keys ───────────────────────────────────────────────────────────────
  static const String geminiApiKey     = '';
  static const String groqApiKey       = '';
  static const String openRouterApiKey = '';

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

enum AIModel {
  geminiFlash(
    id: 'gemini-2.0-flash',
    label: 'Gemini 2.0 Flash',
    provider: AIProvider.gemini,
    badge: 'Recommended',
  ),
  geminiFlashLite(
    id: 'gemini-2.0-flash-lite',
    label: 'Gemini 2.0 Flash Lite',
    provider: AIProvider.gemini,
    badge: 'Fast',
  ),
  gemini15Flash(
    id: 'gemini-1.5-flash',
    label: 'Gemini 1.5 Flash',
    provider: AIProvider.gemini,
    badge: '',
  ),
  groqLlama33(
    id: 'llama-3.3-70b-versatile',
    label: 'Llama 3.3 70B (Groq)',
    provider: AIProvider.groq,
    badge: 'Fast · Free',
  ),
  llama31(
    id: 'meta-llama/llama-3.1-8b-instruct:free',
    label: 'Llama 3.1 8B',
    provider: AIProvider.openRouter,
    badge: 'Free',
  ),
  llama33(
    id: 'meta-llama/llama-3.3-70b-instruct:free',
    label: 'Llama 3.3 70B',
    provider: AIProvider.openRouter,
    badge: 'Free · Capable',
  );

  const AIModel({
    required this.id,
    required this.label,
    required this.provider,
    required this.badge,
  });

  final String id;
  final String label;
  final AIProvider provider;
  final String badge;
}

enum AIProvider { gemini, groq, openRouter }
