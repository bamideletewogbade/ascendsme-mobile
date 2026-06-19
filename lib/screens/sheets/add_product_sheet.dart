import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/inventory_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet for adding a new inventory product.
/// Follows the same pattern as [LogSaleSheet] — single-column form, validation,
/// saving state, success confirmation.
class AddProductSheet extends StatefulWidget {
  /// If provided, the sheet edits this product instead of creating a new one.
  final InventoryItem? existing;

  const AddProductSheet({super.key, this.existing});

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String _category = 'General';
  bool _isGoods = true;

  bool _saving = false;
  String? _error;
  bool _saved = false;

  final _categories = [
    'General', 'Fashion', 'Food & Beverage', 'Beauty',
    'Electronics', 'Home & Living', 'Accessories', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _skuCtrl.text = e.sku ?? '';
      _stockCtrl.text = e.currentStock.toString();
      _thresholdCtrl.text = e.lowStockThreshold?.toString() ?? '';
      _priceCtrl.text = e.unitPrice?.toString() ?? '';
      _costCtrl.text = e.unitCost?.toString() ?? '';
      _category = e.category;
      _isGoods = e.isGoods;
    }
    // Live margin preview: rebuild when price/cost changes
    _priceCtrl.addListener(_onMarginFieldChanged);
    _costCtrl.addListener(_onMarginFieldChanged);
  }

  void _onMarginFieldChanged() {
    // setState is cheap and only rebuilds when a field is actively being edited
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameCtrl.text.trim();
    final sku = _skuCtrl.text.trim();
    final stockRaw = _stockCtrl.text.trim();
    final thresholdRaw = _thresholdCtrl.text.trim();
    final priceRaw = _priceCtrl.text.trim();
    final costRaw = _costCtrl.text.trim();

    if (name.isEmpty) {
      setState(() { _saving = false; _error = 'Product name is required.'; });
      return;
    }

    final stock = int.tryParse(stockRaw) ?? 0;
    final threshold = thresholdRaw.isNotEmpty ? int.tryParse(thresholdRaw) : null;
    final price = priceRaw.isNotEmpty ? double.tryParse(priceRaw) : null;
    final cost = costRaw.isNotEmpty ? double.tryParse(costRaw) : null;

    final appState = context.read<AppState>();
    final businessId = appState.business.id;

    if (!appState.supabaseConfigured) {
      setState(() { _saving = false; _saved = true; });
      return;
    }
    if (businessId == null) {
      setState(() { _saving = false; _error = 'Business profile not set up yet.'; });
      return;
    }      try {
      if (widget.existing != null) {
        await InventoryService.updateProduct(
          productId: widget.existing!.id,
          businessId: businessId,
          name: name,
          sku: _isGoods ? sku : null,
          category: _category,
          currentStock: _isGoods ? stock : 0,
          lowStockThreshold: _isGoods ? threshold : null,
          unitPrice: price,
          unitCost: cost,
          type: _isGoods ? 'GOODS' : 'SERVICE',
        );
      } else {
        await InventoryService.createProduct(
          businessId: businessId,
          name: name,
          sku: _isGoods ? sku : null,
          category: _category,
          currentStock: _isGoods ? stock : 0,
          lowStockThreshold: _isGoods ? threshold : null,
          unitPrice: price,
          unitCost: cost,
          type: _isGoods ? 'GOODS' : 'SERVICE',
        );
      }

      if (!mounted) return;
      unawaited(appState.loadInventory());
      setState(() { _saving = false; _saved = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = _friendlyError(e); });
    }
  }

  double _calcMargin(String priceStr, String costStr) {
    final p = double.tryParse(priceStr);
    final c = double.tryParse(costStr);
    if (p == null || c == null || p == 0) return 0;
    return ((p - c) / p * 100).clamp(0, 100).roundToDouble();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(msg);
    final extracted = match?.group(1)?.trim();
    if (extracted != null && extracted.isNotEmpty) return extracted;
    return 'Could not save the product. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isEdit = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _saved
          ? _buildSaved(c)
          : _buildForm(c, isEdit),
    );
  }

  Widget _buildForm(AppColorsX c, bool isEdit) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(isEdit ? 'Edit product' : 'Add product',
                style: AppType.heading(size: 20, color: c.text)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Text(
              _isGoods
                  ? (isEdit
                      ? 'Update product details and stock levels.'
                      : 'Add a product to start tracking inventory levels.')
                  : (isEdit
                      ? 'Update service details.'
                      : 'Add a service you offer. Services don\'t require stock tracking.'),
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ),

          // Goods / Service toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type',
                    style: AppType.body(
                        size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _TypeToggle(
                        label: 'Physical product',
                        icon: Icons.inventory_2_outlined,
                        active: _isGoods,
                        onTap: () => setState(() => _isGoods = true),
                      ),
                      const SizedBox(width: 3),
                      _TypeToggle(
                        label: 'Service',
                        icon: Icons.miscellaneous_services_outlined,
                        active: !_isGoods,
                        onTap: () => setState(() => _isGoods = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Product name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Field(
              label: _isGoods ? 'Product name' : 'Service name',
              ctrl: _nameCtrl,
              hint: _isGoods ? 'e.g. Ankara fabric, Kente stole' : 'e.g. Consultation, Haircut',
              autofocus: true,
            ),
          ),
          const SizedBox(height: 14),

          // SKU + Category row (only show SKU for goods)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_isGoods)
                  Expanded(
                    child: _Field(
                      label: 'SKU (optional)',
                      ctrl: _skuCtrl,
                      hint: 'e.g. AK-001',
                    ),
                  ),
                if (_isGoods) const SizedBox(width: 12),
                if (_isGoods) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category',
                          style: AppType.body(
                              size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
                      const SizedBox(height: 5),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _category,
                            isExpanded: true,
                            dropdownColor: c.bgElevated,
                            style: AppType.body(size: 14, color: c.text),
                            items: _categories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat, style: AppType.body(size: 13.5, color: c.text)),
                            )).toList(),
                            onChanged: (v) => setState(() => _category = v ?? 'General'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Current stock + Low stock threshold (only for goods)
          if (_isGoods)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Current stock',
                      ctrl: _stockCtrl,
                      hint: '0',
                      keyboard: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Low stock alert at',
                      ctrl: _thresholdCtrl,
                      hint: 'e.g. 5',
                      keyboard: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ),
          if (_isGoods) const SizedBox(height: 14),

          // Price + Cost row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Selling price (GHS)',
                    ctrl: _priceCtrl,
                    hint: '0.00',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: 'Unit cost (GHS)',
                    ctrl: _costCtrl,
                    hint: '0.00',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ),
          if (_isGoods && _priceCtrl.text.isNotEmpty && _costCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                'Profit margin: ${_calcMargin(_priceCtrl.text, _costCtrl.text)}%',
                style: AppType.body(size: 11, color: c.teal),
              ),
            ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      child: Text(_error!,
                          style: AppType.body(size: 13, color: c.rose)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _saving
                ? Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(c.teal),
                      ),
                    ),
                  )
                : AppBtn(isEdit ? 'Save changes' : 'Add product',
                    full: true, onTap: _save),
          ),
        ],
      ),
    );
  }

  Widget _buildSaved(AppColorsX c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: c.greenSurface, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 32, color: c.green),
          ),
          const SizedBox(height: 16),
          Text(
            _isGoods
                ? (widget.existing != null ? 'Product updated' : 'Product added')
                : (widget.existing != null ? 'Service updated' : 'Service added'),
            style: AppType.heading(size: 22, color: c.text),
          ),
          const SizedBox(height: 6),
          Text(
            _isGoods
                ? (widget.existing != null
                    ? 'Inventory levels updated.'
                    : 'Start tracking stock levels and get low-stock alerts.')
                : (widget.existing != null
                    ? 'Service details updated.'
                    : 'Service has been added to your offerings.'),
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

// ── Type Toggle ──────────────────────────────────────────────────────────────
class _TypeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppAnimation.fast,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? c.bgElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: c.border) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? c.teal : c.textFaint),
              const SizedBox(width: 6),
              Text(label,
                  style: AppType.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: active ? c.text : c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable field ────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType? keyboard;
  final bool autofocus;

  const _Field({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.keyboard,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppType.body(
                size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 5),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: ctrl,
            autofocus: autofocus,
            keyboardType: keyboard,
            style: AppType.body(size: 14, color: c.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppType.body(size: 13, color: c.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
