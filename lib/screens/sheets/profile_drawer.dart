import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';
import '../help_screen.dart';
import '../settings_screen.dart';
import '../tools/subscription_screen.dart';

class ProfileDrawer extends StatelessWidget {
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onSignOut;

  const ProfileDrawer({
    super.key,
    required this.open,
    required this.onClose,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();

    final drawerWidth = MediaQuery.of(context).size.width * 0.82;
    final c = context.colors;

    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: Colors.black.withValues(alpha: 0.48)),
        ),
        Positioned(
          left: 0, top: 0, bottom: 0,
          width: drawerWidth,
          child: Material(
            color: c.bgElevated,
            child: SafeArea(
              child: _DrawerContent(onClose: onClose, onSignOut: onSignOut),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSignOut;

  const _DrawerContent({required this.onClose, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: c.bgInset,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 18, color: c.textMuted),
              ),
            ),
          ),
        ),

        // ── Profile header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(state.business.initials, size: 54),
              const SizedBox(height: 12),
              Text(state.business.name,
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 2),
              Text(state.business.handle,
                  style: AppType.body(size: 13, color: c.textMuted)),
            ],
          ),
        ),

        // ── Subscription badge card ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: _SubscriptionBadge(
            tierLabel: state.business.tier,
            subscription: state.subscription,
            onTap: () {
              onClose();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
          ),
        ),

        Divider(color: c.border, height: 1),

        // ── Menu label ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('Menu',
              style: AppType.label(size: 10.5, color: c.textMuted)),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _DrawerSwitch(
                icon: Icons.dark_mode_outlined,
                label: 'Dark mode',
                value: state.darkMode,
                onChanged: state.setDark,
              ),
              _DrawerSection(label: 'Navigation style'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: NavVariant.values.map((nav) {
                    final label = switch (nav) {
                      NavVariant.classic => 'Classic',
                      NavVariant.pill    => 'Pill',
                      NavVariant.fab     => 'FAB',
                    };
                    final active = state.navVariant == nav;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => state.setNavVariant(nav),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? c.text : c.bgInset,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(label,
                              style: AppType.body(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: active
                                      ? c.bgElevated
                                      : c.textMuted)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  onClose();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              _DrawerItem(
                icon: Icons.help_outline,
                label: 'Help & support',
                onTap: () {
                  onClose();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HelpScreen()),
                  );
                },
              ),
            ],
          ),
        ),

        Divider(color: c.border, height: 1),

        GestureDetector(
          onTap: onSignOut,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
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
      ],
    );
  }
}

// ── Subscription badge ──────────────────────────────────────────────────────
class _SubscriptionBadge extends StatelessWidget {
  final String tierLabel;
  final SubscriptionInfo? subscription;
  final VoidCallback onTap;

  const _SubscriptionBadge({
    required this.tierLabel,
    this.subscription,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isFree = subscription == null || subscription!.tierCode == 'free';
    final premiumColor = isFree ? c.teal : c.green;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFree
                ? [c.bgInset, c.tealSurface]
                : [c.navySurface, c.bgInset],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFree
                ? c.tealSurfaceStrong
                : c.green.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isFree ? c.teal : c.green).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFree
                    ? Icons.favorite_outline
                    : Icons.workspace_premium,
                size: 18,
                color: premiumColor,
              ),
            ),
            const SizedBox(width: 12),
            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tierLabel,
                    style: AppType.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isFree
                        ? 'Tap to upgrade'
                        : 'Tap to manage plan',
                    style: AppType.body(
                      size: 11,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // CTA
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isFree ? c.teal : c.bgInset,
                borderRadius: BorderRadius.circular(8),
                border: isFree
                    ? null
                    : Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFree ? 'Upgrade' : 'Manage',
                    style: AppType.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: isFree ? Colors.white : c.text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: isFree ? Colors.white : c.textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drawer section label ────────────────────────────────────────────────────
class _DrawerSection extends StatelessWidget {
  final String label;
  const _DrawerSection({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(label,
          style: AppType.label(size: 10.5, color: c.textMuted)),
    );
  }
}

class _DrawerSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DrawerSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, size: 20, color: c.textMuted),
        title: Text(label,
            style: AppType.body(
                size: 14, weight: FontWeight.w500, color: c.text)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: c.teal,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        dense: true,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DrawerItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, size: 20, color: c.textMuted),
        title: Text(label,
            style: AppType.body(
                size: 14, weight: FontWeight.w500, color: c.text)),
        trailing: Icon(Icons.chevron_right, size: 18, color: c.textFaint),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        dense: true,
        onTap: onTap ?? () {},
      ),
    );
  }
}
