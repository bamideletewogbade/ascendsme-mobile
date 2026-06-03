import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/inventory_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../sheets/add_product_sheet.dart';
import '../sheets/bulk_import_sheet.dart';

/// Inventory management screen — list products, view stock levels, add/edit
/// items, see low-stock alerts, and perform management actions (restock,
/// adjust stock, delete). Accessible from the Tools tab and from the
/// Profile → Inventory link.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.inventory.isEmpty && !state.inventoryLoading) {
        state.loadInventory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final allItems = state.inventory;
    final lowStock = state.lowStockItems;

    // Derive unique categories from items (sorted alphabetically, 'All' first)
    final categories = ['All', ...{
      for (final item in allItems) item.category,
    }.toList()..sort()];

    // Filter by search query and category
    final filtered = allItems.where((item) {
      if (_categoryFilter != 'All' && item.category != _categoryFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!item.name.toLowerCase().contains(q) &&
            !(item.sku?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Inventory',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: state.inventoryLoading && allItems.isEmpty
                  ? const _LoadingState()
                  : allItems.isEmpty
                      ? _EmptyState(onAdd: () => _openAddProduct(context))
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: c.teal,
                          child: _ListBody(
                            items: filtered,
                            allItems: allItems,
                            lowStock: lowStock,
                            categories: categories,
                            searchQuery: _searchQuery,
                            categoryFilter: _categoryFilter,
                            onSearchChanged: (v) =>
                                setState(() => _searchQuery = v),
                            onCategoryChanged: (v) =>
                                setState(() => _categoryFilter = v),
                            onAdd: () => _openAddProduct(context),
                            onItemTap: (item) =>
                                _showItemActions(context, item),
                          ),
                        ),
            ),
            if (allItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppBtn(
                        'Add product',
                        full: true,
                        icon: 'add',
                        onTap: () => _openAddProduct(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBtn(
                      'Bulk import',
                      icon: 'folder',
                      variant: BtnVariant.outline,
                      onTap: () => _openBulkImport(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await context.read<AppState>().loadInventory();
  }

  void _openAddProduct(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddProductSheet(),
    );
  }

  void _openBulkImport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BulkImportSheet(),
    );
  }

  void _showItemActions(BuildContext context, InventoryItem item) {
    final restockCtrl = TextEditingController();
    final restockCostCtrl = TextEditingController();
    String restockPaymentSource = 'cash';
    final adjustCtrl = TextEditingController(text: '${item.currentStock}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Local state for the bottom sheet
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final sc = ctx.colors;

            Future<void> restock() async {
              final raw = restockCtrl.text.trim();
              final qty = int.tryParse(raw);
              if (qty == null || qty <= 0) return;
              final appState = context.read<AppState>();
              final bizId = appState.business.id;
              if (bizId == null) return;
              try {
                await InventoryService.updateProduct(
                  productId: item.id,
                  businessId: bizId,
                  currentStock: item.currentStock + qty,
                );
                // Log the restock as an expense if a cost was entered
                final costRaw = restockCostCtrl.text.trim();
                final cost = costRaw.isNotEmpty ? num.tryParse(costRaw) : null;
                if (cost != null && cost > 0) {
                  await SupabaseService.createExpense(
                    businessId: bizId,
                    amount: cost,
                    description: 'Restock: ${item.name} x $qty',
                    category: 'Inventory',
                    paymentSource: restockPaymentSource,
                  );
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                unawaited(appState.loadInventory());
                unawaited(appState.loadFinancials());
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Could not update stock.',
                        style: AppType.body(size: 13, color: Colors.white)),
                    backgroundColor: sc.rose,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            Future<void> adjustStock() async {
              final raw = adjustCtrl.text.trim();
              final qty = int.tryParse(raw);
              if (qty == null || qty < 0) return;
              try {
                await InventoryService.updateProduct(
                  productId: item.id,
                  businessId: context.read<AppState>().business.id!,
                  currentStock: qty,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                context.read<AppState>().loadInventory();
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Could not update stock.',
                        style: AppType.body(size: 13, color: Colors.white)),
                    backgroundColor: sc.rose,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            Future<void> deleteProduct() async {
              try {
                await InventoryService.deleteProduct(
                  productId: item.id,
                  businessId: context.read<AppState>().business.id!,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                context.read<AppState>().loadInventory();
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Could not delete product.',
                        style: AppType.body(size: 13, color: Colors.white)),
                    backgroundColor: sc.rose,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: sc.bgElevated,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: item.lowStock
                                  ? sc.roseSurface
                                  : sc.tealSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.lowStock
                                  ? Icons.warning_amber_rounded
                                  : Icons.inventory_2_outlined,
                              size: 20,
                              color: item.lowStock
                                  ? sc.rose
                                  : sc.tealDeep,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: AppType.body(
                                        size: 15,
                                        weight: FontWeight.w600,
                                        color: sc.text)),
                                Text('${item.currentStock} in stock',
                                    style: AppType.body(
                                        size: 12,
                                        color: item.lowStock
                                            ? sc.rose
                                            : sc.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Restock
                    _ActionTile(
                      icon: Icons.add_circle_outline,
                      title: 'Restock',
                      subtitle: 'Add more units to inventory',
                      color: sc.teal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Qty row
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: TextField(
                                    controller: restockCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Qty to add',
                                      filled: true,
                                      fillColor: sc.bg,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: sc.border),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: restock,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18),
                                  decoration: BoxDecoration(
                                    color: sc.teal,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text('Add',
                                        style: AppType.body(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: Colors.white)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Cost row (optional)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: TextField(
                                    controller: restockCostCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: 'Total cost (GHS, optional)',
                                      filled: true,
                                      fillColor: sc.bg,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: sc.border),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Payment source dropdown
                              Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: sc.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: sc.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: restockPaymentSource,
                                    isDense: true,
                                    dropdownColor: sc.bgElevated,
                                    style: AppType.body(size: 12, color: sc.text),
                                    items: const [
                                      DropdownMenuItem(value: 'cash', child: Text('Cash', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'momo', child: Text('MoMo', style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: 'bank', child: Text('Bank', style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setSheetState(() => restockPaymentSource = v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (restockCostCtrl.text.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('This will be logged as an expense',
                                  style: AppType.body(size: 10.5, color: sc.textFaint)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Adjust stock
                    _ActionTile(
                      icon: Icons.tune,
                      title: 'Adjust stock',
                      subtitle: 'Set exact stock count',
                      color: sc.blue,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: TextField(
                                controller: adjustCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'New count',
                                  filled: true,
                                  fillColor: sc.bg,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: sc.border),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: adjustStock,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18),
                              decoration: BoxDecoration(
                                color: sc.blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('Set',
                                    style: AppType.body(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Delete
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmDelete(context, item, deleteProduct);
                      },
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sc.roseSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: sc.rose.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: sc.rose),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('Delete product',
                                      style: AppType.body(
                                          size: 13.5,
                                          weight: FontWeight.w600,
                                          color: sc.rose)),
                                  Text('Permanently remove from inventory',
                                      style: AppType.body(
                                          size: 11.5,
                                          color: sc.rose
                                              .withValues(alpha: 0.8))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, InventoryItem item, Future<void> Function() delete) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${item.name}?',
            style: AppType.heading(size: 18, color: c.text)),
        content: Text(
          'This permanently removes ${item.name} from your inventory. This cannot be undone.',
          style: AppType.body(size: 13.5, color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep',
                style: AppType.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.text)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              delete();
            },
            child: Text('Delete',
                style: AppType.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.rose)),
          ),
        ],
      ),
    );
  }
}

// ── List body ────────────────────────────────────────────────────────────────

class _ListBody extends StatelessWidget {
  final List<InventoryItem> items;
  final List<InventoryItem> allItems;
  final List<InventoryItem> lowStock;
  final List<String> categories;
  final String searchQuery;
  final String categoryFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onAdd;
  final void Function(InventoryItem) onItemTap;

  const _ListBody({
    required this.items,
    required this.allItems,
    required this.lowStock,
    required this.categories,
    required this.searchQuery,
    required this.categoryFilter,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onAdd,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final totalValue = allItems.fold<int>(
        0, (sum, item) => sum + ((item.unitPrice ?? 0) * item.currentStock).round());

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Summary card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total products',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text('${allItems.length}',
                        style: AppType.heading(size: 20, color: c.text)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: c.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock value',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatGHS(totalValue),
                        style: AppType.heading(size: 20, color: c.text)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Low stock alert
        if (lowStock.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.rose.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.rose.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: c.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${lowStock.length} ${lowStock.length == 1 ? 'product' : 'products'} running low on stock',
                    style: AppType.body(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: c.rose),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: c.textFaint),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  style: AppType.body(size: 13.5, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Search products…',
                    hintStyle: AppType.body(size: 13.5, color: c.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => onSearchChanged(''),
                  child: Icon(Icons.close, size: 16, color: c.textFaint),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Category chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, i) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final active = cat == categoryFilter;
              return GestureDetector(
                onTap: () => onCategoryChanged(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? c.teal : c.bgElevated,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: active ? c.teal : c.borderStrong,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: AppType.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: active ? Colors.white : c.textMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Items list
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 36, color: c.textFaint),
                  const SizedBox(height: 8),
                  Text('No products match your search',
                      style: AppType.body(size: 13, color: c.textMuted)),
                ],
              ),
            ),
          )
        else
          ...items.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeInSlide(
                  index: e.key,
                  child: _ProductCard(
                    item: e.value,
                    onTap: () => onItemTap(e.value),
                  ),
                ),
              )),
      ],
    );
  }
}

// ── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  const _ProductCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Product icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.lowStock ? c.roseSurface : c.navySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.lowStock
                  ? Icons.warning_amber_rounded
                  : Icons.inventory_2_outlined,
              size: 20,
              color: item.lowStock ? c.rose : c.navyTint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name,
                          style: AppType.body(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: c.text)),
                    ),
                    if (item.unitPrice != null)
                      Text(formatGHS(item.unitPrice!),
                          style: AppType.body(
                              size: 12,
                              weight: FontWeight.w600,
                              color: c.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.sku != null) ...[
                      Text(item.sku!,
                          style: AppType.mono(size: 10, color: c.textFaint)),
                      Text(' · ',
                          style: AppType.body(
                              size: 10, color: c.textFaint)),
                    ],
                    Text(item.category,
                        style:
                            AppType.body(size: 11, color: c.textFaint)),
                    const Spacer(),
                    Text('${item.currentStock} in stock',
                        style: AppType.body(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: item.lowStock ? c.rose : c.green)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action tile helper ─────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text)),
                    Text(subtitle,
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Loading / Empty states ───────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(c.teal)),
            ),
          const SizedBox(height: 12),
          Text('Loading inventory…',
              style: AppType.body(size: 13, color: c.textMuted)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.navySurface,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.inventory_2_outlined, size: 26, color: c.navy),
              ),
              const SizedBox(height: 16),
              Text('No products yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add your first product to start tracking stock levels and get low-stock alerts.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AppBtn(
                  'Add product',
                  full: true,
                  icon: 'add',
                  onTap: onAdd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
