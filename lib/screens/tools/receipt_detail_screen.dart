import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
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
                  _PaymentCard(receipt: receipt),
                  const SizedBox(height: 16),

                  // ── Line items ──
                  if (lineItems.isNotEmpty) ...[
                    _LineItemsCard(lineItems: lineItems, totalAmount: receipt.totalAmount),
                    const SizedBox(height: 16),
                  ],

                  // ── Related invoice ──
                  if (relatedInvoice != null) ...[
                    _RelatedInvoiceCard(invoice: relatedInvoice!),
                    const SizedBox(height: 16),
                  ],
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

  const _PaymentCard({required this.receipt});

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
          if (receipt.isInvoicePayment) ...[
            const SizedBox(height: 10),
            _MetaRow(label: 'Invoice ID', value: receipt.invoiceId ?? '—', c: c),
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
          const SizedBox(height: 10),
          for (var i = 0; i < lineItems.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 6),
              Divider(color: c.border, height: 1),
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
