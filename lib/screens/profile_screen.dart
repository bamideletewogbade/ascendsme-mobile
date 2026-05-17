import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'verify_screen.dart';

/// Profile tab — the catch-all for things that aren't core day-to-day usage:
/// business identity, verification status, settings, help, and sign-out.
/// VerifyScreen and HelpScreen are kept as pushable sub-screens to preserve
/// the work already done on them.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out',
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.rose)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<AppState>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final business = state.business;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text('Profile',
                style: AppType.display(size: 28, color: c.text)),
          ),

          // Identity card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(business.initials, size: 54),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(business.name,
                                style:
                                    AppType.heading(size: 17, color: c.text)),
                            const SizedBox(height: 2),
                            Text(business.handle,
                                style: AppType.body(
                                    size: 12.5, color: c.textMuted)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (business.verified)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: AppPill('Verified',
                                        tone: PillTone.teal,
                                        icon: 'check_circle',
                                        small: true),
                                  ),
                                AppPill(business.tier,
                                    tone: PillTone.neutral, small: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: c.border),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _IdentityStat(
                          label: 'Industry',
                          value: business.industry,
                        ),
                      ),
                      Container(
                          width: 1, height: 30, color: c.border),
                      Expanded(
                        child: _IdentityStat(
                          label: 'City',
                          value: business.city,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Sections
          _SectionLabel('Account'),
          _ProfileRow(
            icon: Icons.shield_outlined,
            iconColor: c.teal,
            label: 'Verification & funding',
            trailing: business.verified ? 'Verified' : 'Get verified',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyScreen()),
            ),
          ),
          _ProfileRow(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),

          const SizedBox(height: 18),
          _SectionLabel('Support'),
          _ProfileRow(
            icon: Icons.help_outline,
            label: 'Help & support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),

          const SizedBox(height: 28),

          // Sign out
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
        ],
      ),
    );
  }
}

// ── Internals ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Text(label,
          style: AppType.label(size: 11, color: c.textMuted)),
    );
  }
}

class _IdentityStat extends StatelessWidget {
  final String label, value;
  const _IdentityStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppType.body(size: 11, color: c.textMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: AppType.body(
                size: 13, weight: FontWeight.w600, color: c.text)),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: AppCard(
        onTap: onTap,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppType.body(
                      size: 14, weight: FontWeight.w500, color: c.text)),
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
