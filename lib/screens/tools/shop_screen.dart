import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';
import '../sheets/add_product_sheet.dart';
import 'inventory_screen.dart';

/// Online Shop management screen — pushed from the Tools tab.
///
/// Mirrors the AscendSME web platform's shop. Key features:
///   - Toggle storefront draft/live
///   - Product listing synced to inventory (Add product opens AddProductSheet)
///   - Order management with tabs (Pending → Processing → Shipped → Delivered)
///   - Store sharing via WhatsApp / clipboard
///   - Store settings (name, description, payment status)
///
/// The shop is an extension of the Inventory system. Products listed here
/// are InventoryItems; adding a product here is the same as adding inventory.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tabIndex = 0;
  bool _isLive = false; // TBD: persist to backend

  // Mock orders for display — will be replaced by a real orders table.
  static const _mockOrders = [
    _OrderEntry('ORD-001', 'Akua Mensah', 340, 'processing', '2 hrs ago'),
    _OrderEntry('ORD-002', 'Kofi Asante', 1250, 'pending', '5 hrs ago'),
    _OrderEntry('ORD-003', 'Esi Boateng', 780, 'shipped', '1 day ago'),
    _OrderEntry('ORD-004', 'Yaw Osei', 2100, 'delivered', '2 days ago'),
    _OrderEntry('ORD-005', 'Abena Owusu', 560, 'pending', '3 days ago'),
  ];

  @override
  void initState() {
    super.initState();
    // Ensure inventory is loaded so products are available.
    final state = context.read<AppState>();
    if (state.inventory.isEmpty) {
      state.loadInventory();
    }
  }

  void _toggleStorefront() async {
    final c = context.colors;
    if (_isLive) {
      // Going from live to draft: simple switch, no warning.
      setState(() => _isLive = false);
    } else {
      // Going from draft to live: confirm (real businesses should set up payment first)
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.bgElevated,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Go live?',
              style: AppType.heading(size: 17, color: c.text)),
          content: Text(
            'Your storefront will be visible to customers. Make sure your products have prices before going live.',
            style: AppType.body(size: 13, color: c.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Not yet',
                  style: AppType.body(
                      size: 13, weight: FontWeight.w600, color: c.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Go live',
                  style: AppType.body(
                      size: 13, weight: FontWeight.w600, color: c.green)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        setState(() => _isLive = true);
      }
    }
  }

  void _shareStorefront(BuildContext context) {
    final c = context.colors;
    final state = context.read<AppState>();
    final handle = state.business.handle.replaceFirst('@', '');
    final url = 'https://ascendsme.africa/store/$handle';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text('Share your storefront',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 4),
            Text(
              'Let customers browse your products online.',
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 18),
            // WhatsApp
            _ShareOption(
              icon: Icons.chat,
              label: 'Share via WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(ctx);
                _launchWhatsApp(url);
              },
            ),
            const SizedBox(height: 8),
            // Copy link
            _ShareOption(
              icon: Icons.link,
              label: 'Copy storefront link',                  color: c.teal,
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Link copied!',
                        style: AppType.body(size: 13, color: Colors.white)),
                    backgroundColor: c.tealDeep,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _launchWhatsApp(String url) {
    // Build a message with the store link.
    final text = Uri.encodeComponent(
        'Check out my store on AscendSME! Browse my products and place an order: $url');
    final whatsappUrl = 'https://wa.me/?text=$text';
    // Fallback: copy to clipboard since we can't reliably launch external URLs
    // from Flutter without url_launcher package.
    Clipboard.setData(ClipboardData(text: '$url\n\nBrowse my products on AscendSME!'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Store link copied! Paste it in WhatsApp to share.',
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _addProduct(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddProductSheet(),
    );
    if (!mounted) return;
    // Refresh inventory to show new product in the shop.
    context.read<AppState>().loadInventory();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final inventory = state.inventory;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            SubScreenHeader(
              'Online Shop',
              onBack: () => Navigator.pop(context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Share button
                  GestureDetector(
                    onTap: () => _shareStorefront(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.share_outlined,
                          size: 17, color: c.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StoreToggle(isLive: _isLive, onToggle: _toggleStorefront),
                ],
              ),
            ),

            // ── Tab bar ──
            _TabBar(
              tabs: const ['Products', 'Orders', 'Settings'],
              selected: _tabIndex,
              onSelect: (i) => setState(() => _tabIndex = i),
            ),

            // ── Content ──
            Expanded(
              child: _tabIndex == 0
                  ? _buildProductsTab(context, c, inventory)
                  : _tabIndex == 1
                      ? _buildOrdersTab(context, c)
                      : _buildSettingsTab(context, c, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab(
      BuildContext context, AppColorsX c, List<InventoryItem> inventory) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: 16),

        // ── Status card ──
        _StoreStatusCard(
          inventoryCount: inventory.length,
          isLive: _isLive,
        ),

        const SizedBox(height: 20),

        // ── Stats row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Products',
                      value: '${inventory.length}',
                      icon: Icons.inventory_2_outlined)),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'Orders',
                      value: '${_mockOrders.length}',
                      icon: Icons.receipt_outlined)),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatCard(
                      label: 'Revenue',
                      value: 'GHS ${_totalRevenue()}',
                      icon: Icons.trending_up)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Products section ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionHeader(
                inventory.isEmpty ? 'Products' : 'Products (${inventory.length})',
              ),
              GestureDetector(
                onTap: () => _addProduct(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.navySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.navySurfaceStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: c.navyDeep),
                      const SizedBox(width: 4),
                      Text('Add',
                          style: AppType.body(
                              size: 12,
                              weight: FontWeight.w600,
                              color: c.navyDeep)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (inventory.isEmpty)
          _EmptyProductsState(onAddProduct: () => _addProduct(context))
        else
          ...inventory.take(4).map((item) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _ProductCard(item: item),
              )),

        if (inventory.length > 4)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppBtn(
                'View all ${inventory.length} products',
                variant: BtnVariant.secondary,
                full: true,
                fontSize: 13,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOrdersTab(BuildContext context, AppColorsX c) {
    final pending = _mockOrders
        .where((o) => o.status == 'pending')
        .toList();
    final active = _mockOrders
        .where((o) => o.status == 'processing' || o.status == 'shipped')
        .toList();
    final delivered =
        _mockOrders.where((o) => o.status == 'delivered').toList();

    // Status count badges
    final statusCounts = {
      'pending': _mockOrders.where((o) => o.status == 'pending').length,
      'processing': _mockOrders.where((o) => o.status == 'processing').length,
      'shipped': _mockOrders.where((o) => o.status == 'shipped').length,
      'delivered': _mockOrders.where((o) => o.status == 'delivered').length,
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: 16),

        // ── Status chips ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _OrderStatChip(
                  label: 'Pending',
                  count: statusCounts['pending']!,
                  color: c.amber,
                  bg: c.amberSurface),
              const SizedBox(width: 8),
              _OrderStatChip(
                  label: 'Processing',
                  count: statusCounts['processing']!,
                  color: c.blue,
                  bg: c.blueSurface),
              const SizedBox(width: 8),
              _OrderStatChip(
                  label: 'Shipped',
                  count: statusCounts['shipped']!,
                  color: c.navy,
                  bg: c.navySurface),
              const SizedBox(width: 8),
              _OrderStatChip(
                  label: 'Delivered',
                  count: statusCounts['delivered']!,
                  color: c.green,
                  bg: c.greenSurface),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Section: New / Pending ──
        if (pending.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Pending',
                style: AppType.heading(size: 15, color: c.text)),
          ),
          const SizedBox(height: 8),
          ...pending.map((o) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _OrderCard(order: o),
              )),
          const SizedBox(height: 12),
        ],

        // ── Section: Active (processing + shipped) ──
        if (active.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('In progress',
                style: AppType.heading(size: 15, color: c.text)),
          ),
          const SizedBox(height: 8),
          ...active.map((o) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _OrderCard(order: o),
              )),
          const SizedBox(height: 12),
        ],

        // ── Section: Delivered ──
        if (delivered.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Completed',
                style: AppType.heading(size: 15, color: c.text)),
          ),
          const SizedBox(height: 8),
          ...delivered.map((o) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _OrderCard(order: o),
              )),
          const SizedBox(height: 12),
        ],


      ],
    );
  }

  Widget _buildSettingsTab(BuildContext context, AppColorsX c, AppState state) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: 16),

        // ── Store info ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Store details',
              style: AppType.heading(size: 15, color: c.text)),
        ),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.store_outlined,
          label: 'Store name',
          value: state.business.name,
          onTap: () => _showComingSoon(context, 'Edit store name'),
        ),
        _SettingTile(
          icon: Icons.description_outlined,
          label: 'Description',
          value: 'Tell customers about your business…',
          onTap: () => _showComingSoon(context, 'Edit store description'),
        ),
        _SettingTile(
          icon: Icons.link,
          label: 'Storefront URL',
          value: 'ascendsme.africa/store/${state.business.handle.replaceFirst('@', '')}',
          onTap: () => _shareStorefront(context),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Payments',
              style: AppType.heading(size: 15, color: c.text)),
        ),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.payments_outlined,
          label: 'Payment method',
          value: 'Not set up',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.amberSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Setup',
                style: AppType.body(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: c.amber)),
          ),
          onTap: () => _showComingSoon(context, 'Payment setup'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 54),
          child: Text(
            'Connect Paystack or MoMo to accept payments online.',
            style: AppType.body(size: 11.5, color: c.textFaint),
          ),
        ),

        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Shipping',
              style: AppType.heading(size: 15, color: c.text)),
        ),
        const SizedBox(height: 8),
        _SettingTile(
          icon: Icons.local_shipping_outlined,
          label: 'Delivery options',
          value: 'Not configured',
          onTap: () => _showComingSoon(context, 'Delivery settings'),
        ),

        const SizedBox(height: 28),
        // ── Toggle storefront ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Storefront status',
                          style: AppType.body(
                              size: 14,
                              weight: FontWeight.w500,
                              color: c.text)),
                      const SizedBox(height: 3),
                      Text(
                        _isLive
                            ? 'Your store is live and visible to customers.'
                            : 'Only you can see your store. Go live when ready.',
                        style: AppType.body(size: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: _isLive,
                  activeColor: c.green,
                  onChanged: (_) => _toggleStorefront(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _totalRevenue() {
    return _mockOrders.fold(0, (sum, o) => sum + o.amount);
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon',
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Order entry model ──────────────────────────────────────────────────────

class _OrderEntry {
  final String id, customer, status, timeAgo;
  final int amount;

  const _OrderEntry(this.id, this.customer, this.amount, this.status, this.timeAgo);

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending';
      case 'processing': return 'Processing';
      case 'shipped': return 'Shipped';
      case 'delivered': return 'Delivered';
      default: return status;
    }
  }
}

// ── Tab bar ─────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const _TabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? c.bgElevated : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(color: c.border)
                      : null,
                  boxShadow: active ? AppShadows.card : null,
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: AppType.body(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: active ? c.text : c.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Store toggle widget ────────────────────────────────────────────────────

class _StoreToggle extends StatelessWidget {
  final bool isLive;
  final VoidCallback onToggle;

  const _StoreToggle({required this.isLive, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isLive ? c.greenSurface : c.bgInset,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isLive ? c.green : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isLive ? c.green : c.textFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isLive ? 'Live' : 'Draft',
              style: AppType.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: isLive ? c.green : c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Store status card ──────────────────────────────────────────────────────

class _StoreStatusCard extends StatelessWidget {
  final int inventoryCount;
  final bool isLive;

  const _StoreStatusCard({required this.inventoryCount, required this.isLive});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasProducts = inventoryCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLive
                    ? c.greenSurface
                    : (hasProducts ? c.blueSurface : c.amberSurface),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isLive
                    ? Icons.rocket_launch_outlined
                    : (hasProducts
                        ? Icons.check_circle_outline
                        : Icons.spa_outlined),
                size: 24,
                color: isLive
                    ? c.green
                    : (hasProducts ? c.blue : c.amber),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLive
                        ? 'Store is live! 🎉'
                        : (hasProducts
                            ? '$inventoryCount products ready'
                            : 'No products yet'),
                    style: AppType.body(
                        size: 14, weight: FontWeight.w600, color: c.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isLive
                        ? 'Customers can browse and order from your storefront.'
                        : (hasProducts
                            ? 'Set up payment to go live and start selling'
                            : 'Add products from your inventory to launch your store'),
                    style: AppType.body(size: 12, color: c.textMuted),
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

// ── Order card ───────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final _OrderEntry order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (statusColor, statusBg) = switch (order.status) {
      'pending'    => (c.amber, c.amberSurface),
      'processing' => (c.blue, c.blueSurface),
      'shipped'    => (c.teal, c.tealSurface),
      'delivered'  => (c.green, c.greenSurface),
      _            => (c.textMuted, c.bgInset),
    };

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                switch (order.status) {
                  'pending'    => Icons.access_time,
                  'processing' => Icons.cached,
                  'shipped'    => Icons.local_shipping_outlined,
                  'delivered'  => Icons.check_circle_outline,
                  _            => Icons.receipt_long_outlined,
                },
                size: 18,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customer,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(order.id,
                        style: AppType.mono(size: 11, color: c.textFaint)),
                    const SizedBox(width: 8),
                    Text('GHS ${order.amount}',
                        style: AppType.body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: c.text)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(order.statusLabel,
                    style: AppType.label(
                        size: 9.5, color: statusColor)),
              ),
              const SizedBox(height: 4),
              Text(order.timeAgo,
                  style: AppType.body(size: 10.5, color: c.textFaint)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Order stat chip ────────────────────────────────────────────────────────

class _OrderStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color, bg;

  const _OrderStatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$count',
                style: AppType.heading(size: 20, color: color)),
            const SizedBox(height: 1),
            Text(label,
                style: AppType.label(size: 9.5, color: c.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Setting tile ───────────────────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppType.body(
                          size: 13, weight: FontWeight.w500, color: c.text)),
                  const SizedBox(height: 1),
                  Text(value,
                      style: AppType.body(size: 11.5, color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null) Icon(Icons.chevron_right, size: 16, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

// ── Share option ───────────────────────────────────────────────────────────

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.bgInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppType.body(
                      size: 14, weight: FontWeight.w500, color: c.text)),
            ),
            Icon(Icons.chevron_right, size: 18, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 22, color: c.teal),
          const SizedBox(height: 8),
          Text(value,
              style: AppType.heading(size: 16, color: c.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: AppType.body(size: 11, color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Product card ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final InventoryItem item;

  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stock = item.currentStock;
    final isLow = item.lowStock;
    final price = item.unitPrice != null
        ? 'GHS ${item.unitPrice!.toStringAsFixed(0)}'
        : '—';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.navySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                style: AppType.heading(size: 16, color: c.navyDeep),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isLow)
                      AppPill('Low stock', tone: PillTone.rose, small: true)
                    else
                      Text('$stock in stock',
                          style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(width: 8),
                    Text(price,
                        style: AppType.body(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: c.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: c.textFaint),
        ],
      ),
    );
  }
}

// ── Empty states ───────────────────────────────────────────────────────────

class _EmptyProductsState extends StatelessWidget {
  final VoidCallback onAddProduct;
  const _EmptyProductsState({required this.onAddProduct});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c.amberSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_outlined,
                  size: 24, color: c.amber),
            ),
            const SizedBox(height: 12),
            Text('Add products to your shop',
                style: AppType.body(
                    size: 14, weight: FontWeight.w600, color: c.text)),
            const SizedBox(height: 4),
            Text(
              'Products from your inventory will appear here. List what you sell so customers can browse and buy.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 12, color: c.textMuted),
            ),
            const SizedBox(height: 14),
            AppBtn(
              'Add product',
              icon: 'inventory_2',
              fontSize: 13,
              onTap: onAddProduct,
            ),
          ],
        ),
      ),
    );
  }
}

