import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/share_utils.dart';
import '../../services/crm_service.dart';
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
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
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
    final businessId = context.read<AppState>().business.id;
    final method = await showPaymentMethodSheet(context);
    if (method == null) return;
    if (businessId == null || inv.backendId == null) return;
    if (!mounted) return;
    await _runAction(
      () => SupabaseService.markInvoicePaid(
        invoiceId: inv.backendId!,
        businessId: businessId,
        paymentMethod: method,
      ).then((_) {
        unawaited(SupabaseService.fulfillReservationsByReference(
          referenceId: inv.backendId!,
          reservationType: 'invoice',
        ));
        unawaited(CrmService.syncAfterPurchase(
          businessId: businessId,
          customerName: inv.customer,
          customerEmail: inv.clientEmail,
          amountGhs: inv.amount.toDouble(),
        ));
      }),
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
      final state = context.read<AppState>();
      await Future.wait([
        state.loadInvoices(),
        state.loadFinancials(),
      ]);
    }
  }

  Future<void> _convertProforma(Invoice inv) async {
    if (inv.backendId == null) return;
    await _runAction(
      () => SupabaseService.convertProformaToInvoice(
        invoiceId: inv.backendId!,
      ),
      errorMessage: 'Could not convert the proforma. Try again.',
    );
  }

  Future<void> _convertAndMarkPaid(Invoice inv) async {
    final businessId = context.read<AppState>().business.id;
    if (businessId == null || inv.backendId == null) return;

    final method = await showPaymentMethodSheet(context);
    if (method == null) return;
    if (!mounted) return;

    await _runAction(
      () => SupabaseService.convertProformaAndMarkPaid(
        invoiceId: inv.backendId!,
        businessId: businessId,
        paymentMethod: method,
      ).then((_) {
        unawaited(SupabaseService.fulfillReservationsByReference(
          referenceId: inv.backendId!,
          reservationType: 'invoice',
        ));
        unawaited(CrmService.syncAfterPurchase(
          businessId: businessId,
          customerName: inv.customer,
          customerEmail: inv.clientEmail,
          amountGhs: inv.amount.toDouble(),
        ));
        context.read<AppState>().recordConversion(inv.customer, inv.amount, invoiceId: inv.backendId);
      }),
      errorMessage: 'Could not convert and mark as paid. Try again.',
    );
  }

  Future<void> _confirmVoid(Invoice inv) async {
    final ok = await _showVoidConfirm(context, inv);
    if (ok != true || inv.backendId == null) return;
    if (!mounted) return;
    await _runAction(
      () async {
        await SupabaseService.voidInvoice(invoiceId: inv.backendId!);
        await SupabaseService.releaseReservationsByReference(
          referenceId: inv.backendId!,
          reservationType: 'invoice',
        );
      },
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
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _toast('Pay link copied');
  }

  Future<void> _sendReminder(Invoice inv) async {
    if (!inv.hasPayLink) {
      _toast('Generate a pay link first to share with the customer.');
      return;
    }
    final url = '${AppConfig.payLinkBaseUrl}${inv.payToken}';
    final amount = formatGHS(inv.amount);
    final businessName = context.read<AppState>().business.name;
    final msg = ShareUtils.invoiceMessage(
      customer: inv.customer,
      invoiceId: inv.id,
      amount: amount,
      businessName: businessName,
      payLink: url,
      isOverdue: inv.status == 'overdue',
      overdueDays: inv.days > 0 ? inv.days : null,
    );
    await ShareUtils.copyToClipboard(msg, context: context);
  }

  /// Unified share flow: generate PDF → preview → share via system sheet.
  /// Works for all invoice types (proforma, pending, paid).
  Future<void> _shareWithPreview(Invoice inv) async {
    try {
      final state = context.read<AppState>();
      final biz = state.business;
      final bytes = await InvoicePdfService.generatePdfBytes(
        invoice: inv,
        businessName: biz.name,
        businessHandle: biz.handle,
        businessCity: biz.city,
        businessRegion: biz.region,
        logoUrl: biz.logoUrl,
        verified: biz.verified,
      );
      if (!mounted) return;

      // Show a preview confirmation sheet with the document info
      final shouldShare = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => _SharePreviewSheet(
          invoice: inv,
          pdfBytes: bytes,
          businessName: biz.name,
        ),
      );

      if (shouldShare == true && mounted) {
        // Share via system share sheet (WhatsApp, email, etc.)
        final dir = await Directory.systemTemp.createTemp('invoice_share');
        final file = File('${dir.path}/Invoice_${inv.id.replaceAll('/', '_')}.pdf');
        await file.writeAsBytes(bytes);

        final msg = inv.isProforma
            ? 'Hi ${inv.customer}, here\'s your proforma ${inv.id} for ${formatGHS(inv.amount)} from ${biz.name}.'
            : ShareUtils.invoiceMessage(
                customer: inv.customer,
                invoiceId: inv.id,
                amount: formatGHS(inv.amount),
                businessName: biz.name,
                payLink: inv.hasPayLink
                    ? '${AppConfig.payLinkBaseUrl}${inv.payToken}'
                    : null,
              );

        await Share.shareXFiles(
          [XFile(file.path)],
          text: msg,
        );

        // Clean up temp dir
        try { await dir.delete(recursive: true); } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Could not generate PDF. Try again.');
    }
  }

  void _toast(String message) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  if (inv.isProforma) _ProformaExpiryCard(invoice: inv),
                  if (inv.isProforma) const SizedBox(height: 16),
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
              onConvertAndMarkPaid: inv.isProforma ? () => _convertAndMarkPaid(inv) : null,
              onVoid: () => _confirmVoid(inv),
              onEnablePayLink: () => _enablePayLink(inv),
              onCopyPayLink: () => _copyPayLink(inv),
              onSendReminder: () => _sendReminder(inv),
              onShareWithPreview: () => _shareWithPreview(inv),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header card: invoice number, status pill, total, pipeline tracker ──────
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
          const SizedBox(height: 16),
          _PipelineTracker(status: invoice.status),
        ],
      ),
    );
  }
}

// ── Pipeline step tracker: Quote → Invoice → Receipt ──────────────────────
class _PipelineTracker extends StatelessWidget {
  final String status;

  const _PipelineTracker({required this.status});

  int get _currentStep {
    return switch (status) {
      'proforma' => 0,
      'pending' || 'overdue' || 'sent' => 1,
      'paid' => 2,
      'void' => -1,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = _currentStep;

    if (status == 'void') return const SizedBox.shrink();

    final steps = ['Proforma', 'Invoice', 'Receipt'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) Expanded(
              child: Container(
                height: 1.5,
                color: i <= step
                    ? c.teal.withValues(alpha: 0.6)
                    : c.border,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: i <= step ? c.teal : c.bgInset,
                    shape: BoxShape.circle,
                    border: i > step
                        ? Border.all(color: c.borderStrong)
                        : null,
                  ),
                  child: i < step
                      ? Icon(Icons.check, size: 12, color: Colors.white)
                      : i == step
                          ? Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                ),
                const SizedBox(height: 3),
                Text(
                  steps[i],
                  style: AppType.body(
                    size: 9,
                    weight: i == step ? FontWeight.w700 : FontWeight.w500,
                    color: i <= step ? c.tealDeep : c.textFaint,
                  ),
                ),
              ],
            ),
          ],
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
        ? [InvoiceLineItem(description: 'Invoice for ${invoice.customer}', amount: invoice.amount)]
        : invoice.lineItems;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items', style: AppType.label(size: 10, color: c.textMuted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 3, child: Text('Description',
                  style: AppType.body(size: 10.5, weight: FontWeight.w700, color: c.textFaint))),
              const SizedBox(width: 8),
              SizedBox(
                width: 54,
                child: Text('Qty',
                    textAlign: TextAlign.center,
                    style: AppType.body(size: 10.5, weight: FontWeight.w700, color: c.textFaint)),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 72,
                child: Text('Amount',
                    textAlign: TextAlign.right,
                    style: AppType.body(size: 10.5, weight: FontWeight.w700, color: c.textFaint)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) ...[
            _ItemRow(item: items[i], last: i == items.length - 1),
          ],
          const SizedBox(height: 6),
          Divider(color: c.borderStrong, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Total',
                  style: AppType.body(size: 14, weight: FontWeight.w700, color: c.text))),
              Text(formatGHS(invoice.amount),
                  style: AppType.body(size: 14, weight: FontWeight.w700, color: c.text)),
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
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(item.description,
                    style: AppType.body(size: 13, color: c.text), maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (item.itemType != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.itemType == 'goods' ? c.navySurface : c.tealSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.itemType == 'goods' ? '📦' : '🛠️',
                        style: AppType.body(size: 11, color: c.textMuted)),
                  ),
                ],
              ]),
              if (item.qtyLabel != null) ...[
                const SizedBox(height: 2),
                Text(item.qtyLabel!, style: AppType.body(size: 11, color: c.textFaint)),
              ],
            ],
          )),
          const SizedBox(width: 6),
          SizedBox(width: 54, child: Text(
              item.quantity != null ? '${item.quantity!.round()}' : '1',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text))),
          const SizedBox(width: 6),
          SizedBox(width: 72, child: Text(formatGHS(item.amount),
              textAlign: TextAlign.right,
              style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text))),
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
      dueSub = invoice.dueDate != null ? formatLongDate(invoice.dueDate!) : '—';
    } else if (invoice.status == 'overdue') {
      dueSub = invoice.dueDate != null
          ? '${formatLongDate(invoice.dueDate!)} · overdue by ${invoice.days}d'
          : '—';
      dueColor = c.rose;
    } else {
      dueSub = invoice.dueDate != null ? formatLongDate(invoice.dueDate!) : '—';
    }

    final createdSub = invoice.createdAt != null ? formatLongDate(invoice.createdAt!) : '—';

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

  const _MetaRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(child: Text(label, style: AppType.body(size: 12, color: c.textMuted))),
        Text(value, style: AppType.body(size: 13, weight: FontWeight.w600, color: valueColor ?? c.text)),
      ],
    );
  }
}

// ── Proforma expiry warning card ──────────────────────────────────────────────
class _ProformaExpiryCard extends StatelessWidget {
  final Invoice invoice;

  const _ProformaExpiryCard({required this.invoice});

  bool get _isExpired {
    if (invoice.validUntil == null) return false;
    return invoice.validUntil!.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (!_isExpired) return const SizedBox.shrink();

    final daysAgo = invoice.validUntil != null
        ? DateTime.now().difference(invoice.validUntil!).inDays
        : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.rose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.rose.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: c.rose.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded, size: 18, color: c.rose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proforma expired',
                    style: AppType.body(size: 14, weight: FontWeight.w700, color: c.rose)),
                const SizedBox(height: 4),
                Text(
                  daysAgo > 0
                      ? 'Expired $daysAgo day${daysAgo == 1 ? '' : 's'} ago (${invoice.validUntil != null ? formatLongDate(invoice.validUntil!) : ''}). Create a new proforma or convert to continue.'
                      : 'This proforma is no longer valid. Create a new one or convert to invoice.',
                  style: AppType.body(size: 12.5, color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
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
          Expanded(child: Text(message, style: AppType.body(size: 13, color: c.rose))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARE PREVIEW SHEET — unified preview-before-send for all share actions
// ═══════════════════════════════════════════════════════════════════════════════

/// A bottom sheet that shows a PDF preview card and options to share or copy.
/// Returns `true` if the user taps "Share", `null`/`false` otherwise.
class _SharePreviewSheet extends StatelessWidget {
  final Invoice invoice;
  final List<int> pdfBytes;
  final String businessName;

  const _SharePreviewSheet({
    required this.invoice,
    required this.pdfBytes,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fileName = 'Invoice_${invoice.id.replaceAll('/', '_')}.pdf';

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.tealSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.picture_as_pdf, size: 22, color: c.tealDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PDF ready to share',
                          style: AppType.heading(size: 16, color: c.text)),
                      const SizedBox(height: 2),
                      Text(fileName,
                          style: AppType.mono(size: 11, color: c.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Preview info card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  _previewRow(c, 'Customer', invoice.customer),
                  const SizedBox(height: 8),
                  _previewRow(c, 'Amount', formatGHS(invoice.amount)),
                  const SizedBox(height: 8),
                  _previewRow(c, 'Business', businessName),
                  const SizedBox(height: 8),
                  _previewRow(c, 'Document', invoice.isProforma ? 'Proforma' : 'Invoice'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons — Preview · Download · Share
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: AppBtn(
                    'Preview',
                    icon: 'description',
                    variant: BtnVariant.secondary,
                    onTap: () {
                      Navigator.pop(context, false);
                      _previewPdf(context, invoice, pdfBytes);
                    },
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppBtn(
                    'Download',
                    icon: 'download',
                    variant: BtnVariant.secondary,
                    onTap: () {
                      Navigator.pop(context, false);
                      _downloadPdf(context, invoice, pdfBytes);
                    },
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: AppBtn(
                    'Share',
                    icon: 'share',
                    onTap: () => Navigator.pop(context, true),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Copy message link
          if (invoice.hasPayLink || invoice.isProforma)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppBtn(
                invoice.isProforma ? 'Copy WhatsApp message' : 'Copy invoice message',
                icon: 'content_copy',
                variant: BtnVariant.outline,
                full: true,
                fontSize: 12,
                onTap: () {
                  Navigator.pop(context, false);
                  _copyMessage(context, invoice, businessName);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewRow(AppColorsX c, String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppType.body(size: 12, color: c.textMuted))),
        Text(value, style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text)),
      ],
    );
  }

  void _previewPdf(BuildContext context, Invoice invoice, List<int> bytes) {
    // Use the printing package to show native PDF preview
    Printing.layoutPdf(
      onLayout: (_) => Uint8List.fromList(bytes),
      name: 'Invoice_${invoice.id.replaceAll('/', '_')}',
    );
  }

  void _copyMessage(BuildContext context, Invoice invoice, String businessName) {
    String msg;
    if (invoice.isProforma) {
      msg = 'Hi ${invoice.customer}, here\'s your proforma ${invoice.id} for '
          '${formatGHS(invoice.amount)} from $businessName. '
          'Let me know if you have any questions!';
    } else {
      msg = ShareUtils.invoiceMessage(
        customer: invoice.customer,
        invoiceId: invoice.id,
        amount: formatGHS(invoice.amount),
        businessName: businessName,
        payLink: invoice.hasPayLink
            ? '${AppConfig.payLinkBaseUrl}${invoice.payToken}'
            : null,
      );
    }
    ShareUtils.copyToClipboard(msg, context: context);
  }

  Future<void> _downloadPdf(BuildContext context, Invoice invoice, List<int> bytes) async {
    try {
      final fileName = 'Invoice_${invoice.id.replaceAll('/', '_')}.pdf';
      final path = await InvoicePdfService.savePdfToDocuments(
        bytes: bytes,
        fileName: fileName,
      );
      if (path != null && context.mounted) {
        _showToast(context, 'PDF saved: ${path.split('/').last}');
      } else if (context.mounted) {
        _showToast(context, 'Could not save PDF. Try again.');
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Download failed. Try again.');
      }
    }
  }

  void _showToast(BuildContext context, String message) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSOLIDATED ACTION BAR
// ═══════════════════════════════════════════════════════════════════════════════

/// Consolidated bottom action bar. Only the most relevant primary actions are
/// shown as buttons. Share/export are unified into a single "Share" button
/// that opens the PDF preview + share flow.
class _ActionBar extends StatelessWidget {
  final Invoice invoice;
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onEditProforma;
  final VoidCallback onConvertToInvoice;
  final VoidCallback? onConvertAndMarkPaid;
  final VoidCallback onVoid;
  final VoidCallback onEnablePayLink;
  final VoidCallback onCopyPayLink;
  final VoidCallback onSendReminder;
  final VoidCallback onShareWithPreview;

  const _ActionBar({
    required this.invoice,
    required this.busy,
    required this.onMarkPaid,
    required this.onEditProforma,
    required this.onConvertToInvoice,
    this.onConvertAndMarkPaid,
    required this.onVoid,
    required this.onEnablePayLink,
    required this.onCopyPayLink,
    required this.onSendReminder,
    required this.onShareWithPreview,
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
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(c.teal),
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── PROFORMA ACTIONS ──
                  if (isProforma) ...[
                    // Primary: Convert & mark as paid
                    if (onConvertAndMarkPaid != null) ...[
                      AppBtn('Convert & mark as paid', full: true, icon: 'check',
                          onTap: onConvertAndMarkPaid),
                      const SizedBox(height: 8),
                    ],
                    // Secondary row
                    Row(
                      children: [
                        Expanded(
                          child: AppBtn('Convert to invoice', icon: 'north_east',
                              variant: BtnVariant.secondary, onTap: onConvertToInvoice),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppBtn('Edit proforma', icon: 'edit',
                              variant: BtnVariant.secondary, onTap: onEditProforma),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Share button
                    AppBtn('Share', icon: 'share', full: true,
                        variant: BtnVariant.outline, onTap: onShareWithPreview),
                  ],

                  // ── OPEN INVOICE ACTIONS ──
                  if (isOpen) ...[
                    // Pay link section
                    if (invoice.hasPayLink) ...[
                      Row(
                        children: [
                          Expanded(
                            child: AppBtn('Copy pay link', icon: 'content_copy',
                                variant: BtnVariant.secondary, onTap: onCopyPayLink),
                          ),
                          if (isOverdue) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppBtn('Send reminder', icon: 'campaign',
                                  variant: BtnVariant.secondary, onTap: onSendReminder),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      AppBtn('Generate pay link', full: true, icon: 'link',
                          variant: BtnVariant.secondary, onTap: onEnablePayLink),
                      const SizedBox(height: 8),
                    ],
                    // Primary: Mark as paid
                    AppBtn('Mark as paid', full: true, icon: 'check',
                        onTap: onMarkPaid),
                    const SizedBox(height: 8),
                    // Share + Cancel row
                    Row(
                      children: [
                        Expanded(
                          child: AppBtn('Share', icon: 'share',
                              variant: BtnVariant.outline, onTap: onShareWithPreview),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppBtn('Cancel invoice', icon: 'close',
                              variant: BtnVariant.outline, onTap: onVoid),
                        ),
                      ],
                    ),
                  ],

                  // ── PAID / VOID ──
                  if (invoice.status == 'paid') ...[
                    Text('This invoice has been paid.',
                        style: AppType.body(size: 13, color: c.textMuted),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    AppBtn('Share as PDF', full: true, icon: 'share',
                        variant: BtnVariant.outline, onTap: onShareWithPreview),
                  ] else if (invoice.status == 'void') ...[
                    Text('This invoice was cancelled.',
                        style: AppType.body(size: 13, color: c.textMuted),
                        textAlign: TextAlign.center),
                  ],
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
      'proforma' => (PillTone.neutral, 'Proforma'),
      'void' => (PillTone.neutral, 'Cancelled'),
      _ => (PillTone.neutral, 'Draft'),
    };

Future<bool?> _showVoidConfirm(BuildContext context, Invoice inv) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel invoice',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.rose)),
          ),
        ],
      );
    },
  );
}
