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
/// adjust stock, delete). Accessible from the Tools tab.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all' | 'goods' | 'services'

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
    final goodsItems = allItems.where((item) => item.isGoods).toList();
    final serviceItems = allItems.where((item) => !item.isGoods).toList();
    final lowStock = state.lowStockItems;

    // Apply type filter
    final typeFiltered = _typeFilter == 'goods'
        ? goodsItems
        : _typeFilter == 'services'
            ? serviceItems
            : allItems;

    // Filter by search query
    final filtered = typeFiltered.where((item) {
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
              trailing: GestureDetector(
                onTap: () => _openAddProduct(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.teal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
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
                            searchQuery: _searchQuery,
                            typeFilter: _typeFilter,
                            onSearchChanged: (v) =>
                                setState(() => _searchQuery = v),
                            onTypeFilterChanged: (v) =>
                                setState(() => _typeFilter = v),
                            onAdd: () => _openAddProduct(context),
                            onBulkImport: () => _openBulkImport(context),
                            onItemTap: (item) =>
                                _showItemActions(context, item),
                          ),
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
              final bizId = context.read<AppState>().business.id;
              if (bizId == null) return;
              try {
                await InventoryService.updateProduct(
                  productId: item.id,
                  businessId: bizId,
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
              final bizId = context.read<AppState>().business.id;
              if (bizId == null) return;
              try {
                await InventoryService.deleteProduct(
                  productId: item.id,
                  businessId: bizId,
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    // ── Product header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
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
                              color: item.lowStock ? sc.rose : sc.teal,
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
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (item.isGoods)
                                      Text('${item.currentStock} in stock',
                                          style: AppType.body(
                                              size: 12,
                                              color: item.lowStock
                                                  ? sc.rose
                                                  : sc.textMuted))
                                    else
                                      Text('Service',
                                          style: AppType.body(
                                              size: 12, color: sc.teal)),
                                    const SizedBox(width: 8),
                                    if (item.unitPrice != null)
                                      Text('· ${formatGHS(item.unitPrice!)}',
                                          style: AppType.body(
                                              size: 12, color: sc.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Restock (goods only) ──
                    if (item.isGoods)
                      _ActionTile(
                        icon: Icons.add_circle_outline,
                        title: 'Restock',
                        subtitle: 'Add more units to inventory',
                        color: sc.teal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: TextField(
                                      controller: restockCostCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
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
                                Container(
                                  height: 44,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10),
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
                                      style: AppType.body(
                                          size: 12, color: sc.text),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'cash',
                                            child: Text('Cash',
                                                style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(
                                            value: 'momo',
                                            child: Text('MoMo',
                                                style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(
                                            value: 'bank',
                                            child: Text('Bank',
                                                style: TextStyle(fontSize: 12))),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setSheetState(() =>
                                              restockPaymentSource = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // ── Edit item ──
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _openEditProduct(context, item);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sc.bgInset,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sc.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: sc.teal),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Edit details',
                                      style: AppType.body(
                                          size: 13.5,
                                          weight: FontWeight.w600,
                                          color: sc.text)),
                                  Text('Name, price, cost, category',
                                      style: AppType.body(
                                          size: 11.5, color: sc.textMuted)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 18, color: sc.textFaint),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Adjust stock (goods only) ──
                    if (item.isGoods)
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
                    // ── Delete ──
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmDelete(context, item, deleteProduct);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sc.roseSurface,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: sc.rose.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: sc.rose),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Delete product',
                                      style: AppType.body(
                                          size: 13.5,
                                          weight: FontWeight.w600,
                                          color: sc.rose)),
                                  Text('Permanently remove from inventory',
                                      style: AppType.body(
                                          size: 11.5,
                                          color:
                                              sc.rose.withValues(alpha: 0.8))),
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

  void _openEditProduct(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(existing: item),
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
                    size: 13, weight: FontWeight.w600, color: c.text)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              delete();
            },
            child: Text('Delete',
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.rose)),
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
  final String searchQuery;
  final String typeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTypeFilterChanged;
  final VoidCallback onAdd;
  final VoidCallback onBulkImport;
  final void Function(InventoryItem) onItemTap;

  const _ListBody({
    required this.items,
    required this.allItems,
    required this.lowStock,
    required this.searchQuery,
    required this.typeFilter,
    required this.onSearchChanged,
    required this.onTypeFilterChanged,
    required this.onAdd,
    required this.onBulkImport,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;


    // Total stock value at selling price
    final totalValue = allItems.fold<double>(
        0, (sum, item) => sum + item.stockValueAtPrice);

    // Total cost value
    final totalCost = allItems.fold<double>(
        0, (sum, item) => sum + item.stockValueAtCost);

    // Stock health: percentage of items above low-stock threshold
    final healthyCount = allItems.where((i) => !i.lowStock).length;
    final healthPct = allItems.isEmpty
        ? 1.0
        : healthyCount / allItems.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // ── Summary card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items',
                            style: AppType.body(
                                size: 11, color: c.textMuted)),
                        const SizedBox(height: 4),
                        Text('${allItems.length}',
                            style: AppType.heading(size: 22, color: c.text)),
                        const SizedBox(height: 2),
                        Text('${allItems.where((i) => i.isGoods).length} goods · ${allItems.where((i) => !i.isGoods).length} services',
                            style: AppType.body(
                                size: 10.5, color: c.textMuted)),
                      ],
                    ),
                  ),
                  // Stock health ring
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: healthPct.clamp(0.0, 1.0),
                        ringColor: healthPct > 0.7
                            ? c.teal
                            : healthPct > 0.3
                                ? c.amber
                                : c.rose,
                        trackColor: c.bgInset,
                        strokeWidth: 4,
                      ),
                      child: Center(
                        child: Text(
                          '${(healthPct * 100).round()}%',
                          style: AppType.body(
                              size: 11,
                              weight: FontWeight.w700,
                              color: c.text),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: c.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock value',
                            style: AppType.body(
                                size: 11, color: c.textMuted)),
                        const SizedBox(height: 3),
                        Text(formatGHS(totalValue),
                            style: AppType.heading(
                                size: 17, color: c.text)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: c.border),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Low stock',
                            style: AppType.body(
                                size: 11, color: c.textMuted)),
                        const SizedBox(height: 3),
                        Text('${lowStock.length}',
                            style: AppType.heading(
                                size: 17,
                                color: lowStock.isEmpty
                                    ? c.green
                                    : c.rose)),
                        if (lowStock.isNotEmpty)
                          Text('Need attention',
                              style: AppType.body(
                                  size: 10, color: c.rose)),
                      ],
                    ),
                  ),
                ],
              ),
              if (totalCost > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cost: ${formatGHS(totalCost)} · Margin: ${totalValue > 0 ? ((totalValue - totalCost) / totalValue * 100).round() : 0}%',
                        style: AppType.body(
                            size: 10, color: c.textFaint),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Low stock alert ──
        if (lowStock.isNotEmpty && typeFilter != 'services') ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: lowStock.length == 1
                ? () => onItemTap(lowStock.first)
                : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.rose.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.rose.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: c.rose),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lowStock.length} ${lowStock.length == 1 ? 'product' : 'products'} running low',
                      style: AppType.body(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: c.rose),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.rose,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('View',
                        style: AppType.body(
                            size: 10,
                            weight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],

        // ── Search bar with inline type filter ──
        Container(
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              // Inline type dropdown inside search
              GestureDetector(
                onTap: () => _showTypePicker(context, typeFilter, onTypeFilterChanged),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        typeFilter == 'goods'
                            ? Icons.inventory_2_outlined
                            : typeFilter == 'services'
                                ? Icons.miscellaneous_services_outlined
                                : Icons.category_outlined,
                        size: 13,
                        color: c.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        typeFilter == 'all'
                            ? 'All'
                            : typeFilter == 'goods'
                                ? 'Goods'
                                : 'Services',
                        style: AppType.body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: c.teal),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down,
                          size: 16, color: c.teal),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  style: AppType.body(size: 13.5, color: c.text),
                  decoration: InputDecoration(
                    hintText: typeFilter == 'services'
                        ? 'Search services…'
                        : 'Search products…',
                    hintStyle:
                        AppType.body(size: 13.5, color: c.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => onSearchChanged(''),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 16, color: c.textFaint),
                  ),
                ),
              const SizedBox(width: 4),
              // Import button
              GestureDetector(
                onTap: onBulkImport,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file,
                          size: 12, color: c.textMuted),
                      const SizedBox(width: 3),
                      Text('Import',
                          style: AppType.body(
                              size: 10.5,
                              weight: FontWeight.w600,
                              color: c.textMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Items list ──
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
                  const SizedBox(height: 4),
                  Text('Try a different search term.',
                      style: AppType.body(size: 12, color: c.textFaint)),
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

        // ── Bottom actions ──
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppBtn(
                'Add product',
                full: true,
                icon: 'add',
                onTap: onAdd,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppBtn(
                'Bulk import',
                icon: 'folder',
                variant: BtnVariant.outline,
                onTap: onBulkImport,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Type picker bottom sheet ──────────────────────────────────────────────────

void _showTypePicker(BuildContext context, String current, ValueChanged<String> onChange) {
  final c = context.colors;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 4),
          Text('Filter by type',
              style: AppType.heading(size: 17, color: c.text)),
          const SizedBox(height: 12),
          _typeOption(ctx, 'all', 'All items', Icons.category_outlined, current, onChange),
          _typeOption(ctx, 'goods', 'Goods only', Icons.inventory_2_outlined, current, onChange),
          _typeOption(ctx, 'services', 'Services only', Icons.miscellaneous_services_outlined, current, onChange),
        ],
      ),
    ),
  );
}

Widget _typeOption(BuildContext ctx, String value, String label, IconData icon, String current, ValueChanged<String> onChange) {
  final sc = ctx.colors;
  final selected = value == current;
  return GestureDetector(
    onTap: () {
      onChange(value);
      Navigator.pop(ctx);
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? sc.tealSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? sc.teal : sc.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppType.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: selected ? sc.teal : sc.text)),
          ),
          if (selected)
            Icon(Icons.check, size: 16, color: sc.teal),
        ],
      ),
    ),
  );
}

// ── Product card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  const _ProductCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isService = !item.isGoods;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isService
                      ? c.tealSurface
                      : (item.lowStock ? c.roseSurface : c.navySurface),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isService
                      ? Icons.miscellaneous_services_outlined
                      : (item.lowStock
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2_outlined),
                  size: 20,
                  color: isService
                      ? c.teal
                      : (item.lowStock ? c.rose : c.navyTint),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: AppType.body(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: c.text)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.sku != null && !isService) ...[
                          Text(item.sku!,
                              style: AppType.mono(
                                  size: 10, color: c.textFaint)),
                          Text(' · ',
                              style: AppType.body(
                                  size: 10, color: c.textFaint)),
                        ],
                        Text(item.category,
                            style: AppType.body(
                                size: 11, color: c.textFaint)),
                      ],
                    ),
                  ],
                ),
              ),
              // Price
              if (item.unitPrice != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatGHS(item.unitPrice!),
                        style: AppType.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: c.text)),
                    if (item.marginPercent != null)
                      Text('${item.marginPercent!.round()}% margin',
                          style: AppType.body(
                              size: 9.5, color: c.green)),
                  ],
                ),
            ],
          ),
          if (!isService) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: c.border),
            const SizedBox(height: 8),
            Row(
              children: [
                // Stock bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${item.currentStock} in stock',
                            style: AppType.body(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: item.lowStock ? c.rose : c.green),
                          ),
                          const SizedBox(width: 6),
                          if (item.lowStockThreshold != null)
                            Text(
                              '· alert at ${item.lowStockThreshold}',
                              style: AppType.body(
                                  size: 10, color: c.textFaint),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Mini stock bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: item.lowStockThreshold != null &&
                                    item.lowStockThreshold! > 0
                                ? (item.currentStock /
                                        (item.lowStockThreshold! * 3))
                                    .clamp(0.0, 1.0)
                                : 1.0,
                            backgroundColor: c.bgInset,
                            valueColor: AlwaysStoppedAnimation(
                              item.lowStock
                                  ? c.rose
                                  : c.teal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.marginPercent != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.greenSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.marginPercent!.round()}% margin',
                      style: AppType.label(
                          size: 8, color: c.green),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Ring painter (reused from TierRing pattern) ──────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor, trackColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, 0, 2 * 3.14159, false,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);

    canvas.drawArc(
      rect,
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
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
                        style: AppType.body(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: c.text)),
                    Text(subtitle,
                        style: AppType.body(
                            size: 11.5, color: c.textMuted)),
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
        children: [
          SizedBox(
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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.navySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 32, color: c.navy),
              ),
              const SizedBox(height: 20),
              Text('No products yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add your first product to start tracking stock levels, get low-stock alerts, and see your inventory value at a glance.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
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
