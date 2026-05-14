import 'models.dart';

// ─── Business profile ────────────────────────
const kBusiness = Business(
  name: 'Akwaaba Threads',
  handle: '@akwaabathreads',
  industry: 'Apparel & Accessories',
  city: 'Accra',
  region: 'Greater Accra',
  tier: 'SME Suite Lite',
  initials: 'AT',
  sustainabilityScore: 72,
  creditScore: 684,
  verified: true,
  monthlyRevenue: 18420,
  monthlyExpenses: 9840,
  outstandingInvoices: 4280,
  pipeline: 12600,
);

// ─── Recommendations ─────────────────────────
const kRecommendations = [
  Recommendation(
    id: 'r1', priority: 'urgent',
    title: "Log this month's expenses to unlock your Bank-Ready Report",
    why: 'We see GHS 18,420 in revenue but no expenses logged for May. Your P&L is incomplete.',
    cta: 'Log Expenses', minutes: 4, impact: '+6 pts',
  ),
  Recommendation(
    id: 'r2', priority: 'high',
    title: 'Follow up on 3 unpaid invoices over GHS 2,000',
    why: 'Two invoices to Kente Co. are 12 days overdue. A polite WhatsApp reminder usually closes 60% of these.',
    cta: 'Send Reminders', minutes: 2, impact: 'GHS 4,280',
  ),
  Recommendation(
    id: 'r3', priority: 'medium',
    title: 'Apply to the Stanbic Women in Business facility',
    why: 'You qualify based on your verified revenue and 18-month operating history.',
    cta: 'Start Application', minutes: 12, impact: 'up to GHS 80,000',
  ),
  Recommendation(
    id: 'r4', priority: 'low',
    title: 'Add 2 more product photos to your public shop',
    why: 'Listings with 4+ photos get 2.3× more orders.',
    cta: 'Open Shop', minutes: 6, impact: '+12% orders',
  ),
];

// ─── Tips ─────────────────────────────────────
const kTips = [
  Tip(id: 't1', tag: 'Cash flow', text: 'Invoice on the same day a service is delivered — paid 8 days faster on average.'),
  Tip(id: 't2', tag: 'Compliance', text: 'GRA filings are due by the 15th. Set a reminder for the 12th to leave buffer.'),
];

// ─── Quick actions ────────────────────────────
const kQuickActions = [
  QuickAction(id: 'invoice',  label: 'New invoice',  icon: 'description',  tone: 'teal'),
  QuickAction(id: 'booking',  label: 'New booking',  icon: 'calendar',     tone: 'orange'),
  QuickAction(id: 'expense',  label: 'Log expense',  icon: 'receipt',      tone: 'neutral'),
  QuickAction(id: 'customer', label: 'Add customer', icon: 'person_add',   tone: 'neutral'),
];

// ─── Tools ───────────────────────────────────
const kTools = [
  AppTool(id: 'invoicing', name: 'Invoicing',   desc: 'Pro-formas, invoices, receipts', icon: 'description',  tier: 'free', tone: 'teal'),
  AppTool(id: 'booking',   name: 'Bookings',    desc: 'Public booking page',            icon: 'calendar',     tier: 'free', tone: 'orange'),
  AppTool(id: 'customers', name: 'Customers',   desc: 'CRM + profiles',                icon: 'people',       tier: 'free', tone: 'teal'),
  AppTool(id: 'finance',   name: 'Finance',     desc: 'Cash flow, P&L, expenses',      icon: 'wallet',       tier: 'lite', tone: 'teal'),
  AppTool(id: 'inventory', name: 'Inventory',   desc: 'Stock, alerts, batches',        icon: 'inventory_2',  tier: 'lite', tone: 'orange'),
  AppTool(id: 'projects',  name: 'Projects',    desc: 'Kanban, milestones',            icon: 'view_kanban',  tier: 'plus', tone: 'teal'),
  AppTool(id: 'hrm',       name: 'People',      desc: 'Payroll, contracts',            icon: 'how_to_reg',   tier: 'plus', tone: 'teal'),
  AppTool(id: 'shop',      name: 'Online shop', desc: 'Listings + checkout',           icon: 'storefront',   tier: 'lite', tone: 'orange'),
];

// ─── Invoices ─────────────────────────────────
const kInvoices = [
  Invoice(id: 'INV-0142', customer: 'Kente Co.',       amount: 2400, status: 'overdue', days: 12, due: 'May 1'),
  Invoice(id: 'INV-0141', customer: 'Adwoa Fashions',  amount: 1880, status: 'sent',    days: 3,  due: 'May 16'),
  Invoice(id: 'INV-0140', customer: 'Yaa Boutique',    amount: 3200, status: 'paid',    days: -2, due: 'May 9'),
  Invoice(id: 'INV-0139', customer: 'Osei & Sons',     amount: 980,  status: 'paid',    days: -5, due: 'May 6'),
  Invoice(id: 'INV-0138', customer: 'Linda Mensah',    amount: 540,  status: 'draft',   days: 0,  due: '—'),
];

// ─── Verification ─────────────────────────────
const kVerificationSteps = [
  VerificationStep(id: 'v1', label: 'Business registration', status: 'verified', detail: 'RGD certificate'),
  VerificationStep(id: 'v2', label: 'Tax identification',    status: 'verified', detail: 'GRA TIN'),
  VerificationStep(id: 'v3', label: 'Bank account',          status: 'verified', detail: 'Stanbic •• 4421'),
  VerificationStep(id: 'v4', label: 'Operating address',     status: 'pending',  detail: 'Awaiting GPS confirmation'),
  VerificationStep(id: 'v5', label: 'Director ID',           status: 'todo',     detail: 'Upload Ghana Card'),
  VerificationStep(id: 'v6', label: '6 months of revenue',   status: 'todo',     detail: 'Connect MoMo or bank'),
];

// ─── Funding ──────────────────────────────────
const kFundingStages = [
  FundingStage(id: 'f1', label: 'Diagnostic',          status: 'done',   detail: 'Completed Apr 3'),
  FundingStage(id: 'f2', label: 'Bank-ready report',   status: 'active', detail: '4 of 7 items complete'),
  FundingStage(id: 'f3', label: 'Lender matching',     status: 'todo',   detail: '5 lenders ready to review'),
  FundingStage(id: 'f4', label: 'Application',         status: 'todo',   detail: ''),
  FundingStage(id: 'f5', label: 'Disbursement',        status: 'todo',   detail: ''),
];

const kLenders = [
  Lender(id: 'l1', name: 'Stanbic Bank',  product: 'Women in Business',    max: 80000, rate: '18%', match: 92),
  Lender(id: 'l2', name: 'Fidelity Bank', product: 'Orange SME',           max: 50000, rate: '20%', match: 81),
  Lender(id: 'l3', name: 'Letshego',      product: 'Quick Working Capital', max: 25000, rate: '24%', match: 76),
];

// ─── Marketplace ──────────────────────────────
const kMarketplaceCategories = [
  MarketplaceCategory(id: 'm1', name: 'Accounting & Tax', count: 38, icon: 'calculate'),
  MarketplaceCategory(id: 'm2', name: 'Web & Branding',   count: 52, icon: 'palette'),
  MarketplaceCategory(id: 'm3', name: 'Logistics',        count: 27, icon: 'local_shipping'),
  MarketplaceCategory(id: 'm4', name: 'Legal',            count: 19, icon: 'balance'),
  MarketplaceCategory(id: 'm5', name: 'Marketing',        count: 64, icon: 'campaign'),
  MarketplaceCategory(id: 'm6', name: 'Photography',      count: 31, icon: 'camera_alt'),
];

const kMarketplaceFeatured = [
  MarketplaceProvider(id: 'sp1', name: 'Nimo & Co. Accountants', rating: 4.9, reviews: 142, tag: 'GRA-certified', from: 350, category: 'Accounting & Tax'),
  MarketplaceProvider(id: 'sp2', name: 'Bloom Visuals',           rating: 4.8, reviews: 86,  tag: 'Verified',     from: 800, category: 'Photography'),
  MarketplaceProvider(id: 'sp3', name: 'Adinkra Web Studio',      rating: 4.7, reviews: 53,  tag: 'Top Rated',    from: 1200, category: 'Web & Branding'),
];

// ─── Activity feed ────────────────────────────
const kActivity = [
  ActivityItem(id: 'a1', time: '14m', text: 'Yaa Boutique paid INV-0140 — GHS 3,200',     kind: 'payment'),
  ActivityItem(id: 'a2', time: '2h',  text: 'Inventory alert: Kente skirt (size M) low',  kind: 'alert'),
  ActivityItem(id: 'a3', time: '5h',  text: 'New booking from Linda Mensah — Sat 11:00',  kind: 'booking'),
  ActivityItem(id: 'a4', time: '1d',  text: 'AM Kojo verified your Stanbic statement',    kind: 'verify'),
];

// ─── Initial quests ───────────────────────────
const kInitialQuests = [
  Quest(id: 'q1', title: "Log this week's expenses", detail: 'Unblocks Bank-Ready report', pts: 4, action: 'expense'),
  Quest(id: 'q2', title: 'Follow up on Kente Co.',   detail: 'INV-0142 · 12 days overdue', pts: 3, action: 'followup'),
  Quest(id: 'q3', title: 'Send 1 invoice',           detail: "Builds your monthly P&L",    pts: 2, action: 'newInvoice'),
];

// ─── AI system context ────────────────────────
String buildBizContext() => '''You are Ascend AI, an in-app advisor inside the AscendSME mobile app for Ghanaian SMEs.
The user is Adwoa Mensah, owner of "${kBusiness.name}" (${kBusiness.industry}, ${kBusiness.city}).
Sustainability score: ${kBusiness.sustainabilityScore}/100 (${kBusiness.tier}).
Monthly revenue (May to date): GHS ${kBusiness.monthlyRevenue.toString()}.
Monthly expenses: GHS ${kBusiness.monthlyExpenses.toString()}.
Outstanding invoices: GHS ${kBusiness.outstandingInvoices.toString()} (3 invoices, 1 overdue 12 days).
Pipeline: GHS ${kBusiness.pipeline.toString()}.
Top recommendations: Log May expenses · Follow up on 3 unpaid invoices · Apply to Stanbic Women in Business (up to GHS 80,000).

When responding:
- Be concise. Mobile-friendly. Plain English. No markdown headers or bullets unless asked.
- Use GHS for currency. Reference the user's actual numbers.
- Friendly, action-oriented, like a smart business coach.
- Never invent features. Stick to: invoicing, bookings, customers/CRM, finance, inventory, verification, funding, marketplace.''';
