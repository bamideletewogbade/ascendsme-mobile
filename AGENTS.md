# AscendSME Mobile

Flutter app — business management for Ghanaian SMEs. Connects to a shared Supabase backend (same project as the web platform) and uses Gemini / Groq / OpenRouter for AI features.

## Stack
- Flutter 3.11.5+, Material 3
- State: `provider` + `ChangeNotifier` ([lib/state/app_state.dart](lib/state/app_state.dart))
- Backend: Supabase ([lib/services/supabase_service.dart](lib/services/supabase_service.dart))
- AI: Gemini-first, Groq + OpenRouter fallback ([lib/services/ai_service.dart](lib/services/ai_service.dart))

## Dev commands
```powershell
flutter pub get
flutter run                  # device / emulator
flutter analyze              # lint
flutter test                 # unit tests
flutter build apk --release
```

## Conventions
- Secrets live in `lib/config.dart` (git-ignored). Template: [lib/config.example.dart](lib/config.example.dart).
- All log writes via [lib/services/app_logger.dart](lib/services/app_logger.dart) (`log.info/debug/warning/error`). Never `print()`.
- Design tokens come from [lib/core/tokens.dart](lib/core/tokens.dart). Read colors via `context.colors.xxx`; never hardcode hex.
- Supabase calls go through `SupabaseService.*` static methods. Don't reach for `Supabase.instance.client` from screens.
- When Supabase keys are absent, the app falls back to mock mode (`AppState._mockAuthed` / `kBusiness`). Preserve this path when editing auth/data flow.
- PII: pass emails through `AppLogger.maskEmail` and tokens through `AppLogger.maskToken` before logging. Never log raw passwords.
- The Supabase schema is **shared with the AscendSME web platform** (`ascendsme-b` repo). Don't propose schema changes from the mobile side — flag them for backend review.
- AI uses a fallback chain: Vertex AI (Firebase) → Groq → OpenRouter. Vertex AI requires Firebase initialization; it's wrapped in try-catch so the app degrades gracefully if Firebase isn't configured. New providers must implement `_ModelAttempt` and be added to the `_models` list in `ai_service.dart`.

## Don't
- Don't bypass the `SupabaseService` wrapper.
- Don't hardcode colors, fonts, or spacing — extend `AppColors` / `AppType` instead.
- Don't commit `lib/config.dart`.
- Don't add a new AI provider without adding it to the `_models` fallback chain in `AIService`.

## Topic docs
- [DESIGN.md](DESIGN.md) — tokens, theming, typography, UI variants
- [TOOLS.md](TOOLS.md) — services, dev commands, configuration
- [SKILLS.md](SKILLS.md) — Claude skills useful in this repo
- [SOUL.md](SOUL.md) — product voice, mission, Ascend AI persona. Consult before writing user-facing copy, error messages, or AI prompts.

## Auto-update
A PostToolUse hook in `.claude/settings.local.json` emits a reminder when files in design / services / skills domains change. When you see that reminder, update the relevant topic doc in the same response.
