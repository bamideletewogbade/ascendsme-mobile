// Copy this file to lib/config.dart and fill in your keys.
// lib/config.dart is git-ignored — never commit real credentials.
//
// Gemini API key  → https://aistudio.google.com/apikey
// Groq API key    → https://console.groq.com/keys   (fast LPU inference)
// OpenRouter key  → https://openrouter.ai/settings/keys
// Supabase creds  → Supabase dashboard → Settings → API

class AppConfig {
  // ── AI keys ───────────────────────────────────────────────────────────────
  static const String geminiApiKey = '';
  static const String openRouterApiKey = '';
  static const String groqApiKey = '';

  // ── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl = ''; // e.g. https://xxxx.supabase.co
  static const String supabaseAnonKey = ''; // public anon key

  // ── Hosted invoice pay page (Paystack) ────────────────────────────────────
  // Base URL of the web app's hosted invoice pay page. Full link is
  // `${payLinkBaseUrl}<pay_token>`.
  static const String payLinkBaseUrl = 'https://ascendsme.app/pay/';
}

// Available AI models. Order = priority shown in the picker.
// Groq is preferred over OpenRouter when speed matters — Groq's LPU
// inference is ~10x faster end-to-end and avoids OpenRouter timeouts.
enum AIModel {
  // ── Gemini (Google) ───────────────────────────────────────────────────────
  geminiFlash(
    id: 'gemini-2.0-flash',
    label: 'Gemini 2.0 Flash',
    provider: AIProvider.gemini,
    badge: 'Capable',
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

  // ── Groq (LPU inference — fast) ───────────────────────────────────────────
  groqLlama33(
    id: 'llama-3.3-70b-versatile',
    label: 'Llama 3.3 70B (Groq)',
    provider: AIProvider.groq,
    badge: 'Recommended · Fast',
  ),
  groqLlama31(
    id: 'llama-3.1-8b-instant',
    label: 'Llama 3.1 8B (Groq)',
    provider: AIProvider.groq,
    badge: 'Fastest',
  ),

  // ── OpenRouter (slower, broad model catalogue) ────────────────────────────
  llama31(
    id: 'meta-llama/llama-3.1-8b-instruct:free',
    label: 'Llama 3.1 8B (OpenRouter)',
    provider: AIProvider.openRouter,
    badge: 'Free',
  ),
  llama33(
    id: 'meta-llama/llama-3.3-70b-instruct:free',
    label: 'Llama 3.3 70B (OpenRouter)',
    provider: AIProvider.openRouter,
    badge: 'Free',
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
