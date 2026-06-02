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

/// Profile tab — the business identity hub. Shows the business card,
/// subscription status, verification progress, and links to settings/help.
class ProfileScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const ProfileScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final business = state.business;

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

          const SizedBox(height: 24),

          // ── Sign out ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => _confirmSignOut(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: c.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.rose.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 18, color: c.rose),
                    const SizedBox(width: 10),
                    Text('Sign out',
                        style: AppType.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: c.rose)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?',
            style: AppType.heading(size: 17, color: c.text)),
        content: Text(
          'You will need to sign in again to access your business.',
          style: AppType.body(size: 13, color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.rose)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<AppState>().signOut();
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
