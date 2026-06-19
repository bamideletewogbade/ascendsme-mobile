import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/customer_selector.dart';
import '../../core/widgets/inventory_selector.dart';
import '../../services/app_logger.dart';
import '../../services/crm_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../tools/invoices_screen.dart';
import '../tools/inventory_screen.dart';

/// Bottom sheet for creating a new invoice (or a proforma when
/// [isProformaOnly] is true).
///
/// v2: Wires CustomerSelector for CRM linkage and inventory items as line
/// items with quantities. Selected customer + products flow into
/// [SupabaseService.createInvoice] so invoices are always linked to a
/// customer row and their line items are structured for web's PDF generator.
///
/// Use [CreateProformaSheet] for the dedicated proforma creation flow;
/// it is a thin wrapper around this sheet with `isProformaOnly: true`.
class NewInvoiceSheet extends StatefulWidget {
  final VoidCallback? onSent;
  /// When true, renders as a dedicated proforma creation flow.
  final bool isProformaOnly;

  const NewInvoiceSheet({super.key, this.onSent, this.isProformaOnly = false});

  @override
  State<NewInvoiceSheet> createState() => _NewInvoiceSheetState();
}

class _NewInvoiceSheetState extends State<NewInvoiceSheet> {
  int _step = 0;

  // ── Customer state ──
  String _customerName = '';
  String? _customerId;
  Customer? _selectedCustomer;
  String _customerEmail = '';
  String _customerPhone = '';

  // ── Invoice description ──
  final _descCtrl = TextEditingController();

  // ── Manual amount fallback (when no inventory items) ──
  final _amountCtrl = TextEditingController();

  // ── Line items from inventory ──
  final List<_SelectedItem> _selectedItems = [];

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
    super.dispose();
  }

  void _onProductSelected(InventoryItem product) {
    // Check if already added — increment quantity instead of duplicating
    setState(() {
      final existing = _selectedItems.indexWhere((it) => it.product.id == product.id);
      if (existing >= 0) {
        _selectedItems[existing] = _SelectedItem(
          product: product,
          quantity: _selectedItems[existing].quantity + 1,
        );
      } else {
        _selectedItems.add(_SelectedItem(product: product, quantity: 1));
      }
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

      final validUntil = widget.isProformaOnly
          ? DateTime.now().add(const Duration(days: 14))
          : null;
      final row = await SupabaseService.createInvoice(
        businessId: businessId,
        customerName: customer,
        customerId: _customerId,
        totalAmount: amount,
        description: _descCtrl.text.trim(),
        customerEmail: _customerEmail.trim().isNotEmpty ? _customerEmail.trim() : null,
        lineItems: lineItems.isNotEmpty ? lineItems : null,
        isProforma: widget.isProformaOnly,
        validUntil: validUntil,
      );

      if (!mounted) return;

      // Sync CRM metrics in background
      unawaited(CrmService.syncAfterPurchase(
        businessId: businessId,
        customerName: customer,
        customerEmail: null,
        amountGhs: amount.toDouble(),
      ));

      // Create inventory reservations for each selected item
      if (_selectedItems.isNotEmpty) {
        final invoiceId = row['id'] as String?;
        if (invoiceId != null) {
          for (final it in _selectedItems) {
            try {
              await SupabaseService.createProductReservation(
                businessId: businessId,
                productId: it.product.id,
                quantity: it.quantity,
                reservationType: 'invoice',
                referenceId: invoiceId,
              );
            } catch (e) {
              log.warning('createProductReservation failed for ${it.product.id}: $e');
              // Non-fatal — don't block invoice creation on reservation failure
            }
          }
        }
      }

      // ignore: unawaited_futures
      appState.loadFinancials();
      // ignore: unawaited_futures
      appState.loadInvoices();
      // ignore: unawaited_futures
      appState.loadInventory();
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

  // ── Customer email + phone callbacks ──
  void _onEmailChanged(String v) => _customerEmail = v;
  void _onPhoneChanged(String v) => _customerPhone = v;

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
            totalAmount: _totalAmount,
            customerEmail: _customerEmail,
            customerPhone: _customerPhone,
            onCustomerChanged: _onCustomerChanged,
            onProductSelected: _onProductSelected,
            onUpdateQuantity: _updateItemQuantity,
            onEmailChanged: _onEmailChanged,
            onPhoneChanged: _onPhoneChanged,
            onNext: () => setState(() => _step = 1),
            isProformaOnly: widget.isProformaOnly,
          ),
        1 => _PreviewStep(
            customer: _customerName,
            amount: _totalAmount,
            desc: _descCtrl.text,
            selectedItems: _selectedItems,
            sending: _sending,
            error: _sendError,
            isProformaOnly: widget.isProformaOnly,
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
            isProformaOnly: widget.isProformaOnly,
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
  final TextEditingController descCtrl, amountCtrl;
  final List<_SelectedItem> selectedItems;
  final num totalAmount;
  final String customerEmail;
  final String customerPhone;
  final void Function(String, Customer?) onCustomerChanged;
  final void Function(InventoryItem) onProductSelected;
  final void Function(int, int) onUpdateQuantity;
  final void Function(String) onEmailChanged;
  final void Function(String) onPhoneChanged;
  final VoidCallback onNext;
  final bool isProformaOnly;

  const _DetailsStep({
    required this.customerName,
    required this.customerId,
    required this.businessId,
    required this.selectedCustomer,
    required this.descCtrl,
    required this.amountCtrl,
    required this.selectedItems,
    required this.totalAmount,
    required this.customerEmail,
    required this.customerPhone,
    required this.onCustomerChanged,
    required this.onProductSelected,
    required this.onUpdateQuantity,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onNext,
    this.isProformaOnly = false,
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
            child: Text(isProformaOnly ? 'New proforma' : 'New invoice',
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
          const SizedBox(height: 14),

          // ── Client email ──
          _ContactField(
            label: 'Client email',
            hint: 'Email (optional)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            initialValue: customerEmail,
            onChanged: onEmailChanged,
          ),
          const SizedBox(height: 14),

          // ── Client phone ──
          _ContactField(
            label: 'Client phone',
            hint: 'Phone (optional)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            initialValue: customerPhone,
            onChanged: onPhoneChanged,
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

          // Add product from inventory — use InventorySelector like CustomerSelector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InventorySelector(
              inventory: context.read<AppState>().inventory,
              label: 'Add products',
              multiSelect: true,
              onChanged: onProductSelected,
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

          // ── Notes / description ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notes',
                    style: AppType.body(
                        size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: descCtrl,
                    style: AppType.body(size: 13, color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Optional — add a note for this invoice',
                      hintStyle:
                          AppType.body(size: 12, color: c.textFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Jump to full tool ──
          _NavFooter(context: context, isProformaOnly: isProformaOnly),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppBtn(
              isProformaOnly ? 'Preview proforma →' : 'Preview invoice →',
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
                if (item.product.unitPrice != null)                      Text('${formatGHS(item.product.unitPrice!)} each',
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
  final bool isProformaOnly;
  final VoidCallback? onBack, onSend;

  const _PreviewStep({
    required this.customer,
    required this.amount,
    required this.desc,
    required this.selectedItems,
    required this.sending,
    required this.error,
    this.isProformaOnly = false,
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
                Text(isProformaOnly ? 'Preview proforma' : 'Preview invoice',
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
                : AppBtn(isProformaOnly ? 'Create proforma' : 'Create invoice',
                    full: true, icon: 'north_east', onTap: onSend),
          ),
        ],
      ),
    );
  }
}

// ── Contact field widget ─────────────────────────────────────────────────────

/// A compact text field row for optional client contact info (email or phone).
/// Matches the web's in-form fields — visible, not hidden, so the user can
/// fill them in one pass.
class _ContactField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _ContactField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.initialValue = '',
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
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
              controller: TextEditingController.fromValue(
                TextEditingValue(text: initialValue),
              ),
              keyboardType: keyboardType,
              textInputAction: TextInputAction.next,
              style: AppType.body(size: 14, color: c.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.body(size: 13, color: c.textFaint),
                prefixIcon: Icon(icon, size: 17, color: c.textFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav footer — jump to full tools ─────────────────────────────────────────

Widget _NavFooter({required BuildContext context, required bool isProformaOnly}) {
  final c = context.colors;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.open_in_new, size: 10, color: c.textFaint),
            const SizedBox(width: 4),
            Text('GO TO FULL TOOL',
                style: AppType.body(size: 9, weight: FontWeight.w700, color: c.textFaint)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context)
                    ..pop()
                    ..push(MaterialPageRoute(builder: (_) => const InvoicesScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: c.navySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.description_outlined, size: 14, color: c.navy),
                      ),
                      const SizedBox(height: 4),
                      Text(isProformaOnly ? 'All invoices' : 'All invoices',
                          style: AppType.body(size: 10, weight: FontWeight.w600, color: c.text),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context)
                    ..pop()
                    ..push(MaterialPageRoute(builder: (_) => const InventoryScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: c.tealSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.inventory_2_outlined, size: 14, color: c.tealDeep),
                      ),
                      const SizedBox(height: 4),
                      Text('Inventory',
                          style: AppType.body(size: 10, weight: FontWeight.w600, color: c.text),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Step 3: Sent ─────────────────────────────────────────────────────────────
class _SentStep extends StatelessWidget {
  final String? invoiceNumber;
  final bool isProformaOnly;
  final VoidCallback onClose;

  const _SentStep({required this.invoiceNumber, this.isProformaOnly = false, required this.onClose});

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
          Text(isProformaOnly ? 'Proforma saved' : 'Invoice saved',
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
            isProformaOnly
                ? 'Share this proforma with your customer via WhatsApp or email.'
                : 'Added to your Outstanding list.\nShare with your customer via WhatsApp or email.',
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
