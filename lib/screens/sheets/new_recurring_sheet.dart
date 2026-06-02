import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/customer_selector.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet for creating a recurring invoice template. Lets the user
/// configure the customer, amount, frequency, and next invoice date. The
/// actual invoice generation happens server-side via pg_cron.
class NewRecurringSheet extends StatefulWidget {
  final VoidCallback? onCreated;

  const NewRecurringSheet({super.key, this.onCreated});

  static Future<void> show(BuildContext context, {VoidCallback? onCreated}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewRecurringSheet(onCreated: onCreated),
    );
  }

  @override
  State<NewRecurringSheet> createState() => _NewRecurringSheetState();
}

class _NewRecurringSheetState extends State<NewRecurringSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Customer
  String _customerName = '';
  String? _customerId;

  // Frequency
  RecurringFrequency _frequency = RecurringFrequency.monthly;

  // Next date
  DateTime _nextDate = DateTime.now().add(const Duration(days: 30));

  bool _saving = false;
  String? _error;
  bool _saved = false;

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

  String _frequencyDbValue(RecurringFrequency f) => switch (f) {
        RecurringFrequency.weekly => 'weekly',
        RecurringFrequency.monthly => 'monthly',
        RecurringFrequency.quarterly => 'quarterly',
        RecurringFrequency.yearly => 'yearly',
      };

  String _frequencyLabel(RecurringFrequency f) => switch (f) {
        RecurringFrequency.weekly => 'Weekly',
        RecurringFrequency.monthly => 'Monthly',
        RecurringFrequency.quarterly => 'Quarterly',
        RecurringFrequency.yearly => 'Yearly',
      };

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final amount = _parseAmount();
    final appState = context.read<AppState>();
    final businessId = appState.business.id;

    if (_customerName.trim().isEmpty) {
      setState(() {
        _saving = false;
        _error = 'Customer name is required.';
      });
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() {
        _saving = false;
        _error = 'Enter a valid amount greater than 0.';
      });
      return;
    }
    if (businessId == null) {
      setState(() {
        _saving = false;
        _error = 'Your business profile isn\'t set up yet.';
      });
      return;
    }

    try {
      await SupabaseService.createRecurringTemplate(
        businessId: businessId,
        customerName: _customerName.trim(),
        customerId: _customerId,
        totalAmount: amount,
        frequency: _frequencyDbValue(_frequency),
        nextInvoiceDate: _nextDate,
        description: _descCtrl.text.trim(),
        dayOfMonth: _frequency == RecurringFrequency.monthly ||
                _frequency == RecurringFrequency.quarterly ||
                _frequency == RecurringFrequency.yearly
            ? _nextDate.day
            : null,
        dayOfWeek: _frequency == RecurringFrequency.weekly
            ? _nextDate.weekday - 1
            : null,
      );

      if (!mounted) return;
      widget.onCreated?.call();
      setState(() {
        _saving = false;
        _saved = true;
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
    return 'Could not save the template. Check your connection and try again.';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _saved ? _buildSaved(c) : _buildForm(c),
    );
  }

  Widget _buildForm(AppColorsX c) {
    final state = context.watch<AppState>();
    final businessId = state.business.id;

    final freqOptions = [
      (RecurringFrequency.weekly, 'Weekly'),
      (RecurringFrequency.monthly, 'Monthly'),
      (RecurringFrequency.quarterly, 'Quarterly'),
      (RecurringFrequency.yearly, 'Yearly'),
    ];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text('Recurring invoice',
                style: AppType.heading(size: 20, color: c.text)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Text(
              'Auto-generate invoices on a schedule for retainers and standing orders.',
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ),

          // Customer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomerSelector(
              businessId: businessId,
              label: 'Customer',
              optional: false,
              onChanged: (name, customer) {
                _customerName = name;
                _customerId = customer?.id;
              },
            ),
          ),

          const SizedBox(height: 16),

          // Amount
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
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: AppType.body(size: 16, color: c.text),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle:
                          AppType.body(size: 16, color: c.textFaint),
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

          const SizedBox(height: 16),

          // Frequency selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Frequency',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: freqOptions.map((opt) {
                    final active = _frequency == opt.$1;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: opt.$1 == freqOptions.last.$1 ? 0 : 6),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _frequency = opt.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? c.tealSurface : c.bgInset,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active
                                    ? c.teal
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(opt.$2,
                                textAlign: TextAlign.center,
                                style: AppType.body(
                                    size: 11.5,
                                    weight: FontWeight.w600,
                                    color: active
                                        ? c.tealDeep
                                        : c.textMuted)),
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

          // Next invoice date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First invoice date',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _nextDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) {
                      setState(() => _nextDate = picked);
                    }
                  },
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
                          child: Text(_formatDate(_nextDate),
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

          // Description (optional)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description (optional)',
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
                    style: AppType.body(size: 14, color: c.text),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Monthly retainer — website maintenance',
                      hintStyle:
                          AppType.body(size: 13, color: c.textFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
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
                  border: Border.all(color: c.rose.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: c.rose),
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
                : AppBtn('Create recurring invoice',
                    full: true, icon: 'add', onTap: _save),
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
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(color: c.greenSurface, shape: BoxShape.circle),
            child: Icon(Icons.repeat, size: 32, color: c.green),
          ),
          const SizedBox(height: 16),
          Text('Recurring invoice set up',
              style: AppType.heading(size: 22, color: c.text)),
          const SizedBox(height: 8),
          Text(
            'Invoices will be generated ${_frequencyLabel(_frequency).toLowerCase()} starting ${_formatDate(_nextDate)}.',
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
