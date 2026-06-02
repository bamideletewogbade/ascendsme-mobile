import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';
import 'verify_screen.dart';
import 'help_screen.dart';
import 'tools/invoices_screen.dart';
import 'tools/inventory_screen.dart';
import 'tools/staff_screen.dart';
import 'tools/subscription_screen.dart';
import 'tools/shop_screen.dart';
import 'tools/recurring_invoices_screen.dart';
import 'tools/receipts_screen.dart';
import 'tools/expenses_screen.dart';
import 'tools/booking_screen.dart';

/// Tools tab — replaces the old Profile tab. Serves as the operations hub:
///   - Business identity card at top
///   - Featured Shop section with prominent CTA
///   - Grid of all business tools
///   - Footer links (subscription, verification, help, sign out)
///
/// Profile/account access is handled via:
///   - [onOpenDrawer] → opens the ProfileDrawer (avatar tap)
///   - Gear icon in header → pushes SettingsScreen
class ToolsScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const ToolsScreen({super.key, this.onOpenDrawer});

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
          // ── Header card ──
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

          // ── Featured: Online Shop ──
          _ShopFeatureCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShopScreen()),
            ),
            onManageProducts: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── Tools grid ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('All tools'),
          ),
          const SizedBox(height: 12),
          _ToolGrid(onAction: (id) {
            if (id == 'booking' || id == 'projects') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${id[0].toUpperCase()}${id.substring(1)} — coming soon to mobile. Available in the web app.',
                    style: AppType.body(size: 13, color: Colors.white)),
                  backgroundColor: context.colors.navyDeep,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 3),
                ),
              );
              return;
            }
            final route = switch (id) {
              'invoicing' => MaterialPageRoute(builder: (_) => const InvoicesScreen()),
              'inventory' => MaterialPageRoute(builder: (_) => const InventoryScreen()),
              'staff'     => MaterialPageRoute(builder: (_) => const StaffScreen()),
              'shop'      => MaterialPageRoute(builder: (_) => const ShopScreen()),
              'recurring' => MaterialPageRoute(builder: (_) => const RecurringInvoicesScreen()),
              'receipts'  => MaterialPageRoute(builder: (_) => const ReceiptsScreen()),
              'expenses'  => MaterialPageRoute(builder: (_) => const ExpensesScreen()),
              'booking'   => MaterialPageRoute(builder: (_) => const BookingScreen()),
              _           => null,
            };
            if (route != null) Navigator.push(context, route);
          }),

          const SizedBox(height: 28),

          // ── Divider ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(height: 1, color: c.border),
          ),
          const SizedBox(height: 12),

          // ── Footer links ──
          _FooterLink(
            icon: Icons.workspace_premium_outlined,
            label: 'Subscription',
            trailing: business.tier,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          _FooterLink(
            icon: Icons.shield_outlined,
            label: 'Verification & funding',
            trailing: business.verified ? 'Verified' : 'Get verified',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerifyScreen()),
            ),
          ),
          _FooterLink(
            icon: Icons.help_outline,
            label: 'Help & support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),

          const SizedBox(height: 20),

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
                          style: AppType.heading(
                              size: 18, color: c.text)),
                      const SizedBox(height: 2),
                      Text(handle,
                          style: AppType.body(
                              size: 12.5, color: c.textMuted)),
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
                // Sustainability score
                Row(
                  children: [
                    Icon(Icons.eco, size: 16, color: c.green),
                    const SizedBox(width: 4),
                    Text('$sustainabilityScore',
                        style: AppType.body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: c.text)),
                  ],
                ),
                const SizedBox(width: 14),
                Row(
                  children: [
                    Icon(Icons.business, size: 14, color: c.textFaint),
                    const SizedBox(width: 4),
                    Text(industry,
                        style: AppType.body(
                            size: 12, color: c.textMuted)),
                  ],
                ),
                const Spacer(),
                if (verified)
                  AppPill('Verified',
                      tone: PillTone.navy,
                      icon: 'check_circle',
                      small: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shop feature card ──────────────────────────────────────────────────────

class _ShopFeatureCard extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onManageProducts;

  const _ShopFeatureCard({required this.onTap, required this.onManageProducts});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Row(
              children: [
                Icon(Icons.star, size: 14, color: c.amber),
                const SizedBox(width: 6),
                Text('FEATURED',
                    style: AppType.label(
                        size: 11,
                        color: c.textMuted,
                        letterSpacing: 1.2)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.navyDeep, c.navy, c.navyTint],
                ),
                boxShadow: AppShadows.navy,
              ),
              padding: const EdgeInsets.all(22),
              child: Stack(
                children: [
                  // Decorative green radial
                  Positioned(
                    top: -40,
                    right: -40,
                    child: IgnorePointer(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.green.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.storefront_outlined,
                                size: 22, color: c.green),
                          ),
                          const SizedBox(width: 12),
                          Text('Online Shop',
                              style: AppType.heading(
                                  size: 18, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Reach customers beyond your location. Set up your storefront, list products, and accept payments online — all from within AscendSME.',
                        style: AppType.body(
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.75)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: onTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 11),
                              decoration: BoxDecoration(
                                color: c.green,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: AppShadows.green,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_forward,
                                      size: 15, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text('Set up storefront',
                                      style: AppType.body(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: onManageProducts,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Manage products',
                                      style: AppType.body(
                                          size: 12.5,
                                          weight: FontWeight.w500,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tool grid ──────────────────────────────────────────────────────────────

class _ToolGrid extends StatelessWidget {
  final void Function(String) onAction;

  const _ToolGrid({required this.onAction});

  static const _tools = [
    _ToolEntry('invoicing', 'Invoicing', Icons.description_outlined, 'Send invoices & receipts', 'free'),
    _ToolEntry('inventory', 'Inventory', Icons.inventory_2_outlined, 'Stock & alerts', 'lite'),
    _ToolEntry('staff', 'Staff', Icons.people_outline, 'Manage your team', 'plus'),
    _ToolEntry('booking', 'Bookings', Icons.calendar_today_outlined, 'Client appointments', 'free'),
    _ToolEntry('projects', 'Projects', Icons.view_kanban_outlined, 'Kanban & milestones', 'plus'),
    _ToolEntry('shop', 'Online Shop', Icons.storefront_outlined, 'Listings & orders', 'lite'),
    _ToolEntry('recurring', 'Recurring', Icons.repeat, 'Retainers & standing orders', 'lite'),
    _ToolEntry('receipts', 'Receipts', Icons.receipt_long_outlined, 'All payments received', 'free'),
    _ToolEntry('expenses', 'Expenses', Icons.receipt_long, 'Track outflows', 'free'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: _tools
            .map((t) => _ToolTile(
                  entry: t,
                  onTap: () => onAction(t.id),
                ))
            .toList(),
      ),
    );
  }
}

class _ToolEntry {
  final String id, name, description, tier;
  final IconData icon;
  const _ToolEntry(this.id, this.name, this.icon, this.description, this.tier);
}

class _ToolTile extends StatelessWidget {
  final _ToolEntry entry;
  final VoidCallback onTap;

  const _ToolTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.tealSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, size: 18, color: c.tealDeep),
          ),
          const Spacer(),
          Text(entry.name,
              style: AppType.body(
                  size: 13, weight: FontWeight.w600, color: c.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(entry.description,
              style: AppType.body(size: 11, color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Footer link ────────────────────────────────────────────────────────────

class _FooterLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  const _FooterLink({
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
