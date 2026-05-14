import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import '../state/app_state.dart';

class VerifyScreen extends StatelessWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final tier = getTier(state.score);
    final next = getNextTier(state.score);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text('Verify & Trust',
                style: AppType.display(size: 28, color: c.text)),
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
                          score: state.score,
                          initials: kBusiness.initials,
                          size: 56),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kBusiness.name,
                                style: AppType.heading(size: 16, color: c.text)),
                            Text(kBusiness.handle,
                                style:
                                    AppType.body(size: 12, color: c.textMuted)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (kBusiness.verified)
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
                          value: '${state.score}',
                          sub: '/ 100'),
                      Container(
                          width: 1, height: 36, color: c.border,
                          margin: const EdgeInsets.symmetric(horizontal: 12)),
                      _StatBox(
                          label: 'Credit score',
                          value: '${kBusiness.creditScore}',
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

          // Verification checklist
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Verification checklist'),
                ...kVerificationSteps
                    .map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _VerifyRow(step: step),
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

          // Matched lenders
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Matched lenders'),
                ...kLenders.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LenderCard(lender: l),
                    )),
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

  const _VerifyRow({required this.step});

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

class _LenderCard extends StatelessWidget {
  final Lender lender;

  const _LenderCard({required this.lender});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lender.name,
                        style: AppType.body(
                            size: 14, weight: FontWeight.w700, color: c.text)),
                    Text(lender.product,
                        style: AppType.body(size: 12, color: c.textMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: c.tealSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${lender.match}% match',
                    style: AppType.body(
                        size: 12, weight: FontWeight.w700, color: c.tealDeep)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Max loan',
                      style: AppType.body(size: 11, color: c.textMuted)),
                  Text(
                      'GHS ${(lender.max / 1000).toStringAsFixed(0)}k',
                      style: AppType.body(
                          size: 14, weight: FontWeight.w600, color: c.text)),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Interest rate',
                      style: AppType.body(size: 11, color: c.textMuted)),
                  Text('${lender.rate} p.a.',
                      style: AppType.body(
                          size: 14, weight: FontWeight.w600, color: c.text)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppBtn('View offer →', variant: BtnVariant.outline, fontSize: 13),
        ],
      ),
    );
  }
}
