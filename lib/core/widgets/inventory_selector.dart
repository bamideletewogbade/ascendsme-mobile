import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../tokens.dart';

/// Typeahead picker for [InventoryItem] — mirrors the [CustomerSelector]
/// pattern so adding products to an invoice feels consistent with adding
/// customers.
///
/// Behaviour:
///  - Empty focused → shows the first 6 items from the full inventory list.
///  - Non-empty input that matches → filtered list, tap to select.
///  - Tap on an item → calls [onChanged] with the selected item.
///
/// When [multiSelect] is true (for flows like adding line items), the field
/// clears after each selection so the user can keep adding products.
/// When false (default, single-select), the field shows the selected item.
class InventorySelector extends StatefulWidget {
  /// The full inventory list — used for both "recent" display and local search.
  final List<InventoryItem> inventory;

  /// Fires when an item is selected. [item] is always non-null when called.
  final ValueChanged<InventoryItem> onChanged;

  /// Label shown above the field.
  final String label;

  /// When true, clears after each selection (for multi-add flows).
  final bool multiSelect;

  const InventorySelector({
    super.key,
    required this.inventory,
    required this.onChanged,
    this.label = 'Add product',
    this.multiSelect = false,
  });

  @override
  State<InventorySelector> createState() => _InventorySelectorState();
}

class _InventorySelectorState extends State<InventorySelector> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  List<InventoryItem> _results = const [];
  bool _searching = false;
  InventoryItem? _selected;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
    if (_focusNode.hasFocus && _ctrl.text.trim().isEmpty && _selected == null) {
      setState(() {
        _results = widget.inventory.take(6).toList();
      });
    }
  }

  void _onTextChanged(String value) {
    if (_selected != null) {
      _selected = null;
    }

    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = _focusNode.hasFocus ? widget.inventory.take(6).toList() : [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () => _runSearch(query));
  }

  void _runSearch(String query) {
    setState(() => _searching = true);
    final q = query.toLowerCase();
    final filtered = widget.inventory.where((p) {
      return p.name.toLowerCase().contains(q) ||
          (p.sku?.toLowerCase().contains(q) ?? false);
    }).take(8).toList();
    setState(() {
      _results = filtered;
      _searching = false;
    });
  }

  void _selectItem(InventoryItem item) {
    widget.onChanged(item);

    if (widget.multiSelect) {
      // Multi-select: clear and keep the field ready for the next item
      _ctrl.clear();
      setState(() {
        _selected = null;
        _results = widget.inventory.take(6).toList();
      });
      _focusNode.requestFocus();
    } else {
      // Single-select: show the selected item
      _ctrl.text = item.name;
      setState(() {
        _selected = item;
        _results = const [];
      });
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = _ctrl.text.trim();
    final isOpen = _focusNode.hasFocus;
    final showDropdown = isOpen && (_results.isNotEmpty || _searching);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: AppType.body(
                size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: c.bgInset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isOpen ? c.navy : c.border, width: isOpen ? 1.5 : 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 48,
          child: Row(
            children: [
              Icon(
                  _selected != null && !widget.multiSelect
                      ? Icons.inventory_2_rounded
                      : Icons.inventory_2_outlined,
                  size: 17,
                  color: _selected != null && !widget.multiSelect
                      ? c.navy
                      : c.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  onChanged: _onTextChanged,
                  style: AppType.body(
                      size: 14, weight: FontWeight.w500, color: c.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.multiSelect
                        ? 'Search and add products…'
                        : 'Search products…',
                    hintStyle: AppType.body(size: 14, color: c.textFaint),
                  ),
                ),
              ),
              if (_searching)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(c.navy),
                  ),
                )
              else if (_selected != null && !widget.multiSelect)
                Icon(Icons.check_circle_rounded, size: 17, color: c.green),
            ],
          ),
        ),
        // Dropdown
        if (showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: c.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
              boxShadow: AppShadows.card,
            ),
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                  )
                else if (_results.isEmpty && query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('No products match "$query"',
                        style: AppType.body(size: 13, color: c.textMuted)),
                  )
                else
                  ..._results.map((item) => _buildItemRow(context, c, item)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, AppColorsX c, InventoryItem item) {
    final stock = item.currentStock;
    final isLow = item.lowStock;
    final price = item.unitPrice != null ? formatGHS(item.unitPrice!) : null;

    return InkWell(
      onTap: () => _selectItem(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _results.last == item
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border, width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.navySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                style: AppType.body(
                    size: 13, weight: FontWeight.w700, color: c.navy),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: AppType.body(
                          size: 13, weight: FontWeight.w600, color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      if (price != null)
                        Text(price,
                            style: AppType.body(size: 11.5, color: c.textMuted)),
                      if (price != null) const SizedBox(width: 8),
                      Text('$stock in stock',
                          style: AppType.body(
                              size: 11,
                              color: isLow ? c.rose : c.textFaint,
                              weight: isLow ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(widget.multiSelect
                ? Icons.add_circle_outline
                : Icons.chevron_right,
                size: 18,
                color: widget.multiSelect ? c.navy : c.textFaint),
          ],
        ),
      ),
    );
  }
}
