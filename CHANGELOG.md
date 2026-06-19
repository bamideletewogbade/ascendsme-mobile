# AscendSME Mobile — Changelog

> *How to read this: Each section describes what changed from a business/user perspective, not a technical one. Share the PDF with anyone on your team.*

---

## Unreleased

### CRM — Customer interaction logging

**What changed:**
- When you create a booking for a customer, it is now automatically logged in their CRM interaction history so you can see all touchpoints in one place.
- When you update a booking status (confirm, fulfil, or cancel), the CRM log is updated automatically.
- When a shop order status changes (confirmed, shipped, delivered, cancelled), the CRM log captures it too.
- The customer detail screen now groups interactions by time period (Today, Yesterday, This Week, This Month, Older) making it easier to see recent activity at a glance.
- New quick-action buttons on the CRM dashboard let you log a Call, WhatsApp, Email, Meeting, or Note without navigating into a customer's profile.

**How to test:**
1. Go to **CRM** tab → tap any customer → scroll to **Activity log**
2. Verify interactions are grouped into Today / Yesterday / This Week / This Month / Older sections
3. Go to **Bookings** → create a new booking → go back to the customer's CRM profile → verify a "Booking" entry appears
4. Change a booking status (e.g. confirm it) → verify a system interaction is logged
5. Go to **Shop** → change an order status → verify CRM interaction is logged
6. In CRM dashboard → tap a customer row → tap **Log** → try Call, WhatsApp, Email, Meeting, and Note buttons → verify interactions appear in the activity log

---

### Subscription Screen — Aligned with web platform

**What changed:**
- The Plus plan now shows a **"Most Popular"** badge with a teal highlight so users know which tier is recommended.
- If a paid subscription expires, an amber banner appears at the top of the subscription screen with a renewal prompt.
- Billing period toggles now show dynamic savings: "Save ~10%" for quarterly, "Save up to 17%" for yearly.
- Each plan card now shows exactly how much you save compared to monthly billing (e.g. "Save GHS 450 vs monthly").
- For quarterly and yearly plans, the per-month equivalent is shown below the total price.
- Buttons are clearer: "Subscribe Now" for new subscriptions, "Current Plan" (disabled) for the active tier, "Free Forever" for the free plan.
- Free tier now displays as "GHS 0 Forever" instead of just "Free" for clarity.

**How to test:**
1. Go to **Profile** → **Subscription** 
2. Verify the Plus/SME Suite Plus card has a "Most Popular" badge with teal border accent
3. Tap **Quarterly** toggle → verify "Save ~10%" badge appears
4. Tap **Yearly** toggle → verify "Save up to 17%" badge appears
5. On a paid plan card with Quarterly selected → verify "Save GHS X vs monthly" is shown
6. On the Free plan card → verify it says "GHS 0 Forever"
7. If you have an expired subscription → verify the amber banner appears at the top

---

### Home Screen & Cash Flow — Dashboard refinements

**What changed:**
- The Cash Flow Hero card now uses the correct sustainability credit score range (300–850 scale) matching the web platform.
- The activity feed now includes proforma quote events: when a quote is created, expires, or is converted to an invoice, it shows up in the timeline.
- Quick Tools are now ordered by pipeline flow: Proforma → Invoicing → Sale → Expense.

**How to test:**
1. Go to **Home** → check the **Cash Flow Hero** card loads correctly
2. Scroll to **Recent Activity** → create a proforma quote from Invoicing → verify "Proforma for X created" appears
3. Convert a proforma to an invoice → verify "Proforma for X converted" appears
4. Verify the Quick Tools row shows: Proforma → Invoicing → Sale → Expense

---

### AI Service — Updated provider chain

**What changed:**
- The AI chat now uses **OpenCode Zen** as the first-priority provider (free, fast) before falling back to Groq and OpenRouter.
- New configuration key `opencodeApiKey` added to config — sign up at opencode.ai/zen for free access.

**How to test:**
1. Open **Ask Ascend** (FAB or tab 4)
2. Send a business question → verify you get a response
3. The model chain is automatic — no user action needed

---

### Business Model — Credit score alignment

**What changed:**
- The sustainability credit score now uses the 300–850 scale (matching the web platform's formula).
- Score tiers: Foundation (300–449), Growth (450–649), Verified (650–850).
- The `Business.creditScore` getter computes the score from four pillar values (Financial Integrity, Compliance, Operational Velocity, Governance Stability) when not pre-computed.

**How to test:**
1. Go to **Home** → verify the sustainability score displays correctly
2. Go to **Verification** → check score tier badge matches the correct range

---

### Core & Services — Data layer improvements

**What changed:**
- New `Business.logoUrl` field for displaying business logos from Supabase Storage.
- Bookings, shop orders, and invoice detail screens now log CRM interactions automatically.
- The activity feed now merges proforma events and conversion events into the timeline.

**How to test:**
- All underlying — no direct UI test. Covered by the CRM and Home Screen tests above.

---

### Previous Release — Upgrade & Downgrade

- Paystack payment flow integrated for subscription upgrades.
- Offline mutation queue for invoices, expenses, and receipts (create + mark paid).
- Two-phase caching for all data domains (instant load from cache, silent network refresh).
- Cash flow 30-day forecast with at-risk detection.
- Booking portal with WhatsApp reminders.
- CRM with smart segments, tags, groups, and CLV tracking.
- Invoice PDF generation and sharing.
- Document vault with Supabase Storage uploads.
- Verification/KYB step wizard.
- Recurring invoice templates with MRR breakdown.
- Shop management with online storefront toggle.
- Project management with milestone tracking.
- Payroll processing with delegation index.
