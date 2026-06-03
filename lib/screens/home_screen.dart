import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/activity.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import '../core/recommendations.dart';
import '../services/ai_service.dart';
import '../state/app_state.dart';
import 'home_skeleton.dart';
import 'recommendations_screen.dart';
import 'tools/activity_screen.dart';

// Single, opinionated home — cash flow first, then quick actions, then the
// recommendations that actually move the user's business. No layout switcher,
// no gamification overlays. Matches SOUL.md's "my business in my pocket"
// framing.
class HomeScreen extends StatelessWidget {
  final void Function(String) onAction;
  final VoidCallback onOpenDrawer;

  const HomeScreen({
    super.key,
    required this.onAction,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Real Supabase user signed in but business profile hasn't loaded yet.
    // Prevents a flash of mock kBusiness data ("Akwaaba Threads") on first
    // sign-in. Mock mode (no Supabase keys) keeps state.user == null and
    // intentionally uses the mock data, so the skeleton is skipped there.
    if (state.user != null && !state.hasRealBusiness) {
      return RefreshIndicator(
        onRefresh: state.refreshAll,
        displacement: 80,
        child: const HomeSkeleton(),
      );
    }
    final recs = buildRecommendations(
      business: state.business,
      financials: state.financials,
      invoices: state.invoices,
    );
    final showAllLink = recs.length > 3;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.refreshAll,
        displacement: 80,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _Header(
              onOpenDrawer: onOpenDrawer,
              onAction: onAction,
            ),
            const SizedBox(height: 18),
            _CashFlowHero(onAction: onAction),
            const SizedBox(height: 24),
            _QuickActions(onAction: onAction),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SectionHeader(
                'Top actions',
                action: showAllLink ? 'View all' : null,
                onAction: showAllLink
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecommendationsScreen(
                                recs: recs, onAction: onAction),
                          ),
                        )
                    : null,
              ),
            ),
            ...recs.take(3).toList().asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: FadeInSlide(
                      index: e.key,
                      child: _RecommendationCard(rec: e.value, onAction: onAction),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            _DailyBrief(onAction: onAction),
            const SizedBox(height: 8),
            const SizedBox(height: 22),
            const _ActivityFeed(),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────
/// Clean two-line greeting area: avatar + greeting on top row, business name
/// below in muted text. Long business names don't crowd the greeting.
class _Header extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  final void Function(String) onAction;

  const _Header({required this.onOpenDrawer, required this.onAction});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _tierShortLabel(String tier) {
    if (tier.contains('Free')) return 'FREE';
    if (tier.contains('Lite')) return 'LITE';
    if (tier.contains('Plus')) return 'PLUS';
    if (tier.contains('Elite')) return 'ELITE';
    return 'FREE';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final business = state.business;
    final greeting = state.firstName != null
        ? '$_greeting, ${state.firstName}'
        : _greeting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + greeting + bell ──
          Row(
            children: [
              GestureDetector(
                onTap: onOpenDrawer,
                child: AppAvatar(business.initials, size: 42),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(greeting,
                            style: AppType.body(size: 16, weight: FontWeight.w600, color: c.text),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Icon(Icons.auto_awesome, size: 13, color: c.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(business.name,
                              style: AppType.body(size: 13, weight: FontWeight.w500, color: c.textMuted),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        // Subtle subscription tier badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: c.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _tierShortLabel(business.tier),
                            style: AppType.body(
                              size: 8.5,
                              weight: FontWeight.w700,
                              color: c.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onAction('notifications'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: c.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.notifications_outlined,
                      size: 18, color: c.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick tools ────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final void Function(String) onAction;

  const _QuickActions({required this.onAction});

  static const _quickTools = [
    QuickAction(id: 'invoice',  label: 'Invoicing',  icon: 'description', tone: 'teal'),
    QuickAction(id: 'sale',     label: 'Log sale',   icon: 'payments',    tone: 'teal'),
    QuickAction(id: 'expense',  label: 'Expense',    icon: 'receipt',     tone: 'orange'),
    QuickAction(id: 'tools',    label: 'More',       icon: 'grid_view',   tone: 'teal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Quick tools'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: _quickTools
                .map((a) => _QuickTile(action: a, onTap: () => onAction(a.id)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;

  const _QuickTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isTeal = action.tone == 'teal';
    final isOrange = action.tone == 'orange';
    final iconBg = isTeal ? c.tealSurface : isOrange ? c.orangeSurface : c.bgInset;
    final iconFg = isTeal ? c.tealDeep : isOrange ? c.orange : c.textMuted;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Center(child: AppIcon(action.icon, size: 17, color: iconFg)),
          ),
          const SizedBox(height: 6),
          Text(action.label,
              style: AppType.body(size: 10.5, weight: FontWeight.w600, color: c.text),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Recommendation card ────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final Recommendation rec;
  final void Function(String) onAction;

  const _RecommendationCard({required this.rec, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dotColor = switch (rec.priority) {
      'urgent' => c.rose,
      'high'   => c.orange,
      'medium' => c.amber,
      _        => c.teal,
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(rec.minutes == 1 ? '1 min' : '${rec.minutes} min',
                  style: AppType.body(size: 11.5, color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(rec.title,
              style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 6),
          Text(rec.why,
              style: AppType.body(size: 12.5, color: c.textMuted)),
          const SizedBox(height: 12),
          AppBtn(
            rec.cta,
            variant: BtnVariant.secondary,
            fontSize: 12.5,
            onTap: () => onAction(rec.id),
          ),
        ],
      ),
    );
  }
}

// ── Daily brief ────────────────────────────────────────────────────────────
/// AI Daily Brief card. Calls AIService.ask once on mount, falls back to a
/// rotating tip when AI is unavailable.
class _DailyBrief extends StatefulWidget {
  final void Function(String) onAction;
  const _DailyBrief({required this.onAction});

  @override
  State<_DailyBrief> createState() => _DailyBriefState();
}

class _DailyBriefState extends State<_DailyBrief> {
  String? _brief;
  bool _loading = true;
  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fetched) return;
    _fetched = true;
    final state = context.read<AppState>();
    _loadBrief(state);
  }

  Future<void> _loadBrief(AppState state) async {
    // Show a rotating tip immediately while AI loads in the background
    final tip = kTips.isNotEmpty ? kTips.first : null;
    if (tip != null) {
      setState(() {
        _brief = tip.text;
        _loading = true; // keep loading true so subtle indicator shows
      });
    }
    try {
      final brief = await AIService.ask(
        'Give me a 2-sentence morning brief: the single most important thing '
        'I should do for my business today, and a one-line cash-flow note. '
        'Be specific to my numbers.',
        maxSentences: 2,
        business: state.business,
        financials: state.financials,
      );
      if (!mounted) return;
      if (!brief.contains('AI unavailable') && brief.trim().isNotEmpty) {
        setState(() {
          _brief = brief;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tip = kTips.isNotEmpty ? kTips.first : null;
    final aiText = (_brief != null &&
            !_brief!.contains('AI unavailable') &&
            _brief!.trim().isNotEmpty)
        ? _brief!
        : (tip?.text ??
            'Log a sale or send an invoice — your daily brief will appear here.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.navyDeep, c.navy],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.auto_awesome, size: 20, color: c.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Ascend AI',
                          style: AppType.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: c.teal)),
                      const SizedBox(width: 6),
                      Container(
                          width: 4, height: 4, decoration: BoxDecoration(
                              color: c.textFaint,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Daily brief',
                          style: AppType.body(
                              size: 12,
                              weight: FontWeight.w500,
                              color: c.textFaint)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(aiText,
                            style: AppType.body(
                                size: 14, color: c.text, weight: FontWeight.w400)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 10, height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation(c.teal),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('AI updating…',
                                style: AppType.body(size: 11, color: c.teal)),
                          ],
                        ),
                      ],
                    )
                  else
                    Text(aiText,
                        style: AppType.body(
                            size: 14, color: c.text, weight: FontWeight.w400)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _TealPillBtn(
                        label: 'Ask AI',
                        icon: Icons.chat_bubble_outline_rounded,
                        onTap: () => widget.onAction('askAI'),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => widget.onAction('askAI'),
                        child: Text('See more insights',
                            style: AppType.body(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: c.blueDeep)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TealPillBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TealPillBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.teal,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: AppType.body(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(width: width, height: height, radius: 4);
  }
}

// ── Cash flow snapshot ─────────────────────────────────────────────────────
// Navy-gradient hero — net cash is the hero metric. The right side shows a
// sustainability score ring (score / 850) with tier label and eco icon.
class _CashFlowHero extends StatelessWidget {
  final void Function(String) onAction;
  const _CashFlowHero({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final f = state.financials;
    final hasData = f.revenueThisMonth > 0 || f.expensesThisMonth > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.7, -1),
              end: const Alignment(0.7, 1),
              colors: [c.navyDeep, c.navy],
            ),
            boxShadow: AppShadows.navy,
          ),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -60,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.green.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              hasData ? _activeBody(context, c, f) : _emptyBody(context, c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeBody(BuildContext context, AppColorsX c, Financials f) {
    final net = f.revenueThisMonth - f.expensesThisMonth;
    final netPositive = net >= 0;
    final inflow = f.revenueThisMonth;
    final outflow = f.expensesThisMonth;
    final business = context.watch<AppState>().business;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS MONTH · ${currentMonthShort().toUpperCase()}',
                    style: AppType.label(
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${netPositive ? '' : '−'}${formatGHS(net.abs())}',
                    style: AppType.display(
                        size: 32,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    netPositive
                        ? 'Net cash · you kept more than you spent'
                        : 'Net cash · spent more than you earned',
                    style: AppType.body(
                        size: 12.5,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _SustainabilityScoreLarge(business: business),
          ],
        ),        const SizedBox(height: 18),
            Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.10)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _HeroStat(
                label: 'Revenue',
                amount: formatGHS(inflow),
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.10),
              margin: const EdgeInsets.symmetric(horizontal: 14),
            ),
            Expanded(
              child: _HeroStat(
                label: 'Expenses',
                amount: formatGHS(outflow),
              ),
            ),
          ],
        ),
        if (f.outstanding > 0) ...[
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: c.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_outstandingSubtitle(f),
                      style: AppType.body(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: Colors.white)),
                ),
                if (f.outstandingOverdueCount > 0)
                  GestureDetector(
                    onTap: () => onAction('followup'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.rose,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('Follow up',
                          style: AppType.body(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyBody(BuildContext context, AppColorsX c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THIS MONTH · ${currentMonthShort().toUpperCase()}',
          style: AppType.label(
              size: 11, color: Colors.white.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 14),
        Text('Start your records',
            style:
                AppType.heading(size: 22, color: Colors.white)),
        const SizedBox(height: 6),
        Text(
          "Log your first sale or invoice and your cash flow will appear here. We'll keep track so you don't have to.",
          style: AppType.body(
              size: 13, color: Colors.white.withValues(alpha: 0.72)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: () => onAction('sale'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: c.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.green,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Log a sale',
                        style: AppType.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => onAction('invoice'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Send invoice',
                        style: AppType.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _outstandingSubtitle(Financials f) {
    final word = f.outstandingCount == 1 ? 'invoice' : 'invoices';
    if (f.outstandingOverdueCount == 0) {
      return '${formatGHS(f.outstanding)} across ${f.outstandingCount} $word';
    }
    return '${formatGHS(f.outstanding)} · ${f.outstandingOverdueCount} overdue';
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String amount;

  const _HeroStat({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppType.body(
                size: 11.5,
                weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65))),
        const SizedBox(height: 4),
        Text(amount,
            style: AppType.heading(size: 17, color: Colors.white)),
      ],
    );
  }
}



class _SustainabilityScoreLarge extends StatelessWidget {
  final Business business;

  const _SustainabilityScoreLarge({required this.business});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final score = business.sustainabilityScore;
    final tier = getTier(score);
    final tierColor = Color(tier.color);

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _RingPainter(
                share: (score.clamp(0, 850) / 850),
                color: tierColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco, size: 16, color: c.teal),
                    const SizedBox(height: 1),
                    Text('$score',
                        style: AppType.display(
                            size: 26, color: Colors.white)),
                    Text('/850',
                        style: AppType.body(
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.55))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double share;
  final Color color;
  _RingPainter({required this.share, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = Colors.white.withValues(alpha: 0.14);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = Offset.zero & size;
    final c = rect.center;
    final r = (size.shortestSide - 7) / 2;
    canvas.drawCircle(c, r, track);
    final sweep = 2 * 3.141592653589793 * share;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -3.141592653589793 / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.share != share || old.color != color;
}

// ── Activity feed ──────────────────────────────────────────────────────────
class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final events = buildActivityFeed(
      invoices: state.invoices,
      receipts: state.receipts,
      expenses: state.expenses,
      limit: 6,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'Recent activity',
            action: events.isNotEmpty ? 'View all' : null,
            onAction: events.isNotEmpty
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ActivityScreen()),
                    )
                : null,
          ),
          if (events.isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.history, size: 22, color: c.textFaint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your activity will appear here as you log sales, send invoices, and record expenses.',
                      style: AppType.body(size: 12.5, color: c.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < events.length; i++) ...[
                    FadeInSlide(
                      index: i,
                      child: _ActivityRow(event: events[i]),
                    ),
                    if (i < events.length - 1)
                      FadeInSlide(
                        index: i,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          child: Divider(
                              height: 1, thickness: 0.5, color: c.border),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEvent event;
  const _ActivityRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, iconBg, iconFg, amountColor, amountPrefix) = switch (event.kind) {
      ActivityKind.invoicePaid => (
        Icons.check_circle,
        c.greenSurface,
        c.green,
        c.green,
        '+',
      ),
      ActivityKind.saleLogged => (
        Icons.payments,
        c.tealSurface,
        c.tealDeep,
        c.tealDeep,
        '+',
      ),
      ActivityKind.invoiceSent => (
        Icons.description_outlined,
        c.bgInset,
        c.textMuted,
        c.textMuted,
        '',
      ),
      ActivityKind.expenseLogged => (
        Icons.receipt_long,
        c.orangeSurface,
        c.orange,
        c.rose,
        '−',
      ),
    };
    final amount = event.amount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(formatRelativeTime(event.time),
                        style:
                            AppType.body(size: 11, color: c.textFaint)),
                    if (event.subtitle != null) ...[
                      Text(' · ',
                          style: AppType.body(
                              size: 11, color: c.textFaint)),
                      Text(event.subtitle!,
                          style: AppType.body(
                              size: 11,
                              weight: FontWeight.w600,
                              color: c.rose)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (amount != null && amount > 0)
            Text('${amountPrefix}GHS ${amount.toString()}',
                style: AppType.body(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: amountColor)),
        ],
      ),
    );
  }
}
