// Port of ascendsme-b/src/lib/expense-mapping.ts. Kept 1:1 so web + mobile
// classify expenses identically — same keyword lists, same mapped_category
// vocabulary, same sustainability auto-tagging. If the web file changes,
// update this one in lockstep.

/// Display-side categories the user picks in the UI.
const List<String> kManualExpenseCategories = [
  'Inventory/Stock',
  'Rent',
  'Utilities',
  'Wages',
  'Marketing',
  'Transport',
  'Other',
];

/// Internal categories the backend's scoring + cash-flow engines work with.
/// Allowed values: cogs, opex_rent, opex_utilities, labor, marketing,
/// logistics, compliance, other.
const Map<String, String> _kManualToMapped = {
  'Inventory/Stock': 'cogs',
  'Rent': 'opex_rent',
  'Utilities': 'opex_utilities',
  'Wages': 'labor',
  'Marketing': 'marketing',
  'Transport': 'logistics',
  'Other': 'other',
};

const List<({String category, List<String> keywords})> _kKeywordMap = [
  (
    category: 'Inventory/Stock',
    keywords: ['kente', 'thread', 'fabric', 'buttons', 'stock', 'inventory', 'raw'],
  ),
  (category: 'Rent', keywords: ['rent', 'lease', 'shop', 'studio']),
  (
    category: 'Utilities',
    keywords: ['electricity', 'ecg', 'water', 'internet', 'wifi', 'utility'],
  ),
  (category: 'Wages', keywords: ['salary', 'wage', 'commission', 'staff', 'payroll']),
  (
    category: 'Transport',
    keywords: ['fuel', 'delivery', 'transport', 'maintenance', 'repair'],
  ),
  (
    category: 'Marketing',
    keywords: [
      'ads', 'advert', 'marketing', 'promotion', 'facebook', 'instagram', 'social',
    ],
  ),
  (
    category: 'Other',
    keywords: [
      'rgd', 'tin', 'tax', 'gra', 'registration', 'compliance', 'filing', 'formalization',
    ],
  ),
];

const List<String> _kComplianceKeywords = [
  'rgd', 'tin', 'tax', 'gra', 'registration', 'compliance', 'filing', 'formalization',
];

const List<String> _kSustainabilityKeywords = [
  'eco',
  'eco-friendly',
  'sustainable',
  'recycle',
  'recycled',
  'green',
  'biodegradable',
  'packaging',
  'formalization',
  'compliance',
];

/// If the user picked "Other", scan the description for an obvious match
/// and upgrade to the more specific category. Returns null if no keyword fires.
String? detectExpenseCategoryFromDescription(String description) {
  final normalized = description.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final entry in _kKeywordMap) {
    if (entry.keywords.any(normalized.contains)) {
      return entry.category;
    }
  }
  return null;
}

class ExpenseMapping {
  /// What we save to `expenses.category` — promoted from "Other" if keyword
  /// detection found a better fit.
  final String manualCategory;

  /// What we save to `expenses.mapped_category`. Goes into the ledger /
  /// cash-flow forecasts / score engine.
  final String mappedCategory;

  /// What we save to `expenses.sustainability_tagged` — auto-derived from
  /// description keywords. Each tagged expense is worth 3 pts in pillar G
  /// (max 15).
  final bool sustainabilityTagged;

  const ExpenseMapping({
    required this.manualCategory,
    required this.mappedCategory,
    required this.sustainabilityTagged,
  });
}

/// Mirror of web's mapExpenseCategory(). Compliance keywords override
/// the mapped_category to 'compliance' regardless of the manual pick — so
/// "Other / GRA filing" lands in compliance, where the scoring engine
/// looks for it.
ExpenseMapping mapExpense({
  required String manualCategory,
  String? description,
}) {
  final normalizedDesc = (description ?? '').toLowerCase();
  final detected = description == null || description.isEmpty
      ? null
      : detectExpenseCategoryFromDescription(description);
  final effectiveCategory =
      manualCategory == 'Other' && detected != null ? detected : manualCategory;
  final isCompliance =
      _kComplianceKeywords.any(normalizedDesc.contains);
  final mappedCategory =
      isCompliance ? 'compliance' : (_kManualToMapped[effectiveCategory] ?? 'other');
  final isSustainabilityTagged =
      _kSustainabilityKeywords.any(normalizedDesc.contains);
  return ExpenseMapping(
    manualCategory: effectiveCategory,
    mappedCategory: mappedCategory,
    sustainabilityTagged: isSustainabilityTagged,
  );
}
