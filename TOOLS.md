# Tools & Integrations

## Dev commands

```powershell
flutter pub get                    # install deps
flutter run                        # launch on connected device / emulator
flutter run -d chrome              # web target (limited — Supabase + AI work, native bits don't)
flutter analyze                    # lint (uses flutter_lints)
flutter test                       # run flutter_test suite
flutter build apk --release        # Android release
flutter build appbundle --release  # Play Store bundle
```

## Configuration

Copy [lib/config.example.dart](lib/config.example.dart) → `lib/config.dart` and fill in keys. The real file is git-ignored — never commit it.

| Key                      | Where to get it                          |
| ------------------------ | ---------------------------------------- |
| `groqApiKey`             | https://console.groq.com/keys (fast LPU, generous free tier) |
| `openRouterApiKey`       | https://openrouter.ai/settings/keys (free Llama tier) |
| `supabaseUrl`            | Supabase Dashboard → Settings → API      |
| `supabaseAnonKey`        | Supabase Dashboard → Settings → API      |
| `payLinkBaseUrl`         | Defaults to `https://pay.ascendsme.app/inv/` |

If `supabaseUrl` / `supabaseAnonKey` are blank the app runs in **mock mode** — auth flips a local flag and `AppState.business` falls back to `kBusiness` mock. Preserve this branch when editing auth/data paths.

## Supabase

Client wrapper: [lib/services/supabase_service.dart](lib/services/supabase_service.dart). All DB access goes through static methods on `SupabaseService` — never `Supabase.instance.client` from screens.

Tables touched by the mobile app:
- `businesses` — keyed on `user_id`. Bootstrap row is created by the `handle_new_user` Postgres trigger on signup.
- `receipts` — `total_amount`, `paid_date`, `business_id`. Aggregated in `sumReceipts`.
- `expenses` — `amount_ghs`, `expense_date`, `business_id`. Aggregated in `sumExpenses`.
- `invoices` — full lifecycle (create, mark paid, void, enable pay-link). Status enum: `pending` / `paid` / `overdue` / `void`.

RPCs used:
- `get_next_document_number(p_business_id, p_document_type)` — returns formatted strings like `OPH3F2-INV-0001`.
- Future: `mark_invoice_paid_manual` (atomic receipt+status update — currently two non-atomic writes; see [supabase_service.dart:177](lib/services/supabase_service.dart#L177)).

RLS scopes every row to the signed-in user's businesses, so client-side filtering is by `business_id` only.

Shared with the AscendSME **web platform** — same Supabase project, same schema. Migrations live in the `ascendsme-b` repo (see `20251109132813_create_initial_schema.sql`, `20260122000001_business_document_prefix_and_profile.sql`, `20260514220000_handle_new_user`).

## AI providers

Client: [lib/services/ai_service.dart](lib/services/ai_service.dart). Switch model at runtime via `AppState.setAiModel(AIModel.xxx)`.

| Provider     | Models                                                  | Transport                                      |
| ------------ | ------------------------------------------------------- | ---------------------------------------------- |
| Vertex AI    | `gemini-2.0-flash`, `gemini-2.0-flash-lite`            | `firebase_ai` package (Firebase Auth)          |
| Groq         | `llama-3.3-70b-versatile`, `llama-3.1-8b-instant`      | REST → `https://api.groq.com/openai/v1/chat/completions` |
| OpenRouter   | `meta-llama/llama-3.3-70b-instruct:free`, `llama-3.1-8b-instruct:free`, `openrouter/free` | REST → `https://openrouter.ai/api/v1/chat/completions` |

`AIService.ask()` is the general-purpose entrypoint. `AIService.parseInvoice()` is the specialized JSON extractor used by `new_invoice_sheet`. All providers return `'(AI unavailable — try again in a moment)'` on error — never throw to the UI.

The model fallback chain is defined in the `_models` list at the bottom of `ai_service.dart`. Add/remove/reorder entries freely.

## Auth deep links (Google OAuth + password reset + email confirmation)

The mobile app uses a custom URL scheme `ascendsme://auth-callback` for everything that requires a return-to-app redirect: Google sign-in, password-reset emails, and email confirmation links. The scheme is declared in three places that must stay in sync:

- [lib/config.dart](lib/config.dart) — `AppConfig.oauthRedirectUrl`
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) — `<intent-filter>` with `android:scheme="ascendsme"` and `android:host="auth-callback"`
- [ios/Runner/Info.plist](ios/Runner/Info.plist) — `CFBundleURLTypes` entry with `CFBundleURLSchemes` set to `ascendsme`

`supabase_flutter` captures incoming deep links automatically after `Supabase.initialize()` — no manual `app_links` package required.

### Supabase Dashboard setup (one-time, required for Google OAuth to work)

1. **Auth → URL Configuration** → add `ascendsme://auth-callback` to the **Redirect URLs** allow-list. Without this, Supabase rejects the OAuth redirect.
2. **Auth → Providers → Google** → toggle on. You'll need a Google Cloud OAuth 2.0 Web Client ID + Client Secret (see below).

### Google Cloud Console setup (one-time)

1. Go to https://console.cloud.google.com → APIs & Services → Credentials.
2. Create an **OAuth 2.0 Client ID** of type **Web application**:
   - Authorized redirect URI: `https://orrarzogiobfxsahcaty.supabase.co/auth/v1/callback` (substitute your project's Supabase URL).
3. Copy the Client ID and Client Secret → paste into Supabase Dashboard → Auth → Providers → Google.
4. No Android OAuth Client ID is needed because we go through Supabase's hosted OAuth flow, not the native `google_sign_in` SDK.

### Local testing

Once dashboard setup is done: rebuild the APK (`flutter build apk --release` or `flutter run`). Tap **Sign up / Continue with Google** → system browser opens → sign in with Google → browser auto-redirects to `ascendsme://auth-callback?...` → Android opens the app → `supabase_flutter` exchanges the params for a session → auth stream fires `signedIn` → `_AuthGate` switches to `AppShell`.

If the redirect doesn't open the app, check `adb logcat | findstr ascendsme` for the intent dispatch. The intent-filter must have `android:autoVerify="false"` for custom schemes (HTTPS App Links need `true`).

## Payments

Paystack-hosted pay page is enabled per-invoice by setting `invoices.pay_token` + `online_pay_enabled` via `SupabaseService.enableInvoicePayLink`. The webhook + finalize flow lives on the backend (`finalize_invoice_paystack_payment`); mobile only generates the token and surfaces the share URL (`${payLinkBaseUrl}{token}`).

## Logging

[lib/services/app_logger.dart](lib/services/app_logger.dart) — singleton `log` with `info/debug/warning/error`. File output is attached after `WidgetsFlutterBinding.ensureInitialized()` ([main.dart:77](lib/main.dart#L77)). PII helpers: `AppLogger.maskEmail`, `AppLogger.maskToken`. Never log raw passwords or tokens.

## Dependencies (pubspec.yaml)

Runtime: `provider`, `supabase_flutter`, `google_generative_ai`, `http`, `google_fonts`, `flutter_animate`, `shared_preferences`, `logger`, `path_provider`. Dev: `flutter_test`, `flutter_lints`.
