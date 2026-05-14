// Copy this file to lib/config.dart and fill in your keys.
// lib/config.dart is git-ignored — never commit real credentials.
//
// Gemini API key  → https://aistudio.google.com/apikey
// OpenRouter key  → https://openrouter.ai/settings/keys
// Supabase creds  → Supabase dashboard → Settings → API

class AppConfig {
  // ── AI keys ───────────────────────────────────────────────────────────────
  static const String geminiApiKey = '';
  static const String openRouterApiKey = '';

  // ── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl = ''; // e.g. https://xxxx.supabase.co
  static const String supabaseAnonKey = ''; // public anon key
}

// Available AI models — Gemini is first in line.
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

enum AIProvider { gemini, openRouter }
