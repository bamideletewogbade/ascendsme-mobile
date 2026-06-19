import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/models.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';
import '../../services/app_logger.dart';
import '../../services/crm_service.dart';
import '../../services/supabase_service.dart';
import '../../services/order_service.dart';
import '../sheets/add_product_sheet.dart';

/// Online Shop management screen — pushed from the Tools tab.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tabIndex = 0;
  List<ShopOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.inventory.isEmpty) state.loadInventory();
      state.loadShop();
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) return;
    try {
      final rawOrders = await SupabaseService.fetchOrders(businessId: bizId);
      if (mounted) {
        setState(() => _orders = rawOrders.map(ShopOrder.fromRow).toList());
      }
    } catch (_) {}
  }

  Future<void> _updateOrderStatus(ShopOrder order, String newStatus) async {
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == order.id);
      if (idx != -1) {
        _orders[idx] = ShopOrder(
          id: order.id, businessId: order.businessId,
          customerName: order.customerName, totalGhs: order.totalGhs,
          subtotalGhs: order.subtotalGhs, status: newStatus,
          items: order.items, createdAt: order.createdAt,
          deliveryFeeGhs: order.deliveryFeeGhs,
        );
      }
    });
    try {
      await OrderService.updateStatus(orderId: order.id, status: newStatus);
      // Log CRM interaction
      unawaited(_logCrmOrderInteraction(
        bizId: bizId,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        orderTotal: order.totalGhs,
        newStatus: newStatus,
      ));
    } catch (e) {
      log.error('ShopScreen: Failed to update order status', error: e);
      _loadOrders();
    }
  }

  void _openOrderDetail(ShopOrder order) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        onStatusChange: (s) => _updateOrderStatus(order, s),
      ),
    );
  }

  int get _totalRevenue => _orders.fold(0, (sum, o) => sum + o.totalGhs);

  void _toggleStorefront(bool currentLive) {
    final state = context.read<AppState>();
    final shopId = state.shop?.id;
    if (shopId == null) return;
    if (currentLive) {
      SupabaseService.updateShop(shopId: shopId, isPublished: false);
      state.loadShop();
    } else {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.colors.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Go live?', style: AppType.heading(size: 17, color: context.colors.text)),
          content: Text('Your storefront will be visible to customers.',
              style: AppType.body(size: 13, color: context.colors.textMuted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Go live', style: TextStyle(color: context.colors.green))),
          ],
        ),
      ).then((confirmed) {
        if (confirmed == true) {
          SupabaseService.updateShop(shopId: shopId, isPublished: true);
          state.loadShop();
        }
      });
    }
  }

  void _shareStorefront(BuildContext context, String? slug) {
    if (slug == null) return;
    Clipboard.setData(ClipboardData(text: 'https://ascendsme.africa/store/$slug'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Store link copied! Share it with customers.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final shop = state.shop;
    final inventory = state.inventory;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Online Shop',
              onBack: () => Navigator.pop(context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _shareStorefront(context, shop?.slug),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: c.bgElevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                      child: Icon(Icons.share_outlined, size: 17, color: c.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StoreToggle(isLive: shop?.isPublished ?? false, onToggle: () => _toggleStorefront(shop?.isPublished ?? false)),
                ],
              ),
            ),
            _TabBar(
              tabs: const ['Overview', 'Products', 'Orders', 'Settings'],
              selected: _tabIndex,
              onSelect: (i) => setState(() => _tabIndex = i),
            ),
            Expanded(
              child: state.shopLoading && shop == null
                  ? const Center(child: CircularProgressIndicator())
                  : IndexedStack(
                      index: _tabIndex,
                      children: [
                        _buildOverviewTab(c, state, shop),
                        _buildProductsTab(c, inventory, shop),
                        _buildOrdersTab(c),
                        _buildSettingsTab(c, state, shop),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab(AppColorsX c, AppState state, Shop? shop) {
    final goods = state.inventory.where((i) => i.isGoods).toList();
    final recentOrders = _orders.take(5).toList();
    final pendingCount = _orders.where((o) => o.status == 'pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Store status + quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(padding: const EdgeInsets.all(18), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: shop?.isPublished == true ? c.greenSurface : c.blueSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        shop?.isPublished == true ? Icons.rocket_launch_outlined : Icons.check_circle_outline,
                        size: 24, color: shop?.isPublished == true ? c.green : c.blue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop?.isPublished == true
                                ? 'Store is live! 🎉'
                                : '${goods.length} products ready',
                            style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            shop?.isPublished == true
                                ? 'Customers can browse and order from your storefront.'
                                : 'Go live when you are ready to start selling.',
                            style: AppType.body(size: 12, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionChip(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: () => _shareStorefront(context, shop?.slug),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionChip(
                        icon: shop?.isPublished == true ? Icons.visibility_off_outlined : Icons.publish_outlined,
                        label: shop?.isPublished == true ? 'Unpublish' : 'Go live',
                        onTap: () => _toggleStorefront(shop?.isPublished ?? false),
                      ),
                    ),
                  ],
                ),
              ],
            )),
          ),

          const SizedBox(height: 20),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _StatCard(
                  label: 'Views', value: '${shop?.totalViews ?? 0}',
                  icon: Icons.visibility_outlined, c: c,
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  label: 'Orders', value: '${shop?.totalOrders ?? _orders.length}',
                  icon: Icons.receipt_outlined, c: c,
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  label: 'Revenue', value: formatGHS(shop?.totalRevenueGhs ?? _totalRevenue),
                  icon: Icons.payments_outlined, c: c,
                )),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Products summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(padding: const EdgeInsets.all(14), child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: c.navySurface, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.inventory_2_outlined, size: 20, color: c.navyDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${goods.length} Products listed',
                          style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
                      const SizedBox(height: 2),
                      Text('${goods.length - goods.where((i) => i.lowStock).length} in stock, ${goods.where((i) => i.lowStock).length} low',
                          style: AppType.body(size: 11.5, color: c.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _tabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: c.bgInset, borderRadius: BorderRadius.circular(8)),
                    child: Text('View', style: AppType.body(size: 11, weight: FontWeight.w600, color: c.teal)),
                  ),
                ),
              ],
            )),
          ),

          if (pendingCount > 0) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                background: c.amberSurface,
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: c.amber, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('$pendingCount pending order${pendingCount == 1 ? '' : 's'} — Review now',
                          style: AppType.body(size: 12.5, weight: FontWeight.w500, color: c.amber)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _tabIndex = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: c.amberSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.amber)),
                        child: Text('View', style: AppType.body(size: 11, weight: FontWeight.w600, color: c.amber)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Recent orders
          if (recentOrders.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionHeader('Recent Orders'),
                  if (_orders.length > 5)
                    GestureDetector(
                      onTap: () => setState(() => _tabIndex = 2),
                      child: Text('View all', style: AppType.body(size: 12, color: c.teal)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...recentOrders.map((o) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _OrderCard(order: o, onTap: () => _openOrderDetail(o)),
            )),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Products Tab ──────────────────────────────────────────────────────────

  Widget _buildProductsTab(AppColorsX c, List<InventoryItem> inventory, Shop? shop) {
    final goods = inventory.where((item) => item.isGoods).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: 16),

        // Stats cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: _StatCard(
                label: 'Public Views', value: '${shop?.totalViews ?? 0}',
                icon: Icons.visibility_outlined, c: c,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                label: 'Orders', value: '${shop?.totalOrders ?? _orders.length}',
                icon: Icons.receipt_outlined, c: c,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                label: 'Sales', value: formatGHS(shop?.totalRevenueGhs ?? _totalRevenue),
                icon: Icons.payments_outlined, c: c,
              )),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionHeader(goods.isEmpty ? 'Products' : 'Products (${goods.length})'),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context, isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddProductSheet(),
                  );
                  context.read<AppState>().loadInventory();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: c.navySurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.navySurfaceStrong)),
                  child: Row(children: [
                    Icon(Icons.add, size: 14, color: c.navyDeep),
                    const SizedBox(width: 4),
                    Text('Add', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.navyDeep)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (goods.isEmpty)
          _EmptyProductsState()
        else
          ...goods.take(6).map((item) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _ProductCard(item: item),
          )),
      ],
    );
  }

  // ── Orders Tab ────────────────────────────────────────────────────────────

  Widget _buildOrdersTab(AppColorsX c) {
    final pending = _orders.where((o) => o.status == 'pending').toList();
    final active = _orders.where((o) => ['confirmed', 'processing', 'shipped'].contains(o.status)).toList();
    final delivered = _orders.where((o) => o.status == 'delivered').toList();

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          if (pending.isNotEmpty) ...[
            Row(
              children: [
                Text('Pending Orders', style: AppType.heading(size: 15, color: c.text)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: c.amberSurface, borderRadius: BorderRadius.circular(6)),
                  child: Text('${pending.length}', style: AppType.label(size: 9, color: c.amber)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...pending.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OrderCard(order: o, onTap: () => _openOrderDetail(o)),
            )),
          ],
          if (active.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Active Processing', style: AppType.heading(size: 15, color: c.text)),
            const SizedBox(height: 8),
            ...active.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OrderCard(order: o, onTap: () => _openOrderDetail(o)),
            )),
          ],
          if (delivered.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Completed', style: AppType.heading(size: 15, color: c.text)),
            const SizedBox(height: 8),
            ...delivered.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OrderCard(order: o, onTap: () => _openOrderDetail(o)),
            )),
          ],
          if (_orders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Text('No orders yet', style: AppType.body(color: c.textFaint)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Settings Tab ──────────────────────────────────────────────────────────

  Widget _buildSettingsTab(AppColorsX c, AppState state, Shop? shop) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Store info section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Store Info', style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.store_outlined, label: 'Shop Name',
                value: shop?.shopName ?? state.business.name,
                onTap: () => _editShopName(context, state, shop),
              ),
              _SettingTile(
                icon: Icons.link, label: 'Store URL',
                value: 'ascendsme.africa/store/${shop?.slug ?? '—'}',
                onTap: () => _copyStoreUrl(context, shop?.slug),
              ),
              _SettingTile(
                icon: Icons.description_outlined, label: 'Tagline',
                value: shop != null && (shop.tagline != null && shop.tagline!.isNotEmpty) ? shop.tagline! : 'Add a tagline',
                onTap: () => _editTagline(context, state, shop),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Delivery settings section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 16, color: c.textMuted),
                  const SizedBox(width: 8),
                  Text('Delivery Settings', style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
                ],
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.payments_outlined, label: 'Delivery Fee',
                value: shop != null ? shop.deliveryFeeGhs?.toString() ?? '—' : '—',
                onTap: () => _editDeliveryField(context, shop, 'fee'),
              ),
              _SettingTile(
                icon: Icons.shopping_bag_outlined, label: 'Free Delivery Above',
                value: shop != null ? shop.freeDeliveryThresholdGhs?.toString() ?? '—' : '—',
                onTap: () => _editDeliveryField(context, shop, 'free_threshold'),
              ),
              _SettingTile(
                icon: Icons.notes_outlined, label: 'Delivery Notes',
                value: shop != null ? shop.deliveryDescription?.toString() ?? 'Add delivery info' : '—',
                onTap: () => _editDeliveryField(context, shop, 'description'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Marketplace & payments section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_outlined, size: 16, color: c.textMuted),
                  const SizedBox(width: 8),
                  Text('Visibility & Payments', style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Marketplace Listing', style: AppType.body(size: 13, weight: FontWeight.w500, color: c.text)),
                      const SizedBox(height: 2),
                      Text('List in the public AscendSME marketplace.',
                          style: AppType.body(size: 11, color: c.textMuted)),
                    ]),
                  ),
                  Switch.adaptive(
                    value: shop?.isMarketplaceListed ?? false,
                    activeTrackColor: c.teal,
                    onChanged: shop != null ? (v) => _toggleMarketplace(shop.id, v) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Digital Payments', style: AppType.body(size: 13, weight: FontWeight.w500, color: c.text)),
                      const SizedBox(height: 2),
                      Text('Mobile Money, card, etc.', style: AppType.body(size: 11, color: c.textMuted)),
                    ]),
                  ),
                  Switch.adaptive(value: true, activeTrackColor: c.teal, onChanged: null),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pay on Delivery', style: AppType.body(size: 13, weight: FontWeight.w500, color: c.text)),
                      const SizedBox(height: 2),
                      Text('Customers pay when order arrives.', style: AppType.body(size: 11, color: c.textMuted)),
                    ]),
                  ),
                  Switch.adaptive(value: true, activeTrackColor: c.teal, onChanged: null),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── Settings helpers ──────────────────────────────────────────────────────

  void _editShopName(BuildContext context, AppState state, Shop? shop) {
    final c = context.colors;
    final ctrl = TextEditingController(text: shop?.shopName ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Container(
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 12),
              Text('Edit Shop Name', style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Shop Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              AppBtn('Save', full: true, onTap: () {
                final name = ctrl.text.trim();
                if (name.isNotEmpty && shop != null) {
                  SupabaseService.updateShop(shopId: shop.id, shopName: name)
                      .then((_) => state.loadShop())
                      .catchError((e) => log.error('Failed to update shop name', error: e));
                }
                Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _editTagline(BuildContext context, AppState state, Shop? shop) {
    if (shop == null) return;
    final c = context.colors;
    final ctrl = TextEditingController(text: shop.tagline ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Container(
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 12),
              Text('Edit Tagline', style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl, autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'A short description of your shop',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              AppBtn('Save', full: true, onTap: () {
                SupabaseService.updateShop(shopId: shop.id, tagline: ctrl.text.trim())
                    .then((_) => state.loadShop())
                    .catchError((e) => log.error('Failed to update tagline', error: e));
                Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _editDeliveryField(BuildContext context, Shop? shop, String field) {
    if (shop == null) return;
    final c = context.colors;
    final isNumeric = field == 'fee' || field == 'free_threshold';
    final label = field == 'fee' ? 'Delivery Fee (GHS)'
        : field == 'free_threshold' ? 'Free Delivery Above (GHS)'
        : 'Delivery Notes';
    final currentValue = field == 'fee' ? shop.deliveryFeeGhs?.toString() ?? ''
        : field == 'free_threshold' ? shop.freeDeliveryThresholdGhs?.toString() ?? ''
        : shop.deliveryDescription ?? '';
    final ctrl = TextEditingController(text: currentValue);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Container(
          decoration: BoxDecoration(color: c.bgElevated, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 12),
              Text('Edit $label', style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl, autofocus: true,
                keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                maxLines: isNumeric ? 1 : 3,
                decoration: InputDecoration(
                  hintText: isNumeric ? 'Amount in GHS' : 'Delivery notes for customers',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              AppBtn('Save', full: true, onTap: () {
                final value = ctrl.text.trim();
                final update = <String, dynamic>{};
                if (field == 'fee') {
                  update['deliveryFeeGhs'] = int.tryParse(value) ?? 0;
                } else if (field == 'free_threshold') {
                  update['freeDeliveryThresholdGhs'] = int.tryParse(value) ?? 0;
                } else {
                  update['deliveryDescription'] = value;
                }
                SupabaseService.updateShop(shopId: shop.id, deliveryFeeGhs: update['deliveryFeeGhs'] as int?,
                    freeDeliveryThresholdGhs: update['freeDeliveryThresholdGhs'] as int?,
                    deliveryDescription: update['deliveryDescription'] as String?)
                    .then((_) => context.read<AppState>().loadShop())
                    .catchError((e) => log.error('Failed to update delivery setting', error: e));
                Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _copyStoreUrl(BuildContext context, String? slug) {
    if (slug == null) return;
    Clipboard.setData(ClipboardData(text: 'https://ascendsme.africa/store/$slug'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Store link copied!')),
    );
  }

  /// Log a CRM interaction when an order status changes.
  Future<void> _logCrmOrderInteraction({
    required String bizId,
    required String customerName,
    String? customerPhone,
    required int orderTotal,
    required String newStatus,
  }) async {
    final label = switch (newStatus) {
      'confirmed' => 'confirmed',
      'processing' => 'processing started',
      'shipped' => 'shipped',
      'delivered' => 'delivered',
      'cancelled' => 'cancelled',
      _ => 'updated',
    };
    final profile = await CrmService.getOrCreateCrmProfile(
      businessId: bizId,
      name: customerName,
      phone: customerPhone,
    );
    if (profile != null) {
      unawaited(CrmService.addInteraction(
        businessId: bizId,
        customerProfileId: profile['id'] as String,
        type: 'system_event',
        description: 'Order $label — GHS $orderTotal',
      ));
    }
  }

  Future<void> _toggleMarketplace(String shopId, bool value) async {
    try {
      await SupabaseService.updateShop(shopId: shopId, isMarketplaceListed: value);
      if (!mounted) return;
      context.read<AppState>().loadShop();
    } catch (e) {
      log.error('Failed to toggle marketplace listing', error: e);
    }
  }
}

// ── Shared Widgets ───────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.tabs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bgInset, borderRadius: BorderRadius.circular(12)),
      child: Row(children: List.generate(tabs.length, (i) {
        final active = i == selected;
        return Expanded(child: GestureDetector(
          onTap: () => onSelect(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: active ? c.bgElevated : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: active ? Border.all(color: c.border) : null,
            ),
            child: Center(
              child: Text(tabs[i],
                  style: AppType.body(size: 12.5, weight: FontWeight.w600,
                      color: active ? c.text : c.textMuted)),
            ),
          ),
        ));
      })),
    );
  }
}

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
          border: Border.all(color: isLive ? c.green : c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: isLive ? c.green : c.textFaint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(isLive ? 'Live' : 'Draft',
              style: AppType.body(size: 12, weight: FontWeight.w600,
                  color: isLive ? c.green : c.textMuted)),
        ]),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.bgInset, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: c.textMuted),
            const SizedBox(width: 6),
            Text(label, style: AppType.body(size: 12, weight: FontWeight.w500, color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final AppColorsX c;
  const _StatCard({required this.label, required this.value, required this.icon, required this.c});

  @override
  Widget build(BuildContext context) {
    return AppCard(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12), child: Column(children: [
      Icon(icon, size: 20, color: c.teal),
      const SizedBox(height: 8),
      Text(value, style: AppType.heading(size: 15, color: c.text),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: AppType.body(size: 10, color: c.textMuted)),
    ]));
  }
}

class _ProductCard extends StatelessWidget {
  final InventoryItem item;
  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLowStock = item.lowStock;
    return AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: c.navySurface, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(item.name[0].toUpperCase(),
            style: AppType.heading(size: 16, color: c.navyDeep))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Flexible(
              child: Text(item.name, style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (isLowStock) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: c.roseSurface, borderRadius: BorderRadius.circular(4)),
                child: Text('Low', style: AppType.label(size: 8, color: c.rose)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          item.isGoods
              ? '${item.currentStock} in stock · ${formatGHS(item.unitPrice ?? 0)}'
              : 'Service · ${formatGHS(item.unitPrice ?? 0)}',
          style: AppType.body(size: 11.5, color: c.textMuted),
        ),
      ])),
      Icon(Icons.chevron_right, size: 18, color: c.textFaint),
    ]));
  }
}

class _OrderCard extends StatelessWidget {
  final ShopOrder order;
  final VoidCallback? onTap;
  const _OrderCard({required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Flexible(
                child: Text(order.customerName,
                    style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (order.paymentStatus == 'paid' || order.paymentStatus == 'deposit_paid') ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, size: 12, color: c.green),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text('${order.items.length} items · ${formatGHS(order.totalGhs)}${order.deliveryFeeGhs > 0 ? ' · +${formatGHS(order.deliveryFeeGhs)} delivery' : ''}',
              style: AppType.body(size: 12, color: c.textMuted)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: switch (order.status) {
              'delivered' => c.greenSurface,
              'cancelled' => c.roseSurface,
              'shipped' => c.blueSurface,
              _ => c.bgInset,
            },
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            order.statusLabel,
            style: AppType.label(
              size: 9,
              color: switch (order.status) {
                'delivered' => c.green,
                'cancelled' => c.rose,
                'shipped' => c.blue,
                _ => c.textMuted,
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _SettingTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(onTap: onTap, padding: const EdgeInsets.all(14), child: Row(children: [
        Icon(icon, size: 18, color: c.textMuted),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppType.body(size: 13, weight: FontWeight.w500, color: c.text)),
          Text(value, style: AppType.body(size: 11.5, color: c.textMuted), maxLines: 1),
        ])),
        Icon(Icons.chevron_right, size: 16, color: c.textFaint),
      ])),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(padding: const EdgeInsets.all(20), child: Column(children: [
        Icon(Icons.storefront_outlined, size: 32, color: c.amber),
        const SizedBox(height: 12),
        Text('No products listed yet', style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 4),
        Text('Add products from your inventory to start selling.',
            textAlign: TextAlign.center, style: AppType.body(size: 12, color: c.textMuted)),
      ])),
    );
  }
}

// ── Order Detail Sheet ───────────────────────────────────────────────────────

class _OrderDetailSheet extends StatelessWidget {
  final ShopOrder order;
  final Function(String) onStatusChange;

  const _OrderDetailSheet({required this.order, required this.onStatusChange});

  static const _statusFlow = ['pending', 'confirmed', 'processing', 'shipped', 'delivered'];
  int get _currentStep => _statusFlow.indexOf(order.status);
  bool get _isCancelled => order.status == 'cancelled';
  bool get _isDelivered => order.status == 'delivered';

  List<String> get _availableActions {
    if (_isCancelled || _isDelivered) return [];
    final idx = _currentStep;
    if (idx < 0 || idx >= _statusFlow.length - 1) return [];
    return [_statusFlow[idx + 1]];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = order.items;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),

          // Customer + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customerName, style: AppType.heading(size: 18, color: c.text)),
                    if (order.customerPhone != null) ...[
                      const SizedBox(height: 2),
                      Text(order.customerPhone!, style: AppType.body(size: 12, color: c.textMuted)),
                    ],
                    if (order.customerEmail != null) ...[
                      const SizedBox(height: 2),
                      Text(order.customerEmail!, style: AppType.body(size: 12, color: c.textMuted)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isCancelled ? c.roseSurface : _isDelivered ? c.greenSurface : c.tealSurface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  order.statusLabel,
                  style: AppType.body(
                    size: 11, weight: FontWeight.w700,
                    color: _isCancelled ? c.rose : _isDelivered ? c.green : c.tealDeep,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Order summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.bgInset, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Summary', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 10),
                _SummaryRow(label: 'Subtotal', value: formatGHS(order.subtotalGhs), c: c),
                if (order.deliveryFeeGhs > 0)
                  _SummaryRow(label: 'Delivery fee', value: formatGHS(order.deliveryFeeGhs), c: c),
                if (order.deliveryMethod != null)
                  _SummaryRow(label: 'Delivery', value: _deliveryLabel(order.deliveryMethod!), c: c),
                if (order.paymentStatus != null)
                  _SummaryRow(label: 'Payment', value: _paymentLabel(order.paymentStatus!), c: c),
                if (order.customerAddress != null && order.customerAddress!.isNotEmpty)
                  _SummaryRow(label: 'Address', value: order.customerAddress!, c: c),
                const Divider(height: 16),
                _SummaryRow(label: 'Total', value: formatGHS(order.totalGhs), c: c, bold: true),
              ],
            ),
          ),

          // Items
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Items', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
            const SizedBox(height: 8),
            ...items.map((item) => _ItemRow(item: item, c: c)),
          ],

          // Notes
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.bgInset, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_outlined, size: 14, color: c.textFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(order.notes!, style: AppType.body(size: 11.5, color: c.textMuted)),
                  ),
                ],
              ),
            ),
          ],

          // Progress stepper
          if (!_isCancelled) ...[
            const SizedBox(height: 20),
            _buildProgressStepper(c),
          ],

          // Action buttons
          if (_availableActions.isNotEmpty || !_isCancelled && !_isDelivered) ...[
            const SizedBox(height: 16),
            _buildActions(context, c),
          ],

          // Cancelled note
          if (_isCancelled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.roseSurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: c.rose),
                const SizedBox(width: 8),
                Text('This order was cancelled.', style: AppType.body(size: 12, color: c.rose)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  String _deliveryLabel(String method) {
    switch (method) {
      case 'pickup': return 'Pickup';
      case 'delivery': return 'Delivery';
      default: return method;
    }
  }

  String _paymentLabel(String status) {
    switch (status) {
      case 'paid': return 'Paid ✓';
      case 'deposit_paid': return 'Deposit paid';
      case 'refunded': return 'Refunded';
      default: return 'Unpaid';
    }
  }

  Widget _buildProgressStepper(AppColorsX c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(4, (i) {
            final labels = ['Pending', 'Confirm', 'Ship', 'Deliver'];
            final isComplete = _currentStep >= i;
            final isCurrent = _currentStep == i;
            return Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(height: 3, color: isComplete ? c.teal : c.border),
                        ),
                      Container(
                        width: isCurrent ? 28 : 24,
                        height: isCurrent ? 28 : 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isComplete ? c.teal : c.bgInset,
                          border: isCurrent ? Border.all(color: c.teal, width: 2) : Border.all(color: c.border),
                        ),
                        child: Center(
                          child: isComplete
                              ? Icon(Icons.check, size: 14, color: Colors.white)
                              : Text('${i + 1}',
                                  style: AppType.body(size: 10, weight: FontWeight.w700, color: c.textFaint)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i],
                      style: AppType.body(size: 9, color: isComplete ? c.tealDeep : c.textFaint)),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, AppColorsX c) {
    if (_isCancelled || _isDelivered) return const SizedBox.shrink();

    final nextStatus = _availableActions.isNotEmpty ? _availableActions.first : null;
    final actionLabel = switch (nextStatus) {
      'confirmed' => 'Confirm Order',
      'processing' => 'Start Processing',
      'shipped' => 'Mark as Shipped',
      'delivered' => 'Mark as Delivered',
      _ => null,
    };

    return Row(
      children: [
        if (nextStatus != null && actionLabel != null)
          Expanded(
            child: AppBtn(actionLabel, onTap: () {
              onStatusChange(nextStatus);
              Navigator.pop(context);
            }),
          ),
        if (nextStatus != null) const SizedBox(width: 10),
        if (!_isCancelled && !_isDelivered && _currentStep < 2)
          Expanded(
            child: AppBtn('Cancel Order', variant: BtnVariant.outline,
                onTap: () => _confirmCancel(context, c)),
          ),
      ],
    );
  }

  void _confirmCancel(BuildContext context, AppColorsX c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text('This cannot be undone. The customer will be notified.',
            style: AppType.body(size: 13, color: c.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep order')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onStatusChange('cancelled');
              Navigator.pop(context);
            },
            child: const Text('Cancel order', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final AppColorsX c;
  const _SummaryRow({required this.label, required this.value, required this.c, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: AppType.body(size: 12, color: c.textMuted)),
        const Spacer(),
        Text(value, style: AppType.body(size: 12, weight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? c.text : c.text)),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ShopOrderItem item;
  final AppColorsX c;
  const _ItemRow({required this.item, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(Icons.inventory_2_outlined, size: 14, color: c.textFaint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(item.productName, style: AppType.body(size: 12, color: c.text),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text('x${item.quantity}', style: AppType.body(size: 11, color: c.textMuted)),
        const SizedBox(width: 8),
        Text(formatGHS(item.totalPriceGhs), style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text)),
      ]),
    );
  }
}
