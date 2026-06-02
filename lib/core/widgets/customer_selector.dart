import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../tokens.dart';
import '../../services/app_logger.dart';
import '../../services/supabase_service.dart';

/// Typeahead picker for [Customer]. Embeds inline in any form — invoice
/// builder, log-sale sheet, etc. The widget owns its own debounced search
/// against `SupabaseService.fetchCustomers`. Behaviour:
///
///  - Empty input → shows the user's [recentCustomers] (passed in).
///  - Non-empty input that matches → list of matches, tap to select.
///  - Non-empty input with no match → single "+ Add 'X' as a new customer"
///    row at the bottom. Tapping it calls [SupabaseService.createCustomer]
///    and selects the new row.
///
/// [onChanged] fires whenever the chosen customer changes, OR when the user
/// types a free-text name that hasn't been resolved to a Customer yet. The
/// caller writes both: `client_name` (always present) and `customer_id`
/// (only when a Customer is selected). That preserves the existing free-text
/// fallback for sales where the user just wants to log a walk-in without
/// creating a record.
class CustomerSelector extends StatefulWidget {
  /// The signed-in user's businessId — needed for fetch + insert.
  final String? businessId;

  /// Recent customers to show before the user types. Caller controls how
  /// these are sourced (e.g. AppState.recentCustomers).
  final List<Customer> recentCustomers;

  /// Fires when selection changes. [customer] is null while the user is
  /// typing free text that hasn't been bound to a real Customer yet.
  /// [name] is the trimmed string currently in the field — always present.
  final void Function(String name, Customer? customer) onChanged;

  /// Initial value to seed the field with. Useful when re-opening a sheet
  /// after a partial entry.
  final String initialName;
  final Customer? initialCustomer;

  /// Label shown above the field. Default 'Customer'.
  final String label;

  /// Whether to mark customer as optional. When true, the helper text
  /// reminds the user they can skip.
  final bool optional;

  const CustomerSelector({
    super.key,
    required this.businessId,
    required this.onChanged,
    this.recentCustomers = const [],
    this.initialName = '',
    this.initialCustomer,
    this.label = 'Customer',
    this.optional = false,
  });

  @override
  State<CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends State<CustomerSelector> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  List<Customer> _results = const [];
  bool _searching = false;
  bool _adding = false;
  Customer? _selected;
  String? _error;

  // Recent customers loaded lazily the first time the field is focused with
  // an empty query. Kept in widget state so we don't re-fetch on every
  // rebuild / focus toggle.
  List<Customer> _recents = const [];
  bool _recentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialName;
    _selected = widget.initialCustomer;
    _recents = widget.recentCustomers;
    _recentsLoaded = widget.recentCustomers.isNotEmpty;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
    // Lazy-load recents the first time the user focuses the field.
    if (_focusNode.hasFocus &&
        !_recentsLoaded &&
        _ctrl.text.trim().isEmpty &&
        widget.businessId != null) {
      _loadRecents();
    }
  }

  Future<void> _loadRecents() async {
    final bizId = widget.businessId;
    if (bizId == null) return;
    _recentsLoaded = true;
    try {
      final rows = await SupabaseService.fetchCustomers(
          businessId: bizId, limit: 6);
      if (!mounted) return;
      setState(() {
        _recents = rows.map(Customer.fromRow).toList();
      });
    } catch (e, st) {
      log.warning('CustomerSelector — recents load failed',
          error: e, stackTrace: st);
      _recentsLoaded = false; // allow retry on next focus
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    // Editing the text invalidates any previous selection — the user is
    // typing something new. Notify the caller with the free-text name so
    // the parent form still has a value to write to `client_name`.
    if (_selected != null && value.trim() != _selected!.fullName) {
      _selected = null;
    }
    widget.onChanged(value.trim(), _selected);

    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final bizId = widget.businessId;
    if (bizId == null) return;
    setState(() => _searching = true);
    try {
      final rows = await SupabaseService.fetchCustomers(
        businessId: bizId,
        query: query,
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _results = rows.map(Customer.fromRow).toList();
        _searching = false;
      });
    } catch (e, st) {
      log.warning('CustomerSelector — search failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _selectExisting(Customer customer) {
    _ctrl.text = customer.fullName;
    setState(() {
      _selected = customer;
      _results = const [];
    });
    widget.onChanged(customer.fullName, customer);
    _focusNode.unfocus();
  }

  Future<void> _addNew(String name) async {
    final bizId = widget.businessId;
    if (bizId == null) {
      setState(() => _error = 'Sign in to add customers.');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final row = await SupabaseService.createCustomer(
        businessId: bizId,
        fullName: name,
      );
      final customer = Customer.fromRow(row);
      if (!mounted) return;
      _selectExisting(customer);
    } catch (e, st) {
      log.error('CustomerSelector — add failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error =
            'Could not add "$name". Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = _ctrl.text.trim();
    final isOpen = _focusNode.hasFocus;
    // What we surface in the dropdown:
    //   - typing → search results + "+ Add" row if no exact match
    //   - empty + focused → recent customers
    final hasExactMatch = _results.any(
        (r) => r.fullName.toLowerCase() == query.toLowerCase());
    final showAddRow =
        isOpen && query.isNotEmpty && !hasExactMatch && !_searching;
    final dropdownItems = query.isEmpty ? _recents : _results;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label,
                style: AppType.body(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: c.textMuted)),
            if (widget.optional) ...[
              const SizedBox(width: 6),
              Text('(optional)',
                  style: AppType.body(size: 11, color: c.textFaint)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: c.bgInset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isOpen ? c.navy : c.border,
                width: isOpen ? 1.5 : 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 50,
          child: Row(
            children: [
              Icon(
                _selected != null
                    ? Icons.person_rounded
                    : Icons.person_outline,
                size: 17,
                color: _selected != null ? c.navy : c.textFaint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  onChanged: _onTextChanged,
                  style: AppType.body(
                      size: 14,
                      weight: FontWeight.w500,
                      color: c.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.optional
                        ? 'Walk-in or type a name'
                        : 'Type a name',
                    hintStyle:
                        AppType.body(size: 14, color: c.textFaint),
                  ),
                ),
              ),
              if (_searching || _adding)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(c.navy),
                  ),
                )
              else if (_selected != null)
                Icon(Icons.check_circle_rounded,
                    size: 17, color: c.green),
            ],
          ),
        ),
        // Dropdown — only render when focused and there's something to show
        if (isOpen &&
            (dropdownItems.isNotEmpty || showAddRow))
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: c.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                for (final cust in dropdownItems.take(5))
                  _CustomerRow(
                    customer: cust,
                    onTap: () => _selectExisting(cust),
                  ),
                if (showAddRow)
                  _AddCustomerRow(
                    name: query,
                    onTap: _adding ? null : () => _addNew(query),
                  ),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: AppType.body(size: 12, color: c.rose)),
        ],
      ],
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  const _CustomerRow({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.navySurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(customer.fullName),
                style: AppType.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: c.navy),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.fullName,
                      style: AppType.body(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (customer.phone != null)
                    Text(customer.phone!,
                        style: AppType.body(
                            size: 11.5, color: c.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join();
  }
}

class _AddCustomerRow extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  const _AddCustomerRow({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.greenSurface.withValues(alpha: 0.5),
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 18, color: c.greenDeep),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppType.body(size: 13, color: c.text),
                  children: [
                    const TextSpan(text: 'Add '),
                    TextSpan(
                      text: '"$name"',
                      style: AppType.body(
                          size: 13,
                          weight: FontWeight.w700,
                          color: c.greenDeep),
                    ),
                    const TextSpan(text: ' as a new customer'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
