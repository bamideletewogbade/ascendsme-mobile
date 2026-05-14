// All data models for AscendSME Mobile

class Business {
  /// Backend row id (`businesses.id`). Null on the mock fallback (kBusiness)
  /// since no real row backs it.
  final String? id;
  final String name, handle, industry, city, region, tier, initials;
  final int sustainabilityScore, creditScore;
  final bool verified;
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

/// Map the backend's snake_case industry vocabulary back to display labels.
/// Inverse of `public.normalize_mobile_industry()` in the backend migration.
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
      // Backend allows free-form text; render whatever it sent.
      return raw!;
  }
}

/// Display label for the backend's `subscription_tier` enum.
String _displaySubscriptionTier(String? raw) {
  switch ((raw ?? '').toLowerCase().trim()) {
    case '':
    case 'free':
      return 'Free plan';
    case 'standard':
      return 'SME Suite Standard';
    case 'pro':
      return 'SME Suite Pro';
    case 'quarterly':
      return 'SME Suite Quarterly';
    default:
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
  const InvoiceLineItem({required this.description, required this.amount});

  factory InvoiceLineItem.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const InvoiceLineItem(description: 'Item', amount: 0);
    }
    final desc = (raw['description'] ??
            raw['item'] ??
            raw['name'] ??
            'Item')
        .toString();
    final amt = raw['amount'];
    final num parsed = amt is num
        ? amt
        : num.tryParse(amt?.toString() ?? '0') ?? 0;
    return InvoiceLineItem(description: desc, amount: parsed);
  }
}

class Invoice {
  /// Display id — invoice_number from the backend (e.g. "OPH3F2-INV-0001")
  /// for real rows, kInvoices mock ids ("INV-0142") for fallback.
  final String id;
  final String customer;
  /// One of: 'pending' | 'paid' | 'overdue' | 'void'. The Invoice.fromRow
  /// factory promotes 'pending' rows with due_date < today to 'overdue' so
  /// the UI doesn't depend on a backend cron having run.
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
  });

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
    );
  }
}

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

class Lender {
  final String id, name, product, rate;
  final int max, match;
  const Lender({required this.id, required this.name, required this.product, required this.rate, required this.max, required this.match});
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

class ActivityItem {
  final String id, time, text, kind;
  const ActivityItem({required this.id, required this.time, required this.text, required this.kind});
}

class Quest {
  final String id, title, detail, action;
  final int pts;
  final bool done;
  const Quest({
    required this.id, required this.title, required this.detail,
    required this.action, required this.pts, this.done = false,
  });

  Quest copyWith({bool? done}) => Quest(
    id: id, title: title, detail: detail, action: action, pts: pts, done: done ?? this.done,
  );
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
