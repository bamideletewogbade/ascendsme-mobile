# AscendSME Mobile — Updates & Changes Report

**Prepared for:** Management Review  
**Date:** May 28, 2026  
**Project:** AscendSME Mobile App (Flutter)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [What Changed & Why](#2-what-changed--why)
3. [Detailed Changes by Area](#3-detailed-changes-by-area)
   - 3.1 [Navigation & App Shell](#31-navigation--app-shell)
   - 3.2 [New Tools Tab](#32-new-tools-tab)
   - 3.3 [Online Shop Screen](#33-online-shop-screen)
   - 3.4 [Design Refresh (Colours & Typography)](#34-design-refresh-colours--typography)
   - 3.5 [New Services (Inventory, HRM, Subscriptions)](#35-new-services-inventory-hrm-subscriptions)
   - 3.6 [AI Service Rewrite](#36-ai-service-rewrite)
   - 3.7 [Home Screen Header Refresh](#37-home-screen-header-refresh)
   - 3.8 [New & Updated Data Models](#38-new--updated-data-models)
3. [Visual Summary (Before vs After)](#4-visual-summary-before-vs-after)
4. [Files Changed — Complete List](#5-files-changed--complete-list)
5. [What This Means for Users](#6-what-this-means-for-users)
6. [What This Means for Development](#7-what-this-means-for-development)
7. [Next Steps & Recommendations](#8-next-steps--recommendations)

---

## 1. Executive Summary

This update represents a **major navigation redesign** and **feature expansion** for the AscendSME mobile app. The key changes are:

| Change | What It Does |
|--------|-------------|
| **Profile tab → Tools tab** | Replaces the old static profile page with a central hub for all business tools |
| **New Shop screen** | Adds an online storefront manager (Products, Orders, Settings) |
| **New Design System** | Refreshes colours from teal/orange to navy/green — cleaner, more professional |
| **3 new back-end services** | Inventory, HRM (staff), and Subscription management |
| **8 new data models** | Customer, InventoryItem, SubscriptionPlan, StaffMember, and more |
| **AI fallback chain** | More reliable AI responses — tries 3 providers automatically |
| **UI polish** | Every screen header now shows the business avatar; home screen greeting is warmer |

> **Bottom line:** The app is now a full-featured business management tool with inventory tracking, staff management, subscription plans, and an online shop — all accessible from a redesigned navigation that puts tools front and centre.

---

## 2. What Changed & Why

### The Problem We Solved

Before these changes, the app had a **Profile tab** that showed only the user's personal details — not very useful for daily business operations. Business tools (invoices, inventory, staff) were scattered and hard to find. The colour scheme used teal, which didn't match the professional brand identity the business wanted.

### Our Approach

We redesigned the navigation around the idea of **"tools first"** — every tab should help the user run their business, not just show static info. We also aligned the mobile app's features with what the web platform already offers, so users have a consistent experience across devices.

---

## 3. Detailed Changes by Area

### 3.1 Navigation & App Shell

**Files affected:** `app_shell.dart`, `common.dart`, `app_state.dart`

#### Before

```
┌──────────────────────┐
│   Bottom Navigation  │
├──────┬──────┬──────┬─┤
│ Home │Finance│Custs.│Profile│
│      │      │      │       │
└──────┴──────┴──────┴───────┘
```

The Profile tab just showed:
- User's name and email
- Business name
- Sign out button

No quick access to actual business tools.

#### After

```
┌──────────────────────┐
│   Bottom Navigation  │
├──────┬──────┬──────┬─┤
│ Home │Finance│Custs.│ Tools │
│      │      │      │       │
└──────┴──────┴──────┴───────┘
```

The Tools tab is a **command centre** containing:

```
┌─────────────────────────────┐
│   👤 Business Identity Card  │ ← Avatar, name, score, industry
├─────────────────────────────┤
│   🏪 Shop Feature Card       │ ← Quick access to Online Shop
├─────────────────────────────┤
│   ┌──────┬──────┐           │
│   │Invoices│Inventory│       │ ← 6 tools in a grid
│   ├──────┼──────┤           │
│   │ Staff │ Bookings│       │
│   ├──────┼──────┤           │
│   │Projects│  Shop  │       │
│   └──────┴──────┘           │
├─────────────────────────────┤
│   📋 Subscription            │ ← Footer links
│   ✅ Verification            │
│   ❓ Help & Support          │
│   🚪 Sign Out               │
└─────────────────────────────┘
```

**Why:** The Profile tab was a dead end for users. The new Tools tab gives instant access to everything a business owner needs — invoices, inventory, staff, shop, and more — all from one screen.

**Also improved:** The business avatar now appears in the header of **every tab** (Home, Finance, Customers, Tools). Tapping it opens the profile drawer from anywhere.

---

### 3.2 New Tools Tab

**New file:** `tools_screen.dart`

This is a brand new screen that replaces the old Profile tab. It's built like a **business dashboard**:

| Section | Content |
|---------|---------|
| **Identity Card** | Business avatar, name, sustainability score, city, industry, verified badge. Settings gear icon in the corner. |
| **Shop Feature Card** | A navy gradient card promoting the Online Shop feature — "Set up storefront" and "Manage products" CTAs. |
| **Tool Grid** | 6 tools in a 2-column grid: Invoicing, Inventory, Staff, Bookings, Projects, Online Shop. Each shows name, description, required subscription tier. |
| **Footer Links** | Subscription plan, Verification & funding, Help & support — each navigates to the relevant screen. |
| **Sign Out** | Bottom logout with a confirmation dialog. |

**Why:** Business owners need a central place to access all their tools. This replaces a static profile with an actionable hub.

---

### 3.3 Online Shop Screen

**New file:** `shop_screen.dart`

This is a **full online storefront manager** with 3 tabs:

```
┌─────────────────────────────┐
│  ← Shop           Draft [🔴]│ ← Store toggle
├─────────────────────────────┤
│  [Products] [Orders] [Settings] │ ← Tab bar
└─────────────────────────────┘
```

#### Products Tab
- **Store Status Card** — Shows if store is Draft or Live, product count, last updated
- **Stats Row** — Products count, total orders, total revenue
- **Product List** — Items from the business's inventory with:
  - Product image (or colour placeholder)
  - Name, price (GHS), stock badge (green for in stock, red for low stock)
  - "Add" button opens a bottom sheet to create new products
  - "View all" links to the full Inventory screen
- **Empty State** — Friendly illustration when no products exist yet

#### Orders Tab
- **Status Chips** — Filter orders: Pending, Processing, Shipped, Delivered
- **Order Cards** — Each order shows:
  - Customer name
  - Order date
  - Item count
  - Amount (GHS)
  - Status badge with appropriate colour
  - Items purchased
- **Order Groups** — Orders are grouped logically

#### Settings Tab
- **Store Details** — Store name, description, storefront URL (e.g., `ascendsme.africa/store/mybusiness`)
- **Payments** — "Not set up" with a "Setup" button (placeholder for Paystack/other integration)
- **Delivery Options** — Placeholder for configuring shipping
- **Storefront Status** — Toggle to enable/disable the store
- **Share Storefront** — Button to share via WhatsApp or copy link to clipboard

**Why:** The web platform already has an online shop feature. Mobile users needed the same capability to manage products and orders on the go.

---

### 3.4 Design Refresh (Colours & Typography)

**File affected:** `tokens.dart`

#### Old Colour Palette

| Colour | Usage |
|--------|-------|
| Teal (`#00A99D`) | Primary brand colour, CTAs |
| Orange (`#FF7A00`) | Accent, warnings |
| Light grey bg | Background surfaces |

#### New Colour Palette

| Colour | Usage |
|--------|-------|
| **Navy** (`#1A2B48`) | **New primary brand** — headings, CTAs, brand elements |
| **Green** (`#2ECC71`) | **New positive/CTAs** — success states, growth indicators |
| Blue (`#3498DB`) | Interactive elements, links |
| Amber (`#F5B021`) | Warnings |
| Rose (`#E5484D`) | Errors, destructive actions |

The old code still has backward-compatible `teal` getters that map to navy — so existing screens automatically use the new colour without needing individual edits.

#### Typography Update
- Added `letterSpacing` as an optional parameter to the label text style
- This fixed a compile error in the Tools screen

**Why:** The old teal palette felt dated. Navy + Green is more professional and aligns with the AscendSME brand identity used on the web platform.

---

### 3.5 New Services (Inventory, HRM, Subscriptions)

Three new service files connect the mobile app to the shared Supabase backend:

#### Inventory Service (`inventory_service.dart`)
- Fetches all products for a business
- Creates new products (name, SKU, category, stock, price, type)
- Updates product stock levels
- Deletes products
- All calls go through `SupabaseService` wrapper (never direct DB access)

#### HRM Service (`hrm_service.dart`)
- Fetches all staff members for a business
- Creates new staff (name, email, phone, role, salary, hire date)
- Toggles staff active/inactive status
- Updates staff details

#### Subscription Service (`subscription_service.dart`)
- Fetches available subscription plans (Free, Lite, Plus, Elite)
- Fetches the business's current subscription info
- Provides pricing data (monthly, quarterly, yearly in GHS)

**Why:** These services mirror what the web platform already does. They give mobile users access to real data instead of mock data, and they all follow the existing pattern of going through `SupabaseService`.

---

### 3.6 AI Service Rewrite

**File affected:** `ai_service.dart`

#### Before
The AI service used Gemini API directly with an API key. If Gemini was down, the user got an error.

#### After
The AI now uses a **fallback chain** of 3 providers:

```
User asks a question
        │
        ▼
┌─────────────────┐
│ 1. Vertex AI     │ ← Firebase AI (Gemini models)
│    (Gemini 2.0   │    Requires Firebase setup
│     Flash)       │    Free GCP quota
└────────┬────────┘
         │ fails → try next
         ▼
┌─────────────────┐
│ 2. Groq          │ ← Llama 3.3 70B (very fast)
│    (llama-3.3    │    Free dev tier
│     -70b)        │
└────────┬────────┘
         │ fails → try next
         ▼
┌─────────────────┐
│ 3. OpenRouter    │ ← Free Llama models
│    (llama-3.3    │    Backup option
│     70b free)    │
└────────┬────────┘
         │ all fail
         ▼
   "AI unavailable
   — try again"
```

Each model attempt is wrapped in proper timeout handling and error logging. The models list is defined at the bottom of the file and can be easily reordered or extended.

**Why:** More reliable AI. If one provider has an outage or rate limit, the next one in the chain is tried automatically. Users see AI responses more consistently.

---

### 3.7 Home Screen Header Refresh

**File affected:** `home_screen.dart`

#### Before
```
┌───────────────────┐
│   Some greeting    │
│                    │
└───────────────────┘
```

A simple, plain header.

#### After
```
┌──────────────────────────────────┐
│  Good afternoon 👋  ✨           │ ← Time-appropriate greeting + sparkle
│  John's Store                     │ ← Business name
│  ★ 85  ·  Accra          ⚙️      │ ← Sustainability score + city
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │ ← Gradient accent bar (navy → green)
└──────────────────────────────────┘
```

**Why:** A warmer, more professional header that shows key business info at a glance. The sustainability score and location are always visible, and the gradient bar adds a premium feel.

---

### 3.8 New & Updated Data Models

**File affected:** `models.dart`

#### New Models

| Model | Purpose | Key Fields |
|-------|---------|------------|
| `Customer` | A business customer | id, fullName, phone, email |
| `InventoryItem` | A tracked product in inventory | id, name, sku, category, currentStock, lowStockThreshold, unitPrice |
| `SubscriptionPlan` | A subscription tier | id, tierCode, tierName, priceMonthly, priceQuarterly, features |
| `SubscriptionInfo` | Business's active subscription | id, businessId, tierId, status, currentPeriodEnd |
| `StaffMember` | An employee | id, businessId, staffName, role, salaryMonthly, isActive |
| `BillingPeriod` | Enum for subscription billing | monthly, quarterly, yearly |

#### Updated Models

| Model | What Changed |
|-------|-------------|
| `Business` | Added 4 pillar scores (scoreF, scoreO, scoreG, scoreC) for sustainability breakdown |
| `InvoiceLineItem` | Now accepts both `{description, amount}` (legacy) and `{description, quantity, price}` (canonical) formats |

#### New Helper Functions

| Function | What It Does |
|----------|-------------|
| `canonicalIndustry()` | Translates mobile dropdown labels ("Food & Beverage") to web's snake_case ("food_catering") |

---

## 4. Visual Summary (Before vs After)

### Navigation Flow Before

```
Launch → Splash → Sign In → Home Tab
                              │
                    ┌─────────┼─────────┬──────────┐
                    ▼         ▼         ▼          ▼
                  Home    Finance  Customers   Profile
                                              (static)
```

### Navigation Flow After

```
Launch → Splash → Sign In → Home Tab
                              │
                    ┌─────────┼─────────┬──────────────┐
                    ▼         ▼         ▼              ▼
                  Home    Finance  Customers       Tools
                                                (hub for all tools)
                                                   │
                                    ┌──────────────┼──────────────────┐
                                    ▼              ▼                  ▼
                               Invoices     Inventory         Online Shop
                               Staff        Bookings           │
                               Projects                    ┌───┼───┐
                                                           ▼   ▼   ▼
                                                      Products Orders Settings
```

**Every tab** now has the business avatar in the header → tapping it opens the profile drawer from anywhere.

---

## 5. Files Changed — Complete List

### New Files Created (9)

| File | What It Does |
|------|-------------|
| `lib/screens/tools_screen.dart` | The new Tools tab (business command centre) |
| `lib/screens/tools/shop_screen.dart` | Online Shop manager (Products, Orders, Settings) |
| `lib/screens/tools/inventory_screen.dart` | Full inventory management screen |
| `lib/screens/tools/staff_screen.dart` | Staff management screen |
| `lib/screens/tools/subscription_screen.dart` | Subscription plans and management |
| `lib/services/inventory_service.dart` | Backend service for product data |
| `lib/services/hrm_service.dart` | Backend service for staff data |
| `lib/services/subscription_service.dart` | Backend service for subscription data |
| `lib/screens/sheets/add_product_sheet.dart` | Bottom sheet to add new products |
| `lib/screens/sheets/add_staff_sheet.dart` | Bottom sheet to add new staff |
| `lib/core/widgets/customer_selector.dart` | Reusable customer picker widget |
| `lib/core/activity.dart` | Activity/feed tracking utilities |
| `lib/core/expense_mapping.dart` | Expense category keyword mapping |

### Existing Files Modified (20+)

| File | What Changed |
|------|-------------|
| `lib/main.dart` | Updated to handle new navigation |
| `lib/state/app_state.dart` | AppTab.profile renamed to AppTab.tools; added loadInventory() |
| `lib/screens/app_shell.dart` | ToolsScreen replaces ProfileScreen; onOpenDrawer passed to all tabs |
| `lib/screens/home_screen.dart` | Refreshed header with greeting, score, gradient bar |
| `lib/screens/finance_screen.dart` | Avatar header with onOpenDrawer support |
| `lib/screens/customers_screen.dart` | Avatar header with onOpenDrawer support |
| `lib/core/tokens.dart` | Navy+Green colour system; letterSpacing in label style |
| `lib/core/widgets/common.dart` | BottomNav updated to "Tools" with grid icon |
| `lib/core/models.dart` | 5 new models, updated Business & InvoiceLineItem |
| `lib/core/mock_data.dart` | Added 'shop' to quick actions; updated app tools list |
| `lib/services/ai_service.dart` | Rewritten with 3-provider fallback chain |
| `lib/services/supabase_service.dart` | Updated for new service patterns |
| `lib/config.example.dart` | Updated config template |
| Multiple screen files | UI polish, new patterns, improved consistency |

### Files Deleted (1)

| File | Why |
|------|-----|
| `lib/screens/profile_screen.dart` | Replaced by `tools_screen.dart` |

---

## 6. What This Means for Users

### ✅ What Users Can Do Now That They Couldn't Before

1. **Manage inventory** — Add, edit, and track product stock levels
2. **Manage staff** — Add employees, set roles and salaries, activate/deactivate
3. **View online shop** — See products, manage orders, configure store settings
4. **Access tools from anywhere** — The Tools tab is available from the bottom nav at all times
5. **Better AI reliability** — If one AI provider fails, the app automatically tries another

### 🎨 What Looks Different

- **Colours** — Navy blue + green instead of teal + orange. Cleaner, more professional
- **Navigation** — "Tools" instead of "Profile". Much more useful
- **Headers** — Business avatar appears on every screen
- **Home screen** — Warmer greeting, sustainability score always visible

### ⚡ What's Faster

- AI responses are more reliable with the fallback chain
- Inventory and staff data load efficiently from Supabase

---

## 7. What This Means for Development

### Architecture Improvements

```
Before:                    After:
┌──────────────┐          ┌──────────────┐
│  Profile Tab │          │   Tools Tab  │
│  (static)    │          │  (dynamic)   │
└──────────────┘          └──────┬───────┘
                                 │
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
          ┌──────────────┐ ┌──────────┐ ┌──────────┐
          │  Screens     │ │ Services │ │  Models  │
          │ (6 tool      │ │ (3 new)  │ │ (5 new)  │
          │  screens)    │ │          │ │          │
          └──────────────┘ └──────────┘ └──────────┘
```

### Code Quality Improvements

- **All service calls go through `SupabaseService`** — No direct DB access from screens
- **Consistent error handling** — All services log through `AppLogger`
- **Backward compatibility** — Old colour getters (teal) map to new colours (navy) automatically
- **Extensible AI chain** — New AI providers can be added by adding one entry to a list

---

## 8. Next Steps & Recommendations

### Short Term (1-2 Weeks)

| Priority | Task | Why |
|----------|------|-----|
| 🔴 High | Test the Shop screen on real devices | Ensure product listing and order display work on various screen sizes |
| 🔴 High | Run `flutter analyze` to fix any remaining warnings | Clean bill of health before release |
| 🟡 Medium | Connect real payment integration (Paystack/Hubtel) in Shop Settings | Currently a placeholder |
| 🟡 Medium | Add real order data instead of mock orders in the Shop screen | Currently shows sample data |

### Medium Term (1-2 Months)

| Priority | Task | Why |
|----------|------|-----|
| 🟡 Medium | Add "Bookings" and "Projects" tool screens | Currently shows "Coming soon" snackbar |
| 🟡 Medium | Add pull-to-refresh to Inventory, Staff, and Subscription screens | Currently only Home has it |
| 🟢 Nice-to-have | Add search/filter to Inventory and Staff lists | Better UX for businesses with lots of data |

### Long Term (3+ Months)

| Priority | Task | Why |
|----------|------|-----|
| 🟢 Nice-to-have | Offline mode for inventory and staff data | Works without internet |
| 🟢 Nice-to-have | Dark mode polish (ensure all new screens look good in dark mode) | Consistency |
| 🟢 Nice-to-have | Analytics — track which tools users open most | Data-driven decisions |

---

## Appendix: Key Design Principles Followed

Throughout these changes, we followed these principles:

1. **Never hardcode colours** — All colours come from `context.colors.xxx` (the tokens system)
2. **All logging goes through `AppLogger`** — No `print()` statements
3. **All Supabase calls go through `SupabaseService`** — No direct DB access
4. **Never commit secrets** — `lib/config.dart` is git-ignored
5. **Backward compatibility** — Old code continues to work (e.g., teal colour getters map to navy)
6. **Consistent with web platform** — Data models and service patterns match the web backend

---

> **Questions about this report?** Contact the development team or refer to the project documentation files:
> - `DESIGN.md` — Design tokens, theming, typography
> - `TOOLS.md` — Services, dev commands, configuration
> - `SKILLS.md` — Developer skills and techniques
> - `SOUL.md` — Product voice and mission
> - `AGENTS.md` — Development conventions and stack info
