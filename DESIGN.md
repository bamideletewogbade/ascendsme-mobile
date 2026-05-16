# Design System

Single source of truth: [lib/core/tokens.dart](lib/core/tokens.dart). Everything below should match that file — if they drift, the file wins.

## Colors

Brand:
- **Teal** `#00A99D` — primary (`tealDeep #0F8079`, `tealInk #024A45`, `tealSurface #E6F7F6`)
- **Orange** `#FF7A00` — accent (`orangeSurface #FFF1E2`)
- **Amber** `#F5B021` · **Rose** `#E5484D` · **Green** `#1F9D5C` (each has a `*Surface` tint)

Neutrals (light → dark):
- `bg` `#F2F4F6` → `#0A0F11`
- `bgElevated` `#FFFFFF` → `#141B1E`
- `bgInset` `#ECEFF2` → `#1B2326`
- `text` `#0F1418` → `#F1F4F6` (with `textMuted`, `textFaint` for hierarchy)
- `border` `0x14000000` → `0x12FFFFFF` (alpha-channel hairlines)

Dark-mode brand variants are brighter (e.g. `tealDark #3DC9BC`) to maintain WCAG contrast on dark surfaces.

## Accessing tokens

```dart
import '../core/tokens.dart';

final c = context.colors;          // AppColorsX — resolves to light/dark automatically
Container(color: c.tealSurface);
context.isDark;                    // brightness check
```

Never hardcode hex in widgets. Add a new token to `AppColors` + `AppColorsX` first.

## Typography

`AppType` ([lib/core/tokens.dart:103](lib/core/tokens.dart#L103)):
- **Display** — Outfit 600, tight letter-spacing, sizes 32/44/52
- **Heading** — Outfit 600, sizes 13/15/17/18/22/28
- **Body** — Inter 400/600, sizes 11.5/13/15
- **Mono** — JetBrains Mono 500, size 11 (for invoice numbers, IDs, code)
- **Label** — Inter 700, size 10.5, letter-spacing 0.08 (caps-style labels)

`AppTheme.light() / dark()` wires these into `TextTheme` so `Text(…, style: Theme.of(context).textTheme.titleMedium)` works out of the box.

## Elevation

`AppShadows` ([lib/core/tokens.dart:138](lib/core/tokens.dart#L138)):
- `card` — flat surface lift (2px + 14px blur)
- `cardLg` — pronounced card / modal (12px + 40px blur)
- `sheet` — bottom-sheet upward shadow

## Layout primitives

Reusable widgets in [lib/core/widgets/common.dart](lib/core/widgets/common.dart): `AppIcon`, `AppCard`, `AppPill`, `AppBtn`, `AppAvatar`, `BottomNav`, `TierRing`, `StreakChip`. Prefer these over building one-off styled containers.

## UI variants (user-switchable)

Lives on `AppState` ([lib/state/app_state.dart](lib/state/app_state.dart)):
- `HomeLayout` — `score` (sustainability dial), `agenda` (cashflow timeline), `cards` (stacked panels)
- `NavVariant` — `classic` (standard bottom bar), `pill` (floating glass), `fab` (center FAB)
- `darkMode` — explicit toggle (does not auto-follow system yet)

Toggle UI lives in [lib/screens/sheets/profile_drawer.dart](lib/screens/sheets/profile_drawer.dart).

## Page transitions

`CupertinoPageTransitionsBuilder` on both Android and iOS — see [lib/core/tokens.dart:178](lib/core/tokens.dart#L178). Right-edge swipe-back works on both platforms.
