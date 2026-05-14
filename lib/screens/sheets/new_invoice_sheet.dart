import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/ai_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

class NewInvoiceSheet extends StatefulWidget {
  final VoidCallback? onSent;

  const NewInvoiceSheet({super.key, this.onSent});

  @override
  State<NewInvoiceSheet> createState() => _NewInvoiceSheetState();
}

class _NewInvoiceSheetState extends State<NewInvoiceSheet> {
  int _step = 0;
  final _customerCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _aiParsing = false;

  // Send state
  bool _sending = false;
  String? _sendError;
  String? _createdInvoiceNumber;

  @override
  void dispose() {
    _customerCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

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
            _customerCtrl.text = customer;
          }
          final amount = result['amount'];
          if (amount != null) {
            _amountCtrl.text = amount.toString();
          }
        }
      });
    }
  }

  /// Parse the amount text into a num. Strips commas and whitespace.
  /// Returns null if the field is empty or unparseable.
  num? _parseAmount() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return num.tryParse(raw);
  }

  Future<void> _sendInvoice() async {
    setState(() {
      _sending = true;
      _sendError = null;
    });

    final customer = _customerCtrl.text.trim();
    final amount = _parseAmount();
    final appState = context.read<AppState>();
    final businessId = appState.business.id;

    // Validation — defensive; step 0 already collected these.
    if (customer.isEmpty) {
      setState(() {
        _sending = false;
        _sendError = 'Customer name is required.';
      });
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() {
        _sending = false;
        _sendError = 'Enter a valid amount greater than 0.';
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
      final row = await SupabaseService.createInvoice(
        businessId: businessId,
        customerName: customer,
        totalAmount: amount,
        description: _descCtrl.text.trim(),
      );

      if (!mounted) return;

      // Refresh Outstanding tile + invoices list on the home screen
      // (fire-and-forget — UI updates when these resolve).
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
    // Trim Supabase's verbose "PostgrestException(message: ..., code: ..., …)"
    // to just the message text so the user isn't confronted with raw stack.
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
            customerCtrl: _customerCtrl,
            descCtrl: _descCtrl,
            amountCtrl: _amountCtrl,
            aiParsing: _aiParsing,
            onAiDraft: _aiDraft,
            onNext: () => setState(() => _step = 1),
          ),
        1 => _PreviewStep(
            customer: _customerCtrl.text,
            amount: _amountCtrl.text,
            desc: _descCtrl.text,
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

// ── Step 1: Details ───────────────────────────────────────────────────────────
class _DetailsStep extends StatelessWidget {
  final TextEditingController customerCtrl, descCtrl, amountCtrl;
  final bool aiParsing;
  final VoidCallback onAiDraft;
  final VoidCallback onNext;

  const _DetailsStep({
    required this.customerCtrl,
    required this.descCtrl,
    required this.amountCtrl,
    required this.aiParsing,
    required this.onAiDraft,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Text('New invoice',
              style: AppType.heading(size: 20, color: c.text)),
        ),

        // AI smart draft
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: c.tealSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.tealSurfaceStrong),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: c.tealDeep),
                      const SizedBox(width: 6),
                      Text('AI smart draft',
                          style: AppType.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: c.tealDeep)),
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
                                  strokeWidth: 2,
                                  color: Colors.white))
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
        const SizedBox(height: 16),

        // Manual fields
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _Field(
                  label: 'Customer name',
                  ctrl: customerCtrl,
                  hint: 'e.g. Kente Co.'),
              const SizedBox(height: 10),
              _Field(
                label: 'Amount (GHS)',
                ctrl: amountCtrl,
                hint: '0.00',
                keyboard: TextInputType.number,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppBtn('Preview invoice →', full: true, onTap: onNext),
        ),
      ],
    );
  }
}

// ── Step 2: Preview ───────────────────────────────────────────────────────────
class _PreviewStep extends StatelessWidget {
  final String customer, amount, desc;
  final bool sending;
  final String? error;
  final VoidCallback? onBack, onSend;

  const _PreviewStep({
    required this.customer,
    required this.amount,
    required this.desc,
    required this.sending,
    required this.error,
    required this.onBack,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
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
                            style:
                                AppType.label(size: 10, color: c.textMuted)),
                        Text('Number assigned on save',
                            style:
                                AppType.body(size: 11, color: c.textFaint)),
                      ],
                    ),
                    AppPill('Draft',
                        tone: PillTone.neutral, small: true),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total amount',
                        style: AppType.body(size: 13, color: c.textMuted)),
                    Text(
                        'GHS ${amount.isEmpty ? "0.00" : amount}',
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
                        valueColor: AlwaysStoppedAnimation(c.teal),
                      ),
                    ),
                  ),
                )
              : AppBtn('Send invoice',
                  full: true, icon: 'north_east', onTap: onSend),
        ),
      ],
    );
  }
}

// ── Step 3: Sent ──────────────────────────────────────────────────────────────
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
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: c.greenSurface, shape: BoxShape.circle),
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

// ── Input field ───────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType? keyboard;

  const _Field({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.keyboard,
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
