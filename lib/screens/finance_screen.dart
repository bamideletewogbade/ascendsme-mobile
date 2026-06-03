import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'sheets/log_expense_sheet.dart';
import 'sheets/log_sale_sheet.dart';
import 'sheets/new_invoice_sheet.dart';
import 'tools/cash_flow_screen.dart';
import 'tools/receipts_screen.dart';
import 'tools/expenses_screen.dart';
import 'tools/invoices_screen.dart';

// ── Tab enum ──────────────────────────────────────────────────────────────

enum _FinanceTab { transactions, insights, reports }

// ── Main screen ───────────────────────────────────────────────────────────

/// Unified Finance screen — mobile version of web's FinanceModule.
///
/// Tabs:
///   **Transactions** — unified income + expense feed with summary cards
///   **Insights** — breakdown charts (by method, by category)
///   **Reports** — Profit & Loss statement + General Ledger
class FinanceScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const FinanceScreen({super.key, this.onOpenDrawer});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  _FinanceTab _tab = _FinanceTab.transactions;

  // Filters for transactions tab
  String _directionFilter = 'all'; // all | income | expense
  String _methodFilter = 'all';    // all | cash | momo | bank

  void _openNewInvoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewInvoiceSheet(),
    );
  }

  void _openLogExpense() {
    LogExpenseSheet.show(context);
  }

  void _openLogSale() {
    LogSaleSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final f = state.financials;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onOpenDrawer,
                  child: AppAvatar(state.business.initials, size: 40),
                ),
                const SizedBox(width: 12),
                Text('Finance',
                    style: AppType.display(size: 28, color: c.text)),
                const Spacer(),
                // Forecast shortcut
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CashFlowForecastScreen()),
                  ),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: c.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.timeline, size: 18, color: c.textMuted),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                _TabBtn(
                  label: 'Transactions',
                  selected: _tab == _FinanceTab.transactions,
                  onTap: () => setState(() => _tab = _FinanceTab.transactions),
                ),
                const SizedBox(width: 8),
                _TabBtn(
                  label: 'Insights',
                  selected: _tab == _FinanceTab.insights,
                  onTap: () => setState(() => _tab = _FinanceTab.insights),
                ),
                const SizedBox(width: 8),
                _TabBtn(
                  label: 'Reports',
                  selected: _tab == _FinanceTab.reports,
                  onTap: () => setState(() => _tab = _FinanceTab.reports),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Tab content ──
          Expanded(
            child: switch (_tab) {
              _FinanceTab.transactions => _TransactionsTab(
                  f: f,
                  state: state,
                  directionFilter: _directionFilter,
                  methodFilter: _methodFilter,
                  onDirectionChanged: (v) => setState(() => _directionFilter = v),
                  onMethodChanged: (v) => setState(() => _methodFilter = v),
                  onLogSale: _openLogSale,
                  onLogExpense: _openLogExpense,
                  onNewInvoice: _openNewInvoice,
                  onOpenExpenses: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                  ),
                  onOpenReceipts: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReceiptsScreen()),
                  ),
                  onOpenInvoices: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoicesScreen()),
                  ),
                ),
              _FinanceTab.insights => _InsightsTab(
                  receipts: state.receiptList,
                  expenses: state.expenseList,
                  f: f,
                ),
              _FinanceTab.reports => _ReportsTab(
                  receipts: state.receiptList,
                  expenses: state.expenseList,
                  invoices: state.invoices,
                  f: f,
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimation.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.tealSurface : c.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.teal : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppType.body(
            size: 12.5,
            weight: FontWeight.w600,
            color: selected ? c.tealDeep : c.textMuted,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSACTIONS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _TransactionsTab extends StatelessWidget {
  final Financials f;
  final AppState state;
  final String directionFilter, methodFilter;
  final ValueChanged<String> onDirectionChanged, onMethodChanged;
  final VoidCallback onLogSale, onLogExpense, onNewInvoice;
  final VoidCallback onOpenExpenses, onOpenReceipts, onOpenInvoices;

  const _TransactionsTab({
    required this.f,
    required this.state,
    required this.directionFilter,
    required this.methodFilter,
    required this.onDirectionChanged,
    required this.onMethodChanged,
    required this.onLogSale,
    required this.onLogExpense,
    required this.onNewInvoice,
    required this.onOpenExpenses,
    required this.onOpenReceipts,
    required this.onOpenInvoices,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final netCash = f.revenueThisMonth - f.expensesThisMonth;
    final hasData = f.revenueThisMonth > 0 || f.expensesThisMonth > 0;

    // Build unified transaction feed
    final transactions = <_TxItem>[];
    for (final r in state.receiptList) {
      transactions.add(_TxItem(
        id: r.id,
        date: r.paidDate,
        title: r.clientName ?? 'Received payment',
        subtitle: r.methodLabel,
        amount: r.totalAmount,
        isIncome: true,
        method: r.paymentMethod,
        category: r.isInvoicePayment ? 'Invoice payment' : 'Direct sale',
      ));
    }
    for (final e in state.expenseList) {
      transactions.add(_TxItem(
        id: e.id,
        date: e.expenseDate,
        title: e.description ?? e.category,
        subtitle: e.category,
        amount: e.amount,
        isIncome: false,
        method: e.paymentSource,
        category: e.mappedCategory,
      ));
    }
    transactions.sort((a, b) => b.date.compareTo(a.date));

    // Apply filters
    final filtered = transactions.where((tx) {
      if (directionFilter == 'income' && !tx.isIncome) return false;
      if (directionFilter == 'expense' && tx.isIncome) return false;
      if (methodFilter != 'all' && tx.method != methodFilter) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Summary cards ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Inflows',
                  value: formatGHS(f.revenueThisMonth),
                  icon: Icons.arrow_circle_down_rounded,
                  color: c.green,
                  onTap: () => onDirectionChanged(
                      directionFilter == 'income' ? 'all' : 'income'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'Outflows',
                  value: formatGHS(f.expensesThisMonth),
                  icon: Icons.arrow_circle_up_rounded,
                  color: c.rose,
                  onTap: () => onDirectionChanged(
                      directionFilter == 'expense' ? 'all' : 'expense'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'Net',
                  value: formatGHS(netCash.abs()),
                  icon: netCash >= 0
                      ? Icons.account_balance_wallet_rounded
                      : Icons.warning_amber_rounded,
                  color: netCash >= 0 ? c.teal : c.amber,
                  onTap: null,
                ),
              ),
            ],
          ),
        ),

        // Pipeline card
        if (f.pipeline > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _SummaryCard(
              label: 'Expected income',
              value: formatGHS(f.pipeline),
              subtitle: 'From proforma quotes',
              icon: Icons.pending_actions_rounded,
              color: c.blue,
              onTap: null,
              dense: true,
            ),
          ),

        const SizedBox(height: 16),

        // ── Quick actions ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.payments,
                  label: 'Log sale',
                  subtitle: 'Cash, MoMo, bank',
                  color: c.teal,
                  onTap: onLogSale,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.description_outlined,
                  label: 'Invoice',
                  subtitle: 'Send a bill',
                  color: c.navy,
                  onTap: onNewInvoice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.receipt_long,
                  label: 'Expense',
                  subtitle: 'Record outflow',
                  color: c.orange,
                  onTap: onLogExpense,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Filters ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transactions',
                  style: AppType.body(
                      size: 14, weight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FilterChipSmall(
                    label: 'All',
                    selected: directionFilter == 'all',
                    onTap: () => onDirectionChanged('all'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChipSmall(
                    label: 'Income',
                    selected: directionFilter == 'income',
                    onTap: () => onDirectionChanged('income'),
                  ),
                  const SizedBox(width: 6),
                  _FilterChipSmall(
                    label: 'Expenses',
                    selected: directionFilter == 'expense',
                    onTap: () => onDirectionChanged('expense'),
                  ),
                  const Spacer(),
                  _methodBtn(c),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Transaction list ──
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyTransactions(
              hasData: hasData,
              directionFilter: directionFilter,
              onLogSale: onLogSale,
              onLogExpense: onLogExpense,
            ),
          )
        else
          ...filtered.map((tx) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 3),
                child: _transactionCard(context, tx, c),
              )),
      ],
    );
  }

  Widget _methodBtn(AppColorsX c) {
    final methodLabel = switch (methodFilter) {
      'cash' => 'Cash',
      'momo' => 'MoMo',
      'bank' => 'Bank',
      _ => 'All methods',
    };
    return GestureDetector(
      onTap: () {
        final next = switch (methodFilter) {
          'all' => 'cash',
          'cash' => 'momo',
          'momo' => 'bank',
          _ => 'all',
        };
        onMethodChanged(next);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 12, color: c.textMuted),
            const SizedBox(width: 4),
            Text(methodLabel,
                style: AppType.body(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: c.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _transactionCard(BuildContext context, _TxItem tx, AppColorsX c) {
    final color = tx.isIncome ? c.green : c.rose;
    final icon = tx.isIncome
        ? Icons.arrow_circle_down_rounded
        : Icons.arrow_circle_up_rounded;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title,
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${tx.subtitle} · ${_fmtShortDate(tx.date)}',
                  style: AppType.body(size: 10.5, color: c.textFaint),
                ),
              ],
            ),
          ),
          Text(
            '${tx.isIncome ? '+' : '-'}${formatGHS(tx.amount)}',
            style: AppType.body(
              size: 13,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtShortDate(DateTime d) {
  const ms = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${ms[d.month - 1]} ${d.day}';
}

// ── Summary card ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool dense;

  const _SummaryCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(dense ? 10 : 12),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            SizedBox(height: dense ? 6 : 8),
            Text(value,
                style: AppType.heading(
                    size: dense ? 14 : 16, color: c.text)),
            Text(label,
                style: AppType.body(size: 10, color: c.textMuted)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: AppType.body(size: 9, color: c.textFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Quick action card ─────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: AppType.body(
                    size: 11, weight: FontWeight.w700, color: c.text)),
            Text(subtitle,
                style: AppType.body(size: 9, color: c.textFaint)),
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────

class _FilterChipSmall extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipSmall({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimation.fast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.tealSurface : c.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? c.teal : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: AppType.body(
                size: 10.5,
                weight: FontWeight.w600,
                color: selected ? c.tealDeep : c.textMuted)),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  final bool hasData;
  final String directionFilter;
  final VoidCallback onLogSale, onLogExpense;

  const _EmptyTransactions({
    required this.hasData,
    required this.directionFilter,
    required this.onLogSale,
    required this.onLogExpense,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (hasData) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 36, color: c.textFaint),
              const SizedBox(height: 8),
              Text('No matching transactions',
                  style: AppType.heading(size: 15, color: c.text)),
              const SizedBox(height: 4),
              Text(
                directionFilter == 'income'
                    ? 'No income recorded for this period'
                    : directionFilter == 'expense'
                        ? 'No expenses recorded for this period'
                        : 'Try adjusting your filters',
                style: AppType.body(size: 12, color: c.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: c.textFaint),
            const SizedBox(height: 12),
            Text('No transactions yet',
                style: AppType.heading(size: 17, color: c.text)),
            const SizedBox(height: 6),
            Text(
              'Log a sale or expense to get started.',
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBtn('Log sale',
                    variant: BtnVariant.secondary,
                    icon: 'payments',
                    onTap: onLogSale),
                const SizedBox(width: 10),
                AppBtn('Log expense',
                    variant: BtnVariant.secondary,
                    icon: 'receipt',
                    onTap: onLogExpense),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction item model ────────────────────────────────────────────────

class _TxItem {
  final String id;
  final DateTime date;
  final String title, subtitle;
  final num amount;
  final bool isIncome;
  final String method, category;

  const _TxItem({
    required this.id,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    required this.method,
    required this.category,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// INSIGHTS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _InsightsTab extends StatelessWidget {
  final List<Receipt> receipts;
  final List<Expense> expenses;
  final Financials f;

  const _InsightsTab({
    required this.receipts,
    required this.expenses,
    required this.f,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (f.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights, size: 40, color: c.textFaint),
            const SizedBox(height: 12),
            Text('No data yet',
                style: AppType.heading(size: 17, color: c.text)),
            const SizedBox(height: 4),
            Text('Log transactions to see insights.',
                style: AppType.body(size: 13, color: c.textMuted)),
          ],
        ),
      );
    }

    // Aggregate inflows by payment method
    final inflowsByMethod = <String, num>{};
    for (final r in receipts) {
      inflowsByMethod[r.paymentMethod] =
          (inflowsByMethod[r.paymentMethod] ?? 0) + r.totalAmount;
    }

    // Aggregate outflows by payment method
    final outflowsByMethod = <String, num>{};
    for (final e in expenses) {
      outflowsByMethod[e.paymentSource] =
          (outflowsByMethod[e.paymentSource] ?? 0) + e.amount;
    }

    // Aggregate outflows by mapped category
    final outflowsByCategory = <String, num>{};
    for (final e in expenses) {
      outflowsByCategory[e.mappedCategory] =
          (outflowsByCategory[e.mappedCategory] ?? 0) + e.amount;
    }

    // Aggregate inflows by source label
    final inflowsBySource = <String, num>{};
    for (final r in receipts) {
      final label = r.isInvoicePayment ? 'Invoice payment' : 'Direct sale';
      inflowsBySource[label] = (inflowsBySource[label] ?? 0) + r.totalAmount;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // Summary strip
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total inflows',
                        style: AppType.body(
                            size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatGHS(f.revenueThisMonth),
                        style: AppType.heading(
                            size: 20, color: c.green)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: c.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total outflows',
                        style: AppType.body(
                            size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatGHS(f.expensesThisMonth),
                        style: AppType.heading(
                            size: 20, color: c.rose)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: c.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net', style: AppType.body(
                        size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                      formatGHS(
                          (f.revenueThisMonth - f.expensesThisMonth).abs()),
                      style: AppType.heading(
                        size: 20,
                        color: f.revenueThisMonth >= f.expensesThisMonth
                            ? c.teal
                            : c.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Inflows by payment method
        _BreakdownCard(
          title: 'Inflows by payment method',
          data: inflowsByMethod,
          total: f.revenueThisMonth,
          c: c,
          getColor: (key) => switch (key) {
            'momo' => c.teal,
            'bank' => c.navy,
            'paystack' => c.blue,
            _ => c.green,
          },
          labelFn: (key) => key == 'momo'
              ? 'Mobile Money'
              : key == 'cash'
                  ? 'Cash'
                  : 'Bank transfer',
        ),

        const SizedBox(height: 12),

        // Outflows by payment method
        _BreakdownCard(
          title: 'Outflows by payment method',
          data: outflowsByMethod,
          total: f.expensesThisMonth > 0 ? f.expensesThisMonth : 0,
          c: c,
          getColor: (key) => switch (key) {
            'momo' => c.teal,
            'bank' => c.navy,
            _ => c.rose,
          },
          labelFn: (key) => key == 'momo'
              ? 'Mobile Money'
              : key == 'cash'
                  ? 'Cash'
                  : 'Bank transfer',
        ),

        const SizedBox(height: 12),

        // Income sources
        _BreakdownCard(
          title: 'Where inflows came from',
          data: inflowsBySource,
          total: f.revenueThisMonth > 0 ? f.revenueThisMonth : 0,
          c: c,
          getColor: (key) =>
              key == 'Invoice payment' ? c.teal : c.green,
          labelFn: (key) => key,
        ),

        const SizedBox(height: 12),

        // Outflows by category
        _BreakdownCard(
          title: 'What outflows were made of',
          data: outflowsByCategory,
          total: f.expensesThisMonth,
          c: c,
          getColor: (key) => switch (key) {
            'cogs' => c.orange,
            'opex_rent' => c.blueDeep,
            'opex_utilities' => c.amber,
            'labor' => c.tealDeep,
            'marketing' => c.rose,
            'logistics' => c.navyTint,
            'compliance' => c.greenDeep,
            _ => c.textMuted,
          },
          labelFn: (key) => switch (key) {
            'cogs' => 'Stock',
            'opex_rent' => 'Rent',
            'opex_utilities' => 'Utilities',
            'labor' => 'Wages',
            'marketing' => 'Marketing',
            'logistics' => 'Transport',
            'compliance' => 'Compliance',
            _ => 'Other',
          },
        ),
      ],
    );
  }
}

// ── Breakdown card (insights) ─────────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  final String title;
  final Map<String, num> data;
  final num total;
  final AppColorsX c;
  final Color Function(String) getColor;
  final String Function(String) labelFn;

  const _BreakdownCard({
    required this.title,
    required this.data,
    required this.total,
    required this.c,
    required this.getColor,
    required this.labelFn,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || total <= 0) return const SizedBox.shrink();

    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppType.body(
                  size: 13, weight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 12),
          ...sorted.map((e) {
            final pct = (e.value / total * 100).round();
            final barWidth = maxVal > 0 ? (e.value / maxVal) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: getColor(e.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(labelFn(e.key),
                            style: AppType.body(
                                size: 11.5, color: c.textMuted)),
                      ),
                      Text('$pct%',
                          style: AppType.mono(
                              size: 11, color: c.text)),
                      const SizedBox(width: 6),
                      Text(formatGHS(e.value),
                          style: AppType.body(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: c.text)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 5,
                      color: c.bgInset,
                      child: FractionallySizedBox(
                        widthFactor: barWidth.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: getColor(e.key).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REPORTS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _ReportsTab extends StatelessWidget {
  final List<Receipt> receipts;
  final List<Expense> expenses;
  final List<Invoice> invoices;
  final Financials f;

  const _ReportsTab({
    required this.receipts,
    required this.expenses,
    required this.invoices,
    required this.f,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasData = f.revenueThisMonth > 0 || f.expensesThisMonth > 0;

    if (!hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assessment, size: 40, color: c.textFaint),
            const SizedBox(height: 12),
            Text('No reports yet',
                style: AppType.heading(size: 17, color: c.text)),
            const SizedBox(height: 4),
            Text('Log transactions to generate reports.',
                style: AppType.body(size: 13, color: c.textMuted)),
          ],
        ),
      );
    }

    // P&L calculations
    final revenue = f.revenueThisMonth;
    final opex = f.expensesThisMonth;
    final netIncome = revenue - opex;
    final margin = revenue > 0 ? (netIncome / revenue * 100) : 0.0;

    // Categorize expenses for COGS vs OPEX
    num cogs = 0;
    num otherOpex = 0;
    for (final e in expenses) {
      if (e.mappedCategory == 'cogs') {
        cogs += e.amount;
      } else {
        otherOpex += e.amount;
      }
    }
    final grossProfit = revenue - cogs;

    // Build ledger entries
    final ledger = <_LedgerEntry>[];
    for (final r in receipts) {
      ledger.add(_LedgerEntry(
        date: r.paidDate,
        type: 'Income',
        account: r.clientName ?? 'Received payment',
        description: r.methodLabel,
        credit: r.totalAmount,
        debit: 0,
        reference: r.receiptNumber ?? '',
      ));
    }
    for (final e in expenses) {
      ledger.add(_LedgerEntry(
        date: e.expenseDate,
        type: 'Expense',
        account: e.description ?? e.category,
        description: '${e.category} · ${e.paymentSource}',
        credit: 0,
        debit: e.amount,
        reference: '',
      ));
    }
    for (final inv in invoices.where(
        (i) => i.status == 'pending' || i.status == 'overdue')) {
      ledger.add(_LedgerEntry(
        date: inv.dueDate ?? inv.createdAt ?? DateTime.now(),
        type: 'Receivable',
        account: inv.customer,
        description: '${inv.status} · due ${inv.due}',
        credit: inv.amount,
        debit: 0,
        reference: inv.id,
      ));
    }
    ledger.sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // ── P&L Statement ──
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assessment, size: 16, color: c.teal),
                  const SizedBox(width: 6),
                  Text('Profit & Loss',
                      style: AppType.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: c.text)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(currentMonthShort(),
                        style: AppType.body(
                            size: 10,
                            weight: FontWeight.w600,
                            color: c.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _pnlRow(c, 'Total Revenue', formatGHS(revenue), c.green,
                  bold: true),
              _pnlRow(c, 'Cost of Goods Sold', formatGHS(cogs), c.rose),
              _pnlDivider(c),
              _pnlRow(c, 'Gross Profit', formatGHS(grossProfit), c.teal,
                  bold: true),
              const SizedBox(height: 8),
              _pnlRow(c, 'Operating Expenses', formatGHS(otherOpex), c.rose),
              _pnlDivider(c),
              _pnlRow(c, 'Net Income', formatGHS(netIncome),
                  netIncome >= 0 ? c.tealDeep : c.rose,
                  bold: true, size: 16),
              if (revenue > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Spacer(),
                    Text('${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}% margin',
                        style: AppType.mono(
                            size: 11,
                            color: margin >= 0 ? c.green : c.rose)),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── General Ledger ──
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book, size: 16, color: c.navy),
                  const SizedBox(width: 6),
                  Text('General Ledger',
                      style: AppType.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: c.text)),
                  const Spacer(),
                  Text('${ledger.length} entries',
                      style: AppType.body(
                          size: 10.5, color: c.textMuted)),
                ],
              ),
              const SizedBox(height: 12),

              // Header row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: c.bgInset,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _ledgerHeader(c, 'Date', flex: 2),
                    _ledgerHeader(c, 'Account', flex: 3),
                    _ledgerHeader(c, 'Debit', flex: 2, align: TextAlign.right),
                    _ledgerHeader(c, 'Credit', flex: 2, align: TextAlign.right),
                  ],
                ),
              ),

              // Entries
              ...ledger.take(50).map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: c.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text(_fmtShortDate(e.date),
                                style: AppType.mono(
                                    size: 10, color: c.textMuted))),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.account,
                                  style: AppType.body(
                                      size: 11,
                                      weight: FontWeight.w500,
                                      color: c.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(e.description,
                                  style: AppType.body(
                                      size: 9, color: c.textFaint)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            e.debit > 0 ? formatGHS(e.debit) : '',
                            style: AppType.mono(
                                size: 10,
                                color: e.debit > 0 ? c.rose : c.textFaint),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            e.credit > 0 ? formatGHS(e.credit) : '',
                            style: AppType.mono(
                                size: 10,
                                color: e.credit > 0 ? c.green : c.textFaint),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  )),

              if (ledger.length > 50)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text('+${ledger.length - 50} more entries',
                        style: AppType.body(
                            size: 11,
                            weight: FontWeight.w600,
                            color: c.tealDeep)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pnlRow(AppColorsX c, String label, String value, Color color,
      {bool bold = false, double size = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppType.body(
                    size: size - 1,
                    weight: bold ? FontWeight.w600 : FontWeight.w400,
                    color: c.textMuted)),
          ),
          Text(value,
              style: AppType.mono(
                  size: size,
                  // weight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  Widget _pnlDivider(AppColorsX c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, color: c.border),
    );
  }

  Widget _ledgerHeader(AppColorsX c, String label,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: AppType.body(
              size: 9.5,
              weight: FontWeight.w700,
              color: c.textMuted),
          textAlign: align),
    );
  }
}

class _LedgerEntry {
  final DateTime date;
  final String type, account, description, reference;
  final num debit, credit;

  const _LedgerEntry({
    required this.date,
    required this.type,
    required this.account,
    required this.description,
    required this.debit,
    required this.credit,
    required this.reference,
  });
}
