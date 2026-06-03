import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/customer_selector.dart';
import '../../services/crm_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

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

class _LogSaleSheetState extends State<LogSaleSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  DateTime _date = DateTime.now();

  // Customer state — name is always present (may be free-text for walk-ins),
  // customerId is set only when the user selected or added a real Customer row.
  String _customerName = '';
  String? _customerId;

  bool _saving = false;
  String? _error;
  bool _saved = false;
  String? _savedReceiptNumber;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
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
