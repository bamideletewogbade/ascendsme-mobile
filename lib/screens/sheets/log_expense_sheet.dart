import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/expense_mapping.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet for logging an expense. Three states:
/// - form (default) — amount + description + date
/// - sending — spinner
/// - saved — success confirmation
///
/// Use [show] to open the sheet from any screen.
class LogExpenseSheet extends StatefulWidget {
  final VoidCallback? onSaved;

  const LogExpenseSheet({super.key, this.onSaved});

  /// Convenience launcher — call from any screen.
  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogExpenseSheet(onSaved: onSaved),
    );
  }

  @override
  State<LogExpenseSheet> createState() => _LogExpenseSheetState();
}

class _LogExpenseSheetState extends State<LogExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'Other';
  // 'cash' | 'momo' | 'bank' — required NOT NULL on the expenses table.
  String _paymentSource = 'cash';

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
      // Mock mode — pretend it worked. Real apps won't hit this in production.
      setState(() {
        _saving = false;
        _saved = true;
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
      await SupabaseService.createExpense(
        businessId: businessId,
        amount: amount,
        date: _date,
        description: _descCtrl.text.trim(),
        category: _category,
        paymentSource: _paymentSource,
      );

      if (!mounted) return;

      // Refresh cashflow tiles + activity feed so the new expense shows up.
      // ignore: unawaited_futures
      appState.loadFinancials();
      // ignore: unawaited_futures
      appState.loadExpenses();
      widget.onSaved?.call();

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
    return 'Could not save the expense. Check your connection and try again.';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final today = DateTime.now();
    final isToday = d.year == today.year &&
        d.month == today.month &&
        d.day == today.day;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text('Log expense',
              style: AppType.heading(size: 20, color: c.text)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Text(
              'Record money going out so your cash flow stays accurate.',
              style: AppType.body(size: 13, color: c.textMuted)),
        ),

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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  textInputAction: TextInputAction.next,
                  style: AppType.body(
                      size: 16, weight: FontWeight.w600, color: c.text),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: AppType.body(size: 16, color: c.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Description
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
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  style: AppType.body(size: 14, color: c.text),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Fabric purchase from Makola',
                    hintStyle: AppType.body(size: 13, color: c.textFaint),
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

        const SizedBox(height: 14),

        // Category
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category',
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    dropdownColor: c.bgElevated,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: c.textFaint, size: 20),
                    style: AppType.body(
                        size: 14, weight: FontWeight.w500, color: c.text),
                    items: kManualExpenseCategories
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Payment source
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paid with',
                  style: AppType.body(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: c.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PaymentChip(
                    label: 'Cash',
                    selected: _paymentSource == 'cash',
                    onTap: () => setState(() => _paymentSource = 'cash'),
                  ),
                  const SizedBox(width: 8),
                  _PaymentChip(
                    label: 'MoMo',
                    selected: _paymentSource == 'momo',
                    onTap: () => setState(() => _paymentSource = 'momo'),
                  ),
                  const SizedBox(width: 8),
                  _PaymentChip(
                    label: 'Bank',
                    selected: _paymentSource == 'bank',
                    onTap: () => setState(() => _paymentSource = 'bank'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
                      strokeWidth: 2.5,                        valueColor: AlwaysStoppedAnimation(c.teal),
                    ),
                  ),
                )
              : AppBtn('Save expense', full: true, onTap: _save),
        ),
      ],
    );
  }

  Widget _buildSaved(AppColorsX c) {
    final amount = _parseAmount();
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
            decoration: BoxDecoration(
              color: c.greenSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 32, color: c.green),
          ),
          const SizedBox(height: 16),
          Text('Expense saved',
              style: AppType.heading(size: 22, color: c.text)),
          const SizedBox(height: 6),
          if (amount != null)
            Text('GHS ${amount.toString()}',
                style: AppType.mono(size: 14, color: c.textMuted)),
          const SizedBox(height: 12),
          Text(
            'Your cash flow is updated.',
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

class _PaymentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected ? c.tealSurface : c.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? c.teal : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.body(
              size: 13,
              weight: FontWeight.w600,
              color: selected ? c.tealDeep : c.text,
            ),
          ),
        ),
      ),
    );
  }
}
