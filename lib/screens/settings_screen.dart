import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final email = state.user?.email;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Settings', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ── Account ─────────────────────────────────────────────
                  _SectionLabel('Account'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email ?? '—',
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        _SettingsRow(
                          icon: Icons.business_outlined,
                          label: 'Business',
                          value: state.business.name,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Appearance ──────────────────────────────────────────
                  _SectionLabel('Appearance'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: _ThemeToggle(
                      value: state.darkMode,
                      onChanged: state.setDark,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── About ───────────────────────────────────────────────
                  _SectionLabel('About'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: _SettingsRow(
                      icon: Icons.info_outline,
                      label: 'App version',
                      value: '1.0.0',
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Sign out ────────────────────────────────────────────
                  _SignOutButton(
                    onTap: () => _confirmSignOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
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

    // Pop back to root before clearing auth — keeps the Navigator stack clean
    // when _AuthGate switches us to SignInScreen.
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<AppState>().signOut();
  }
}

// ── Internals ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(label, style: AppType.label(size: 11, color: c.textMuted)),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: AppType.body(
                    size: 14, weight: FontWeight.w500, color: c.text)),
          ),
          Text(value,
              style: AppType.body(size: 13, color: c.textMuted),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ThemeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.dark_mode_outlined, size: 20, color: c.textMuted),
          const SizedBox(width: 16),
          Expanded(
            child: Text('Dark mode',
                style: AppType.body(
                    size: 14, weight: FontWeight.w500, color: c.text)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: c.teal,
            activeTrackColor: c.tealSurface,
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
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
                    size: 14, weight: FontWeight.w600, color: c.rose)),
          ],
        ),
      ),
    );
  }
}
