import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../sheets/edit_proforma_sheet.dart';

/// Detail view for a single invoice. Pushed from the InvoicesScreen list
/// when the user taps a card.
///
/// Re-reads the freshest copy of the invoice from AppState on every build so
/// status changes (mark-paid / void / pay-link-enabled) flow through after a
/// refresh. Falls back to the initial copy passed in by the list when the
/// list refresh hasn't completed yet.
class InvoiceDetailScreen extends StatefulWidget {
  final Invoice initialInvoice;

  const InvoiceDetailScreen({super.key, required this.initialInvoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _busy = false;
  String? _error;

  Invoice _currentInvoice(AppState state) {
    final id = widget.initialInvoice.backendId;
    if (id == null) return widget.initialInvoice;
    return state.invoices.firstWhere(
      (i) => i.backendId == id,
      orElse: () => widget.initialInvoice,
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? errorMessage,
  }) async {
    // Capture state before any awaits so we don't reach across an async gap.
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      // Refresh both invoices and financials so the list, summary card, and
      // home Outstanding tile all reflect the change.
      await Future.wait([state.loadInvoices(), state.loadFinancials()]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessage ?? _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(msg);
    final extracted = match?.group(1)?.trim();
    if (extracted != null && extracted.isNotEmpty) return extracted;
    return 'Something went wrong. Try again.';
  }

  Future<void> _markPaid(Invoice inv) async {
    // Capture business id before the modal so we don't touch context across awaits.
    final businessId = context.read<AppState>().business.id;
    final method = await _showPaymentMethodSheet(context);
    if (method == null) return;
    if (businessId == null || inv.backendId == null) return;
    if (!mounted) return;
    await _runAction(
      () => SupabaseService.markInvoicePaid(
        invoiceId: inv.backendId!,
        businessId: businessId,
        paymentMethod: method,
      ).then((_) {}),
      errorMessage: 'Could not save the receipt. Try again.',
    );
  }

  Future<void> _editProforma(Invoice inv) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProformaSheet(invoice: inv),
    );
    if (result == true && mounted) {
      // EditProformaSheet already calls loadInvoices; just refresh financials.
      context.read<AppState>().loadFinancials();
    }
  }

  Future<void> _convertProforma(Invoice inv) async {
    if (inv.backendId == null) return;
    await _runAction(
      () => SupabaseService.convertProformaToInvoice(
        invoiceId: inv.backendId!,
      ),
      errorMessage: 'Could not convert the quote. Try again.',
    );
  }

  Future<void> _confirmVoid(Invoice inv) async {
    final ok = await _showVoidConfirm(context, inv);
    if (ok != true || inv.backendId == null) return;
    if (!mounted) return;
    await _runAction(
      () => SupabaseService.voidInvoice(invoiceId: inv.backendId!),
      errorMessage: 'Could not void the invoice. Try again.',
    );
  }

  Future<void> _enablePayLink(Invoice inv) async {
    if (inv.backendId == null) return;
    await _runAction(
      () => SupabaseService.enableInvoicePayLink(invoiceId: inv.backendId!)
          .then((_) {}),
      errorMessage: 'Could not generate a pay link. Try again.',
    );
  }

  Future<void> _copyPayLink(Invoice inv) async {
    if (!inv.hasPayLink) return;
    final url = '${AppConfig.payLinkBaseUrl}${inv.payToken}';
    final messenger = ScaffoldMessenger.of(context);
    final c = context.colors;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _toastVia(messenger, c, 'Pay link copied');
  }

  Future<void> _shareAsPdf(Invoice inv) async {
    try {
      final state = context.read<AppState>();
      final biz = state.business;
      await InvoicePdfService.shareInvoice(
        invoice: inv,
        businessName: biz.name,
        businessHandle: biz.handle,
        businessCity: biz.city,
        businessRegion: biz.region,
      );
    } catch (e) {
      if (!mounted) return;
      _toastVia(ScaffoldMessenger.of(context), context.colors,
          'Could not generate PDF. Try again.');
    }
  }

  Future<void> _previewPdf(Invoice inv) async {
    try {
      final state = context.read<AppState>();
      final biz = state.business;
      await InvoicePdfService.previewInvoice(
        invoice: inv,
        businessName: biz.name,
        businessHandle: biz.handle,
        businessCity: biz.city,
        businessRegion: biz.region,
      );
    } catch (e) {
      if (!mounted) return;
      _toastVia(ScaffoldMessenger.of(context), context.colors,
          'Could not generate PDF. Try again.');
    }
  }

  Future<void> _sendReminder(Invoice inv) async {
    if (!inv.hasPayLink) {
      final messenger = ScaffoldMessenger.of(context);
      final c = context.colors;
      _toastVia(messenger, c, 'Generate a pay link first to share with the customer.');
      return;
    }
    final url = '${AppConfig.payLinkBaseUrl}${inv.payToken}';
    final amount = formatGHS(inv.amount);
    final businessName = context.read<AppState>().business.name;
    final days = inv.days > 0 ? ' (${inv.days} days overdue)' : '';
    final msg =
        'Hi ${inv.customer}, this is a friendly reminder about your invoice ${inv.id} '
        'for $amount from $businessName$days. '
        'Pay securely here: $url';
    final messenger = ScaffoldMessenger.of(context);
    final c = context.colors;
    await Clipboard.setData(ClipboardData(text: msg));
    if (!mounted) return;
    _toastVia(messenger, c, 'Reminder copied — paste into WhatsApp');
  }

  Future<void> _copyShareMessage(Invoice inv) async {
    if (!inv.hasPayLink) return;
    final url = '${AppConfig.payLinkBaseUrl}${inv.payToken}';
    final amount = formatGHS(inv.amount);
    final msg =
        'Hi ${inv.customer}, here\'s your invoice ${inv.id} for $amount. '
        'Pay securely here: $url';
    final messenger = ScaffoldMessenger.of(context);
    final c = context.colors;
    await Clipboard.setData(ClipboardData(text: msg));
    if (!mounted) return;
    _toastVia(messenger, c, 'Message copied — paste into WhatsApp');
  }

  void _toastVia(
      ScaffoldMessengerState messenger, AppColorsX c, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final inv = _currentInvoice(state);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Invoice',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _HeaderCard(invoice: inv),
                  const SizedBox(height: 16),
                  _CustomerCard(invoice: inv),
                  const SizedBox(height: 16),
                  _LineItemsCard(invoice: inv),
                  const SizedBox(height: 16),
                  _MetaCard(invoice: inv),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
            _ActionBar(
              invoice: inv,
              busy: _busy,
              onMarkPaid: () => _markPaid(inv),
              onEditProforma: () => _editProforma(inv),
              onConvertToInvoice: () => _convertProforma(inv),
              onVoid: () => _confirmVoid(inv),
              onEnablePayLink: () => _enablePayLink(inv),
              onCopyPayLink: () => _copyPayLink(inv),
              onShareMessage: () => _copyShareMessage(inv),
              onSharePdf: () => _shareAsPdf(inv),
              onPreviewPdf: () => _previewPdf(inv),
              onSendReminder: () => _sendReminder(inv),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header card: invoice number, status pill, total ──────────────────────────
class _HeaderCard extends StatelessWidget {
  final Invoice invoice;

  const _HeaderCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (pillTone, pillLabel) = _statusDisplay(invoice.status);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INVOICE',
                        style: AppType.label(size: 10, color: c.textMuted)),
                    const SizedBox(height: 2),
                    Text(invoice.id,
                        style: AppType.mono(size: 14, color: c.text)),
                  ],
                ),
              ),
              AppPill(pillLabel, tone: pillTone),
            ],
          ),
          const SizedBox(height: 16),
          Text('Total amount',
              style: AppType.body(size: 12, color: c.textMuted)),
          const SizedBox(height: 4),
          Text(formatGHS(invoice.amount),
              style: AppType.display(size: 32, color: c.text)),
        ],
      ),
    );
  }
}

// ── Customer card ────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final Invoice invoice;

  const _CustomerCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill to',
              style: AppType.label(size: 10, color: c.textMuted)),
          const SizedBox(height: 6),
          Text(invoice.customer,
              style: AppType.heading(size: 17, color: c.text)),
          if (invoice.clientEmail != null) ...[
            const SizedBox(height: 4),
            Text(invoice.clientEmail!,
                style: AppType.body(size: 12.5, color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

// ── Line items list ──────────────────────────────────────────────────────────
class _LineItemsCard extends StatelessWidget {
  final Invoice invoice;

  const _LineItemsCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = invoice.lineItems.isEmpty
        ? [
            InvoiceLineItem(
              description: 'Invoice for ${invoice.customer}',
              amount: invoice.amount,
            )
          ]
        : invoice.lineItems;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items',
              style: AppType.label(size: 10, color: c.textMuted)),
          const SizedBox(height: 10),
          // Column headers
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Description',
                    style: AppType.body(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: c.textFaint)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text('Qty',
                    textAlign: TextAlign.center,
                    style: AppType.body(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: c.textFaint)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text('Amount',
                    textAlign: TextAlign.right,
                    style: AppType.body(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: c.textFaint)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) ...[
            _ItemRow(item: items[i], last: i == items.length - 1),
          ],
          // Total row
          const SizedBox(height: 6),
          Divider(color: c.borderStrong, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Total',
                    style: AppType.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: c.text)),
              ),
              Text(formatGHS(invoice.amount),
                  style: AppType.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: c.text)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final InvoiceLineItem item;
  final bool last;

  const _ItemRow({required this.item, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description,
                    style: AppType.body(size: 13, color: c.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (item.qtyLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(item.qtyLabel!,
                      style: AppType.body(size: 11, color: c.textFaint)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              item.quantity != null ? '${item.quantity!.round()}' : '1',
              textAlign: TextAlign.center,
              style: AppType.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: c.text),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(formatGHS(item.amount),
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

// ── Meta card: due date, created date ────────────────────────────────────────
class _MetaCard extends StatelessWidget {
  final Invoice invoice;

  const _MetaCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    String dueSub;
    Color dueColor = c.text;
    if (invoice.status == 'paid') {
      dueSub = invoice.dueDate != null
          ? formatLongDate(invoice.dueDate!)
          : '—';
    } else if (invoice.status == 'overdue') {
      dueSub = invoice.dueDate != null
          ? '${formatLongDate(invoice.dueDate!)} · overdue by ${invoice.days}d'
          : '—';
      dueColor = c.rose;
    } else {
      dueSub = invoice.dueDate != null
          ? formatLongDate(invoice.dueDate!)
          : '—';
    }

    final createdSub = invoice.createdAt != null
        ? formatLongDate(invoice.createdAt!)
        : '—';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _MetaRow(label: 'Due date', value: dueSub, valueColor: dueColor),
          const SizedBox(height: 10),
          _MetaRow(label: 'Created', value: createdSub),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;

  const _MetaRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppType.body(size: 12, color: c.textMuted)),
        ),
        Text(value,
            style: AppType.body(
                size: 13,
                weight: FontWeight.w600,
                color: valueColor ?? c.text)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
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
            child: Text(message,
                style: AppType.body(size: 13, color: c.rose)),
          ),
        ],
      ),
    );
  }
}

// ── Action bar (bottom-pinned, status-aware) ─────────────────────────────────
class _ActionBar extends StatelessWidget {
  final Invoice invoice;
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onEditProforma;
  final VoidCallback onConvertToInvoice;
  final VoidCallback onVoid;
  final VoidCallback onEnablePayLink;
  final VoidCallback onCopyPayLink;
  final VoidCallback onShareMessage;
  final VoidCallback onSharePdf;
  final VoidCallback onPreviewPdf;
  final VoidCallback onSendReminder;

  const _ActionBar({
    required this.invoice,
    required this.busy,
    required this.onMarkPaid,
    required this.onEditProforma,
    required this.onConvertToInvoice,
    required this.onVoid,
    required this.onEnablePayLink,
    required this.onCopyPayLink,
    required this.onShareMessage,
    required this.onSharePdf,
    required this.onPreviewPdf,
    required this.onSendReminder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isProforma = invoice.isProforma;
    final isOpen = invoice.status == 'pending' || invoice.status == 'overdue';
    final isOverdue = invoice.status == 'overdue';

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SafeArea(
        top: false,
        child: busy
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
              )              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Proforma actions ──
                  if (isProforma) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppBtn(
                            'Convert to invoice',
                            icon: 'north_east',
                            onTap: onConvertToInvoice,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppBtn(
                            'Cancel quote',
                            icon: 'close',
                            variant: BtnVariant.outline,
                            onTap: onVoid,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppBtn(
                      'Edit quote',
                      full: true,
                      icon: 'edit',
                      variant: BtnVariant.secondary,
                      onTap: onEditProforma,
                    ),
                  ],

                  // ── Open invoice actions ──
                  if (isOpen) ...[
                    if (invoice.hasPayLink) ...[
                      Row(
                        children: [
                          Expanded(
                            child: AppBtn(
                              'Copy pay link',
                              icon: 'content_copy',
                              variant: BtnVariant.outline,
                              onTap: onCopyPayLink,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppBtn(
                              'Share',
                              icon: 'share',
                              variant: BtnVariant.outline,
                              onTap: onShareMessage,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      AppBtn(
                        'Generate pay link',
                        full: true,
                        icon: 'link',
                        variant: BtnVariant.outline,
                        onTap: onEnablePayLink,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Reminder button for overdue invoices
                    if (isOverdue) ...[
                      AppBtn(
                        'Send reminder',
                        full: true,
                        icon: 'campaign',
                        variant: BtnVariant.outline,
                        onTap: onSendReminder,
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: AppBtn(
                            'Mark as paid',
                            icon: 'check',
                            onTap: onMarkPaid,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppBtn(
                            'Cancel',
                            icon: 'close',
                            variant: BtnVariant.outline,
                            onTap: onVoid,
                          ),
                        ),
                      ],
                    ),
                  ] else if (invoice.status == 'paid') ...[
                    Text('This invoice has been paid.',
                        style: AppType.body(size: 13, color: c.textMuted),
                        textAlign: TextAlign.center),
                  ] else if (invoice.status == 'void') ...[
                    Text('This invoice was cancelled.',
                        style: AppType.body(size: 13, color: c.textMuted),
                        textAlign: TextAlign.center),
                  ],

                  // PDF share — always visible for any status
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppBtn(
                          'Preview PDF',
                          icon: 'description',
                          variant: BtnVariant.secondary,
                          onTap: onPreviewPdf,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppBtn(
                          'Share as PDF',
                          icon: 'share',
                          variant: BtnVariant.outline,
                          onTap: onSharePdf,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

(PillTone, String) _statusDisplay(String status) => switch (status) {
      'paid' => (PillTone.green, 'Paid'),
      'overdue' => (PillTone.rose, 'Overdue'),
      'pending' || 'sent' => (PillTone.orange, 'Pending'),
      'proforma' => (PillTone.neutral, 'Quote'),
  'void' => (PillTone.neutral, 'Cancelled'),
      _ => (PillTone.neutral, 'Draft'),
    };

Future<String?> _showPaymentMethodSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.colors;
      const options = [
        ('cash', 'Cash', Icons.money),
        ('momo', 'Mobile Money', Icons.phone_android),
        ('bank', 'Bank transfer', Icons.account_balance),
      ];
      return Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 4),
            Text('How was it paid?',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 6),
            Text('This creates a receipt linked to the invoice.',
                style: AppType.body(size: 12.5, color: c.textMuted)),
            const SizedBox(height: 16),
            for (final (value, label, icon) in options)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, value),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.navySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: c.navy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label,
                            style: AppType.body(
                                size: 14,
                                weight: FontWeight.w600,
                                color: c.text)),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: c.textFaint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<bool?> _showVoidConfirm(BuildContext context, Invoice inv) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return AlertDialog(
        backgroundColor: c.bgElevated,                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel invoice?',
            style: AppType.heading(size: 18, color: c.text)),
        content: Text(
          'This marks ${inv.id} as cancelled. The customer can no longer pay it. This cannot be undone from the mobile app.',
          style: AppType.body(size: 13.5, color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it',
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel invoice',
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.rose)),
          ),
        ],
      );
    },
  );
}
