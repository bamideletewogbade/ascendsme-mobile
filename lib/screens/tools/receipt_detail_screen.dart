import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/share_utils.dart';
import '../../services/invoice_pdf_service.dart';
import '../../state/app_state.dart';
import 'invoice_detail_screen.dart';

/// Detail view for a single receipt. Pushed from [ReceiptsScreen] when the
/// user taps a receipt card. Shows full receipt info: receipt number,
/// client name, payment method, paid date, line items, and a link to the
/// related invoice when applicable.
///
/// We use the raw [Map] from AppState.receipts so we can access line_items
/// and other fields not modeled in the lightweight [Receipt] model.
class ReceiptDetailScreen extends StatelessWidget {
  final Receipt receipt;
  final Map<String, dynamic> rawRow;

  const ReceiptDetailScreen({
    super.key,
    required this.receipt,
    required this.rawRow,
  });

  void _toastVia(ScaffoldMessengerState messenger, AppColorsX c, String message) {
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

  Future<void> _shareOnWhatsApp(
      BuildContext context, Receipt receipt) async {
    final state = context.read<AppState>();
    final biz = state.business;
    final amount = formatGHS(receipt.totalAmount);
    final msg = ShareUtils.receiptMessage(
      customer: receipt.clientName ?? 'Customer',
      amount: amount,
      businessName: biz.name,
      receiptNumber: receipt.receiptNumber,
    );
    await ShareUtils.shareViaWhatsApp(message: msg, context: context);
  }

  Future<void> _previewPdf(
      BuildContext context, Receipt receipt,
      List<InvoiceLineItem> lineItems) async {
    try {
      final state = context.read<AppState>();
      final biz = state.business;
      await InvoicePdfService.previewReceipt(
        receipt: receipt,
        businessName: biz.name,
        businessHandle: biz.handle,
        businessCity: biz.city,
        businessRegion: biz.region,
        logoUrl: biz.logoUrl,
        verified: biz.verified,
        lineItems: lineItems,
      );
    } catch (e) {
      if (!context.mounted) return;
      _toastVia(ScaffoldMessenger.of(context), context.colors,
          'Could not preview PDF. Try again.');
    }
  }

  Future<void> _shareAsPdf(
      BuildContext context, Receipt receipt,
      List<InvoiceLineItem> lineItems) async {
    try {
      final state = context.read<AppState>();
      final biz = state.business;
      await InvoicePdfService.shareReceipt(
        receipt: receipt,
        businessName: biz.name,
        businessHandle: biz.handle,
        businessCity: biz.city,
        businessRegion: biz.region,
        logoUrl: biz.logoUrl,
        verified: biz.verified,
        lineItems: lineItems,
      );
    } catch (e) {
      if (!context.mounted) return;
      _toastVia(ScaffoldMessenger.of(context), context.colors,
          'Could not generate PDF. Try again.');
    }
  }

  Future<void> _downloadPdf(
      BuildContext context, Receipt receipt,
      List<InvoiceLineItem> lineItems) async {
    try {
      final state = context.read<AppState>();
      final biz = state.business;
      final path = await InvoicePdfService.downloadReceipt(
        receipt: receipt,
        businessName: biz.name,
        businessHandle: biz.handle,
        businessCity: biz.city,
        businessRegion: biz.region,
        logoUrl: biz.logoUrl,
        verified: biz.verified,
        lineItems: lineItems,
      );
      if (path != null && context.mounted) {
        _toastVia(ScaffoldMessenger.of(context), context.colors,
            'PDF saved: ${path.split('/').last}');
      } else if (context.mounted) {
        _toastVia(ScaffoldMessenger.of(context), context.colors,
            'Could not save PDF. Try again.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _toastVia(ScaffoldMessenger.of(context), context.colors,
          'Download failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    // Find related invoice if this is an invoice payment
    final Invoice? relatedInvoice;
    if (receipt.invoiceId != null) {
      relatedInvoice = state.invoices.cast<Invoice?>().firstWhere(
            (inv) => inv?.backendId == receipt.invoiceId,
            orElse: () => null,
          );
    } else {
      relatedInvoice = null;
    }

    // Parse line items from the raw row
    final rawItems = rawRow['line_items'];
    final lineItems = rawItems is List
        ? rawItems
            .map((e) => e is Map ? InvoiceLineItem.fromJson(e) : null)
            .whereType<InvoiceLineItem>()
            .toList()
        : <InvoiceLineItem>[];

    // Find the related invoice number from state if available
    final String? relatedInvoiceNumber;
    if (receipt.invoiceId != null) {
      final inv = state.invoices.cast<Invoice?>().firstWhere(
            (inv) => inv?.backendId == receipt.invoiceId,
            orElse: () => null,
          );
      relatedInvoiceNumber = inv?.id;
    } else {
      relatedInvoiceNumber = null;
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Receipt',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── Header card ──
                  _HeaderCard(receipt: receipt, rawRow: rawRow),
                  const SizedBox(height: 16),

                  // ── Customer card ──
                  _CustomerCard(receipt: receipt),
                  const SizedBox(height: 16),

                  // ── Payment details ──
                  _PaymentCard(receipt: receipt, relatedInvoiceNumber: relatedInvoiceNumber),
                  const SizedBox(height: 16),

                  // ── Line items ──
                  if (lineItems.isNotEmpty) ...[
                    _LineItemsCard(lineItems: lineItems, totalAmount: receipt.totalAmount),
                    const SizedBox(height: 16),
                  ] else if (receipt.isInvoicePayment && relatedInvoice != null) ...[
                    // Show line items from the related invoice if receipt doesn't have its own
                    _RelatedInvoiceLineItems(invoice: relatedInvoice!),
                    const SizedBox(height: 16),
                  ],

                  // ── Related invoice link ──
                  if (relatedInvoice != null) ...[
                    _RelatedInvoiceCard(invoice: relatedInvoice!),
                    const SizedBox(height: 16),
                  ],

                  // ── Share & download actions ──
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        AppBtn(
                          'Share on WhatsApp',
                          full: true,
                          icon: 'share',
                          variant: BtnVariant.secondary,
                          fontSize: 12.5,
                          onTap: () => _shareOnWhatsApp(context, receipt),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppBtn(
                                'Preview',
                                icon: 'visibility',
                                variant: BtnVariant.secondary,
                                fontSize: 11.5,
                                onTap: () => _previewPdf(context, receipt, lineItems),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AppBtn(
                                'Share PDF',
                                icon: 'description',
                                variant: BtnVariant.secondary,
                                fontSize: 11.5,
                                onTap: () => _shareAsPdf(context, receipt, lineItems),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AppBtn(
                                'Download',
                                icon: 'download',
                                variant: BtnVariant.outline,
                                fontSize: 11.5,
                                onTap: () => _downloadPdf(context, receipt, lineItems),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header card: receipt number, type pill, total ──────────────────────────

class _HeaderCard extends StatelessWidget {
  final Receipt receipt;
  final Map<String, dynamic> rawRow;

  const _HeaderCard({required this.receipt, required this.rawRow});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final typeLabel = receipt.isInvoicePayment ? 'Invoice payment' : 'Direct sale';

    // Payment method icon
    final (IconData icon, Color iconBg, Color iconFg) =
        switch (receipt.paymentMethod) {
      'momo' => (Icons.phone_android_rounded, c.tealSurface, c.tealDeep),
      'bank' => (Icons.account_balance_rounded, c.navySurface, c.navyTint),
      'paystack' => (Icons.credit_card_rounded, c.blueSurface, c.blueDeep),
      _ => (Icons.money_rounded, c.greenSurface, c.greenDeep),
    };

    final paidDateStr = formatLongDate(receipt.paidDate);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECEIPT',
                      style: AppType.label(size: 10, color: c.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    receipt.receiptNumber ?? '—',
                    style: AppType.mono(size: 14, color: c.text),
                  ),
                ],
              ),
              const Spacer(),
              AppPill(typeLabel, tone: PillTone.teal),
            ],
          ),
          const SizedBox(height: 16),
          Text('Amount received',
              style: AppType.body(size: 12, color: c.textMuted)),
          const SizedBox(height: 4),
          Text(formatGHS(receipt.totalAmount),
              style: AppType.display(size: 32, color: c.green)),
          const SizedBox(height: 14),
          Container(height: 1, color: c.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconFg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receipt.methodLabel,
                        style: AppType.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: c.text)),
                    Text(paidDateStr,
                        style: AppType.body(
                            size: 11.5, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Customer card ──────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Receipt receipt;

  const _CustomerCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paid by',
              style: AppType.label(size: 10, color: c.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.tealSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline,
                    size: 18, color: c.tealDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  receipt.clientName ?? 'Walk-in customer',
                  style: AppType.heading(size: 17, color: c.text),
                ),
              ),
            ],
          ),
          if (receipt.isInvoicePayment) ...[
            const SizedBox(height: 8),
            Text('Invoice payment · linked to invoice',
                style: AppType.body(size: 12, color: c.textMuted)),
          ] else ...[
            const SizedBox(height: 8),
            Text('Direct sale · no invoice',
                style: AppType.body(size: 12, color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

// ── Payment details card ───────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Receipt receipt;
  final String? relatedInvoiceNumber;

  const _PaymentCard({required this.receipt, this.relatedInvoiceNumber});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _MetaRow(label: 'Payment method', value: receipt.methodLabel, c: c),
          const SizedBox(height: 10),
          _MetaRow(label: 'Date paid', value: formatLongDate(receipt.paidDate), c: c),
          if (receipt.receiptNumber != null) ...[
            const SizedBox(height: 10),
            _MetaRow(label: 'Receipt number', value: receipt.receiptNumber!, c: c),
          ],
          if (receipt.isInvoicePayment && relatedInvoiceNumber != null) ...[
            const SizedBox(height: 10),
            _MetaRow(label: 'Invoice', value: relatedInvoiceNumber!, c: c),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label, value;
  final AppColorsX c;

  const _MetaRow({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
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
                color: c.text)),
      ],
    );
  }
}

// ── Line items card ────────────────────────────────────────────────────────

class _LineItemsCard extends StatelessWidget {
  final List<InvoiceLineItem> lineItems;
  final num totalAmount;

  const _LineItemsCard({
    required this.lineItems,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items',
              style: AppType.label(size: 10, color: c.textMuted)),
          const SizedBox(height: 10),          for (var i = 0; i < lineItems.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 6),
              Container(height: 1, color: c.border),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(lineItems[i].description,
                      style: AppType.body(size: 13, color: c.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                if (lineItems[i].qtyLabel != null) ...[
                  Text(lineItems[i].qtyLabel!,
                      style: AppType.body(size: 11, color: c.textFaint)),
                  const SizedBox(width: 8),
                ],
                Text(formatGHS(lineItems[i].amount),
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.text)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(height: 1, color: c.borderStrong),
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
              Text(formatGHS(totalAmount),
                  style: AppType.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: c.green)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Related invoice line items (fallback when receipt has no line_items) ───

class _RelatedInvoiceLineItems extends StatelessWidget {
  final Invoice invoice;

  const _RelatedInvoiceLineItems({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = invoice.lineItems.isEmpty
        ? [InvoiceLineItem(description: 'Invoice for ${invoice.customer}', amount: invoice.amount)]
        : invoice.lineItems;
    final total = invoice.amount;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items from invoice',
              style: AppType.label(size: 10, color: c.textMuted)),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 6),
              Container(height: 1, color: c.border),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(items[i].description,
                      style: AppType.body(size: 13, color: c.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                if (items[i].qtyLabel != null) ...[
                  Text(items[i].qtyLabel!,
                      style: AppType.body(size: 11, color: c.textFaint)),
                  const SizedBox(width: 8),
                ],
                Text(formatGHS(items[i].amount),
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.text)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(height: 1, color: c.borderStrong),
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
              Text(formatGHS(total),
                  style: AppType.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: c.green)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Related invoice card ───────────────────────────────────────────────────

class _RelatedInvoiceCard extends StatelessWidget {
  final Invoice invoice;

  const _RelatedInvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (pillTone, pillLabel) = switch (invoice.status) {
      'paid' => (PillTone.green, 'Paid'),
      'overdue' => (PillTone.rose, 'Overdue'),
      _ => (PillTone.orange, 'Pending'),
    };
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(initialInvoice: invoice),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.tealSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_outlined,
                size: 18, color: c.tealDeep),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('View invoice',
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.text)),
                const SizedBox(height: 2),
                Text(invoice.id,
                    style: AppType.mono(size: 11, color: c.textMuted)),
              ],
            ),
          ),
          AppPill(pillLabel, tone: pillTone, small: true),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: c.textFaint),
        ],
      ),
    );
  }
}
