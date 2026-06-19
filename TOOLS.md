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
| `opencodeApiKey`         | https://opencode.ai/zen (Nemotron 3 Ultra + DeepSeek V4 Flash, free tier) |
| `groqApiKey`             | https://console.groq.com/keys (fast LPU, generous free tier) |
| `openRouterApiKey`       | https://openrouter.ai/settings/keys (free Llama tier) |
| `supabaseUrl`            | Supabase Dashboard → Settings → API      |
| `supabaseAnonKey`        | Supabase Dashboard → Settings → API      |
| `payLinkBaseUrl`         | Defaults to `https://pay.ascendsme.app/inv/` |

If `supabaseUrl` / `supabaseAnonKey` are blank the app runs in **mock mode** — auth flips a local flag and `AppState.business` falls back to `kBusiness` mock. Preserve this branch when editing auth/data paths.

## Services layer

All services live in [lib/services/](lib/services/). The service wrapper pattern (`SupabaseService.*` static methods) applies to all data access — never `Supabase.instance.client` from screens.

| Service | File | Purpose | Supabase Tables Touched |
|---|---|---|---|
| **SupabaseService** | `supabase_service.dart` | Core DB wrapper — auth, profile, invoices, receipts, expenses, customers, documents, orders, reservations | `users`, `businesses`, `receipts`, `expenses`, `invoices`, `customers`, `recurring_invoice_templates`, `shop_orders`, `shop_order_items`, `business_documents`, `support_requests`, `payment_transactions`, `inventory_reservations` |
| **AIService** | `ai_service.dart` | AI chat — fallback chain (OpenCode → Groq → OpenRouter). Entrypoints: `ask()`, `parseInvoice()` | — |
| **AppLogger** | `app_logger.dart` | Singleton `log` with `info/debug/warning/error`. File output, PII masking (`maskEmail`, `maskToken`) | — |
| **CacheService** | `cache_service.dart` | SharedPreferences-backed offline cache per domain. Used by every data loader in AppState | — |
| **SyncService** | `sync_service.dart` | Offline mutation queue — persists to SharedPrefs, replays on connectivity restore | — |
| **ConnectivityService** | `connectivity_service.dart` | Network status detection via `connectivity_plus` | — |
| **InventoryService** | `inventory_service.dart` | Product CRUD + stock management | `user_products` |
| **BookingService** | `booking_service.dart` | Booking/appointment CRUD + service management | `booking_services`, `bookings` |
| **HrmService** | `hrm_service.dart` | Staff CRUD, delegation index calculation | `staff_members`, `users` |
| **CrmService** | `crm_service.dart` | CRM profile management, tags, interactions, groups, smart segments via Postgres functions | `crm_profiles`, `crm_interactions`, `crm_tags`, `customer_groups`, `customer_group_members` |
| **CashFlowService** | `cash_flow_service.dart` | 30-day cash flow forecast engine | — (reads via SupabaseService) |
| **ProjectService** | `project_service.dart` | Project milestones, tasks CRUD, milestone advancement | `project_milestones`, `project_tasks` |
| **PayrollService** | `payroll_service.dart` | Payroll run creation, processing to finance | `payroll_runs`, `staff_payments` |
| **SubscriptionService** | `subscription_service.dart` | Subscription tier CRUD, current subscription info | `subscription_plans`, `business_subscriptions` |
| **OrderService** | `order_service.dart` | Shop order status updates | `shop_orders` |
| **PaymentService** | `payment_service.dart` | Paystack payment charge flow | `payment_transactions` |
| **DocumentService** | `document_service.dart` | Business document upload + file picker + Supabase Storage | `business_documents` + `verification-documents` bucket |
| **InvoicePdfService** | `invoice_pdf_service.dart` | PDF invoice generation + preview + share | — |
| **AppRouterObserver** | `app_router_observer.dart` | Navigator observer for page transition logging | — |

## Supabase

Client wrapper: [lib/services/supabase_service.dart](lib/services/supabase_service.dart).

### Tables

**Core platform (shared with web):**
- `businesses` — keyed on `user_id`. Bootstrap row created by `handle_new_user` Postgres trigger on signup, or by the client-side `ensureProfileBootstrapped()` fallback.
- `users` — user profiles (email, phone, full_name, user_type)
- `receipts` — `total_amount`, `paid_date`, `business_id`. Invoice payments + direct sales.
- `expenses` — `amount_ghs`, `expense_date`, `business_id`. With `mapped_category`, `sustainability_tagged`, `attachment_url`.
- `invoices` — full lifecycle (create, mark paid, void, enable pay-link). Status enum: `pending` / `paid` / `overdue` / `void` / `proforma`.
- `customers` — `full_name`, `phone`, `email`. Unique constraint on `(business_id, full_name)`.

**Modules (mobile + web):**
- `recurring_invoice_templates` — `frequency`, `day_of_month`, `next_invoice_date`, `is_active`
- `shop_orders` + `shop_order_items` — online storefront orders
- `shops` — business storefront (name, slug, is_published, is_marketplace_listed)
- `user_products` — inventory items with `current_stock`, `low_stock_threshold`, `unit_price`
- `inventory_reservations` — hard reservations linked to invoices/bookings/shop_orders
- `project_milestones` + `project_tasks` — project management
- `payroll_runs` + `staff_payments` — payroll processing
- `staff_members` — HRM roster
- `booking_services` + `bookings` — appointment scheduling
- `crm_profiles` + `crm_interactions` + `crm_tags` + `customer_groups` + `customer_group_members` — CRM
- `business_documents` — verification documents with Supabase Storage links
- `support_requests` — AI chat support ticket logging
- `payment_transactions` — payment records
- `subscription_plans` + `business_subscriptions` — tiered billing

### RPCs (Postgres functions)

| RPC | Purpose |
|---|---|
| `get_next_document_number(p_business_id, p_document_type)` | Returns formatted strings like `OPH3F2-INV-0001` |
| `generate_invoice_from_recurring_template(p_template_id)` | Generates an invoice from a recurring template, updates `next_invoice_date` |

### Storage buckets

| Bucket | Purpose |
|---|---|
| `verification-documents` | Business verification document uploads (TIN cert, registration, utility bill, etc.) |
| `receipt-images` / `expense-receipts` | Expense receipt photo uploads |

## AI providers

Client: [lib/services/ai_service.dart](lib/services/ai_service.dart). Switch model at runtime via `AppState.setAiModel(AIModel.xxx)` (not implemented — future).

The model fallback chain is defined in the `_models` list at the bottom of `ai_service.dart`. Add/remove/reorder entries freely.

| Provider | Models | Transport | Config key |
|---|---|---|---|
| **OpenCode Zen** | `opencode/nemotron-3-ultra-free`, `opencode/deepseek-v4-flash-free` | REST → `https://opencode.ai/zen/v1/chat/completions` | `opencodeApiKey` |
| **Groq** | `llama-3.3-70b-versatile`, `llama-3.1-8b-instant` | REST → `https://api.groq.com/openai/v1/chat/completions` | `groqApiKey` |
| **OpenRouter** | `meta-llama/llama-3.3-70b-instruct:free`, `meta-llama/llama-3.1-8b-instruct:free`, `openrouter/free` | REST → `https://openrouter.ai/api/v1/chat/completions` | `openRouterApiKey` |

**Fallback chain order:** OpenCode (free) → Groq (fast, free dev tier) → OpenRouter (free models). Providers with empty API keys are skipped.

`AIService.ask()` is the general-purpose entrypoint. `AIService.parseInvoice()` is the specialized JSON extractor used by `new_invoice_sheet`. All providers return `'(AI unavailable — try again in a moment)'` on error — never throw to the UI.

## Offline architecture

The app has a complete offline-first data architecture:

1. **ConnectivityService** (`connectivity_plus`) — monitors network status, exposes `isOnline` flag
2. **CacheService** — per-domain SharedPreferences-backed cache (invoices, receipts, expenses, inventory, staff, customers, recurring, projects, payroll, shop)
3. **Two-phase loading** — every `load*()` method in AppState:
   - Phase 1: restore from local cache (instant — no network)
   - Phase 2: fetch fresh from Supabase (silent refresh if cache was available)
4. **SyncService** — when offline, mutations are queued as `PendingMutation` objects in SharedPrefs. When connectivity returns, they're replayed in order.
5. **Mutation queue:** supports `create` for expenses, receipts, and invoices + `mark_paid` for invoices
6. **Offline banner** — shown in AppShell when offline, with sync status indicators

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

| Package | Version | Purpose |
|---|---|---|
| `flutter` | sdk | Core framework |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |
| `google_fonts` | ^6.2.1 | Outfit + Inter + JetBrains Mono |
| `provider` | ^6.1.2 | State management |
| `http` | ^1.2.2 | AI provider REST calls |
| `flutter_animate` | ^4.5.0 | Animations (FadeInSlide, etc.) |
| `shared_preferences` | ^2.4.0 | Local cache + sync queue persistence |
| `supabase_flutter` | ^2.8.4 | Backend DB + Auth + Realtime + Storage |
| `logger` | ^2.4.0 | Structured logging |
| `path_provider` | ^2.1.4 | Log file paths |
| `connectivity_plus` | ^6.1.0 | Network status detection |
| `pdf` | ^3.11.0 | Invoice PDF generation |
| `share_plus` | ^10.0.0 | PDF sharing |
| `printing` | ^5.13.0 | PDF preview |
| `file_picker` | ^8.1.6 | Document upload (image, PDF selection) |

## Tool screens

The [Tools tab](lib/screens/tools_screen.dart) lists 9 tools with plan-based availability:

| Tool | Screen | Plan Tier | Status |
|---|---|---|---|
| Invoicing | `invoices_screen.dart` + `invoice_detail_screen.dart` | Free | ✅ Full CRUD, pay links, PDF, mark paid, reminders |
| Booking Portal | `booking_screen.dart` | Free | ✅ Full CRUD, services management, WhatsApp reminders |
| Document Vault | `documents_screen.dart` | Lite | ✅ Upload, categorize, delete, Supabase Storage |
| My Shop | `shop_screen.dart` | Lite | ✅ Products, orders, storefront toggle, settings |
| CRM | `crm_screen.dart` + `customers_screen.dart` + `customer_detail_screen.dart` | Free | ✅ Smart segments, tags, interactions, groups, CLV, churn |
| Finance & Accounting | `finance_screen.dart` + `cash_flow_screen.dart` + `expenses_screen.dart` + `receipts_screen.dart` | Free | ✅ Transactions, insights, forecast, reports, P&L |
| Inventory | `inventory_screen.dart` | Lite | ✅ Full CRUD, restock, adjust, low-stock alerts, bulk import |
| Project Management | `project_screen.dart` | Plus | ✅ Milestones, tasks, staff assignment, status cycling |
| HRM & Staff | `staff_screen.dart` | Plus | ✅ Team roster, payroll history, delegation index, payroll processing |

**Additional screens (reachable from other paths):**
- [recurring_invoices_screen.dart](lib/screens/tools/recurring_invoices_screen.dart) — Recurring invoice templates (create, pause/resume, generate, delete, MRR breakdown chart)
- [activity_screen.dart](lib/screens/tools/activity_screen.dart) — Full unified activity feed with filters and date range
- [subscription_screen.dart](lib/screens/tools/subscription_screen.dart) — Tier comparison, upgrade/downgrade, cancel, Paystack integration
- [receipt_detail_screen.dart](lib/screens/tools/receipt_detail_screen.dart) — Receipt detail with line items, payment info, related invoice

**Bottom sheets:**
- `new_invoice_sheet.dart` — AI-assisted invoice creation
- `log_expense_sheet.dart` + built-in `EditExpenseSheet` — Expense logging/editing
- `log_sale_sheet.dart` — Quick sale logging
- `add_product_sheet.dart` + `bulk_import_sheet.dart` — Inventory management
- `add_staff_sheet.dart` — Staff creation/editing
- `create_booking_sheet.dart` + `create_booking_service_sheet.dart` — Booking management
- `new_recurring_sheet.dart` — Recurring template creation
- `edit_proforma_sheet.dart` — Proforma quote editing
- `forgot_password_sheet.dart` — Password reset
- `ask_ascend_sheet.dart` — AI chat assistant
- `notifications_sheet.dart` — Notification list
- `profile_drawer.dart` — Side drawer with settings, nav variant, dark mode

## Verification / KYB flow

The [verify_screen.dart](lib/screens/verify_screen.dart) and [verify_step_screen.dart](lib/screens/verify_step_screen.dart) implement a multi-step business verification flow:

- **Step-based wizard** — each step covers a document category (TIN cert, business registration, utility bill, proof of address, etc.)
- **Document upload** — uses `file_picker` → uploads to Supabase Storage `verification-documents` bucket → creates `business_documents` record
- **Status tracking** — each document links to a `verification_task_id`

## Core modules

| File | Purpose |
|---|---|
| `lib/core/activity.dart` | Activity feed builder — merges invoices, receipts, expenses into unified timeline. Dedup logic (invoice-paid receipts skip duplicate). |
| `lib/core/expense_mapping.dart` | Expense keyword detection — mirrors web exactly. Promotes "Other" → specific category, auto-tags sustainability, sets mapped_category for scoring. |
| `lib/core/finance_utils.dart` | Ghana VAT/NHIL/GETFund/Tourism levy breakdown calculation (combined rate 21%). |
| `lib/core/recommendations.dart` | Dynamic recommendation engine — replaces hardcoded `kRecommendations` list. Generates urgent/high/medium recs from real business state. |
| `lib/core/widgets/` | Reusable UI components: `common.dart` (AppIcon, AppCard, AppPill, AppBtn, AppAvatar, BottomNav, TierRing, etc.), `customer_selector.dart`, `inventory_selector.dart` |

## Navigation architecture

```
AppShell (IndexedStack)
├── HomeScreen (tab 0)
│   ├── Cash flow hero with period pills (1M/3M/6M/YTD)
│   ├── Quick actions (invoicing, sale, expense, more)
│   ├── Recommendations cards
│   ├── Daily brief (AI-powered)
│   ├── Activity feed (last 6 events)
│   └── → ActivityScreen (full feed)
├── CashFlowForecastScreen (tab 1)
│   ├── 30-day forecast hero
│   ├── Mini chart (custom paint)
│   ├── Breakdown (current cash, receivables, costs)
│   └── Recommendations + overdue invoices
├── ToolsScreen (tab 2)
│   ├── Identity card + plan banner + search
│   └── 9 tool tiles → navigates to each tool screen
├── ProfileScreen (tab 3)
│   └── Settings, verification, subscription, help
└── AskAscendScreen (tab 4)
    └── AI chat assistant

FAB (floating action button) → AskAscendScreen
ProfileDrawer → side drawer (settings, dark mode, nav variant, sign out)
```

## Tool navigation flows

Each tool screen is pushed via `Navigator.push`, with a shared `SubScreenHeader` for back navigation. Bottom sheets are used for CRUD operations (create, edit, delete) throughout.

**Key navigation patterns:**
- Tools list → Navigator.push → ToolScreen
- ToolScreen → showModalBottomSheet → Create/Edit form
- ToolScreen → Navigator.push → Detail screen
- Detail screen → showModalBottomSheet → Actions (mark paid, void, delete, etc.)
