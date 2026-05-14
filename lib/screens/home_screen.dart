import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import '../state/app_state.dart';

class HomeScreen extends StatelessWidget {
  final void Function(String) onAction;
  final void Function(String) onTool;
  final VoidCallback onOpenDrawer;

  const HomeScreen({
    super.key,
    required this.onAction,
    required this.onTool,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.watch<AppState>().homeLayout;
    return switch (layout) {
      HomeLayout.score  => _ScoreLayout(onAction: onAction, onTool: onTool, onOpenDrawer: onOpenDrawer),
      HomeLayout.agenda => _AgendaLayout(onAction: onAction, onTool: onTool, onOpenDrawer: onOpenDrawer),
      HomeLayout.cards  => _CardsLayout(onAction: onAction, onTool: onTool, onOpenDrawer: onOpenDrawer),
    };
  }
}

// ── Shared header ────────────────────────────────────────────────────────────
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenDrawer,
            child: TierRing(score: state.score, initials: kBusiness.initials, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_greeting, Adwoa',
                    style: AppType.heading(size: 15, color: c.text)),
                Text(kBusiness.name,
                    style: AppType.body(size: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          StreakChip(days: state.streak),
          const SizedBox(width: 8),
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

// ── Layout switcher ───────────────────────────────────────────────────────────
class _LayoutSwitcher extends StatelessWidget {
  const _LayoutSwitcher();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    const layouts = [
      (HomeLayout.score,  'Score'),
      (HomeLayout.agenda, 'Agenda'),
      (HomeLayout.cards,  'Cards'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: layouts.map((item) {
          final active = state.homeLayout == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => state.setHomeLayout(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? c.teal : c.bgElevated,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: active ? c.teal : c.border),
                ),
                child: Text(item.$2,
                    style: AppType.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: active ? Colors.white : c.textMuted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Sustainability dial ───────────────────────────────────────────────────────
class _SustainabilityDial extends StatelessWidget {
  final int score;
  final VoidCallback? onTap;

  const _SustainabilityDial({required this.score, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tier = getTier(score);
    final next = getNextTier(score);
    final tierColor = Color(tier.color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            SizedBox(
              width: 180, height: 140,
              child: CustomPaint(
                painter: _DialPainter(
                  score: score.toDouble(),
                  fillColor: tierColor,
                  trackColor: c.bgInset,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$score',
                            style: AppType.display(size: 44, color: c.text)),
                        Text('/100',
                            style: AppType.body(size: 12, color: c.textFaint)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: tierColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(tier.label,
                    style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
                const SizedBox(width: 8),
                AppPill(kBusiness.tier, tone: PillTone.teal, small: true),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 6),
              Text(
                'Next: ${next.label} at ${next.min} · ${next.min - score} pts to go',
                style: AppType.body(size: 11.5, color: c.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: c.tealSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: c.tealDeep),
                    const SizedBox(width: 6),
                    Text('Explain my score',
                        style: AppType.body(
                            size: 12.5, weight: FontWeight.w600, color: c.tealDeep)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double score;
  final Color fillColor;
  final Color trackColor;

  const _DialPainter({
    required this.score,
    required this.fillColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 14);
    final radius = size.width * 0.41;
    const startAngle = math.pi * (150 / 180);
    const totalSweep = math.pi * (240 / 180);
    final fillSweep = totalSweep * (score / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, totalSweep, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    if (score > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, fillSweep, false,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.score != score || old.fillColor != fillColor;
}

// ── Quick actions ─────────────────────────────────────────────────────────────
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

// ── Daily quests card ─────────────────────────────────────────────────────────
class _DailyQuests extends StatelessWidget {
  final void Function(String) onAction;

  const _DailyQuests({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quests = context.watch<AppState>().quests;
    final done = quests.where((q) => q.done).length;
    final remaining = quests.where((q) => !q.done).fold(0, (s, q) => s + q.pts);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Today's quests",
                            style: AppType.heading(size: 15, color: c.text)),
                        const SizedBox(height: 2),
                        Text('$done of ${quests.length} done',
                            style: AppType.body(size: 11.5, color: c.textMuted)),
                      ],
                    ),
                  ),
                  if (remaining > 0)
                    AppPill('+$remaining pts available', tone: PillTone.teal, small: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: done / quests.length,
                  minHeight: 4,
                  backgroundColor: c.bgInset,
                  valueColor: AlwaysStoppedAnimation(c.teal),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...quests.map((q) => _QuestRow(quest: q, onAction: onAction)),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final Quest quest;
  final void Function(String) onAction;

  const _QuestRow({required this.quest, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: quest.done ? null : () => onAction(quest.action),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: quest.done ? c.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: quest.done ? c.teal : c.borderStrong, width: 1.5),
              ),
              child: quest.done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quest.title,
                      style: AppType.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: quest.done ? c.textFaint : c.text)),
                  Text(quest.detail,
                      style: AppType.body(size: 11, color: c.textMuted)),
                ],
              ),
            ),
            AppPill('+${quest.pts} pts', tone: PillTone.teal, small: true),
          ],
        ),
      ),
    );
  }
}

// ── Recommendation card ───────────────────────────────────────────────────────
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
              AppBtn(rec.cta, variant: BtnVariant.secondary, fontSize: 12.5),
              const SizedBox(width: 8),
              AppPill(rec.impact, tone: PillTone.green, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Daily brief ───────────────────────────────────────────────────────────────
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

// ── Activity feed ─────────────────────────────────────────────────────────────
class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Recent activity'),
          ...kActivity.map((item) => _ActivityRow(item: item)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityItem item;
  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dotColor = switch (item.kind) {
      'payment' => c.green,
      'alert'   => c.amber,
      'booking' => c.teal,
      _         => c.textMuted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(item.text, style: AppType.body(size: 13, color: c.text))),
          const SizedBox(width: 8),
          Text(item.time, style: AppType.body(size: 11.5, color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Cash flow snapshot ────────────────────────────────────────────────────────
class _CashFlow extends StatelessWidget {
  const _CashFlow();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Cash flow — May'),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: _CashTile(
                      label: 'Revenue', amount: 'GHS 18,420', change: '+12%', up: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: _CashTile(
                      label: 'Expenses', amount: 'GHS 9,840', change: '+3%', up: false),
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
                      Text('GHS 4,280',
                          style: AppType.heading(size: 18, color: c.text)),
                      Text('3 invoices · 1 overdue',
                          style: AppType.body(size: 11.5, color: c.textMuted)),
                    ],
                  ),
                ),
                AppPill('Follow up', tone: PillTone.rose, small: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashTile extends StatelessWidget {
  final String label, amount, change;
  final bool up;

  const _CashTile(
      {required this.label,
      required this.amount,
      required this.change,
      required this.up});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.body(size: 11.5, color: c.textMuted)),
        const SizedBox(height: 4),
        Text(amount, style: AppType.heading(size: 16, color: c.text)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(up ? Icons.trending_up : Icons.trending_down,
                size: 13, color: up ? c.green : c.rose),
            const SizedBox(width: 3),
            Text(change,
                style: AppType.body(size: 11, color: up ? c.green : c.rose)),
          ],
        ),
      ],
    );
  }
}

// ── Invoice row (used in Cards layout) ───────────────────────────────────────
class _InvoiceRow extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (tone, label) = switch (invoice.status) {
      'paid'    => (PillTone.green, 'Paid'),
      'overdue' => (PillTone.rose, 'Overdue'),
      'sent'    => (PillTone.orange, 'Sent'),
      _         => (PillTone.neutral, 'Draft'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.customer,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text)),
                Text(invoice.id,
                    style: AppType.mono(size: 10.5, color: c.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('GHS ${invoice.amount}',
                  style: AppType.body(
                      size: 13, weight: FontWeight.w600, color: c.text)),
              AppPill(label, tone: tone, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Score layout ──────────────────────────────────────────────────────────────
class _ScoreLayout extends StatelessWidget {
  final void Function(String) onAction;
  final void Function(String) onTool;
  final VoidCallback onOpenDrawer;

  const _ScoreLayout(
      {required this.onAction, required this.onTool, required this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final score = context.watch<AppState>().score;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _Header(onOpenDrawer: onOpenDrawer, onAction: onAction),
          const _LayoutSwitcher(),
          const SizedBox(height: 8),
          _SustainabilityDial(score: score, onTap: () => onAction('askAI')),
          const SizedBox(height: 20),
          _QuickActions(onAction: onAction),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SectionHeader('Recommendations', action: 'View all'),
          ),
          ...kRecommendations.take(2).map(
            (r) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _RecommendationCard(rec: r, onAction: onAction),
            ),
          ),
          const SizedBox(height: 4),
          _DailyQuests(onAction: onAction),
          const SizedBox(height: 20),
          const _DailyBrief(),
          const SizedBox(height: 20),
          const _ActivityFeed(),
        ],
      ),
    );
  }
}

// ── Agenda layout ─────────────────────────────────────────────────────────────
class _AgendaLayout extends StatelessWidget {
  final void Function(String) onAction;
  final void Function(String) onTool;
  final VoidCallback onOpenDrawer;

  const _AgendaLayout(
      {required this.onAction, required this.onTool, required this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _Header(onOpenDrawer: onOpenDrawer, onAction: onAction),
          const _LayoutSwitcher(),
          const SizedBox(height: 8),
          const _CashFlow(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text("Today's focus",
                style: AppType.heading(size: 17, color: c.text)),
          ),
          _DailyQuests(onAction: onAction),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Top actions', style: AppType.heading(size: 17, color: c.text)),
          ),
          ...kRecommendations.take(3).map(
            (r) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _RecommendationCard(rec: r, onAction: onAction),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cards layout ──────────────────────────────────────────────────────────────
class _CardsLayout extends StatelessWidget {
  final void Function(String) onAction;
  final void Function(String) onTool;
  final VoidCallback onOpenDrawer;

  const _CardsLayout(
      {required this.onAction, required this.onTool, required this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final tier = getTier(state.score);
    final tierColor = Color(tier.color);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _Header(onOpenDrawer: onOpenDrawer, onAction: onAction),
          const _LayoutSwitcher(),
          const SizedBox(height: 8),
          // Score card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  TierRing(
                      score: state.score, initials: kBusiness.initials, size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${state.score}/100 · ${tier.label}',
                            style: AppType.heading(size: 16, color: c.text)),
                        const SizedBox(height: 2),
                        Text('Sustainability score',
                            style: AppType.body(size: 12, color: c.textMuted)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: state.score / 100,
                            minHeight: 6,
                            backgroundColor: c.bgInset,
                            valueColor: AlwaysStoppedAnimation(tierColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Invoicing card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c.tealSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:
                            Icon(Icons.description_outlined, size: 18, color: c.tealDeep),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invoicing',
                              style: AppType.heading(size: 15, color: c.text)),
                          Text('GHS 4,280 outstanding',
                              style: AppType.body(size: 12, color: c.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...kInvoices
                      .take(3)
                      .map((inv) => _InvoiceRow(invoice: inv)),
                  const SizedBox(height: 8),
                  AppBtn('New invoice',
                      icon: 'add',
                      onTap: () => onAction('invoice'),
                      fontSize: 13),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Recommendations card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top recommendations',
                      style: AppType.heading(size: 15, color: c.text)),
                  const SizedBox(height: 12),
                  ...kRecommendations
                      .take(2)
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecommendationCard(rec: r, onAction: onAction),
                          )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quick actions
          _QuickActions(onAction: onAction),
        ],
      ),
    );
  }
}
