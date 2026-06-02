import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'sheets/log_expense_sheet.dart';
import 'sheets/log_sale_sheet.dart';
import 'sheets/new_invoice_sheet.dart';
import 'tools/invoices_screen.dart';
import 'tools/invoice_detail_screen.dart';
import 'tools/receipts_screen.dart';
import 'tools/expenses_screen.dart';
import 'tools/cash_flow_screen.dart';

/// Finance tab — the financial pulse of the business. Surfaces:
/// - Month-to-date cashflow summary (revenue / expenses / outstanding)
/// - Quick actions: New invoice, Log sale (cash/MoMo), Log expense
/// - Recent invoices with a "View all" link to the full list
///
/// Full invoice management lives at [InvoicesScreen] (pushable).
class FinanceScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const FinanceScreen({super.key, this.onOpenDrawer});

  void _openNewInvoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewInvoiceSheet(),
    );
  }

  void _pushAllInvoices(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InvoicesScreen()),
    );
  }

  void _openLogExpense(BuildContext context) {
    LogExpenseSheet.show(context);
  }

  void _openLogSale(BuildContext context) {
    LogSaleSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final f = state.financials;
    final recent = state.recentInvoices(count: 3);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onOpenDrawer,
                  child: AppAvatar(state.business.initials, size: 40),
                ),
                const SizedBox(width: 12),
                Text('Finance',
                    style: AppType.display(size: 28, color: c.text)),
              ],
            ),
          ),

          // Cashflow summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Cash flow — ${currentMonthShort()}'),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyTile(
                        label: 'Revenue',
                        amount: formatGHS(f.revenueThisMonth),
                        changePct: f.revenueChangePctVsLastMonth,
                        loading: state.financialsLoading,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MoneyTile(
                        label: 'Expenses',
                        amount: formatGHS(f.expensesThisMonth),
                        changePct: f.expensesChangePctVsLastMonth,
                        inverted: true,
                        loading: state.financialsLoading,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.all(14),
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
                            Text(formatGHS(f.outstanding),
                                style: AppType.heading(size: 20, color: c.text)),
                            const SizedBox(height: 2),
                            Text(_outstandingSubtitle(f),
                                style: AppType.body(
                                    size: 11.5, color: c.textMuted)),
                          ],
                        ),
                      ),
                      if (f.outstandingOverdueCount > 0)
                        AppPill('Follow up',
                            tone: PillTone.rose, small: true),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptsScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 16, color: c.tealDeep),
                  const SizedBox(width: 6),
                  Text('View all receipts',
                      style: AppType.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: c.tealDeep)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios,
                      size: 12, color: c.tealDeep),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpensesScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 16, color: c.orange),
                  const SizedBox(width: 6),
                  Text('View all expenses',
                      style: AppType.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: c.orange)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios,
                      size: 12, color: c.orange),
                ],
              ),
            ),
          ),

          // Cash flow forecast link
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashFlowForecastScreen()),
              ),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: c.navySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.timeline, size: 18, color: c.navyDeep),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cash Flow Forecast',
                              style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
                          Text('30-day projection & insights',
                              style: AppType.body(size: 11.5, color: c.textMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: c.textFaint),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppBtn(
                        'Log sale',
                        icon: 'payments',
                        onTap: () => _openLogSale(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppBtn(
                        'New invoice',
                        icon: 'description',
                        variant: BtnVariant.secondary,
                        onTap: () => _openNewInvoice(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppBtn(
                  'Log expense',
                  icon: 'receipt',
                  variant: BtnVariant.outline,
                  full: true,
                  onTap: () => _openLogExpense(context),
                  fontSize: 13,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Recent invoices
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SectionHeader('Recent invoices',
                action: recent.isNotEmpty ? 'View all' : null),
          ),
          if (recent.isEmpty && state.invoicesLoading)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 24),
              child: Center(
                child: Text('Loading invoices…',
                    style: AppType.body(size: 12, color: c.textMuted)),
              ),
            )
          else if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 36, color: c.textFaint),
                    const SizedBox(height: 12),
                    Text('No invoices yet',
                        style: AppType.heading(size: 15, color: c.text)),
                    const SizedBox(height: 4),
                    Text(
                      'Send your first invoice to start tracking cash flow.',
                      textAlign: TextAlign.center,
                      style: AppType.body(size: 12.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ...[...recent].asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FadeInSlide(
                          index: e.key,
                          child: _InvoiceRow(
                            invoice: e.value,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InvoiceDetailScreen(initialInvoice: e.value),
                              ),
                            ),
                          ),
                        ),
                      )),
                  if (recent.length >= 3) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _pushAllInvoices(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: c.bgInset,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('View all invoices',
                                style: AppType.body(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: c.tealDeep)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                size: 12, color: c.tealDeep),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _outstandingSubtitle(Financials f) {
    if (f.outstandingCount == 0) return 'No open invoices';
    final invoiceWord = f.outstandingCount == 1 ? 'invoice' : 'invoices';
    if (f.outstandingOverdueCount == 0) {
      return '${f.outstandingCount} $invoiceWord · all on track';
    }
    return '${f.outstandingCount} $invoiceWord · ${f.outstandingOverdueCount} overdue';
  }
}

// ── Inline widgets ─────────────────────────────────────────────────────────

class _MoneyTile extends StatelessWidget {
  final String label, amount;
  final double? changePct;
  final bool inverted;
  final bool loading;

  const _MoneyTile({
    required this.label,
    required this.amount,
    required this.changePct,
    this.inverted = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final changeText = formatChangePct(changePct);
    final isPositive = (changePct ?? 0) > 0;
    final isGood = inverted ? !isPositive : isPositive;
    final showChange = changeText != null && !loading;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.body(size: 11.5, color: c.textMuted)),
          const SizedBox(height: 4),
          Text(amount, style: AppType.heading(size: 18, color: c.text)),
          const SizedBox(height: 4),
          if (showChange)
            Row(
              children: [
                Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 13, color: isGood ? c.green : c.rose),
                const SizedBox(width: 3),
                Text(changeText,
                    style: AppType.body(
                        size: 11, color: isGood ? c.green : c.rose)),
              ],
            )
          else if (loading)
            Text('Loading…',
                style: AppType.body(size: 11, color: c.textFaint))
          else
            Text('No prior month',
                style: AppType.body(size: 11, color: c.textFaint)),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _InvoiceRow({required this.invoice, required this.onTap});

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
                Text(invoice.customer,
                    style: AppType.body(
                        size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 2),
                Text(invoice.id,
                    style: AppType.mono(size: 10.5, color: c.textMuted)),
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
