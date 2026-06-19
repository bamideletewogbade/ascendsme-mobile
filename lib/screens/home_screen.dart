import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/activity.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../core/recommendations.dart';
import '../state/app_state.dart';
import 'home_skeleton.dart';
import 'recommendations_screen.dart';
import 'tools/activity_screen.dart';
import 'verify_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
        child: _SkeletonWithTimeout(
          key: ValueKey('skeleton_${state.user!.id}'),
          onRetry: state.refreshAll,
        ),
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
            const SizedBox(height: 18),
            // Daily Brief removed — AI lives in the FAB + Ask Ascend tab
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
                child: AppAvatar(business.initials, size: 42, imageUrl: business.logoUrl),
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

                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NotificationBadge(
                count: state.notificationsCount,
                onTap: () => onAction('notifications'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Notification badge (bell icon with count) ─────────────────────────────

class _NotificationBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBadge({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: c.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(Icons.notifications_outlined,
                  size: 18, color: c.textMuted),
            ),
            if (count > 0)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.rose,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bgElevated, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$count',
                    style: AppType.body(
                      size: 8,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Quick tools ────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final void Function(String) onAction;

  const _QuickActions({required this.onAction});

  static const _quickTools = [
    QuickAction(id: 'quote',    label: 'Proforma',   icon: 'request_quote', tone: 'teal'),
    QuickAction(id: 'invoice',  label: 'Invoicing',  icon: 'description',  tone: 'teal'),
    QuickAction(id: 'sale',     label: 'Log sale',   icon: 'payments',     tone: 'teal'),
    QuickAction(id: 'expense',  label: 'Expense',    icon: 'receipt',      tone: 'orange'),
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
      'medium' => c.orange,
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



// ── Cash flow snapshot ─────────────────────────────────────────────────────
// Navy-gradient hero — net cash is the hero metric. Time-range pills let the
// user switch between 1M / 3M / 6M / YTD, with change indicators vs prior
// equivalent period and compact monthly trend bars.

const _kBarMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _CashFlowHero extends StatefulWidget {
  final void Function(String) onAction;
  const _CashFlowHero({required this.onAction});

  @override
  State<_CashFlowHero> createState() => _CashFlowHeroState();
}

class _CashFlowHeroState extends State<_CashFlowHero> {
  bool _expandedPipeline = false;

  static const _periodOptions = [
    _PeriodOption(months: 1, label: '1M'),
    _PeriodOption(months: 3, label: '3M'),
    _PeriodOption(months: 6, label: '6M'),
    _PeriodOption(months: 0, label: 'YTD'),
  ];

  String _periodLabel(int months, int index) {
    final now = DateTime.now();
    if (_periodOptions[index].months == 1) {
      return 'THIS MONTH · ${_kBarMonths[now.month - 1]}';
    }
    final startM = now.month - months + 1;
    if (_periodOptions[index].months == 0) {
      return 'YTD · ${_kBarMonths[0]}–${_kBarMonths[now.month - 1]}';
    }
    return 'LAST $months MONTHS · ${_kBarMonths[startM - 1]}–${_kBarMonths[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final months = state.effectivePeriodMonths;
    final sel = state.selectedPeriodIndex;
    final summary = state.computePeriodSummary(months);
    final f = state.financials;
    final hasData = summary.revenue > 0 || summary.expenses > 0;

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
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
          child: Stack(
            children: [
              Positioned(
                top: -60, right: -60,
                child: IgnorePointer(
                  child: Container(
                    width: 220, height: 220,
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
              hasData
                  ? _activeBody(c, summary, state, f, months, sel)
                  : _emptyBody(c),
            ],
          ),
        ),
      ),
    );
  }

  // ── Period pills row ───────────────────────────────────────────────────
  Widget _periodPills(AppColorsX c, int sel, ValueChanged<int> onSelect) {
    return Row(
      children: [
        for (int i = 0; i < _periodOptions.length; i++) ...[
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: sel == i
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                _periodOptions[i].label,
                style: AppType.label(
                  size: 10,
                  color: sel == i
                      ? c.navyDeep
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Active body (has data) ─────────────────────────────────────────────
  Widget _activeBody(
      AppColorsX c, PeriodSummary summary, AppState state, Financials f,
      int months, int sel) {
    final net = summary.net;
    final netPositive = net >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period pills
        Row(
          children: [
            _periodPills(c, sel, (i) => state.setSelectedPeriod(i)),
          ],
        ),
        const SizedBox(height: 8),
        // Period label
        Text(
          _periodLabel(months, sel),
          style: AppType.label(
              size: 11, color: Colors.white.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 8),
        // Hero net cash
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${netPositive ? '' : '−'}${formatGHS(net.abs())}',
                    style: AppType.display(size: 32, color: Colors.white),
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
            const _SustainabilityRing(),
          ],
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
        const SizedBox(height: 12),
        // Revenue & Expenses with change indicators
        Row(
          children: [                Expanded(
              child: _HeroStat(
                label: 'Revenue',
                amount: formatGHS(summary.revenue),
              ),
            ),
            Container(
              width: 1, height: 36,
              color: Colors.white.withValues(alpha: 0.10),
              margin: const EdgeInsets.symmetric(horizontal: 14),
            ),
            Expanded(
              child: _HeroStat(
                label: 'Expenses',
                amount: formatGHS(summary.expenses),
              ),
            ),
          ],
        ),
        // ── Pipeline (proformas) row ──
        if (f.pipeline > 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _expandedPipeline = !_expandedPipeline),
            child: Container(
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
                  Icon(Icons.description_outlined, size: 16, color: c.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(                          '${formatGHS(f.pipeline)} in ${state.invoices.where((i) => i.isProforma).length} proforma${state.invoices.where((i) => i.isProforma).length == 1 ? '' : 's'} · awaiting client approval',
                      style: AppType.body(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: Colors.white)),
                  ),
                  GestureDetector(
                    onTap: () => widget.onAction('quote'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.teal.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('New proforma',
                          style: AppType.body(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expandedPipeline ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 16, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
          // ── Pipeline breakdown (expandable) ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _PipelineBreakdown(state: state, c: c, onViewAll: () => widget.onAction('invoicing')),
            crossFadeState: _expandedPipeline
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
        // ── Outstanding invoices row ──
        if (f.outstanding > 0) ...[
          const SizedBox(height: 12),
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
                    onTap: () => widget.onAction('followup'),
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

  // ── Empty body ────────────────────────────────────────────────────────
  Widget _emptyBody(AppColorsX c) {
    final state = context.watch<AppState>();
    final months = state.effectivePeriodMonths;
    final sel = state.selectedPeriodIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _periodPills(c, sel, (i) => state.setSelectedPeriod(i)),
        const SizedBox(height: 10),
        Text(
          _periodLabel(months, sel),
          style: AppType.label(
              size: 11, color: Colors.white.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 14),
        Text('Start your records',
            style: AppType.heading(size: 22, color: Colors.white)),
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
              onTap: () => widget.onAction('sale'),
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
              onTap: () => widget.onAction('invoice'),
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
                    Text('Create invoice',
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

// ── Pipeline breakdown (expandable inside cash flow hero) ──────────────────

class _PipelineBreakdown extends StatelessWidget {
  final AppState state;
  final AppColorsX c;
  final VoidCallback? onViewAll;

  const _PipelineBreakdown({required this.state, required this.c, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final proformas = state.invoices.where((i) => i.isProforma).toList();
    if (proformas.isEmpty) return const SizedBox.shrink();

    // Aggregate by customer
    final Map<String, List<Invoice>> byCustomer = {};
    for (final p in proformas) {
      byCustomer.putIfAbsent(p.customer, () => []).add(p);
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final entry in byCustomer.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            style: AppType.body(
                                size: 12.5,
                                weight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85))),
                      ),
                      Text(
                        formatGHS(entry.value.fold<num>(0,
                            (s, p) => s + p.amount)),
                        style: AppType.mono(
                            size: 12,
                            weight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      if (entry.value.length > 1)
                        SizedBox(
                          width: 32,
                          child: Text('×${entry.value.length}',
                              textAlign: TextAlign.right,
                              style: AppType.body(
                                  size: 10,
                                  color:
                                      Colors.white.withValues(alpha: 0.5))),
                        ),
                    ],
                  ),
                  // ── Expiry badges per quote ──
                  for (final p in entry.value)
                    if (p.validUntil != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _ExpiryBadgeSmall(
                          validUntil: p.validUntil!,
                          isExpired: p.validUntil!.isBefore(DateTime.now()),
                        ),
                      ),
                ],
              ),
            ),
            if (entry.key != byCustomer.keys.last)
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.white.withValues(alpha: 0.08)),
          ],
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onViewAll,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new,
                    size: 12, color: c.teal.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text('View all in invoicing',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.teal.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expiry badge (small, for pipeline breakdown) ───────────────────────────

class _ExpiryBadgeSmall extends StatelessWidget {
  final DateTime validUntil;
  final bool isExpired;

  const _ExpiryBadgeSmall({
    required this.validUntil,
    required this.isExpired,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final daysLeft = validUntil.difference(DateTime.now()).inDays;
    final expiringSoon = !isExpired && daysLeft >= 0 && daysLeft <= 7;

    if (!isExpired && !expiringSoon) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isExpired ? Icons.warning_amber_rounded : Icons.schedule,
          size: 10,
          color: isExpired ? c.rose : c.amber,
        ),
        const SizedBox(width: 3),
        Text(
          isExpired
              ? 'Expired ${formatLongDate(validUntil)}'
              : 'Expiring in $daysLeft day${daysLeft == 1 ? '' : 's'}',
          style: AppType.body(
            size: 9.5,
            color: isExpired ? c.rose : c.amber,
          ),
        ),
      ],
    );
  }
}

// ── Period option config ─────────────────────────────────────────────────────

class _PeriodOption {
  final int months; // 0 means YTD (year-to-date)
  final String label;
  const _PeriodOption({required this.months, required this.label});
}

// ── Hero stat with optional change indicator ─────────────────────────────────

class _HeroStat extends StatelessWidget {
  final String label;
  final String amount;

  const _HeroStat({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
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

// ── Sustainability score ring ─────────────────────────────────────────────
/// Shows the business's sustainability score with tier progress. Replaces
/// the verification steps ring — score is the more actionable home metric.

const _kRingSize = 96.0;
const _kRingStroke = 7.0;

class _SustainabilityRing extends StatelessWidget {
  const _SustainabilityRing();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final score = state.business.creditScore;
    final tier = getTier(score);
    final nextTier = getNextTier(score);

    final progress = nextTier != null
        ? ((score - tier.min) / (nextTier.min - tier.min)).clamp(0.0, 1.0)
        : 1.0;
    final tierColor = Color(tier.color);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VerifyScreen()),
      ),
      child: SizedBox(
        width: _kRingSize + 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _kRingSize,
              height: _kRingSize,
              child: CustomPaint(
                painter: _RingPainter(share: progress, color: tierColor),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score',
                          style: AppType.display(size: 24, color: Colors.white)),
                      const SizedBox(height: 0),
                      Text('/ 850',
                          style: AppType.body(
                              size: 9,
                              weight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



/// Generic circular progress painter — draws a track ring and a filled arc.
/// Reused by [TierRing] in common.dart via a different painter.
class _RingPainter extends CustomPainter {
  final double share;
  final Color color;
  const _RingPainter({required this.share, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kRingStroke
      ..color = Colors.white.withValues(alpha: 0.14);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kRingStroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final c = (Offset.zero & size).center;
    final r = (size.shortestSide - _kRingStroke) / 2;
    canvas.drawCircle(c, r, track);
    final sweep = 2 * 3.141592653589793 * share.clamp(0.0, 1.0);
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
      conversionEvents: state.conversionEvents,
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
      ActivityKind.quoteCreated => (
        Icons.description_outlined,
        c.tealSurface,
        c.tealDeep,
        c.tealDeep,
        '',
      ),
      ActivityKind.quoteExpired => (
        Icons.warning_amber_rounded,
        c.rose.withValues(alpha: 0.12),
        c.rose,
        c.rose,
        '',
      ),
      ActivityKind.quoteConverted => (
        Icons.north_east,
        c.greenSurface,
        c.green,
        c.green,
        '',
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

// ── Skeleton with timeout ────────────────────────────────────────────────────

/// Shows [HomeSkeleton] initially, then switches to a network-error state with
/// a retry button after 15 seconds if the business profile still hasn't loaded.
/// Prevents the "stuck in white loading state" problem when Supabase is
/// unreachable and no cached profile exists.
class _SkeletonWithTimeout extends StatefulWidget {
  final VoidCallback onRetry;
  const _SkeletonWithTimeout({super.key, required this.onRetry});

  @override
  State<_SkeletonWithTimeout> createState() => _SkeletonWithTimeoutState();
}

class _SkeletonWithTimeoutState extends State<_SkeletonWithTimeout> {
  static const _timeout = Duration(seconds: 15);
  bool _timedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_timedOut) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: c.textFaint),
                  const SizedBox(height: 16),
                  Text('Unable to load your profile',
                      style: AppType.heading(size: 18, color: c.text)),
                  const SizedBox(height: 8),
                  Text(
                    'We couldn\'t reach our servers. Check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: AppType.body(size: 13, color: c.textMuted),
                  ),
                  const SizedBox(height: 24),
                  AppBtn('Retry', onTap: widget.onRetry),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const HomeSkeleton();
  }
}
