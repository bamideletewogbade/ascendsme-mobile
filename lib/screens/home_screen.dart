import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import '../core/recommendations.dart';
import '../state/app_state.dart';
import 'home_skeleton.dart';
import 'recommendations_screen.dart';

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
      return const HomeSkeleton();
    }
    final recs = buildRecommendations(
      business: state.business,
      financials: state.financials,
      invoices: state.invoices,
    );
    final showAllLink = recs.length > 3;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _Header(onOpenDrawer: onOpenDrawer, onAction: onAction),
          const SizedBox(height: 16),
          const _CashFlow(),
          const SizedBox(height: 22),
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
          ...recs.take(3).map(
                (r) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _RecommendationCard(rec: r, onAction: onAction),
                ),
              ),
          const SizedBox(height: 8),
          const _DailyBrief(),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final business = state.business;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenDrawer,
            child: AppAvatar(business.initials, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    state.firstName != null
                        ? '$_greeting, ${state.firstName}'
                        : _greeting,
                    style: AppType.heading(size: 15, color: c.text)),
                Text(business.name,
                    style: AppType.body(size: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onAction('notifications'),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: c.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.notifications_outlined, size: 18, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ──────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final void Function(String) onAction;

  const _QuickActions({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Quick actions'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            // Slightly taller than wide so 2-line labels ("New invoice",
            // "Log expense") fit without overflowing the 36px icon + 6px
            // gap + 2-line text stack.
            childAspectRatio: 0.85,
            children: kQuickActions
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
    final (tone, dotColor) = switch (rec.priority) {
      'urgent' => (PillTone.rose, c.rose),
      'high'   => (PillTone.orange, c.orange),
      'medium' => (PillTone.amber, c.amber),
      _        => (PillTone.teal, c.teal),
    };
    final priorityLabel = rec.priority[0].toUpperCase() + rec.priority.substring(1);

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
              AppPill(priorityLabel, tone: tone, small: true),
              const Spacer(),
              Text('${rec.minutes} min',
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
          Row(
            children: [
              AppBtn(
                rec.cta,
                variant: BtnVariant.secondary,
                fontSize: 12.5,
                onTap: () => onAction(rec.id),
              ),
              const SizedBox(width: 8),
              AppPill(rec.impact, tone: PillTone.green, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Daily brief ────────────────────────────────────────────────────────────
class _DailyBrief extends StatefulWidget {
  const _DailyBrief();

  @override
  State<_DailyBrief> createState() => _DailyBriefState();
}

class _DailyBriefState extends State<_DailyBrief> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tip = kTips[_idx % kTips.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        background: c.tealSurface,
        border: Border.all(color: c.tealSurfaceStrong),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: c.tealDeep),
                const SizedBox(width: 6),
                Text('Daily brief',
                    style: AppType.body(
                        size: 12, weight: FontWeight.w700, color: c.tealDeep)),
                const Spacer(),
                AppPill(tip.tag, tone: PillTone.teal, small: true),
              ],
            ),
            const SizedBox(height: 10),
            Text(tip.text, style: AppType.body(size: 13, color: c.text)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _idx++),
              child: Text('Next tip →',
                  style: AppType.body(
                      size: 12, weight: FontWeight.w600, color: c.tealDeep)),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Cash flow snapshot ─────────────────────────────────────────────────────
class _CashFlow extends StatelessWidget {
  const _CashFlow();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final f = state.financials;
    final loading = state.financialsLoading;
    final outstandingSub = _outstandingSubtitle(f);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Cash flow — ${currentMonthShort()}'),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: _CashTile(
                    label: 'Revenue',
                    amount: formatGHS(f.revenueThisMonth),
                    changePct: f.revenueChangePctVsLastMonth,
                    loading: loading,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: _CashTile(
                    label: 'Expenses',
                    amount: formatGHS(f.expensesThisMonth),
                    changePct: f.expensesChangePctVsLastMonth,
                    // For expenses, "down vs. last month" is the good direction.
                    inverted: true,
                    loading: loading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding',
                          style: AppType.body(size: 11.5, color: c.textMuted)),
                      const SizedBox(height: 4),
                      Text(formatGHS(f.outstanding),
                          style: AppType.heading(size: 18, color: c.text)),
                      Text(outstandingSub,
                          style: AppType.body(size: 11.5, color: c.textMuted)),
                    ],
                  ),
                ),
                if (f.outstandingOverdueCount > 0)
                  AppPill('Follow up', tone: PillTone.rose, small: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _outstandingSubtitle(Financials f) {
    if (f.outstandingCount == 0) return 'No open invoices';
    final invoiceWord = f.outstandingCount == 1 ? 'invoice' : 'invoices';
    if (f.outstandingOverdueCount == 0) {
      return '${f.outstandingCount} $invoiceWord · all on track';
    }
    return '${f.outstandingCount} $invoiceWord · ${f.outstandingOverdueCount} overdue';
  }
}

class _CashTile extends StatelessWidget {
  final String label, amount;
  final double? changePct;
  final bool inverted;
  final bool loading;

  const _CashTile({
    required this.label,
    required this.amount,
    required this.changePct,
    this.inverted = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final changeText = formatChangePct(changePct);
    // Up = green when not inverted (revenue going up is good).
    // Up = red when inverted (expenses going up is bad).
    final isPositive = (changePct ?? 0) > 0;
    final isGood = inverted ? !isPositive : isPositive;
    final showChange = changeText != null && !loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.body(size: 11.5, color: c.textMuted)),
        const SizedBox(height: 4),
        Text(amount, style: AppType.heading(size: 16, color: c.text)),
        const SizedBox(height: 4),
        if (showChange)
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 13, color: isGood ? c.green : c.rose),
              const SizedBox(width: 3),
              Text(changeText,
                  style: AppType.body(
                      size: 11, color: isGood ? c.green : c.rose)),
            ],
          )
        else if (loading)
          Text('Loading…',
              style: AppType.body(size: 11, color: c.textFaint))
        else
          Text('No prior month',
              style: AppType.body(size: 11, color: c.textFaint)),
      ],
    );
  }
}
