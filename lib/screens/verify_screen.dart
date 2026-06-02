import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import '../state/app_state.dart';
import 'verify_step_screen.dart';

class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final business = state.business;
    final tier = getTier(business.sustainabilityScore);
    final next = getNextTier(business.sustainabilityScore);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Records & Readiness',
                style: AppType.display(size: 28, color: c.text)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              "Keep your records up to date so you're ready when a grant or lender opportunity comes your way. You don't have to apply for anything yet — just keep going.",
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ),

          // Trust profile card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      TierRing(
                          score: business.sustainabilityScore,
                          initials: business.initials,
                          size: 56),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(business.name,
                                style: AppType.heading(size: 16, color: c.text)),
                            Text(business.handle,
                                style:
                                    AppType.body(size: 12, color: c.textMuted)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (business.verified)
                                  AppPill('Verified',
                                      tone: PillTone.teal,
                                      icon: 'check_circle'),
                                const SizedBox(width: 6),
                                AppPill(tier.label, tone: PillTone.neutral,
                                    small: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatBox(
                          label: 'Sustainability',
                          value: '${business.sustainabilityScore}',
                          sub: '/ 100'),
                      Container(
                          width: 1, height: 36, color: c.border,
                          margin: const EdgeInsets.symmetric(horizontal: 12)),
                      _StatBox(
                          label: 'Credit score',
                          value: '${business.creditScore}',
                          sub: '/ 850'),
                      Container(
                          width: 1, height: 36, color: c.border,
                          margin: const EdgeInsets.symmetric(horizontal: 12)),
                      _StatBox(
                          label: 'Tier',
                          value: tier.label,
                          sub: next != null ? '→ ${next.label}' : 'Top tier'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Pillar breakdown — surfaces the four underlying scores that feed
          // sustainability_score. Web's scoring engine weights them: F 30%,
          // C 30%, O 25%, G 15% — the bar widths mirror those weights so the
          // user sees which pillars matter most for their stage upgrade.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Score breakdown'),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                  child: Column(
                    children: [
                      _PillarRow(
                        label: 'Financial Integrity',
                        weight: '30%',
                        score: business.scoreF,
                        hint: 'Invoices, ledger, bank statements',
                      ),
                      _PillarRow(
                        label: 'Compliance',
                        weight: '30%',
                        score: business.scoreC,
                        hint: 'TIN, RGD, Ghana Card, address',
                      ),
                      _PillarRow(
                        label: 'Operational Velocity',
                        weight: '25%',
                        score: business.scoreO,
                        hint: 'Bookings, quotes, fulfillment',
                      ),
                      _PillarRow(
                        label: 'Governance Stability',
                        weight: '15%',
                        score: business.scoreG,
                        hint: 'Staff, profile, sustainable expenses',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Verification checklist
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Verification checklist'),
                ...kVerificationSteps.map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _VerifyRow(
                        step: step,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VerifyStepScreen(step: step),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Funding pathway
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Funding pathway'),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: kFundingStages
                        .map((stage) => _FundingRow(stage: stage))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Funding opportunities — placeholder until we curate a real list
          // (grants like Tony Elumelu Foundation, MasterCard Foundation, GIRSAL,
          // industry-specific programs). The previous "Matched lenders" UI
          // showed real-looking offers with a stubbed Apply button, which is
          // worse than no list at all.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Funding opportunities'),
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings_outlined,
                              size: 22, color: c.navyDeep),
                          const SizedBox(width: 10),
                          Text('Coming soon',
                              style: AppType.heading(
                                  size: 15, color: c.text)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We're curating grants, accelerators, and SME-friendly programs (Tony Elumelu Foundation, MasterCard Foundation, GIRSAL, industry-specific funds) and will surface the ones that fit your business here.",
                        style:
                            AppType.body(size: 13, color: c.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'In the meantime, complete your checklist above so you\'re ready when an opportunity lands.',
                        style: AppType.body(
                            size: 12.5, color: c.textFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value, sub;

  const _StatBox(
      {required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppType.heading(size: 20, color: c.text)),
          Text(sub, style: AppType.body(size: 10.5, color: c.textFaint)),
          const SizedBox(height: 3),
          Text(label,
              style: AppType.body(size: 10.5, color: c.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _VerifyRow extends StatelessWidget {
  final VerificationStep step;
  final VoidCallback onTap;

  const _VerifyRow({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, iconColor, tone) = switch (step.status) {
      'verified' => (Icons.check_circle, c.green, PillTone.green),
      'pending'  => (Icons.access_time, c.amber, PillTone.amber),
      _          => (Icons.radio_button_unchecked, c.textFaint, PillTone.neutral),
    };
    final badgeLabel = switch (step.status) {
      'verified' => 'Done',
      'pending'  => 'Pending',
      _          => 'To-do',
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text)),
                Text(step.detail,
                    style: AppType.body(size: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          AppPill(badgeLabel, tone: tone, small: true),
        ],
      ),
    );
  }
}

class _PillarRow extends StatelessWidget {
  final String label;
  final String weight;
  final int score; // 0-100
  final String hint;

  const _PillarRow({
    required this.label,
    required this.weight,
    required this.score,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (score.clamp(0, 100)) / 100.0;
    // Bar color grades with progress so users can read "low / mid / high" at
    // a glance without reading the number. Below 40 = neutral, 40-79 = teal
    // (growth band), 80+ = green (verified band) — mirrors the tier_status
    // grey/teal/indigo thresholds on the web side.
    final barColor = score >= 80
        ? c.green            : score >= 40
                ? c.teal
                : c.borderStrong;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text)),
              ),
              Text('$score',
                  style: AppType.mono(size: 13, color: c.text)),
              Text(' / 100',
                  style: AppType.body(size: 11.5, color: c.textFaint)),
              const SizedBox(width: 8),
              AppPill(weight, tone: PillTone.neutral, small: true),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: c.bgInset),
                LayoutBuilder(
                  builder: (_, constraints) => Container(
                    height: 6,
                    width: constraints.maxWidth * pct,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(hint,
              style: AppType.body(size: 11.5, color: c.textMuted)),
        ],
      ),
    );
  }
}

class _FundingRow extends StatelessWidget {
  final FundingStage stage;

  const _FundingRow({required this.stage});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = stage.status == 'done';
    final active = stage.status == 'active';
    final dotColor =
        done ? c.green : active ? c.teal : c.borderStrong;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: done || active ? dotColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: done || active
                      ? null
                      : Border.all(color: c.borderStrong, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : active
                        ? null
                        : null,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.label,
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: done || active ? c.text : c.textMuted)),
                if (stage.detail.isNotEmpty)
                  Text(stage.detail,
                      style: AppType.body(size: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          if (active) AppPill('Active', tone: PillTone.teal, small: true),
          if (done) AppPill('Done', tone: PillTone.green, small: true),
        ],
      ),
    );
  }
}

