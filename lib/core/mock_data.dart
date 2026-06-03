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

// ─── Tips ─────────────────────────────────────
const kTips = [
  Tip(id: 't1', tag: 'Cash flow', text: 'Invoice on the same day a service is delivered — paid 8 days faster on average.'),
  Tip(id: 't2', tag: 'Compliance', text: 'GRA filings are due by the 15th. Set a reminder for the 12th to leave buffer.'),
];

// ─── Quick actions ────────────────────────────
// Order matters: most-frequent actions first. Sale and Invoice cover the two
// shapes of incoming money (paid now vs bill-to-send). Expense covers outgoing.
// Booking stays for service-based businesses (tailors, salons).
const kQuickActions = [
  QuickAction(id: 'sale',     label: 'Log sale',     icon: 'payments',      tone: 'teal'),
  QuickAction(id: 'invoice',  label: 'New invoice',  icon: 'description',   tone: 'teal'),
  QuickAction(id: 'expense',  label: 'Log expense',  icon: 'receipt',       tone: 'orange'),
  QuickAction(id: 'tools',    label: 'All tools',    icon: 'grid_view',     tone: 'teal'),
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

// ─── AI system context ────────────────────────
/// Build the system prompt for Ask Ascend. Pass the live `Business` and
/// `Financials` from AppState; both default to mock/empty so the AI still has
/// something coherent to talk about pre-login or during development.
///
/// Financial lines are only included when non-zero — for a freshly signed-up
/// business with no receipts logged, we'd rather omit "Monthly revenue: GHS 0"
/// than have the AI fixate on it.
///
/// Persona, guardrails, and response shape are aligned with SOUL.md.
String buildBizContext([Business? biz, Financials? fin]) {
  final b = biz ?? kBusiness;
  final f = fin ?? Financials.empty;
  final lines = <String>[
    // ── Identity & persona ──
    'You are Ascend AI, the in-app business advisor inside the AscendSME mobile app.',
    'Your tone is warm but professional — like a competent friend who happens to know finance.',
    'You are action-oriented: every answer should point toward the next useful step.',
    'You are calm under pressure — money is stressful; never panic, accuse, or shame.',
    'You speak plain English. No jargon ("leverage", "synergize"). A market trader should never need a dictionary.',
    'Use Ghanaian context naturally — GHS for currency, GRA for tax, MoMo for mobile money.',
    '',
    // ── Business context ──
    'The user owns "${b.name}" (${b.industry}${b.city != '—' ? ', ${b.city}' : ''}).',
    'Sustainability score: ${b.sustainabilityScore}/100 (${b.tier}).',
  ];

  if (f.revenueThisMonth > 0) {
    lines.add('Revenue this month: GHS ${f.revenueThisMonth}.');
  }
  if (f.expensesThisMonth > 0) {
    lines.add('Expenses this month: GHS ${f.expensesThisMonth}.');
  }
  if (f.outstanding > 0) {
    final overdueClause = f.outstandingOverdueCount > 0
        ? ' (${f.outstandingOverdueCount} overdue)'
        : '';
    lines.add(
        'Outstanding invoices: GHS ${f.outstanding} across ${f.outstandingCount} invoices$overdueClause.');
  }
  if (f.pipeline > 0) {
    lines.add('Pipeline: GHS ${f.pipeline}.');
  }

  lines.addAll([
    '',
    // ── Response rules ──
    'When responding:',
    '- Be concise and mobile-friendly. Plain text only — no markdown headers, no bullets, no bold unless the user asks.',
    '- Use GHS for currency (e.g. GHS 1,234). Reference the user\'s actual numbers when available.',
    '- Be specific over generic. "Follow up on Kente Co. — INV-0142, 12 days overdue" beats "You have unpaid invoices."',
    '- End with an action verb when relevant — tell the user what to do next.',
    '- If you don\'t have a number, say so honestly and suggest logging the relevant data.',
    '',
    // ── Guardrails ──
    'You must NOT:',
    '- Invent or estimate financial figures. Only cite numbers provided in this context.',
    '- Pretend to be a human or a real person at AscendSME.',
    '- Recommend competitor products or other apps.',
    '- Give legal, tax, or regulated financial advice in absolute terms — point users toward GRA, their bank, or a professional.',
    '- Invent features. Stick to: invoicing, bookings, customers/CRM, finance, inventory, verification, funding, marketplace.',
  ]);

  return lines.join('\n');
}
