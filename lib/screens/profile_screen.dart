import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../state/app_state.dart';
import '../core/mock_data.dart';
import 'settings_screen.dart';
import 'verify_screen.dart';
import 'help_screen.dart';
import 'tools/subscription_screen.dart';

/// Profile tab — the merged business hub. Shows business identity, records &
/// readiness (merged from Verify), and support access (merged from Help).
/// Also includes a prominent Ask Ascend entry point.
class ProfileScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const ProfileScreen({super.key, this.onOpenDrawer});

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
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── Identity card ──
          _IdentityCard(
            initials: business.initials,
            name: business.name,
            handle: business.handle,
            industry: business.industry,
            tier: business.tier,
            verified: business.verified,
            sustainabilityScore: business.sustainabilityScore,
            onAvatarTap: onOpenDrawer,
            onSettingsTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // ── Stats row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Sustainability',
                    value: '${business.sustainabilityScore}/850',
                    icon: Icons.eco,
                    color: c.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Credit score',
                    value: '${business.creditScore}',
                    icon: Icons.trending_up,
                    color: c.teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Records & Readiness (merged from Verify) ──
          _RecordsSection(business: business, tier: tier, next: next),
          const SizedBox(height: 20),

          // ── Ask Ascend quick access ──
          _AskAscendCard(onOpenChat: () {
            context.read<AppState>().setTab(AppTab.askAscend);
          }),
          const SizedBox(height: 20),

          // ── Section: Business ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('Business'),
          ),
          _ProfileLink(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription',
            trailing: business.tier,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          _ProfileLink(
            icon: Icons.shield_outlined,
            label: 'Verification & funding',
            trailing: business.verified ? 'Verified' : 'Get verified',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyScreen()),
            ),
          ),
          const SizedBox(height: 20),

          // ── Section: Support ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('Support'),
          ),
          _ProfileLink(
            icon: Icons.help_outline,
            label: 'Help & support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          _ProfileLink(
            icon: Icons.info_outline,
            label: 'About AscendSME',
            trailing: 'v1.0.0',
            onTap: () {},
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Identity card ──────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  final String initials, name, handle, industry, tier;
  final bool verified;
  final int sustainabilityScore;
  final VoidCallback? onAvatarTap, onSettingsTap;

  const _IdentityCard({
    required this.initials,
    required this.name,
    required this.handle,
    required this.industry,
    required this.tier,
    required this.verified,
    required this.sustainabilityScore,
    this.onAvatarTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: AppAvatar(initials, size: 52),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppType.heading(size: 18, color: c.text)),
                      const SizedBox(height: 2),
                      Text(handle,
                          style: AppType.body(size: 12.5, color: c.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSettingsTap,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.settings_outlined,
                        size: 18, color: c.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: c.border),
            const SizedBox(height: 14),
            Row(
              children: [
                Row(
                  children: [
                    Icon(Icons.eco, size: 16, color: c.green),
                    const SizedBox(width: 4),
                    Text('$sustainabilityScore',
                        style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text)),
                  ],
                ),
                const SizedBox(width: 14),
                Row(
                  children: [
                    Icon(Icons.business, size: 14, color: c.textFaint),
                    const SizedBox(width: 4),
                    Text(industry,
                        style: AppType.body(size: 12, color: c.textMuted)),
                  ],
                ),
                const Spacer(),
                if (verified)
                  AppPill('Verified',
                      tone: PillTone.navy, icon: 'check_circle', small: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppType.body(size: 10.5, color: c.textMuted)),
                const SizedBox(height: 2),
                Text(value,
                    style: AppType.body(size: 14, weight: FontWeight.w700, color: c.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Records & Readiness section (merged from Verify) ──────────────────────

class _RecordsSection extends StatelessWidget {
  final Business business;
  final ScoreTier tier;
  final ScoreTier? next;

  const _RecordsSection({
    required this.business,
    required this.tier,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final verifiedCount = kVerificationSteps.where((s) => s.status == 'verified').length;
    final totalSteps = kVerificationSteps.length;
    final progress = verifiedCount / totalSteps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Records & Readiness'),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // Score ring + foundation indicator
                Row(
                  children: [
                    TierRing(
                        score: business.sustainabilityScore,
                        initials: business.initials,
                        size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(tier.label,
                                  style: AppType.heading(size: 15, color: c.text)),
                              const SizedBox(width: 6),
                              if (business.verified)
                                AppPill('Verified', tone: PillTone.green, small: true, icon: 'check_circle')
                              else
                                AppPill('Foundation', tone: PillTone.amber, small: true),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            next != null
                                ? '${verifiedCount}/$totalSteps steps · Next: ${next!.label}'
                                : '$verifiedCount/$totalSteps steps · Top tier',
                            style: AppType.body(size: 12, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 6, color: c.bgInset),
                      LayoutBuilder(
                        builder: (_, constraints) => Container(
                          height: 6,
                          width: constraints.maxWidth * progress,
                          color: progress >= 0.8 ? c.green : c.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Pillar scores compact
                _CompactPillar(
                  label: 'Financial Integrity',
                  score: business.scoreF,
                  hint: 'Invoices, ledger, bank statements',
                ),
                const SizedBox(height: 8),
                _CompactPillar(
                  label: 'Compliance',
                  score: business.scoreC,
                  hint: 'TIN, RGD, Ghana Card, address',
                ),
                const SizedBox(height: 8),
                _CompactPillar(
                  label: 'Operational Velocity',
                  score: business.scoreO,
                  hint: 'Bookings, quotes, fulfillment',
                ),
                const SizedBox(height: 8),
                _CompactPillar(
                  label: 'Governance Stability',
                  score: business.scoreG,
                  hint: 'Staff, profile, sustainable expenses',
                ),
                const SizedBox(height: 14),

                // Full verification link
                AppBtn(
                  'View full readiness report',
                  full: true,
                  variant: BtnVariant.secondary,
                  icon: 'arrow_forward',
                  fontSize: 12.5,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VerifyScreen()),
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

class _CompactPillar extends StatelessWidget {
  final String label;
  final int score;
  final String hint;

  const _CompactPillar({
    required this.label,
    required this.score,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (score.clamp(0, 100)) / 100.0;
    final barColor = score >= 80
        ? c.green : score >= 40 ? c.teal : c.borderStrong;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: AppType.body(size: 11.5, color: c.text),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 5, color: c.bgInset),
                LayoutBuilder(
                  builder: (_, constraints) => Container(
                    height: 5,
                    width: constraints.maxWidth * pct,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$score',
            style: AppType.mono(size: 11, color: c.text)),
      ],
    );
  }
}

// ── Ask Ascend card ─────────────────────────────────────────────────────────

class _AskAscendCard extends StatelessWidget {
  final VoidCallback onOpenChat;
  const _AskAscendCard({required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.navy, c.navyDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Ascend AI',
                      style: AppType.heading(size: 15, color: c.text)),
                  const SizedBox(height: 2),
                  Text('Get instant answers about your business, 24/7',
                      style: AppType.body(size: 12, color: c.textMuted)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onOpenChat,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: c.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Chat',
                    style: AppType.body(size: 13, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile link row ────────────────────────────────────────────────────────

class _ProfileLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _ProfileLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppType.body(size: 14, weight: FontWeight.w500, color: c.text)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: AppType.body(size: 12.5, color: c.textMuted)),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, size: 18, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}
