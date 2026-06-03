import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';
import 'tools/invoices_screen.dart';
import 'tools/inventory_screen.dart';
import 'tools/staff_screen.dart';
import 'tools/subscription_screen.dart';
import 'tools/shop_screen.dart';
import 'tools/booking_screen.dart';
import 'tools/cash_flow_screen.dart';
import 'tools/documents_screen.dart';
import 'tools/crm_screen.dart';
import 'tools/project_screen.dart';

/// Tools tab — shows all available business tools with plan-based availability
/// and a search/filter bar.
class ToolsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const ToolsScreen({super.key, this.onOpenDrawer});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// The canonical tool list matching the user's requested tools.
  /// Tier requirements: 'free' (always), 'lite', 'plus', 'elite'.
  static const _allTools = [
    _ToolEntry('invoicing', 'Invoicing', Icons.description_outlined, 'Create & send invoices, track payments', 'free'),
    _ToolEntry('booking', 'Booking Portal', Icons.calendar_today_outlined, 'Client appointments & scheduling', 'free'),
    _ToolEntry('documents', 'Document Vault', Icons.folder_outlined, 'Upload & manage business documents', 'lite'),
    _ToolEntry('shop', 'My Shop', Icons.storefront_outlined, 'Online storefront & order management', 'lite'),
    _ToolEntry('crm', 'CRM', Icons.people_outline, 'Customer management & insights', 'free'),
    _ToolEntry('finance', 'Finance & Accounting', Icons.account_balance_wallet_outlined, 'Cash flow, receipts, expense tracking', 'free'),
    _ToolEntry('inventory', 'Inventory', Icons.inventory_2_outlined, 'Stock tracking & low-stock alerts', 'lite'),
    _ToolEntry('projects', 'Project Management', Icons.view_kanban_outlined, 'Task boards & milestone tracking', 'plus'),
    _ToolEntry('staff', 'HRM & Staff', Icons.people_outline, 'Team management & payroll', 'plus'),
  ];

  /// Map the display tier string back to a tier code.
  static String _tierCode(String displayTier) {
    if (displayTier.contains('Elite')) return 'elite';
    if (displayTier.contains('Plus')) return 'plus';
    if (displayTier.contains('Lite')) return 'lite';
    return 'free';
  }

  static bool _toolAvailable(String toolTier, String businessTierCode) {
    const tierOrder = ['free', 'lite', 'plus', 'elite'];
    final toolIdx = tierOrder.indexOf(toolTier);
    final bizIdx = tierOrder.indexOf(businessTierCode);
    if (toolIdx == -1 || bizIdx == -1) return toolTier == 'free';
    return toolIdx <= bizIdx;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final business = state.business;
    final tierCode = _tierCode(business.tier);

    final totalTools = _allTools.length;
    final availableTools = _allTools.where((t) => _toolAvailable(t.tier, tierCode)).length;

    // Filter by search query
    final filteredTools = _searchQuery.isEmpty
        ? _allTools
        : _allTools.where((t) =>
            t.name.toLowerCase().contains(_searchQuery) ||
            t.description.toLowerCase().contains(_searchQuery)).toList();

    void navigateTool(String id) {
      if (id == 'projects' && !_toolAvailable('plus', tierCode)) {
        _showLockedSnackBar(context, 'Project Management requires the Plus plan');
        return;
      }
      final route = switch (id) {
        'invoicing' => MaterialPageRoute(builder: (_) => const InvoicesScreen()),
        'inventory' => MaterialPageRoute(builder: (_) => const InventoryScreen()),
        'staff'     => MaterialPageRoute(builder: (_) => const StaffScreen()),
        'shop'      => MaterialPageRoute(builder: (_) => const ShopScreen()),
        'booking'   => MaterialPageRoute(builder: (_) => const BookingScreen()),
        'documents' => MaterialPageRoute(builder: (_) => const DocumentsScreen()),
        'crm'       => MaterialPageRoute(builder: (_) => const CrmScreen()),
        'finance'   => MaterialPageRoute(builder: (_) => const CashFlowForecastScreen()),
        'projects'  => MaterialPageRoute(builder: (_) => const ProjectScreen()),
        _           => null,
      };
      if (route != null) Navigator.push(context, route);
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── Identity card with plan display ──
          _IdentityCard(
            initials: business.initials,
            name: business.name,
            handle: business.handle,
            industry: business.industry,
            tier: business.tier,
            tierCode: tierCode,
            verified: business.verified,
            onAvatarTap: widget.onOpenDrawer,
            onSettingsTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),

          const SizedBox(height: 20),

          // ── Plan availability banner ──
          _PlanBanner(
            totalTools: totalTools,
            availableTools: availableTools,
            tier: business.tier,
            tierCode: tierCode,
            onUpgrade: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),

          const SizedBox(height: 20),

          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SearchBar(controller: _searchCtrl),
          ),

          const SizedBox(height: 20),

          // ── Tools grid ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
              _searchQuery.isEmpty
                  ? 'All tools ($totalTools)'
                  : '${filteredTools.length} tool${filteredTools.length == 1 ? '' : 's'} found',
            ),
          ),
          const SizedBox(height: 12),
          if (filteredTools.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 36, color: c.textFaint),
                    const SizedBox(height: 8),
                    Text('No tools match "$_searchQuery"',
                        style: AppType.body(size: 13, color: c.textMuted)),
                  ],
                ),
              ),
            )
          else
            _ToolGrid(
              tools: filteredTools,
              tierCode: tierCode,
              onAction: navigateTool,
            ),

          const SizedBox(height: 28),

          // ── Want different tools? ──
          _ExploreToolsCard(
            onUpgrade: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showLockedSnackBar(BuildContext context, String msg) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, size: 18, color: c.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppType.body(size: 14, color: c.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search tools…',
                hintStyle: AppType.body(size: 14, color: c.textFaint),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () => controller.clear(),
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.close, size: 16, color: c.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Identity card ──────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  final String initials, name, handle, industry, tier, tierCode;
  final bool verified;
  final VoidCallback? onAvatarTap, onSettingsTap;

  const _IdentityCard({
    required this.initials,
    required this.name,
    required this.handle,
    required this.industry,
    required this.tier,
    required this.tierCode,
    required this.verified,
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
                          style: AppType.heading(size: 17, color: c.text)),
                      const SizedBox(height: 1),
                      Text(handle,
                          style: AppType.body(size: 12, color: c.textMuted)),
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
                    child: Icon(Icons.settings_outlined, size: 18, color: c.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: c.border),
            const SizedBox(height: 14),
            Row(
              children: [
                // Plan pill — prominently shows the current plan
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _planColor(tierCode, c).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _planColor(tierCode, c).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 14, color: _planColor(tierCode, c)),
                      const SizedBox(width: 5),
                      Text(tier,
                          style: AppType.body(size: 11.5, weight: FontWeight.w700, color: _planColor(tierCode, c))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (verified)
                  AppPill('Verified', tone: PillTone.green, icon: 'check_circle', small: true),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.business, size: 14, color: c.textFaint),
                    const SizedBox(width: 4),
                    Text(industry,
                        style: AppType.body(size: 12, color: c.textMuted)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _planColor(String code, AppColorsX c) {
    switch (code) {
      case 'free': return c.teal;
      case 'lite': return c.blue;
      case 'plus': return c.amber;
      case 'elite': return c.green;
      default: return c.textMuted;
    }
  }
}

// ── Plan availability banner ───────────────────────────────────────────────

class _PlanBanner extends StatelessWidget {
  final int totalTools, availableTools;
  final String tier, tierCode;
  final VoidCallback onUpgrade;

  const _PlanBanner({
    required this.totalTools,
    required this.availableTools,
    required this.tier,
    required this.tierCode,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final allAvailable = availableTools == totalTools;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.navySurface, c.navySurfaceStrong],
            ),
            border: Border.all(color: c.navySurfaceStrong),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c.navyDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.workspace_premium_outlined, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$availableTools of $totalTools tools',
                      style: AppType.body(size: 14, weight: FontWeight.w700, color: c.navyDeep),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allAvailable
                          ? 'All tools unlocked on your $tier plan'
                          : '$availableTools available on your $tier plan',
                      style: AppType.body(size: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              if (!allAvailable) ...[
                GestureDetector(
                  onTap: onUpgrade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.navyDeep,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Upgrade',
                        style: AppType.body(size: 12, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Explore tools card ─────────────────────────────────────────────────────

class _ExploreToolsCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _ExploreToolsCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: c.amber),
                const SizedBox(width: 10),
                Text('Want different tools?',
                    style: AppType.body(size: 15, weight: FontWeight.w600, color: c.text)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "We're building new tools every month. If there's a specific feature your business needs — or you'd like access to tools on a higher plan — let us know and we'll help find the right fit.",
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                AppBtn('View plans',
                    variant: BtnVariant.primary,
                    fontSize: 12.5,
                    icon: 'crown',
                    onTap: onUpgrade),
                const SizedBox(width: 10),
                AppBtn('Suggest a tool',
                    variant: BtnVariant.secondary,
                    fontSize: 12.5,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tool suggestions — coming soon.',
                              style: AppType.body(size: 13, color: Colors.white)),
                          backgroundColor: c.navyDeep,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tool grid ──────────────────────────────────────────────────────────────

class _ToolGrid extends StatelessWidget {
  final List<_ToolEntry> tools;
  final String tierCode;
  final void Function(String) onAction;

  const _ToolGrid({
    required this.tools,
    required this.tierCode,
    required this.onAction,
  });

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
        children: tools
            .map((t) => _ToolTile(
                  entry: t,
                  available: _toolAvailable(t.tier, tierCode),
                  onTap: () => onAction(t.id),
                ))
            .toList(),
      ),
    );
  }

  bool _toolAvailable(String toolTier, String businessTierCode) {
    const tierOrder = ['free', 'lite', 'plus', 'elite'];
    final toolIdx = tierOrder.indexOf(toolTier);
    final bizIdx = tierOrder.indexOf(businessTierCode);
    if (toolIdx == -1 || bizIdx == -1) return toolTier == 'free';
    return toolIdx <= bizIdx;
  }
}

class _ToolEntry {
  final String id, name, description, tier;
  final IconData icon;
  const _ToolEntry(this.id, this.name, this.icon, this.description, this.tier);
}

class _ToolTile extends StatelessWidget {
  final _ToolEntry entry;
  final bool available;
  final VoidCallback onTap;

  const _ToolTile({required this.entry, required this.available, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = available ? c.tealDeep : c.textFaint;
    final iconBg = available ? c.tealSurface : c.bgInset;

    return AppCard(
      onTap: available ? onTap : null,
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(entry.icon, size: 18, color: iconColor),
                  ),
                  const Spacer(),
                  if (!available)
                    Icon(Icons.lock_outline, size: 14, color: c.textFaint),
                ],
              ),
              const Spacer(),
              Text(entry.name,
                  style: AppType.body(size: 13, weight: FontWeight.w600,
                      color: available ? c.text : c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              if (available)
                Text(entry.description,
                    style: AppType.body(size: 11, color: c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)
              else
                Text('${_tierLabel(entry.tier)} plan',
                    style: AppType.body(size: 11, weight: FontWeight.w600, color: c.textFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'lite': return 'Lite';
      case 'plus': return 'Plus';
      case 'elite': return 'Elite';
      default: return 'Free';
    }
  }
}
