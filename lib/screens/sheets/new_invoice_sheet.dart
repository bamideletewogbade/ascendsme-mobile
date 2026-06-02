import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/customer_selector.dart';
import '../../services/ai_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet for creating a new invoice.
///
/// v2: Wires CustomerSelector for CRM linkage and inventory items as line
/// items with quantities. Selected customer + products flow into
/// [SupabaseService.createInvoice] so invoices are always linked to a
/// customer row and their line items are structured for web's PDF generator.
class NewInvoiceSheet extends StatefulWidget {
  final VoidCallback? onSent;

  const NewInvoiceSheet({super.key, this.onSent});

  @override
  State<NewInvoiceSheet> createState() => _NewInvoiceSheetState();
}

class _NewInvoiceSheetState extends State<NewInvoiceSheet> {
  int _step = 0;

  // ── Customer state ──
  String _customerName = '';
  String? _customerId;
  Customer? _selectedCustomer;

  // ── Invoice description (for AI draft + fallback) ──
  final _descCtrl = TextEditingController();

  // ── Manual amount fallback (when no inventory items) ──
  final _amountCtrl = TextEditingController();

  // ── Line items from inventory ──
  final List<_SelectedItem> _selectedItems = [];

  // ── Inventory search for line items ──
  final _productSearchCtrl = TextEditingController();
  List<InventoryItem> _productResults = [];
  bool _searchingProducts = false;

  // ── AI ──
  bool _aiParsing = false;

  // ── Proforma toggle ──
  bool _isProforma = false;

  // ── Send state ──
  bool _sending = false;
  String? _sendError;
  String? _createdInvoiceNumber;

  // ── Derived totals ──
  num get _totalAmount {
    if (_selectedItems.isNotEmpty) {
      return _selectedItems.fold<num>(0, (s, it) => s + it.total);
    }
    return _parseAmount() ?? 0;
  }

  num? _parseAmount() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return num.tryParse(raw);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

  // ── AI smart draft ──
  Future<void> _aiDraft() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) return;
    setState(() => _aiParsing = true);
    final result = await AIService.parseInvoice(desc);
    if (mounted) {
      setState(() {
        _aiParsing = false;
        if (result != null) {
          final customer = result['customer'] as String?;
          if (customer != null && customer.isNotEmpty) {
            _customerName = customer;
          }
          final amount = result['amount'];
          if (amount != null) {
            _amountCtrl.text = amount.toString();
          }
        }
      });
    }
  }

  // ── Inventory product search ──
  Future<void> _searchProducts(String query) async {
    final state = context.read<AppState>();
    final inventory = state.inventory;
    if (query.trim().isEmpty) {
      setState(() => _productResults = []);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _searchingProducts = true;
      _productResults = inventory.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.sku?.toLowerCase().contains(q) ?? false);
      }).take(8).toList();
    });
    setState(() => _searchingProducts = false);
  }

  void _addProductItem(InventoryItem product) {
    setState(() {
      _selectedItems.add(_SelectedItem(product: product, quantity: 1));
      _productSearchCtrl.clear();
      _productResults = [];
    });
  }

  void _updateItemQuantity(int index, int qty) {
    setState(() {
      if (qty <= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems[index] = _SelectedItem(
          product: _selectedItems[index].product,
          quantity: qty,
        );
      }
    });
  }

  // ── Customer selector callback ──
  void _onCustomerChanged(String name, Customer? customer) {
    _customerName = name;
    _customerId = customer?.id;
    _selectedCustomer = customer;
  }

  // ── Send invoice ──
  Future<void> _sendInvoice() async {
    setState(() {
      _sending = true;
      _sendError = null;
    });

    final customer = _customerName;
    final amount = _totalAmount;
    final appState = context.read<AppState>();
    final businessId = appState.business.id;

    if (customer.isEmpty) {
      setState(() {
        _sending = false;
        _sendError = 'Customer name is required.';
      });
      return;
    }
    if (amount <= 0) {
      setState(() {
        _sending = false;
        _sendError = 'Add at least one item with a valid amount.';
      });
      return;
    }
    if (businessId == null) {
      setState(() {
        _sending = false;
        _sendError =
            'Your business profile isn\'t set up yet. Please complete signup first.';
      });
      return;
    }

    try {
      // Build line items from selected inventory products, or use a single
      // fallback line item.
      final lineItems = _selectedItems.isNotEmpty
          ? _selectedItems.map((it) => {
                'description': it.product.name,
                'quantity': it.quantity,
                'price': it.product.unitPrice ?? (amount / it.quantity),
              }).toList()
          : <Map<String, dynamic>>[];

      final validUntil = _isProforma
          ? DateTime.now().add(const Duration(days: 14))
          : null;
      final row = await SupabaseService.createInvoice(
        businessId: businessId,
        customerName: customer,
        customerId: _customerId,
        totalAmount: amount,
        description: _descCtrl.text.trim(),
        lineItems: lineItems.isNotEmpty ? lineItems : null,
        isProforma: _isProforma,
        validUntil: validUntil,
      );

      if (!mounted) return;

      // ignore: unawaited_futures
      appState.loadFinancials();
      // ignore: unawaited_futures
      appState.loadInvoices();
      widget.onSent?.call();

      setState(() {
        _sending = false;
        _createdInvoiceNumber = row['invoice_number'] as String?;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(msg);
    final extracted = match?.group(1)?.trim();
    if (extracted != null && extracted.isNotEmpty) return extracted;
    return 'Could not save the invoice. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: switch (_step) {
        0 => _DetailsStep(
            customerName: _customerName,
            customerId: _customerId,
            businessId: context.read<AppState>().business.id,
            selectedCustomer: _selectedCustomer,
            descCtrl: _descCtrl,
            amountCtrl: _amountCtrl,
            selectedItems: _selectedItems,
            productSearchCtrl: _productSearchCtrl,
            productResults: _productResults,
            searchingProducts: _searchingProducts,
            aiParsing: _aiParsing,
            totalAmount: _totalAmount,
            onCustomerChanged: _onCustomerChanged,
            onAiDraft: _aiDraft,
            onSearchProducts: _searchProducts,
            onAddProduct: _addProductItem,
            onUpdateQuantity: _updateItemQuantity,
            onNext: () => setState(() => _step = 1),
            isProforma: _isProforma,
            onToggleProforma: (v) => setState(() => _isProforma = v),
          ),
        1 => _PreviewStep(
            customer: _customerName,
            amount: _totalAmount,
            desc: _descCtrl.text,
            selectedItems: _selectedItems,
            sending: _sending,
            error: _sendError,
            onBack: _sending
                ? null
                : () => setState(() {
                      _step = 0;
                      _sendError = null;
                    }),
            onSend: _sending ? null : _sendInvoice,
          ),
        _ => _SentStep(
            invoiceNumber: _createdInvoiceNumber,
            onClose: () => Navigator.pop(context),
          ),
      },
    );
  }
}

// ── Internal model for selected inventory items ──
class _SelectedItem {
  final InventoryItem product;
  final int quantity;

  const _SelectedItem({required this.product, required this.quantity});

  num get total => (product.unitPrice ?? 0) * quantity;
}

// ── Step 1: Details ──────────────────────────────────────────────────────────
class _DetailsStep extends StatelessWidget {
  final String customerName;
  final String? customerId;
  final String? businessId;
  final Customer? selectedCustomer;
  final TextEditingController descCtrl, amountCtrl, productSearchCtrl;
  final List<_SelectedItem> selectedItems;
  final List<InventoryItem> productResults;
  final bool searchingProducts, aiParsing;
  final num totalAmount;
  final void Function(String, Customer?) onCustomerChanged;
  final VoidCallback onAiDraft;
  final void Function(String) onSearchProducts;
  final void Function(InventoryItem) onAddProduct;
  final void Function(int, int) onUpdateQuantity;
  final VoidCallback onNext;
  final bool isProforma;
  final void Function(bool) onToggleProforma;

  const _DetailsStep({
    required this.customerName,
    required this.customerId,
    required this.businessId,
    required this.selectedCustomer,
    required this.descCtrl,
    required this.amountCtrl,
    required this.selectedItems,
    required this.productSearchCtrl,
    required this.productResults,
    required this.searchingProducts,
    required this.aiParsing,
    required this.totalAmount,
    required this.onCustomerChanged,
    required this.onAiDraft,
    required this.onSearchProducts,
    required this.onAddProduct,
    required this.onUpdateQuantity,
    required this.onNext,
    required this.isProforma,
    required this.onToggleProforma,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text('New invoice',
                style: AppType.heading(size: 20, color: c.text)),
          ),

          // ── Customer selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomerSelector(
              businessId: businessId,
              label: 'Bill to',
              optional: false,
              initialName: customerName,
              initialCustomer: selectedCustomer,
              onChanged: onCustomerChanged,
            ),
          ),
          const SizedBox(height: 16),

          // ── Line items from inventory ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Items',
                style: AppType.body(
                    size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
          ),
          const SizedBox(height: 6),

          // Selected items list
          if (selectedItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.all(2),
                child: Column(
                  children: [
                    for (var i = 0; i < selectedItems.length; i++) ...[
                      _SelectedItemRow(
                        item: selectedItems[i],
                        index: i,
                        onUpdateQuantity: onUpdateQuantity,
                      ),
                      if (i < selectedItems.length - 1)
                        Divider(height: 1, thickness: 0.5, color: c.border),
                    ],
                    Divider(height: 1, color: c.borderStrong),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Total',
                                style: AppType.body(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: c.text)),
                          ),
                          Text(formatGHS(totalAmount),
                              style: AppType.body(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: c.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Add product from inventory
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: 48,
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: c.textFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: productSearchCtrl,
                      onChanged: (v) {
                        onSearchProducts(v);
                      },
                      style: AppType.body(size: 13.5, color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Add from inventory…',
                        hintStyle:
                            AppType.body(size: 13, color: c.textFaint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (searchingProducts)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(c.teal)),
                    ),
                ],
              ),
            ),
          ),

          // Product search dropdown
          if (productResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
                boxShadow: AppShadows.card,
              ),
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: productResults.map((product) {
                  final alreadyAdded = selectedItems
                      .any((it) => it.product.id == product.id);
                  return InkWell(
                    onTap: alreadyAdded ? null : () => onAddProduct(product),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name,
                                    style: AppType.body(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: c.text),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (product.unitPrice != null)
                                  Text(formatGHS(product.unitPrice!),
                                      style: AppType.body(
                                          size: 11.5, color: c.textMuted)),
                              ],
                            ),
                          ),
                          Text('Stock: ${product.currentStock}',
                              style: AppType.body(
                                  size: 11.5,
                                  color: c.textFaint)),
                          const SizedBox(width: 8),
                          if (alreadyAdded)
                            Icon(Icons.check_circle,
                                size: 18, color: c.green)
                          else
                            Icon(Icons.add_circle_outline,
                                size: 18, color: c.navy),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Manual amount fallback (shown only when no items selected)
          if (selectedItems.isEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Or enter amount manually',
                      style: AppType.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: c.textFaint)),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      style: AppType.body(size: 14, color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Amount (GHS)',
                        hintStyle:
                            AppType.body(size: 13, color: c.textFaint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Proforma toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => onToggleProforma(!isProforma),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isProforma ? c.navySurface : c.bgInset,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isProforma ? c.navyTint : c.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isProforma
                          ? Icons.description_rounded
                          : Icons.description_outlined,
                      size: 18,
                      color: isProforma ? c.navy : c.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create as proforma quote',
                              style: AppType.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: isProforma ? c.navy : c.text)),
                          Text(
                              isProforma
                                  ? 'Client can review before you send the real invoice'
                                  : 'Send a draft quote for client approval first',
                              style: AppType.body(
                                  size: 11.5, color: c.textMuted)),
                        ],
                      ),
                    ),
                    Icon(
                      isProforma
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 20,
                      color: isProforma ? c.navy : c.textFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AI smart draft
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: c.tealSurface,
                borderRadius: BorderRadius.circular(14),                    border: Border.all(color: c.tealSurfaceStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: c.navyDeep),
                        const SizedBox(width: 6),
                        Text('AI smart draft',
                            style: AppType.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: c.navyDeep)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: descCtrl,
                      style: AppType.body(size: 13, color: c.text),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. "Invoice Kente Co. GHS 2,400 for fabric"',
                        hintStyle:
                            AppType.body(size: 12, color: c.textFaint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: GestureDetector(
                      onTap: aiParsing ? null : onAiDraft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                      color: c.tealDeep,
                      borderRadius: BorderRadius.circular(8),
                        ),
                        child: aiParsing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Fill from description',
                                style: AppType.body(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppBtn(
              'Preview invoice →',
              full: true,
              onTap: totalAmount > 0 && customerName.isNotEmpty
                  ? onNext
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Selected item row ────────────────────────────────────────────────────────
class _SelectedItemRow extends StatelessWidget {
  final _SelectedItem item;
  final int index;
  final void Function(int, int) onUpdateQuantity;

  const _SelectedItemRow({
    required this.item,
    required this.index,
    required this.onUpdateQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (item.product.unitPrice != null)
                  Text(formatGHS(item.product.unitPrice!) + ' each',
                      style: AppType.body(size: 11, color: c.textMuted)),
              ],
            ),
          ),
          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onUpdateQuantity(index, item.quantity - 1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.remove, size: 14, color: c.textMuted),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('${item.quantity}',
                    textAlign: TextAlign.center,
                    style: AppType.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: c.text)),
              ),
              GestureDetector(
                onTap: () => onUpdateQuantity(index, item.quantity + 1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.add, size: 14, color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(formatGHS(item.total),
                textAlign: TextAlign.right,
                style: AppType.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.text)),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Preview ──────────────────────────────────────────────────────────
class _PreviewStep extends StatelessWidget {
  final String customer, desc;
  final num amount;
  final List<_SelectedItem> selectedItems;
  final bool sending;
  final String? error;
  final VoidCallback? onBack, onSend;

  const _PreviewStep({
    required this.customer,
    required this.amount,
    required this.desc,
    required this.selectedItems,
    required this.sending,
    required this.error,
    required this.onBack,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Icon(Icons.arrow_back,
                      size: 20,
                      color: onBack == null ? c.textFaint : c.text),
                ),
                const SizedBox(width: 12),
                Text('Preview invoice',
                    style: AppType.heading(size: 18, color: c.text)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('INVOICE',
                              style: AppType.label(
                                  size: 10, color: c.textMuted)),
                          Text('Number assigned on save',
                              style: AppType.body(
                                  size: 11, color: c.textFaint)),
                        ],
                      ),
                      AppPill('Draft', tone: PillTone.neutral, small: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Bill to',
                      style: AppType.body(size: 11, color: c.textMuted)),
                  Text(customer.isEmpty ? '—' : customer,
                      style: AppType.heading(size: 17, color: c.text)),
                  const SizedBox(height: 16),
                  Divider(color: c.border),
                  const SizedBox(height: 12),
                  if (selectedItems.isNotEmpty) ...[
                    for (final item in selectedItems) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.product.name,
                                style: AppType.body(
                                    size: 13,
                                    weight: FontWeight.w500,
                                    color: c.text)),
                          ),
                          Text('${item.quantity} × ',
                              style: AppType.body(
                                  size: 12, color: c.textFaint)),
                          SizedBox(
                            width: 70,
                            child: Text(formatGHS(item.total),
                                textAlign: TextAlign.right,
                                style: AppType.body(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: c.text)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Divider(color: c.borderStrong),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total amount',
                          style: AppType.body(
                              size: 13, color: c.textMuted)),
                      Text(formatGHS(amount),
                          style: AppType.heading(size: 22, color: c.text)),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(desc,
                        style: AppType.body(size: 12, color: c.textMuted)),
                  ],
                ],
              ),
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.rose.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: c.rose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error!,
                          style: AppType.body(size: 13, color: c.rose)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: sending
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(c.navy),
                        ),
                      ),
                    ),
                  )
                : AppBtn('Send invoice',
                    full: true, icon: 'north_east', onTap: onSend),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Sent ─────────────────────────────────────────────────────────────
class _SentStep extends StatelessWidget {
  final String? invoiceNumber;
  final VoidCallback onClose;

  const _SentStep({required this.invoiceNumber, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(color: c.greenSurface, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 32, color: c.green),
          ),
          const SizedBox(height: 16),
          Text('Invoice saved',
              style: AppType.heading(size: 22, color: c.text)),
          const SizedBox(height: 8),
          if (invoiceNumber != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(invoiceNumber!,
                  style: AppType.mono(size: 13, color: c.text)),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Added to your Outstanding list.\nShare with your customer via WhatsApp or email.',
            style: AppType.body(size: 13, color: c.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppBtn('Done',
              full: true,
              variant: BtnVariant.secondary,
              onTap: onClose),
        ],
      ),
    );
  }
}
