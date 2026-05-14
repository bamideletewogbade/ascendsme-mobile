import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/ai_service.dart';

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
            onBack: () => setState(() => _step = 0),
            onSend: () {
              widget.onSent?.call();
              setState(() => _step = 2);
            },
          ),
        _ => _SentStep(onClose: () => Navigator.pop(context)),
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
  final VoidCallback onBack, onSend;

  const _PreviewStep({
    required this.customer,
    required this.amount,
    required this.desc,
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
                child: Icon(Icons.arrow_back, size: 20, color: c.text),
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
                        Text('INV-0143',
                            style:
                                AppType.mono(size: 14, color: c.text)),
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
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppBtn('Send invoice',
              full: true, icon: 'north_east', onTap: onSend),
        ),
      ],
    );
  }
}

// ── Step 3: Sent ──────────────────────────────────────────────────────────────
class _SentStep extends StatelessWidget {
  final VoidCallback onClose;

  const _SentStep({required this.onClose});

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
          Text('Invoice sent!',
              style: AppType.heading(size: 22, color: c.text)),
          const SizedBox(height: 8),
          Text(
            'The customer will receive a payment link\nvia WhatsApp and email.',
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
