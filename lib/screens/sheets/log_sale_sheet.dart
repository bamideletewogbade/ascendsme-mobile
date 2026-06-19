import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/customer_selector.dart';
import '../../services/crm_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../tools/receipts_screen.dart';

/// Bottom sheet for logging a direct sale — money received in the moment
/// (cash at the counter, MoMo from a customer, bank transfer at delivery).
///
/// Unlike [NewInvoiceSheet], there's no bill-to-be-sent here. The receipt
/// goes straight into the `receipts` table and counts as revenue immediately.
///
/// Use [show] to open from any screen.
class LogSaleSheet extends StatefulWidget {
  final VoidCallback? onSaved;

  const LogSaleSheet({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogSaleSheet(onSaved: onSaved),
    );
  }

  @override
  State<LogSaleSheet> createState() => _LogSaleSheetState();
}

const _paymentMethods = [
  ('cash', 'Cash', Icons.payments_outlined),
  ('momo', 'MoMo', Icons.phone_android),
  ('bank', 'Bank', Icons.account_balance_outlined),
];

/// Line item for a sale — product/service with quantity.
class _SaleLineItem {
  final InventoryItem item;
  int qty;

  _SaleLineItem({required this.item, this.qty = 1});

  num get total => (item.unitPrice ?? 0) * qty;
}

class _LogSaleSheetState extends State<LogSaleSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  DateTime _date = DateTime.now();

  // Customer state — name is always present (may be free-text for walk-ins),
  // customerId is set only when the user selected or added a real Customer row.
  String _customerName = '';
  String? _customerId;

  /// Selected items from inventory — auto-calculates the total amount.
  final List<_SaleLineItem> _selectedItems = [];

  /// Whether to show the inventory selector.
  bool _showItemSelector = false;

  /// Search controller for the item selector — promoted to state field to
  /// avoid being recreated on every parent rebuild.
  final _itemSearchCtrl = TextEditingController();

  bool _saving = false;
  String? _error;
  bool _saved = false;
  String? _savedReceiptNumber;

  num get _itemsTotal =>
      _selectedItems.fold<num>(0, (sum, li) => sum + (li.item.unitPrice ?? 0) * li.qty);

  void _updateAmountFromItems() {
    if (_itemsTotal > 0) {
      _amountCtrl.text = _itemsTotal.toStringAsFixed(0);
    }
  }

  void _addItem(InventoryItem item) {
    final existing = _selectedItems.where((li) => li.item.id == item.id).firstOrNull;
    if (existing != null) {
      existing.qty++;
    } else {
      _selectedItems.add(_SaleLineItem(item: item));
    }
    _showItemSelector = false;
    _updateAmountFromItems();
    setState(() {});
  }

  void _removeItem(int index) {
    _selectedItems.removeAt(index);
    if (_selectedItems.isEmpty) {
      _amountCtrl.clear();
    } else {
      _updateAmountFromItems();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _itemSearchCtrl.dispose();
    super.dispose();
  }

  num? _parseAmount() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return num.tryParse(raw);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final amount = _parseAmount();
    final appState = context.read<AppState>();
    final businessId = appState.business.id;

    if (amount == null || amount <= 0) {
      setState(() {
        _saving = false;
        _error = 'Enter a valid amount greater than 0.';
      });
      return;
    }
    if (!appState.supabaseConfigured) {
      // Mock-mode shortcut.
      setState(() {
        _saving = false;
        _saved = true;
        _savedReceiptNumber = 'MOCK-001';
      });
      widget.onSaved?.call();
      return;
    }
    if (businessId == null) {
      setState(() {
        _saving = false;
        _error =
            'Your business profile isn\'t set up yet. Please complete signup first.';
      });
      return;
    }

    try {
      final row = await SupabaseService.createSale(
        businessId: businessId,
        amount: amount,
        paymentMethod: _paymentMethod,
        paidDate: _date,
        customerName: _customerName,
        customerId: _customerId,
        description: _descCtrl.text.trim(),
      );

      if (!mounted) return;

      // Sync CRM metrics in background
      unawaited(CrmService.syncAfterPurchase(
        businessId: businessId,
        customerName: _customerName,
        customerPhone: null,
        amountGhs: amount.toDouble(),
      ));

      // ignore: unawaited_futures
      appState.loadFinancials();
      // ignore: unawaited_futures
      appState.loadReceipts();
      widget.onSaved?.call();

      setState(() {
        _saving = false;
        _saved = true;
        _savedReceiptNumber = row['receipt_number'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(msg);
    final extracted = match?.group(1)?.trim();
    if (extracted != null && extracted.isNotEmpty) return extracted;
    return 'Could not save the sale. Check your connection and try again.';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final today = DateTime.now();
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    if (isToday) return 'Today';
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
      child: _saved ? _buildSaved(c) : _buildForm(c),
    );
  }

  Widget _buildForm(AppColorsX c) {
    final state = context.watch<AppState>();
    final businessId = state.business.id;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Quick sale',
                      style: AppType.heading(size: 20, color: c.text)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.close, size: 16, color: c.textMuted),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Text(
              'Money received now — cash at the counter, MoMo, or bank.',
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ),

          // Amount — hero field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount (GHS)',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(height: 6),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textInputAction: TextInputAction.next,
                    style: AppType.display(size: 22, color: c.text),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: AppType.display(size: 22, color: c.textFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Select items from inventory ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items',
                        style: AppType.body(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: c.textMuted)),
                    GestureDetector(
                      onTap: () => setState(() => _showItemSelector = !_showItemSelector),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: c.tealSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showItemSelector ? Icons.close : Icons.add,
                              size: 12, color: c.teal
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _showItemSelector ? 'Close' : 'Add from inventory',
                              style: AppType.body(size: 11, weight: FontWeight.w600, color: c.teal),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Selected items
                if (_selectedItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._selectedItems.asMap().entries.map((entry) {
                    final li = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.bgInset,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(li.item.name,
                                    style: AppType.body(size: 12.5, weight: FontWeight.w600, color: c.text),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  'GHS ${li.item.unitPrice?.toStringAsFixed(0) ?? '0'} × ${li.qty}',
                                  style: AppType.body(size: 11, color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (li.qty > 1) {
                                    li.qty--;
                                    _updateAmountFromItems();
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: c.bgElevated,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: c.border),
                                  ),
                                  child: Icon(Icons.remove, size: 14, color: c.textMuted),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('${li.qty}',
                                  style: AppType.body(size: 13, weight: FontWeight.w700, color: c.text)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  li.qty++;
                                  _updateAmountFromItems();
                                  setState(() {});
                                },
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: c.bgElevated,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: c.border),
                                  ),
                                  child: Icon(Icons.add, size: 14, color: c.textMuted),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removeItem(entry.key),
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: c.roseSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.close, size: 12, color: c.rose),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_itemsTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Total: GHS ${_itemsTotal.round()}',
                          style: AppType.body(size: 12, weight: FontWeight.w700, color: c.teal)),
                    ),
                ],
                // Inventory selector (togglable)
                if (_showItemSelector) ...[
                  const SizedBox(height: 8),
                  _buildItemSelector(c),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment method chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment method',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: _paymentMethods.map((pm) {
                    final active = _paymentMethod == pm.$1;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: pm.$1 == _paymentMethods.last.$1 ? 0 : 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _paymentMethod = pm.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: active ? c.navySurface : c.bgInset,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(                                      color: active
                                              ? c.tealDeep
                                              : Colors.transparent,
                                  width: 1.5),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(pm.$3,
                                    size: 18,
                                    color: active ? c.navyDeep : c.textMuted),
                                const SizedBox(height: 4),
                                Text(pm.$2,
                                    style: AppType.body(
                                        size: 12,
                                        weight: FontWeight.w600,                                    color: active ? c.navyDeep : c.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Customer — typeahead from the real `customers` table. Selecting
          // a row sets _customerId; typing free text leaves it null (still
          // works for walk-in sales). "+ Add" creates a new customer inline.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomerSelector(
              businessId: businessId,
              label: 'Customer',
              optional: true,
              initialName: _customerName,
              onChanged: (name, customer) {
                _customerName = name;
                _customerId = customer?.id;
              },
            ),
          ),

          const SizedBox(height: 16),

          // Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 17, color: c.textFaint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_formatDate(_date),
                              style: AppType.body(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: c.text)),
                        ),
                        Icon(Icons.expand_more,
                            size: 18, color: c.textFaint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Note — optional
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Note (optional)',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _descCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    style: AppType.body(size: 14, color: c.text),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. 2 kente skirts (size M)',
                      hintStyle: AppType.body(size: 13, color: c.textFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Jump to full tool ──
          _SaleNavFooter(context),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: c.rose.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: c.rose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: AppType.body(size: 13, color: c.rose)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _saving
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(c.teal),
                      ),
                    ),
                  )
                : AppBtn('Save sale', full: true, onTap: _save),
          ),
        ],
      ),
    );
  }

  Widget _SaleNavFooter(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.open_in_new, size: 10, color: c.textFaint),
              const SizedBox(width: 4),
              Text('GO TO FULL TOOL',
                  style: AppType.body(size: 9, weight: FontWeight.w700, color: c.textFaint)),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.of(context)
                ..pop()
                ..push(MaterialPageRoute(builder: (_) => const ReceiptsScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c.tealSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_long_outlined, size: 16, color: c.tealDeep),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All receipts & sales',
                            style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
                        Text('Review, search, export',
                            style: AppType.body(size: 11, color: c.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: c.tealSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.arrow_forward_ios, size: 10, color: c.tealDeep),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSelector(AppColorsX c) {
    final state = context.watch<AppState>();
    final inventory = state.inventory;

    return StatefulBuilder(
      builder: (ctx, setLocalState) {
        final query = _itemSearchCtrl.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? inventory.take(8).toList()
            : inventory.where((item) =>
                item.name.toLowerCase().contains(query) ||
                (item.sku?.toLowerCase().contains(query) ?? false)
            ).take(8).toList();

        return Container(
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search field
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _itemSearchCtrl,
                  autofocus: true,
                  style: AppType.body(size: 13, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Search products & services…',
                    hintStyle: AppType.body(size: 13, color: c.textFaint),
                    prefixIcon: Icon(Icons.search, size: 16, color: c.textFaint),
                    filled: true,
                    fillColor: c.bgInset,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (_) => setLocalState(() {}),
                ),
              ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No items found',
                      style: AppType.body(size: 13, color: c.textMuted)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: filtered.map((item) {
                      final alreadySelected = _selectedItems.any((li) => li.item.id == item.id);
                      return InkWell(
                        onTap: alreadySelected ? null : () => _addItem(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: item != filtered.last
                              ? BoxDecoration(
                                  border: Border(bottom: BorderSide(color: c.border, width: 0.5)))
                              : null,
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: !item.isGoods ? c.tealSurface : c.navySurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  !item.isGoods ? Icons.miscellaneous_services_outlined : Icons.inventory_2_outlined,
                                  size: 14, color: !item.isGoods ? c.teal : c.navy,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: AppType.body(size: 12.5, weight: FontWeight.w600, color: c.text),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 1),
                                    Text(
                                      item.isGoods
                                          ? 'GHS ${item.unitPrice?.toStringAsFixed(0) ?? '0'} · ${item.currentStock} in stock'
                                          : 'GHS ${item.unitPrice?.toStringAsFixed(0) ?? '0'} · Service',
                                      style: AppType.body(size: 10.5, color: c.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (alreadySelected)
                                Icon(Icons.check_circle, size: 16, color: c.green)
                              else
                                Icon(Icons.add_circle_outline, size: 16, color: c.teal),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaved(AppColorsX c) {
    final amount = _parseAmount();
    final methodLabel = _paymentMethods
        .firstWhere((p) => p.$1 == _paymentMethod, orElse: () => _paymentMethods.first)
        .$2;
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
          Text('Sale logged',
              style: AppType.heading(size: 22, color: c.text)),
          const SizedBox(height: 6),
          if (amount != null)
            Text('GHS $amount  ·  $methodLabel',
                style: AppType.body(size: 13.5, color: c.textMuted)),
          if (_savedReceiptNumber != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_savedReceiptNumber!,
                  style: AppType.mono(size: 12, color: c.text)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Your revenue is updated.',
            textAlign: TextAlign.center,
            style: AppType.body(size: 13, color: c.textMuted),
          ),
          const SizedBox(height: 24),
          AppBtn('Done',
              full: true,
              variant: BtnVariant.secondary,
              onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
