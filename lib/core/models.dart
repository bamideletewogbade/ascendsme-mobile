// All data models for AscendSME Mobile

class Business {
  /// Backend row id (`businesses.id`). Null on the mock fallback (kBusiness)
  /// since no real row backs it.
  final String? id;
  final String name, handle, industry, city, region, tier, initials;
  final int sustainabilityScore, creditScore;
  final bool verified;
  // Four-pillar breakdown that feeds sustainability_score. Each 0-100. See
  // ascendsme-b's score engine + the audit table — F=Financial Integrity
  // (30%), C=Compliance (30%), O=Operational Velocity (25%), G=Governance
  // Stability (15%). Mobile reads them so the Verify screen can show users
  // *why* their score is where it is, not just the aggregate number.
  final int scoreF, scoreO, scoreG, scoreC;
  // Financial roll-ups are NOT stored on businesses in the backend — they're
  // computed by AppState from invoices/expenses/receipts. These fields are
  // kept here for backward compatibility with buildBizContext() and default
  // to 0; for real numbers, read AppState.financials instead.
  final int monthlyRevenue, monthlyExpenses, outstandingInvoices, pipeline;

  const Business({
    this.id,
    required this.name,
    required this.handle,
    required this.industry,
    required this.city,
    required this.region,
    required this.tier,
    required this.initials,
    required this.sustainabilityScore,
    required this.creditScore,
    required this.verified,
    required this.monthlyRevenue,
    required this.monthlyExpenses,
    required this.outstandingInvoices,
    required this.pipeline,
    this.scoreF = 0,
    this.scoreO = 0,
    this.scoreG = 0,
    this.scoreC = 0,
  });

  /// Build a Business from a row returned by `SupabaseService.fetchProfile()`.
  /// Maps backend column names (user_id, business_name, business_handle,
  /// subscription_tier, verification_status, …) onto the mobile model.
  /// Financial fields default to 0; read `AppState.financials` for real
  /// numbers aggregated from invoices/expenses/receipts.
  factory Business.fromRow(Map<String, dynamic> row) {
    final rawName = (row['business_name'] as String?)?.trim();
    final name = (rawName == null || rawName.isEmpty) ? 'Your business' : rawName;
    final rawHandle = (row['business_handle'] as String?)?.trim();
    final handle = (rawHandle == null || rawHandle.isEmpty)
        ? '@${_slugify(name)}'
        : '@$rawHandle';
    return Business(
      id: row['id'] as String?,
      name: name,
      handle: handle,
      industry: _displayIndustry(row['industry'] as String?),
      city: (row['city'] as String?)?.trim().isNotEmpty == true
          ? row['city'] as String
          : '—',
      region: (row['region'] as String?)?.trim().isNotEmpty == true
          ? row['region'] as String
          : '—',
      tier: _displaySubscriptionTier(row['subscription_tier'] as String?),
      initials: _extractInitials(name),
      sustainabilityScore: (row['sustainability_score'] as num?)?.toInt() ?? 0,
      creditScore: (row['credit_score'] as num?)?.toInt() ?? 0,
      verified: _isVerified(row),
      monthlyRevenue: 0,
      monthlyExpenses: 0,
      outstandingInvoices: 0,
      pipeline: 0,
      scoreF: (row['score_f'] as num?)?.toInt() ?? 0,
      scoreO: (row['score_o'] as num?)?.toInt() ?? 0,
      scoreG: (row['score_g'] as num?)?.toInt() ?? 0,
      scoreC: (row['score_c'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Financials — month-to-date roll-up aggregated by AppState ────────────────

/// Month-to-date financial snapshot, computed by AppState from
/// receipts (realized revenue), expenses, and open invoices.
///
/// Receipts vs invoices distinction is intentional (PRD F-04.B):
///   - revenue counts only `receipts.total_amount` for payments actually
///     received this month — never invoices (which double-count if both
///     pending AND paid lifecycle entries are summed).
///   - outstanding counts `invoices.total_amount` where status != 'paid'.
class Financials {
  final int revenueThisMonth;
  final int expensesThisMonth;
  final int outstanding;
  final int outstandingCount;
  final int outstandingOverdueCount;
  final int pipeline; // proforma quotes; not wired yet — see loadFinancials()
  final double? revenueChangePctVsLastMonth;
  final double? expensesChangePctVsLastMonth;

  const Financials({
    required this.revenueThisMonth,
    required this.expensesThisMonth,
    required this.outstanding,
    required this.outstandingCount,
    required this.outstandingOverdueCount,
    required this.pipeline,
    this.revenueChangePctVsLastMonth,
    this.expensesChangePctVsLastMonth,
  });

  static const empty = Financials(
    revenueThisMonth: 0,
    expensesThisMonth: 0,
    outstanding: 0,
    outstandingCount: 0,
    outstandingOverdueCount: 0,
    pipeline: 0,
    revenueChangePctVsLastMonth: null,
    expensesChangePctVsLastMonth: null,
  );

  bool get isEmpty =>
      revenueThisMonth == 0 &&
      expensesThisMonth == 0 &&
      outstanding == 0 &&
      pipeline == 0;

  /// Serialize to a JSON-compatible map for local caching (SharedPreferences).
  Map<String, dynamic> toMap() => {
        'revenueThisMonth': revenueThisMonth,
        'expensesThisMonth': expensesThisMonth,
        'outstanding': outstanding,
        'outstandingCount': outstandingCount,
        'outstandingOverdueCount': outstandingOverdueCount,
        'pipeline': pipeline,
        if (revenueChangePctVsLastMonth != null)
          'revenueChangePctVsLastMonth': revenueChangePctVsLastMonth,
        if (expensesChangePctVsLastMonth != null)
          'expensesChangePctVsLastMonth': expensesChangePctVsLastMonth,
      };

  /// Restore from a map previously produced by [toMap].
  factory Financials.fromMap(Map<String, dynamic> map) => Financials(
        revenueThisMonth: map['revenueThisMonth'] as int? ?? 0,
        expensesThisMonth: map['expensesThisMonth'] as int? ?? 0,
        outstanding: map['outstanding'] as int? ?? 0,
        outstandingCount: map['outstandingCount'] as int? ?? 0,
        outstandingOverdueCount:
            map['outstandingOverdueCount'] as int? ?? 0,
        pipeline: map['pipeline'] as int? ?? 0,
        revenueChangePctVsLastMonth:
            (map['revenueChangePctVsLastMonth'] as num?)?.toDouble(),
        expensesChangePctVsLastMonth:
            (map['expensesChangePctVsLastMonth'] as num?)?.toDouble(),
      );
}

// ── Currency + date formatting helpers ───────────────────────────────────────

/// Format an amount as "GHS 18,420" with thousands separators. Negative
/// values render as "-GHS 18,420". Whole-cedi only — receipts/invoices use
/// numeric(10,2) but we round for header display; line-item screens can
/// format more precisely if needed.
String formatGHS(num amount) {
  final negative = amount < 0;
  final s = amount.abs().round().toString();
  final commas =
      s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${negative ? '-' : ''}GHS $commas';
}

const _kMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String currentMonthShort() => _kMonthNames[DateTime.now().month - 1];

/// Render a +/- percent like "+12%" or "-3%". Returns null when input is null
/// (caller should hide the change chip in that case).
String? formatChangePct(double? pct) {
  if (pct == null) return null;
  final rounded = pct.round();
  final sign = rounded > 0 ? '+' : '';
  return '$sign$rounded%';
}

// ── Business mapping helpers ─────────────────────────────────────────────────

/// First letter of up to two words from the business name (uppercased).
String _extractInitials(String name) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) return '?';
  final letters = parts.map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

/// Convert a name to a URL-safe slug for fallback handles.
String _slugify(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Map the canonical snake_case industry values (used by web's diagnostic
/// wizard + AI rules engine) back to display labels for the UI. Web's known
/// values are: fashion, salon_barber, food_catering, services_consulting,
/// retail_trade, other (see ascendsme-b/src/pages/DiagnosticWizard.tsx).
/// Mobile-written display strings ("Retail", "Food & Beverage") still
/// pass through the default case unchanged for backward compatibility with
/// any rows written before [canonicalIndustry] shipped.
String _displayIndustry(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case '':
      return 'Business';
    case 'retail_trade':
      return 'Retail';
    case 'services_consulting':
      return 'Services & Consulting';
    case 'fashion':
      return 'Fashion';
    case 'food_catering':
      return 'Food & Beverage';
    case 'salon_barber':
      return 'Beauty & Wellness';
    case 'other':
      return 'Other';
    default:
      // Legacy free-form value or a vocab web has added we don't know yet.
      return raw!;
  }
}

/// Translate a mobile-dropdown industry label into web's canonical
/// snake_case vocabulary so the AI rules engine, diagnostic answers, and
/// admin filters all match. Mobile's dropdown is broader than web's six
/// known buckets — anything outside web's vocab maps to 'other' so it
/// at least classifies cleanly instead of breaking equality filters.
String canonicalIndustry(String? displayLabel) {
  switch ((displayLabel ?? '').trim().toLowerCase()) {
    case '':
      return '';
    case 'retail':
      return 'retail_trade';
    case 'food & beverage':
    case 'food and beverage':
      return 'food_catering';
    case 'fashion':
      return 'fashion';
    case 'beauty & wellness':
    case 'beauty and wellness':
      return 'salon_barber';
    case 'services':
    case 'services & consulting':
    case 'services and consulting':
      return 'services_consulting';
    // Mobile's broader options that web doesn't have a bucket for yet.
    case 'technology':
    case 'agriculture':
    case 'healthcare':
    case 'education':
    case 'transport':
    case 'construction':
    case 'finance':
    case 'other':
      return 'other';
    default:
      // Already canonical (snake_case) or unknown — pass through.
      return displayLabel!.trim().toLowerCase();
  }
}

/// Display label for the backend's `subscription_tier` enum. The CHECK
/// constraint on `businesses.subscription_tier` (initial schema) allows only
/// 'free' | 'lite' | 'plus' | 'elite' — see ascendsme-b's subscription_tiers
/// seed in 20250121000001_create_subscription_system.sql.
String _displaySubscriptionTier(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case '':
    case 'free':
      return 'Ascend Free';
    case 'lite':
      return 'SME Suite Lite';
    case 'plus':
      return 'SME Suite Plus';
    case 'elite':
      return 'SME Suite Elite';
    default:
      // Unknown value — surface it raw rather than guess. If we start seeing
      // this in logs, the web schema added a tier we don't know about yet.
      return raw!;
  }
}

/// A business counts as "verified" once it has progressed past the foundation
/// stage. tier_status moves off 'grey' as verification milestones complete.
bool _isVerified(Map<String, dynamic> row) {
  final tierStatus = (row['tier_status'] as String?)?.toLowerCase();
  final verifTier = row['verification_tier'];
  final verifStatus = (row['verification_status'] as String?)?.toLowerCase();
  if (tierStatus != null && tierStatus.isNotEmpty && tierStatus != 'grey') {
    return true;
  }
  if (verifTier != null) return true;
  if (verifStatus != null && verifStatus.isNotEmpty && verifStatus != 'foundation') {
    return true;
  }
  return false;
}

/// A row in the shared `customers` table. Mobile only consumes/writes the
/// fields it actually needs — name + phone — to keep customer creation a
/// one-step inline action inside the invoice / sale flow. Web's CRM rollup
/// (`crm_profiles`) is computed server-side via triggers; mobile never
/// writes there.
class Customer {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;

  const Customer({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
  });

  factory Customer.fromRow(Map<String, dynamic> row) => Customer(
        id: row['id'] as String,
        fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
            ? (row['full_name'] as String).trim()
            : 'Unnamed customer',
        phone: (row['phone'] as String?)?.trim().isNotEmpty == true
            ? (row['phone'] as String).trim()
            : null,
        email: (row['email'] as String?)?.trim().isNotEmpty == true
            ? (row['email'] as String).trim()
            : null,
      );
}

class Recommendation {
  final String id, priority, title, why, cta;
  final int minutes;
  final String impact;
  const Recommendation({
    required this.id,
    required this.priority,
    required this.title,
    required this.why,
    required this.cta,
    required this.minutes,
    required this.impact,
  });
}

class Tip {
  final String id, tag, text;
  const Tip({required this.id, required this.tag, required this.text});
}

class QuickAction {
  final String id, label, icon, tone;
  const QuickAction({required this.id, required this.label, required this.icon, required this.tone});
}

class AppTool {
  final String id, name, desc, icon, tier, tone;
  const AppTool({
    required this.id, required this.name, required this.desc,
    required this.icon, required this.tier, required this.tone,
  });
}

class InvoiceLineItem {
  final String description;
  final num amount;
  /// Quantity, when available (canonical web format). Null for legacy rows.
  final num? quantity;
  /// Unit price, when available. Null for legacy rows.
  final num? unitPrice;

  const InvoiceLineItem({
    required this.description,
    required this.amount,
    this.quantity,
    this.unitPrice,
  });

  /// Display-friendly string like "3 × GHS 150" when both fields are present.
  String? get qtyLabel {
    if (quantity == null || unitPrice == null) return null;
    return '${quantity!.round()} × ${formatGHS(unitPrice!)}';
  }

  /// Accept both shapes that exist in the DB:
  ///   - Web canonical: `{description, quantity, price}`
  ///   - Legacy mobile-only: `{description, amount}` (pre-fix; total line)
  /// We preserve quantity + price when present so the UI can display them.
  factory InvoiceLineItem.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const InvoiceLineItem(description: 'Item', amount: 0);
    }
    final desc = (raw['description'] ??
            raw['item'] ??
            raw['name'] ??
            'Item')
        .toString();

    num parseNum(dynamic v) => v is num
        ? v
        : (num.tryParse(v?.toString() ?? '') ?? 0);

    final rawQty = raw['quantity'];
    final rawPrice = raw['price'] ?? raw['unit_price'];
    if (rawQty != null && rawPrice != null) {
      final qty = parseNum(rawQty);
      final price = parseNum(rawPrice);
      return InvoiceLineItem(
        description: desc,
        amount: qty * price,
        quantity: qty,
        unitPrice: price,
      );
    }
    // Legacy: amount-only row
    return InvoiceLineItem(
      description: desc,
      amount: parseNum(raw['amount']),
    );
  }
}

class Invoice {
  /// Display id — invoice_number from the backend (e.g. "OPH3F2-INV-0001")
  /// for real rows, kInvoices mock ids ("INV-0142") for fallback.
  final String id;
  final String customer;
  /// One of: 'proforma' | 'pending' | 'paid' | 'overdue' | 'void'. The
  /// Invoice.fromRow factory promotes 'pending' rows with due_date < today to
  /// 'overdue' so the UI doesn't depend on a backend cron having run.
  final String status;
  /// Formatted display date for `due_date` (e.g. "May 16"), or "—" if unset.
  final String due;
  /// Numeric amount in GHS (rounded to whole cedis for display).
  final int amount;
  /// Days relative to due_date: positive when overdue, negative when in the
  /// future, 0 when due today. For paid invoices: 0 if we don't have a paid
  /// date, otherwise days since paid (negative).
  final int days;
  /// Underlying backend row UUID (null for the mock kInvoices entries).
  final String? backendId;

  // Extended fields populated by Invoice.fromRow when present.
  final String? clientEmail;
  final List<InvoiceLineItem> lineItems;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final String? payToken;
  final bool onlinePayEnabled;
  /// Date after which this proforma quote expires (null for regular invoices).
  final DateTime? validUntil;

  const Invoice({
    required this.id,
    required this.customer,
    required this.amount,
    required this.status,
    required this.days,
    required this.due,
    this.backendId,
    this.clientEmail,
    this.lineItems = const [],
    this.dueDate,
    this.createdAt,
    this.payToken,
    this.onlinePayEnabled = false,
    this.validUntil,
  });

  /// True when this invoice is a proforma quote (status == 'proforma').
  bool get isProforma => status == 'proforma';

  /// True when this invoice has a usable hosted pay link the SME can share.
  bool get hasPayLink => onlinePayEnabled && (payToken?.isNotEmpty ?? false);

  /// Build an Invoice from a row returned by `SupabaseService.fetchInvoices()`.
  /// Promotes 'pending' invoices with a past due_date to 'overdue' so the UI
  /// reflects reality even when the backend's status hasn't been refreshed.
  factory Invoice.fromRow(Map<String, dynamic> row) {
    final rawStatus = (row['status'] as String?)?.toLowerCase() ?? 'pending';
    final dueRaw = row['due_date'] as String?;
    final dueDate = dueRaw != null ? DateTime.tryParse(dueRaw) : null;
    final createdRaw = row['created_at'] as String?;
    final created =
        createdRaw != null ? DateTime.tryParse(createdRaw) : null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String effectiveStatus = rawStatus;
    int days = 0;
    if (dueDate != null) {
      days = today.difference(dueDate).inDays;
      if (rawStatus == 'pending' && days > 0) {
        effectiveStatus = 'overdue';
      }
    }

    final amountRaw = (row['total_amount'] as num?)?.toDouble() ?? 0;

    List<InvoiceLineItem> items = const [];
    final rawItems = row['line_items'];
    if (rawItems is List) {
      items = rawItems.map(InvoiceLineItem.fromJson).toList();
    }

    // Parse valid_until for proformas
    final validUntilRaw = row['valid_until'] as String?;
    final validUntil =
        validUntilRaw != null ? DateTime.tryParse(validUntilRaw) : null;

    return Invoice(
      id: (row['invoice_number'] as String?) ?? '—',
      backendId: row['id'] as String?,
      customer: (row['client_name'] as String?)?.trim().isNotEmpty == true
          ? row['client_name'] as String
          : 'Customer',
      clientEmail: (row['client_email'] as String?)?.trim().isNotEmpty == true
          ? row['client_email'] as String
          : null,
      amount: amountRaw.round(),
      status: effectiveStatus,
      days: days,
      due: dueDate != null
          ? '${_kMonthNames[dueDate.month - 1]} ${dueDate.day}'
          : '—',
      dueDate: dueDate,
      createdAt: created,
      lineItems: items,
      payToken: row['pay_token'] as String?,
      onlinePayEnabled: row['online_pay_enabled'] == true,
      validUntil: validUntil,
    );
  }
}

/// Format "May 2026" from a year and month (1-indexed).
String monthLabel(int year, int month) =>
    '${_kMonthNames[(month - 1).clamp(0, 11)]} $year';

/// Format a DateTime as "May 16, 2026" for header detail rows.
String formatLongDate(DateTime d) =>
    '${_kMonthNames[d.month - 1]} ${d.day}, ${d.year}';

class VerificationStep {
  final String id, label, status, detail;
  const VerificationStep({required this.id, required this.label, required this.status, required this.detail});
}

class FundingStage {
  final String id, label, status, detail;
  const FundingStage({required this.id, required this.label, required this.status, required this.detail});
}

class MarketplaceCategory {
  final String id, name, icon;
  final int count;
  const MarketplaceCategory({required this.id, required this.name, required this.icon, required this.count});
}

class MarketplaceProvider {
  final String id, name, tag, category;
  final double rating;
  final int reviews, from;
  const MarketplaceProvider({
    required this.id, required this.name, required this.rating,
    required this.reviews, required this.tag, required this.from, required this.category,
  });
}

// ── Inventory ────────────────────────────────────────────────────────────────

/// A product tracked in the business's inventory. Stored in the shared
/// `user_products` table (same as web). Mobile only manages the fields
/// relevant to stock tracking — no complex reservations, no demand prediction.
class InventoryItem {
  final String id;
  final String name;
  final String? sku;
  final String category;
  final int currentStock;
  final int? lowStockThreshold;
  final double? unitPrice;
  final bool isGoods;
  final String? imageUrl;

  const InventoryItem({
    required this.id,
    required this.name,
    this.sku,
    this.category = 'General',
    this.currentStock = 0,
    this.lowStockThreshold,
    this.unitPrice,
    this.isGoods = true,
    this.imageUrl,
  });

  bool get lowStock =>
      lowStockThreshold != null && currentStock <= lowStockThreshold!;

  factory InventoryItem.fromRow(Map<String, dynamic> row) => InventoryItem(
        id: row['id'] as String,
        name: (row['name'] as String?)?.trim().isNotEmpty == true
            ? row['name'] as String
            : 'Unnamed product',
        sku: row['sku'] as String?,
        category: (row['category'] as String?)?.trim().isNotEmpty == true
            ? row['category'] as String
            : 'General',
        currentStock: (row['current_stock'] as num?)?.toInt() ?? 0,
        lowStockThreshold:
            (row['low_stock_threshold'] as num?)?.toInt(),
        unitPrice: (row['unit_price'] as num?)?.toDouble(),
        isGoods: (row['type'] as String?)?.toUpperCase() == 'GOODS',
        imageUrl: row['image_url'] as String?,
      );
}

/// Billing period for subscriptions.
enum BillingPeriod { monthly, quarterly, yearly }

// ── Subscription ──────────────────────────────────────────────────────────────

/// A subscription tier available for businesses to select. Seeded in the
/// `subscription_tiers` table (see ascendsme-b's subscription system seed).
class SubscriptionPlan {
  final String id;
  final String tierCode; // 'free' | 'lite' | 'plus' | 'elite'
  final String tierName;
  final int priceMonthly;
  final int? priceQuarterly;
  final int? priceYearly;
  final String? description;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.tierCode,
    required this.tierName,
    required this.priceMonthly,
    this.priceQuarterly,
    this.priceYearly,
    this.description,
    this.features = const [],
  });

  factory SubscriptionPlan.fromRow(Map<String, dynamic> row) => SubscriptionPlan(
        id: row['id'] as String,
        tierCode: (row['tier_code'] as String?) ?? 'free',
        tierName: (row['tier_name'] as String?) ?? 'Free',
        priceMonthly: ((row['price_monthly_ghs'] as num?)?.toDouble() ?? 0).round(),
        priceQuarterly: row['price_quarterly_ghs'] != null
            ? ((row['price_quarterly_ghs'] as num).toDouble()).round()
            : null,
        priceYearly: row['price_yearly_ghs'] != null
            ? ((row['price_yearly_ghs'] as num).toDouble()).round()
            : null,
        description: row['description'] as String?,
        features: (row['features'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

/// The business's active subscription (or null if on free / expired).
class SubscriptionInfo {
  final String id;
  final String businessId;
  final String tierId;
  final String status; // active | cancelled | expired | past_due
  final DateTime? currentPeriodEnd;
  final String? tierCode;
  final String? tierName;

  const SubscriptionInfo({
    required this.id,
    required this.businessId,
    required this.tierId,
    required this.status,
    this.currentPeriodEnd,
    this.tierCode,
    this.tierName,
  });

  factory SubscriptionInfo.fromRow(Map<String, dynamic> row) {
    final tier = row['tier'] as Map<String, dynamic>?;
    return SubscriptionInfo(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      tierId: row['tier_id'] as String,
      status: (row['status'] as String?) ?? 'active',
      currentPeriodEnd: row['current_period_end'] != null
          ? DateTime.tryParse(row['current_period_end'] as String)
          : null,
      tierCode: tier?['tier_code'] as String?,
      tierName: tier?['tier_name'] as String?,
    );
  }
}

// ── Staff / HRM ──────────────────────────────────────────────────────────────

/// A staff member employed by the business. Stored in the shared `staff_members`
/// table. Mobile covers: name, role, contact, salary, active status. No
/// performance/attendance tracking in this version.
class StaffMember {
  final String id;
  final String businessId;
  final String staffName;
  final String? staffEmail;
  final String? staffPhone;
  final String role;
  final double? salaryMonthly;
  final String hireDate;
  final bool isActive;

  const StaffMember({
    required this.id,
    required this.businessId,
    required this.staffName,
    this.staffEmail,
    this.staffPhone,
    required this.role,
    this.salaryMonthly,
    required this.hireDate,
    this.isActive = true,
  });

  factory StaffMember.fromRow(Map<String, dynamic> row) => StaffMember(
        id: row['id'] as String,
        businessId: row['business_id'] as String,
        staffName: (row['staff_name'] as String?)?.trim().isNotEmpty == true
            ? row['staff_name'] as String
            : 'Unnamed staff',
        staffEmail: row['staff_email'] as String?,
        staffPhone: row['staff_phone'] as String?,
        role: (row['role'] as String?)?.trim().isNotEmpty == true
            ? row['role'] as String
            : 'Staff',
        salaryMonthly: (row['salary_monthly_ghs'] as num?)?.toDouble(),
        hireDate: (row['hire_date'] as String?) ??
            DateTime.now().toIso8601String().substring(0, 10),
        isActive: row['is_active'] != false,
      );
}

// ── Expense ──────────────────────────────────────────────────────────────────

/// An expense recorded by the business. Stored in the shared `expenses` table.
// ── CRM ──────────────────────────────────────────────────────────────────────

/// A CRM profile for a customer — tracks lifetime value, churn risk, tags.
/// Stored in the shared `crm_profiles` table (web also writes here).
class CrmProfile {
  final String id;
  final String businessId;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final double customerLifetimeValueGhs;
  final String? firstInteractionDate;
  final String? lastInteractionDate;
  final int totalOrders;
  final double totalSpentGhs;
  final double churnRiskScore;
  final List<String> tags;
  final String? leadStatus;
  final List<String> groupNames;

  const CrmProfile({
    required this.id,
    required this.businessId,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.customerLifetimeValueGhs = 0,
    this.firstInteractionDate,
    this.lastInteractionDate,
    this.totalOrders = 0,
    this.totalSpentGhs = 0,
    this.churnRiskScore = 0,
    this.tags = const [],
    this.leadStatus,
    this.groupNames = const [],
  });

  List<String> get smartSegments {
    final segments = <String>[];
    if (churnRiskScore >= 0.6) segments.add('At-risk');
    if (customerLifetimeValueGhs >= 1000 || totalSpentGhs >= 1000) {
      segments.add('High value');
    }
    if (lastInteractionDate == null ||
        DateTime.now().difference(DateTime.tryParse(lastInteractionDate!) ?? DateTime(2000)).inDays >= 90) {
      segments.add('Inactive 90d+');
    }
    if (leadStatus != null && ['lead', 'proposal_sent', 'negotiation'].contains(leadStatus)) {
      segments.add('Open lead');
    }
    return segments;
  }

  factory CrmProfile.fromRow(Map<String, dynamic> row) => CrmProfile(
        id: row['id'] as String,
        businessId: row['business_id'] as String,
        customerName: (row['customer_name'] as String?)?.trim() ?? 'Unknown',
        customerEmail: row['customer_email'] as String?,
        customerPhone: row['customer_phone'] as String?,
        customerLifetimeValueGhs: ((row['customer_lifetime_value_ghs'] as num?)?.toDouble() ?? 0),
        firstInteractionDate: row['first_interaction_date'] as String?,
        lastInteractionDate: row['last_interaction_date'] as String?,
        totalOrders: (row['total_orders'] as num?)?.toInt() ?? 0,
        totalSpentGhs: ((row['total_spent_ghs'] as num?)?.toDouble() ?? 0),
        churnRiskScore: ((row['churn_risk_score'] as num?)?.toDouble() ?? 0),
        tags: (row['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        leadStatus: row['lead_status'] as String?,
      );
}

/// A CRM interaction (call, whatsapp, email, note, purchase).
class CrmInteraction {
  final String id;
  final String businessId;
  final String? customerId;
  final String interactionType;
  final String interactionDate;
  final String description;
  final String? internalNotes;
  final bool isInternal;

  const CrmInteraction({
    required this.id,
    required this.businessId,
    this.customerId,
    required this.interactionType,
    required this.interactionDate,
    required this.description,
    this.internalNotes,
    this.isInternal = false,
  });

  factory CrmInteraction.fromRow(Map<String, dynamic> row) => CrmInteraction(
        id: row['id'] as String,
        businessId: row['business_id'] as String,
        customerId: row['customer_id'] as String?,
        interactionType: (row['interaction_type'] as String?) ?? 'note',
        interactionDate: (row['interaction_date'] as String?) ??
            DateTime.now().toIso8601String(),
        description: (row['description'] as String?) ?? '',
        internalNotes: row['internal_notes'] as String?,
        isInternal: row['is_internal'] == true,
      );

  String get typeLabel => switch (interactionType) {
        'call' || 'voice_call' => 'Phone call',
        'whatsapp' => 'WhatsApp',
        'email' => 'Email',
        'meeting' => 'Meeting',
        'purchase' => 'Purchase',
        'booking' => 'Booking',
        'system_event' => 'System',
        _ => 'Note',
      };

  String get typeIcon => switch (interactionType) {
        'call' || 'voice_call' => 'phone',
        'whatsapp' => 'chat',
        'email' => 'mail',
        'meeting' => 'people',
        'purchase' => 'payments',
        'booking' => 'calendar',
        _ => 'receipt',
      };
}

/// A customer group (manual grouping of CRM profiles).
class CustomerGroup {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final String? color;
  final int memberCount;

  const CustomerGroup({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.color,
    this.memberCount = 0,
  });

  factory CustomerGroup.fromRow(Map<String, dynamic> row) => CustomerGroup(
        id: row['id'] as String,
        businessId: row['business_id'] as String,
        name: (row['name'] as String?)?.trim() ?? 'Unnamed group',
        description: row['description'] as String?,
        color: row['color'] as String?,
        memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      );
}

// ── Booking ─────────────────────────────────────────────────────────────────

/// A service offered by the business for booking (e.g. "Haircut", "Consultation").
class BookingService {
  final String id;
  final String businessId;
  final String name;
  final String? description;
  final double? price;
  final int durationMinutes;
  final bool isActive;
  final String? imageUrl;

  const BookingService({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.price,
    this.durationMinutes = 60,
    this.isActive = true,
    this.imageUrl,
  });

  factory BookingService.fromRow(Map<String, dynamic> row) => BookingService(
        id: row['id'] as String,
        businessId: row['business_id'] as String,
        name: (row['name'] as String?)?.trim() ?? 'Unnamed service',
        description: row['description'] as String?,
        price: (row['price'] as num?)?.toDouble(),
        durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 60,
        isActive: row['is_active'] != false,
        imageUrl: row['image_url'] as String?,
      );
}

/// A customer booking/appointment.
class Booking {
  final String id;
  final String businessId;
  final String serviceName;
  final String? serviceId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final DateTime startTime;
  final int durationMinutes;
  final String status; // pending | confirmed | cancelled | fulfilled
  final String? notes;
  final double? price;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.businessId,
    required this.serviceName,
    this.serviceId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.startTime,
    this.durationMinutes = 60,
    this.status = 'pending',
    this.notes,
    this.price,
    required this.createdAt,
  });

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));

  String get statusLabel => switch (status) {
        'confirmed' => 'Confirmed',
        'cancelled' => 'Cancelled',
        'fulfilled' => 'Fulfilled',
        _ => 'Pending',
      };

  factory Booking.fromRow(Map<String, dynamic> row) {
    final startRaw = row['start_time'] as String?;
    final createdRaw = row['created_at'] as String?;
    return Booking(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      serviceName: (row['service_name'] as String?)?.trim() ?? 'Service',
      serviceId: row['service_id'] as String?,
      customerName: (row['customer_name'] as String?)?.trim() ?? 'Customer',
      customerPhone: row['customer_phone'] as String?,
      customerEmail: row['customer_email'] as String?,
      startTime: startRaw != null ? DateTime.parse(startRaw) : DateTime.now(),
      durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 60,
      status: (row['status'] as String?)?.toLowerCase() ?? 'pending',
      notes: row['notes'] as String?,
      price: (row['price'] as num?)?.toDouble(),
      createdAt: createdRaw != null ? DateTime.parse(createdRaw) : DateTime.now(),
    );
  }
}

class Expense {
  final String id;
  final num amount;
  final DateTime expenseDate;
  final String? description;
  /// Manual category selected by user (e.g. "Rent", "Marketing").
  final String category;
  /// Internal category for scoring (e.g. "opex_rent", "compliance").
  final String mappedCategory;
  /// Whether this expense was tagged as sustainable.
  final bool sustainabilityTagged;
  /// Payment source: cash | momo | bank.
  final String paymentSource;

  const Expense({
    required this.id,
    required this.amount,
    required this.expenseDate,
    this.description,
    this.category = 'Other',
    this.mappedCategory = 'other',
    this.sustainabilityTagged = false,
    this.paymentSource = 'cash',
  });

  /// Display label for the expense category with icon-friendly names.
  String get categoryLabel => category;

  /// Icon name matching [AppIcon]'s map.
  String get categoryIcon => switch (mappedCategory) {
        'cogs' => 'inventory_2',
        'opex_rent' => 'home',
        'opex_utilities' => 'bolt',
        'labor' => 'people',
        'marketing' => 'campaign',
        'logistics' => 'local_shipping',
        'compliance' => 'balance',
        _ => 'receipt',
      };

  factory Expense.fromRow(Map<String, dynamic> row) {
    final dateStr = row['expense_date'] as String?;
    return Expense(
      id: row['id'] as String,
      amount: (row['amount_ghs'] as num?)?.toDouble() ?? 0,
      expenseDate: dateStr != null
          ? DateTime.tryParse(dateStr) ?? DateTime.now()
          : DateTime.now(),
      description: (row['description'] as String?)?.trim().isNotEmpty == true
          ? (row['description'] as String).trim()
          : null,
      category: (row['category'] as String?)?.trim().isNotEmpty == true
          ? row['category'] as String
          : 'Other',
      mappedCategory: (row['mapped_category'] as String?)?.trim() ?? 'other',
      sustainabilityTagged: row['sustainability_tagged'] == true,
      paymentSource: (row['payment_source'] as String?)?.toLowerCase() ?? 'cash',
    );
  }
}

// ── Receipt ───────────────────────────────────────────────────────────────────

/// A receipt — money received, either from an invoice payment (has invoice_id)
/// or a direct sale logged via Quick Sale (invoice_id == null). Stored in the
/// shared `receipts` table.
class Receipt {
  final String id;
  final String? receiptNumber;
  final String? invoiceId;
  final String? clientName;
  final num totalAmount;
  final String paymentMethod; // cash | momo | bank | paystack
  final DateTime paidDate;
  final bool isInvoicePayment;

  const Receipt({
    required this.id,
    this.receiptNumber,
    this.invoiceId,
    this.clientName,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paidDate,
    this.isInvoicePayment = false,
  });

  /// Display label for the payment method.
  String get methodLabel => switch (paymentMethod) {
        'momo' => 'Mobile Money',
        'bank' => 'Bank transfer',
        'paystack' => 'Card',
        _ => 'Cash',
      };

  factory Receipt.fromRow(Map<String, dynamic> row) {
    final paidIso = row['paid_date'] as String?;
    final paidDate = paidIso != null ? DateTime.tryParse(paidIso) ?? DateTime.now() : DateTime.now();
    final invoiceId = row['invoice_id'] as String?;
    return Receipt(
      id: row['id'] as String,
      receiptNumber: row['receipt_number'] as String?,
      invoiceId: invoiceId,
      clientName: (row['client_name'] as String?)?.trim().isNotEmpty == true
          ? row['client_name'] as String
          : null,
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: (row['payment_method'] as String?)?.toLowerCase() ?? 'cash',
      paidDate: paidDate,
      isInvoicePayment: invoiceId != null,
    );
  }
}

// ── Recurring Invoices ──────────────────────────────────────────────────────

/// Frequency for recurring invoice templates.
enum RecurringFrequency { weekly, monthly, quarterly, yearly }

/// A template for generating invoices on a recurring schedule. Stored in the
/// `recurring_invoice_templates` table (shared with web). The actual
/// invoice generation is triggered server-side via pg_cron; mobile manages
/// the templates (CRUD) and displays upcoming dates.
class RecurringTemplate {
  final String id;
  final String businessId;
  final String customerName;
  final String? customerId;
  final String? customerEmail;
  final String description;
  final num amount;
  final RecurringFrequency frequency;
  final int? dayOfMonth; // 1-31 for monthly
  final int? dayOfWeek; // 0=Mon..6=Sun for weekly
  final DateTime nextInvoiceDate;
  final DateTime? lastInvoiceDate;
  final bool isActive;
  final DateTime createdAt;
  final List<Map<String, dynamic>> lineItems;

  const RecurringTemplate({
    required this.id,
    required this.businessId,
    required this.customerName,
    this.customerId,
    this.customerEmail,
    required this.description,
    required this.amount,
    required this.frequency,
    this.dayOfMonth,
    this.dayOfWeek,
    required this.nextInvoiceDate,
    this.lastInvoiceDate,
    this.isActive = true,
    required this.createdAt,
    this.lineItems = const [],
  });

  /// Display-friendly label for the frequency.
  String get frequencyLabel => switch (frequency) {
        RecurringFrequency.weekly => 'Weekly',
        RecurringFrequency.monthly => 'Monthly',
        RecurringFrequency.quarterly => 'Quarterly',
        RecurringFrequency.yearly => 'Yearly',
      };

  /// How many days until the next invoice is due. Negative means past due.
  int get daysUntilNext =>
      nextInvoiceDate.difference(DateTime.now()).inDays;

  factory RecurringTemplate.fromRow(Map<String, dynamic> row) {
    final freqRaw = (row['frequency'] as String?)?.toLowerCase() ?? 'monthly';
    final frequency = switch (freqRaw) {
      'weekly' => RecurringFrequency.weekly,
      'quarterly' => RecurringFrequency.quarterly,
      'yearly' => RecurringFrequency.yearly,
      _ => RecurringFrequency.monthly,
    };
    return RecurringTemplate(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      customerName: (row['customer_name'] as String?)?.trim().isNotEmpty == true
          ? row['customer_name'] as String
          : 'Customer',
      customerId: row['customer_id'] as String?,
      customerEmail: row['customer_email'] as String?,
      description: (row['description'] as String?)?.trim() ?? '',
      amount: ((row['total_amount'] as num?)?.toDouble() ?? 0).round(),
      frequency: frequency,
      dayOfMonth: row['day_of_month'] as int?,
      dayOfWeek: row['day_of_week'] as int?,
      nextInvoiceDate: (row['next_invoice_date'] as String?) != null
          ? DateTime.parse(row['next_invoice_date'] as String)
          : DateTime.now(),
      lastInvoiceDate: (row['last_invoice_date'] as String?) != null
          ? DateTime.parse(row['last_invoice_date'] as String)
          : null,
      isActive: row['is_active'] != false,
      createdAt: (row['created_at'] as String?) != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      lineItems: (row['line_items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }
}

// Tier ladder
class ScoreTier {
  final String id, label;
  final int min;
  final int color; // 0xFFRRGGBB
  const ScoreTier({required this.id, required this.label, required this.min, required this.color});
}

const List<ScoreTier> kTiers = [
  ScoreTier(id: 'seedling', label: 'Seedling', min: 0,  color: 0xFF9CA3AF),
  ScoreTier(id: 'sprout',   label: 'Sprout',   min: 30, color: 0xFF86C28A),
  ScoreTier(id: 'bronze',   label: 'Bronze',   min: 50, color: 0xFFC28552),
  ScoreTier(id: 'silver',   label: 'Silver',   min: 70, color: 0xFF9BA8B5),
  ScoreTier(id: 'gold',     label: 'Gold',     min: 85, color: 0xFFE5B349),
  ScoreTier(id: 'indigo',   label: 'Indigo',   min: 95, color: 0xFF5B5BD6),
];

ScoreTier getTier(int score) =>
    kTiers.lastWhere((t) => score >= t.min, orElse: () => kTiers.first);

ScoreTier? getNextTier(int score) {
  try { return kTiers.firstWhere((t) => score < t.min); } catch (_) { return null; }
}
