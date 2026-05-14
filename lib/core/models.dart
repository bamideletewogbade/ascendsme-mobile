// All data models for AscendSME Mobile

class Business {
  final String name, handle, industry, city, region, tier, initials;
  final int sustainabilityScore, creditScore;
  final bool verified;
  final int monthlyRevenue, monthlyExpenses, outstandingInvoices, pipeline;

  const Business({
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

class Invoice {
  final String id, customer, status, due;
  final int amount, days;
  const Invoice({
    required this.id, required this.customer, required this.amount,
    required this.status, required this.days, required this.due,
  });
}

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
