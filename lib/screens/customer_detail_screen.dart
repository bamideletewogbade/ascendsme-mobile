import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'tools/invoice_detail_screen.dart';

/// Customer detail — pushed from the Customers tab. v0.1 derives the
/// customer's invoice history from the loaded invoices list (filtered by
/// `client_name`). Phase 3+ will hit a real `customers` table with full
/// contact info, communication history, etc.
class CustomerDetailScreen extends StatelessWidget {
  final String customerName;

  const CustomerDetailScreen({super.key, required this.customerName});

  String get _initials {
    final parts = customerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    final invoices = state.invoices
        .where((inv) => inv.customer.trim() == customerName.trim())
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    final total = invoices.fold<double>(0, (s, i) => s + i.amount.toDouble());
    final outstanding = invoices
        .where((i) => i.status != 'paid' && i.status != 'void')
        .fold<double>(0, (s, i) => s + i.amount.toDouble());
    final overdue =
        invoices.where((i) => i.status == 'overdue').length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Customer',
                onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  // Identity card
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        AppAvatar(_initials, size: 54),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customerName,
                                  style: AppType.heading(
                                      size: 18, color: c.text)),
                              const SizedBox(height: 4),
                              Text(
                                '${invoices.length} ${invoices.length == 1 ? "invoice" : "invoices"} · GHS ${total.round()} total',
                                style: AppType.body(
                                    size: 12.5, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Outstanding card
                  if (outstanding > 0) ...[
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Outstanding',
                                    style: AppType.body(
                                        size: 11.5, color: c.textMuted)),
                                const SizedBox(height: 4),
                                Text('GHS ${outstanding.round()}',
                                    style: AppType.heading(
                                        size: 20, color: c.text)),
                                if (overdue > 0)
                                  Text(
                                      '$overdue overdue ${overdue == 1 ? "invoice" : "invoices"}',
                                      style: AppType.body(
                                          size: 11.5, color: c.rose)),
                              ],
                            ),
                          ),
                          if (overdue > 0)
                            AppPill('Follow up',
                                tone: PillTone.rose, small: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],

                  Text('Invoice history',
                      style: AppType.heading(size: 16, color: c.text)),
                  const SizedBox(height: 10),

                  if (invoices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No invoices yet for this customer.',
                          style:
                              AppType.body(size: 13, color: c.textMuted)),
                    )
                  else
                    ...invoices.map((inv) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InvoiceTile(
                            invoice: inv,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailScreen(
                                    initialInvoice: inv),
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _InvoiceTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (tone, label) = switch (invoice.status) {
      'paid' => (PillTone.green, 'Paid'),
      'overdue' => (PillTone.rose, 'Overdue'),
      'pending' || 'sent' => (PillTone.orange, 'Pending'),
      _ => (PillTone.neutral, 'Draft'),
    };
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.id,
                    style: AppType.mono(size: 11.5, color: c.text)),
                const SizedBox(height: 2),
                Text('Due ${invoice.due}',
                    style: AppType.body(size: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('GHS ${invoice.amount}',
                  style: AppType.body(
                      size: 13.5, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 4),
              AppPill(label, tone: tone, small: true),
            ],
          ),
        ],
      ),
    );
  }
}
