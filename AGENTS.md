# AscendSME Mobile

Flutter app — business management for Ghanaian SMEs. Connects to a shared Supabase backend (same project as the web platform) and uses OpenCode / Groq / OpenRouter for AI features.

## Stack
- Flutter 3.11.5+, Material 3
- State: `provider` + `ChangeNotifier` ([lib/state/app_state.dart](lib/state/app_state.dart))
- Backend: Supabase ([lib/services/supabase_service.dart](lib/services/supabase_service.dart))
- AI: OpenCode-first, Groq + OpenRouter fallback ([lib/services/ai_service.dart](lib/services/ai_service.dart))

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
- AI uses a fallback chain: OpenCode Zen (free, first priority) → Groq (fast LPU) → OpenRouter (free models). New providers must implement `_ModelAttempt` and be added to the `_models` list in `ai_service.dart`.

## Don't
- Don't bypass the `SupabaseService` wrapper.
- Don't hardcode colors, fonts, or spacing — extend `AppColors` / `AppType` instead.
- Don't commit `lib/config.dart`.
- Don't add a new AI provider without adding it to the `_models` fallback chain in `AIService`.

## Topic docs
- [DESIGN.md](DESIGN.md) — tokens, theming, typography, UI variants
- [TOOLS.md](TOOLS.md) — services, dev commands, configuration, tool screens, Supabase tables, offline architecture
- [SKILLS.md](SKILLS.md) — Claude skills useful in this repo
- [SOUL.md](SOUL.md) — product voice, mission, Ascend AI persona. Consult before writing user-facing copy, error messages, or AI prompts.

## Home screen architecture

`HomeScreen` in [lib/screens/home_screen.dart](lib/screens/home_screen.dart) — the primary dashboard. Sections in render order:

| Section | File widget | Status | Notes |
|---|---|---|---|
| **Header** — greeting + avatar + notification badge | `_Header` | ✅ | Time-based greeting, tier badge, AVATAR + VERIFIED tag |
| **Cash Flow Hero** — period pills, net cash, sustainability score, rev/expenses, pipeline, outstanding | `_CashFlowHero` | ✅ | Navy gradient card with expandable pipeline breakdown |
| **Quick Tools** — 4-column action grid | `_QuickActions` | ✅ | Proforma → Invoicing → Sale → Expense (pipeline order) |
| **Top Actions** — recommendation cards (up to 3) | `_RecommendationCard` | ✅ | Priority-coded (urgent/high/medium), from `buildRecommendations()` |
| **Recent Activity** — unified activity feed | `_ActivityFeed` | ✅ | Merges invoices, receipts, expenses, proforma events, conversion events |

**Daily Brief removed** — the AI daily brief was removed from the home screen. AI access is via:
- FAB (bottom-right, always visible)
- Ask Ascend tab (tab 4 in nav)
- "Follow up" / "Ask AI" contextual action buttons

## Screen-by-screen review plan (active)

Systematic review of every screen, starting with the home screen. Each phase completes before the next begins.

### ✅ Phase 1: Home screen
- Remove Daily Brief (targets: no AI call on mount, cleaner layout)
- Reorder Quick Tools to pipeline order + fix icons
- Future polish: tier badge, pipeline breakdown animations

### 🔜 Phase 2: Finance + Cash Flow
- FinanceScreen, CashFlowScreen, ExpensesScreen, ReceiptsScreen

### ⬜ Phase 3: Tools tab
- ToolsScreen grid layout, tool listing

### ⬜ Phase 4: Invoices / Quotes / Receipts
- InvoicesScreen (tabs), InvoiceDetailScreen, ReceiptDetailScreen

### ⬜ Phase 5: Profile + Settings + Verification
- ProfileScreen, SettingsScreen, VerifyScreen, VerifyStepScreen

### ⬜ Phase 6: Ask Ascend AI chat
- AskAscendScreen, AskAscendSheet

### ⬜ Phase 7: Remaining tools
- CRM, Inventory, Bookings, Shop, Staff, Project, Documents, Subscriptions

## Auto-update
A PostToolUse hook in `.claude/settings.local.json` emits a reminder when files in design / services / skills domains change. When you see that reminder, update the relevant topic doc in the same response.

When a screen review phase is completed, update this file's "Screen-by-screen review plan" section.
