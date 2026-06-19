import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';
import 'verify_screen.dart';
import 'help_screen.dart';
import 'tools/subscription_screen.dart';

/// Profile tab — business identity, subscription, verification, and support.
/// No duplication of records/readiness data — the dedicated verify screen
/// handles that.
class ProfileScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const ProfileScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final business = state.business;
    final tier = getTier(business.creditScore);

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
            verified: business.verified,
            tierLabel: tier.label,
            logoUrl: business.logoUrl,
            onAvatarTap: onOpenDrawer,
            onSettingsTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 20),

          // ── Section: Account ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('Account'),
          ),
          _ProfileLink(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription',
            subtitle: business.tier,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          _ProfileLink(
            icon: Icons.shield_outlined,
            label: 'Verification',
            subtitle: business.verified ? 'Verified' : 'Complete verification steps',
            trailing:
                '${(context.read<AppState>().verificationProgress * 100).round()}%',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyScreen()),
            ),
          ),
          const SizedBox(height: 20),

          // ── Ask Ascend quick access ──
          _AskAscendCard(onOpenChat: () {
            context.read<AppState>().setTab(AppTab.askAscend);
          }),
          const SizedBox(height: 20),

          // ── Section: Support ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('Support'),
          ),
          _ProfileLink(
            icon: Icons.help_outline,
            label: 'Help & support',
            subtitle: 'FAQs, guides, email support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          _ProfileLink(
            icon: Icons.info_outline,
            label: 'About AscendSME',
            subtitle: 'v1.0.0',
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
  final String initials, name, handle, industry, tierLabel;
  final bool verified;
  final String? logoUrl;
  final VoidCallback? onAvatarTap, onSettingsTap;

  const _IdentityCard({
    required this.initials,
    required this.name,
    required this.handle,
    required this.industry,
    required this.verified,
    required this.tierLabel,
    this.logoUrl,
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
                  child: AppAvatar(
                    initials,
                    size: 52,
                    imageUrl: logoUrl,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: AppType.heading(size: 18, color: c.text),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          AppPill(tierLabel,
                              tone: PillTone.teal, small: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(handle,
                          style: AppType.body(size: 12.5, color: c.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSettingsTap,
                  child: Container(
                    width: 36,
                    height: 36,
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
                Icon(Icons.business, size: 14, color: c.textFaint),
                const SizedBox(width: 6),
                Text(industry,
                    style: AppType.body(size: 12.5, color: c.textMuted)),
                const SizedBox(width: 10),
                Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                        color: c.textFaint, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                if (verified)
                  AppPill('Verified',
                      tone: PillTone.teal,
                      icon: 'check_circle',
                      small: true),
                if (!verified)
                  AppPill('Foundation', tone: PillTone.amber, small: true),
              ],
            ),
          ],
        ),
      ),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.navy, c.navyDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 22, color: Colors.white),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: c.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Chat',
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: Colors.white)),
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
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  const _ProfileLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppType.body(
                          size: 14,
                          weight: FontWeight.w500,
                          color: c.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: AppType.body(size: 12, color: c.textMuted)),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, size: 18, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}
