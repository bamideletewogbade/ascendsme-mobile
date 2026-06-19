import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import '../services/cash_flow_service.dart';
import '../services/app_logger.dart';
import '../services/financial_report_service.dart';
import 'sheets/log_expense_sheet.dart';
import 'sheets/log_sale_sheet.dart';
import 'sheets/new_invoice_sheet.dart';
import 'tools/cash_flow_screen.dart';
import 'tools/receipts_screen.dart';
import 'tools/expenses_screen.dart';
import 'tools/invoices_screen.dart';

// ── Tab enum ──────────────────────────────────────────────────────────────

/// Order matters — this is the user journey:
///   Transactions (what just happened) → Insights (where it came from) →
///   Forecast (what's coming) → Reports (give me the receipts).
enum _FinanceTab { transactions, insights, forecast, reports }

// ── Main screen ───────────────────────────────────────────────────────────

/// Unified Finance screen — mobile version of web's FinanceModule.
///
/// Tabs:
///   **Transactions** — net-cash hero, period-filtered unified feed
///   **Insights** — donut + breakdown bars (tappable → filter the feed)
///   **Forecast** — 30-day cash flow projection with mini chart
///   **Reports** — P&L + Cash Flow Statement + General Ledger (PDF)
class FinanceScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool showBackButton;

  const FinanceScreen({super.key, this.onOpenDrawer, this.showBackButton = false});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  _FinanceTab _tab = _FinanceTab.transactions;

  // ── Filters (live across tabs — tapping a breakdown bar in Insights
  //    pushes these filters into Transactions) ───────────────────────────
  String _directionFilter = 'all'; // all | income | expense
  String _methodFilter = 'all';    // all | cash | momo | bank
  String _searchQuery = '';

  // ── Forecast state (lazy-loaded — only when Forecast tab is tapped) ──
  CashFlowForecastData _forecast = CashFlowForecastData.empty;
  List<ForecastRecommendation> _forecastRecs = [];
  bool _forecastLoading = false;
  bool _forecastLoaded = false;

  Future<void> _loadForecastIfNeeded() async {
    if (_forecastLoaded || _forecastLoading) return;
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    setState(() => _forecastLoading = true);
    try {
      final f = await CashFlowService.calculateForecast(businessId: bizId);
      final recs = CashFlowService.generateRecommendations(f);
      if (!mounted) return;
      setState(() {
        _forecast = f;
        _forecastRecs = recs;
        _forecastLoaded = true;
        _forecastLoading = false;
      });
    } catch (e) {
      log.error('finance forecast load failed', error: e);
      if (mounted) setState(() => _forecastLoading = false);
    }
  }

  void _openNewInvoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewInvoiceSheet(),
    );
  }

  void _openLogExpense() => LogExpenseSheet.show(context);
  void _openLogSale() => LogSaleSheet.show(context);

  /// Switch to the Transactions tab and pre-apply a method/direction filter.
  /// Used when the user taps a breakdown bar in Insights — the chart becomes
  /// a real entry point, not a decorative one.
  void _applyCrossFilter({String? direction, String? method}) {
    setState(() {
      _tab = _FinanceTab.transactions;
      if (direction != null) _directionFilter = direction;
      if (method != null) _methodFilter = method;
      // A new filter clears any stale search so the result isn't hidden.
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final f = state.financials;

    return Material(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──
            if (widget.showBackButton)
              SubScreenHeader('Finance', onBack: () => Navigator.pop(context))
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onOpenDrawer,
                      child: AppAvatar(state.business.initials,
                          size: 40, imageUrl: state.business.logoUrl),
                    ),
                    const SizedBox(width: 12),
                    Text('Finance',
                        style: AppType.display(size: 28, color: c.text)),
                    const Spacer(),
                  ],
                ),
              ),

            // ── Tab bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _TabBtn(
                      label: 'Transactions',
                      selected: _tab == _FinanceTab.transactions,
                      onTap: () => setState(() => _tab = _FinanceTab.transactions),
                    ),
                    const SizedBox(width: 6),
                    _TabBtn(
                      label: 'Insights',
                      selected: _tab == _FinanceTab.insights,
                      onTap: () => setState(() => _tab = _FinanceTab.insights),
                    ),
                    const SizedBox(width: 6),
                    _TabBtn(
                      label: 'Forecast',
                      selected: _tab == _FinanceTab.forecast,
                      onTap: () {
                        setState(() => _tab = _FinanceTab.forecast);
                        _loadForecastIfNeeded();
                      },
                    ),
                    const SizedBox(width: 6),
                    _TabBtn(
                      label: 'Reports',
                      selected: _tab == _FinanceTab.reports,
                      onTap: () => setState(() => _tab = _FinanceTab.reports),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Period selector (shared across all tabs) ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: AppPeriodSelector(),
            ),
            const SizedBox(height: 12),

            // ── Tab content ──
            Expanded(
              child: switch (_tab) {
                _FinanceTab.transactions => _TransactionsTab(
                    state: state,
                    periodMonths: state.effectivePeriodMonths,
                    directionFilter: _directionFilter,
                    methodFilter: _methodFilter,
                    searchQuery: _searchQuery,
                    onDirectionChanged: (v) =>
                        setState(() => _directionFilter = v),
                    onMethodChanged: (v) => setState(() => _methodFilter = v),
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
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
                    state: state,
                    periodMonths: state.effectivePeriodMonths,
                    onApplyFilter: _applyCrossFilter,
                  ),
                _FinanceTab.forecast => _ForecastTab(
                    forecast: _forecast,
                    recommendations: _forecastRecs,
                    loading: _forecastLoading,
                    onViewFullForecast: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CashFlowForecastScreen()),
                    ),
                  ),
                _FinanceTab.reports => _ReportsTab(
                    state: state,
                    periodMonths: state.effectivePeriodMonths,
                    invoices: state.invoices,
                  ),
              },
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Returns the start (inclusive) and end (exclusive) of the current period.
(DateTime, DateTime) periodBounds(int periodMonths, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final end = DateTime(n.year, n.month + 1, 1);
  final start = periodMonths <= 0
      ? DateTime(n.year, 1, 1)
      : DateTime(n.year, n.month - periodMonths + 1, 1);
  return (start, end);
}

/// Filters a receipt list to a [start, end) date range.
List<Receipt> receiptsInPeriod(
    List<Receipt> all, int periodMonths, {DateTime? now}) {
  final (start, end) = periodBounds(periodMonths, now: now);
  return all
      .where((r) => !r.paidDate.isBefore(start) && r.paidDate.isBefore(end))
      .toList();
}

/// Filters an expense list to a [start, end) date range.
List<Expense> expensesInPeriod(
    List<Expense> all, int periodMonths, {DateTime? now}) {
  final (start, end) = periodBounds(periodMonths, now: now);
  return all
      .where((e) => !e.expenseDate.isBefore(start) && e.expenseDate.isBefore(end))
      .toList();
}

/// Short "May 12" date label used in rows and ledgers.
String fmtShortDate(DateTime d) {
  const ms = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${ms[d.month - 1]} ${d.day}';
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSACTIONS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _TransactionsTab extends StatelessWidget {
  final AppState state;
  final int periodMonths;
  final String directionFilter, methodFilter;
  final String searchQuery;
  final ValueChanged<String> onDirectionChanged, onMethodChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onLogSale, onLogExpense, onNewInvoice;
  final VoidCallback onOpenExpenses, onOpenReceipts, onOpenInvoices;

  const _TransactionsTab({
    required this.state,
    required this.periodMonths,
    required this.directionFilter,
    required this.methodFilter,
    this.searchQuery = '',
    required this.onDirectionChanged,
    required this.onMethodChanged,
    required this.onSearchChanged,
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
    final summary = state.computePeriodSummary(periodMonths);
    final netCash = summary.revenue - summary.expenses;
    final hasData = summary.revenue > 0 || summary.expenses > 0;

    final periodReceipts = receiptsInPeriod(state.receiptList, periodMonths);
    final periodExpenses = expensesInPeriod(state.expenseList, periodMonths);

    // Build the unified feed (newest first), then apply filters.
    final transactions = <_TxItem>[
      for (final r in periodReceipts)
        _TxItem(
          id: r.id,
          date: r.paidDate,
          title: r.clientName ?? 'Received payment',
          subtitle: r.methodLabel,
          amount: r.totalAmount,
          isIncome: true,
          method: r.paymentMethod,
          category: r.isInvoicePayment ? 'Invoice payment' : 'Direct sale',
        ),
      for (final e in periodExpenses)
        _TxItem(
          id: e.id,
          date: e.expenseDate,
          title: e.description ?? e.category,
          subtitle: e.category,
          amount: e.amount,
          isIncome: false,
          method: e.paymentSource,
          category: e.mappedCategory,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final filtered = transactions.where((tx) {
      if (directionFilter == 'income' && !tx.isIncome) return false;
      if (directionFilter == 'expense' && tx.isIncome) return false;
      if (methodFilter != 'all' && tx.method != methodFilter) return false;
      return true;
    }).toList();

    final searched = searchQuery.isEmpty
        ? filtered
        : filtered.where((tx) {
            final q = searchQuery.toLowerCase();
            return tx.title.toLowerCase().contains(q) ||
                tx.subtitle.toLowerCase().contains(q) ||
                formatGHS(tx.amount).toLowerCase().contains(q);
          }).toList();

    final grouped = groupTransactionsByDate(searched);
    final isFiltering = directionFilter != 'all' ||
        methodFilter != 'all' ||
        searchQuery.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Net-cash hero ──
        _NetCashHero(
          net: netCash,
          revenue: summary.revenue,
          expenses: summary.expenses,
          pipeline: state.financials.pipeline,
          isAtRisk: state.financials.isAtRisk,
        ),

        const SizedBox(height: 16),

        // ── Add-transaction row + speed dial ──
        _AddTransactionRow(
          onLogSale: onLogSale,
          onLogExpense: onLogExpense,
          onNewInvoice: onNewInvoice,
        ),

        const SizedBox(height: 18),

        // ── Section header + filter row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Transactions',
                    style: AppType.heading(size: 16, color: c.text)),
              ),
              if (isFiltering)
                GestureDetector(
                  onTap: () {
                    onDirectionChanged('all');
                    onMethodChanged('all');
                    onSearchChanged('');
                  },
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt_off, size: 13, color: c.textMuted),
                      const SizedBox(width: 4),
                      Text('Clear',
                          style: AppType.body(
                              size: 12, weight: FontWeight.w600, color: c.textMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Filter chips ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _DirectionChip(
                  label: 'All', value: 'all', current: directionFilter, onTap: onDirectionChanged),
              const SizedBox(width: 6),
              _DirectionChip(
                  label: 'Income', value: 'income', current: directionFilter, onTap: onDirectionChanged),
              const SizedBox(width: 6),
              _DirectionChip(
                  label: 'Expenses', value: 'expense', current: directionFilter, onTap: onDirectionChanged),
              const Spacer(),
              _MethodPickerButton(
                methodFilter: methodFilter,
                onChanged: onMethodChanged,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Search bar (with result-count chip) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _SearchBar(
                  query: searchQuery,
                  onChanged: onSearchChanged,
                ),
              ),
              if (isFiltering && searched.isNotEmpty) ...[
                const SizedBox(width: 8),
                AppPill('${searched.length}', tone: PillTone.neutral, small: true),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── List or empty state ──
        if (searched.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyState(
              icon: hasData
                  ? Icons.search_off
                  : Icons.receipt_long_outlined,
              title: hasData ? 'No matching transactions' : 'No transactions yet',
              hint: hasData
                  ? (directionFilter == 'income'
                      ? 'No income recorded for this period'
                      : directionFilter == 'expense'
                          ? 'No expenses recorded for this period'
                          : 'Try adjusting your filters')
                  : 'Log a sale or expense to get started.',
              primaryCta: hasData
                  ? null
                  : ('Log sale', onLogSale),
              secondaryCta: hasData
                  ? null
                  : ('Log expense', onLogExpense),
            ),
          )
        else
          ...grouped.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 20, 6),
                    child: Text(
                      entry.key,
                      style: AppType.label(size: 10, color: c.textMuted),
                    ),
                  ),
                  ...entry.value.map((tx) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 3),
                        child: _TransactionCard(tx: tx),
                      )),
                ],
              )),
      ],
    );
  }
}

// ── Net-cash hero (replaces the 3-card row) ───────────────────────────────

class _NetCashHero extends StatelessWidget {
  final double net;
  final double revenue;
  final double expenses;
  final int pipeline;
  final bool isAtRisk;

  const _NetCashHero({
    required this.net,
    required this.revenue,
    required this.expenses,
    required this.pipeline,
    required this.isAtRisk,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final positive = net >= 0;
    final accent = positive ? c.teal : c.rose;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: context.isDark ? 0.18 : 0.12),
              c.bgElevated,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('NET THIS PERIOD',
                    style: AppType.label(size: 10, color: c.textMuted)),
                const Spacer(),
                if (isAtRisk)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.roseSurface,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 10, color: c.rose),
                        const SizedBox(width: 3),
                        Text('AT RISK',
                            style: AppType.label(size: 9, color: c.rose)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text(
                    positive ? '+' : '−',
                    style: AppType.display(size: 28, color: accent),
                  ),
                ),
                Flexible(
                  child: Text(
                    formatGHS(net.abs()),
                    style: AppType.display(size: 36, color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Side-by-side: inflows | outflows
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Inflows',
                    value: formatGHS(revenue),
                    color: c.green,
                    icon: Icons.arrow_circle_down_rounded,
                  ),
                ),
                Container(width: 1, height: 32, color: c.border),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroStat(
                    label: 'Outflows',
                    value: formatGHS(expenses),
                    color: c.rose,
                    icon: Icons.arrow_circle_up_rounded,
                  ),
                ),
              ],
            ),
            if (pipeline > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.blueSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions_rounded,
                        size: 13, color: c.blue),
                    const SizedBox(width: 6),
                    Text(
                      '${formatGHS(pipeline)} expected from proformas',
                      style: AppType.body(
                          size: 11.5, weight: FontWeight.w600, color: c.blue),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppType.label(size: 9.5, color: c.textMuted)),
              Text(value,
                  style: AppType.body(
                      size: 13, weight: FontWeight.w700, color: c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add-transaction row (speed dial trigger + 3 primary actions) ───────────

class _AddTransactionRow extends StatelessWidget {
  final VoidCallback onLogSale, onLogExpense, onNewInvoice;
  const _AddTransactionRow({
    required this.onLogSale,
    required this.onLogExpense,
    required this.onNewInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _AddTile(
              icon: Icons.payments_outlined,
              label: 'Log sale',
              hint: 'Cash, MoMo, bank',
              color: context.colors.teal,
              onTap: onLogSale,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AddTile(
              icon: Icons.description_outlined,
              label: 'Invoice',
              hint: 'Send a bill',
              color: context.colors.navy,
              onTap: onNewInvoice,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AddTile(
              icon: Icons.receipt_long_outlined,
              label: 'Expense',
              hint: 'Record outflow',
              color: context.colors.orange,
              onTap: onLogExpense,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final Color color;
  final VoidCallback onTap;

  const _AddTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: AppType.body(
                    size: 12, weight: FontWeight.w600, color: c.text)),
            Text(hint,
                style: AppType.body(size: 9.5, color: c.textFaint)),
          ],
        ),
      ),
    );
  }
}

// ── Filter chips (replaces _FilterChipSmall — uses AppPill) ───────────────

class _DirectionChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _DirectionChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: AppAnimation.fast,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.tealSurface : c.bgElevated,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? c.teal : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: AppType.body(
                size: 11.5,
                weight: FontWeight.w600,
                color: selected ? c.tealDeep : c.textMuted)),
      ),
    );
  }
}

/// Tappable button that opens a proper bottom-sheet picker for payment
/// method. Replaces the old tap-cycle button (all → cash → momo → bank)
/// which was invisible to users.
class _MethodPickerButton extends StatelessWidget {
  final String methodFilter;
  final ValueChanged<String> onChanged;
  const _MethodPickerButton({
    required this.methodFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = switch (methodFilter) {
      'cash' => 'Cash',
      'momo' => 'MoMo',
      'bank' => 'Bank',
      _ => 'Any method',
    };
    return GestureDetector(
      onTap: () => _openSheet(context, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 12, color: c.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: AppType.body(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: c.textMuted)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 14, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  static Future<void> _openSheet(
      BuildContext context, ValueChanged<String> onChanged) async {
    final c = context.colors;
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        const options = [
          ('all', 'Any method', 'Show everything', Icons.all_inclusive),
          ('cash', 'Cash', 'Physical cash on hand', Icons.money),
          ('momo', 'Mobile Money', 'MTN, Vodafone, AirtelTigo', Icons.phone_android),
          ('bank', 'Bank transfer', 'Direct bank deposits', Icons.account_balance),
        ];
        return Container(
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 6),
              Text('Filter by payment method',
                  style: AppType.heading(size: 17, color: c.text)),
              const SizedBox(height: 4),
              Text('Limit transactions to a specific way of paying.',
                  style: AppType.body(size: 12, color: c.textMuted)),
              const SizedBox(height: 14),
              for (final (value, label, hint, icon) in options)
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, value),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: c.navySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 16, color: c.navy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: AppType.body(
                                      size: 13.5,
                                      weight: FontWeight.w600,
                                      color: c.text)),
                              Text(hint,
                                  style:
                                      AppType.body(size: 11, color: c.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (result != null) onChanged(result);
  }
}

// ── Search bar ────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.query, required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(_SearchBar old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query && _ctrl.text != widget.query) {
      _ctrl.text = widget.query;
      _ctrl.selection = TextSelection.collapsed(offset: widget.query.length);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: c.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              style: AppType.body(size: 13, color: c.text),
              decoration: InputDecoration(
                hintText: 'Search transactions…',
                hintStyle: AppType.body(size: 13, color: c.textFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (widget.query.isNotEmpty)
            GestureDetector(
              onTap: () => widget.onChanged(''),
              child: Icon(Icons.close, size: 14, color: c.textFaint),
            ),
        ],
      ),
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final _TxItem tx;
  const _TransactionCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                  '${tx.subtitle} · ${fmtShortDate(tx.date)}',
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

// ── Date grouping helper ──────────────────────────────────────────────────

/// Group transactions into date buckets: Today, Yesterday, This Week, Earlier.
Map<String, List<_TxItem>> groupTransactionsByDate(List<_TxItem> items) {
  if (items.isEmpty) return {};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));

  String bucket(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    if (d.isAfter(weekAgo)) return 'This Week';
    return 'Earlier';
  }

  final grouped = <String, List<_TxItem>>{};
  for (final tx in items) {
    grouped.putIfAbsent(bucket(tx.date), () => []).add(tx);
  }
  final ordered = <String, List<_TxItem>>{};
  for (final key in ['Today', 'Yesterday', 'This Week', 'Earlier']) {
    if (grouped.containsKey(key)) ordered[key] = grouped[key]!;
  }
  return ordered;
}

// ── Empty state (shared across tabs) ──────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, hint;
  final (String, VoidCallback)? primaryCta;
  final (String, VoidCallback)? secondaryCta;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
    this.primaryCta,
    this.secondaryCta,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: c.bgInset,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: c.textFaint),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: AppType.heading(size: 16, color: c.text),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(hint,
                style: AppType.body(size: 12.5, color: c.textMuted),
                textAlign: TextAlign.center),
            if (primaryCta != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    AppBtn(primaryCta!.$1,
                        variant: BtnVariant.secondary,
                        icon: 'payments',
                        onTap: primaryCta!.$2),
                    if (secondaryCta != null) ...[
                      const SizedBox(height: 8),
                      AppBtn(secondaryCta!.$1,
                          variant: BtnVariant.secondary,
                          icon: 'receipt',
                          onTap: secondaryCta!.$2),
                    ],
                  ],
                ),
              ),
            ],
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
  final AppState state;
  final int periodMonths;
  final void Function({String? direction, String? method}) onApplyFilter;

  const _InsightsTab({
    required this.state,
    required this.periodMonths,
    required this.onApplyFilter,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final summary = state.computePeriodSummary(periodMonths);
    final hasData = summary.revenue > 0 || summary.expenses > 0;

    if (!hasData) {
      return _EmptyState(
        icon: Icons.insights,
        title: 'No insights yet',
        hint: 'Log transactions to see how your money moves.',
      );
    }

    final periodReceipts = receiptsInPeriod(state.receiptList, periodMonths);
    final periodExpenses = expensesInPeriod(state.expenseList, periodMonths);

    // Aggregate inflows by payment method
    final inflowsByMethod = <String, num>{};
    for (final r in periodReceipts) {
      inflowsByMethod[r.paymentMethod] =
          (inflowsByMethod[r.paymentMethod] ?? 0) + r.totalAmount;
    }

    // Aggregate outflows by payment method
    final outflowsByMethod = <String, num>{};
    for (final e in periodExpenses) {
      outflowsByMethod[e.paymentSource] =
          (outflowsByMethod[e.paymentSource] ?? 0) + e.amount;
    }

    // Aggregate outflows by mapped category
    final outflowsByCategory = <String, num>{};
    for (final e in periodExpenses) {
      outflowsByCategory[e.mappedCategory] =
          (outflowsByCategory[e.mappedCategory] ?? 0) + e.amount;
    }

    // Aggregate inflows by source label
    final inflowsBySource = <String, num>{};
    for (final r in periodReceipts) {
      final label = r.isInvoicePayment ? 'Invoice payment' : 'Direct sale';
      inflowsBySource[label] = (inflowsBySource[label] ?? 0) + r.totalAmount;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // ── Donut + net margin ──
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: _DonutChart(
                  totalInflows: summary.revenue,
                  totalOutflows: summary.expenses,
                  teal: c.teal,
                  rose: c.rose,
                  bgColor: c.bgElevated,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(color: c.green, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Inflows',
                            style: AppType.label(size: 11, color: c.textMuted)),
                        const Spacer(),
                        Text(formatGHS(summary.revenue),
                            style: AppType.body(
                                size: 13,
                                weight: FontWeight.w700,
                                color: c.green)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(color: c.rose, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Outflows',
                            style: AppType.label(size: 11, color: c.textMuted)),
                        const Spacer(),
                        Text(formatGHS(summary.expenses),
                            style: AppType.body(
                                size: 13,
                                weight: FontWeight.w700,
                                color: c.rose)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: c.border),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Net',
                            style: AppType.label(size: 11, color: c.textMuted)),
                        const Spacer(),
                        Text(
                          formatGHS(summary.net.abs()),
                          style: AppType.heading(
                            size: 16,
                            color: summary.net >= 0 ? c.teal : c.rose,
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

        const SizedBox(height: 16),

        // Inflows by payment method
        _BreakdownCard(
          title: 'Inflows by payment method',
          caption: 'Tap a row to filter the feed',
          data: inflowsByMethod,
          total: summary.revenue,
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
          onTapRow: (key) => onApplyFilter(
              direction: 'income', method: _methodKey(key)),
        ),

        const SizedBox(height: 12),

        // Outflows by payment method
        _BreakdownCard(
          title: 'Outflows by payment method',
          caption: 'Tap a row to filter the feed',
          data: outflowsByMethod,
          total: summary.expenses > 0 ? summary.expenses : 0,
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
          onTapRow: (key) => onApplyFilter(
              direction: 'expense', method: _methodKey(key)),
        ),

        const SizedBox(height: 12),

        // Income sources
        _BreakdownCard(
          title: 'Where inflows came from',
          caption: 'Tap a row to filter the feed',
          data: inflowsBySource,
          total: summary.revenue > 0 ? summary.revenue : 0,
          c: c,
          getColor: (key) =>
              key == 'Invoice payment' ? c.teal : c.green,
          labelFn: (key) => key,
          onTapRow: (key) => onApplyFilter(direction: 'income'),
        ),

        const SizedBox(height: 12),

        // Outflows by category
        _BreakdownCard(
          title: 'What outflows were made of',
          caption: 'Tap a row to filter the feed',
          data: outflowsByCategory,
          total: summary.expenses,
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
          onTapRow: (key) => onApplyFilter(direction: 'expense'),
        ),
      ],
    );
  }

  /// Map a human-readable payment label back to the canonical key used by
  /// the transaction filter.
  static String _methodKey(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('mobile')) return 'momo';
    if (lower.contains('cash')) return 'cash';
    if (lower.contains('bank')) return 'bank';
    return 'all';
  }
}

// ── Donut chart widget ────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  final double totalInflows, totalOutflows;
  final Color teal, rose, bgColor;

  const _DonutChart({
    required this.totalInflows,
    required this.totalOutflows,
    required this.teal,
    required this.rose,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalInflows + totalOutflows;
    if (total <= 0) return const SizedBox.shrink();

    final inflowPct = totalInflows / total;
    final outflowPct = totalOutflows / total;

    return CustomPaint(
      size: const Size(96, 96),
      painter: _DonutPainter(
        inflowPct: inflowPct,
        outflowPct: outflowPct,
        teal: teal,
        rose: rose,
        bgColor: bgColor,
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double inflowPct, outflowPct;
  final Color teal, rose, bgColor;

  _DonutPainter({
    required this.inflowPct,
    required this.outflowPct,
    required this.teal,
    required this.rose,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawCircle(center, radius, bgPaint);

    if (inflowPct + outflowPct <= 0) return;

    final inflowPaint = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    final outflowPaint = Paint()
      ..color = rose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    if (inflowPct > 0) {
      final sweepInflow = inflowPct * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        sweepInflow,
        false,
        inflowPaint,
      );
    }

    if (outflowPct > 0) {
      final sweepOutflow = outflowPct * 2 * 3.14159;
      final startAngle = -3.14159 / 2 + (inflowPct * 2 * 3.14159);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepOutflow,
        false,
        outflowPaint,
      );
    }

    // Punch out the center so the donut feels open
    final centerPaint = Paint()..color = bgColor;
    canvas.drawCircle(center, radius - 8, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.inflowPct != inflowPct || old.outflowPct != outflowPct;
}

// ── Breakdown card (insights) ─────────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  final String title;
  final String? caption;
  final Map<String, num> data;
  final num total;
  final AppColorsX c;
  final Color Function(String) getColor;
  final String Function(String) labelFn;
  final ValueChanged<String>? onTapRow;

  const _BreakdownCard({
    required this.title,
    this.caption,
    required this.data,
    required this.total,
    required this.c,
    required this.getColor,
    required this.labelFn,
    this.onTapRow,
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
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppType.heading(size: 13, color: c.text)),
              ),
              Text('${sorted.length} items',
                  style: AppType.body(size: 9.5, color: c.textFaint)),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                style: AppType.body(size: 10.5, color: c.textFaint)),
          ],
          const SizedBox(height: 12),
          ...sorted.map((e) {
            final pct = (e.value / total * 100).round();
            final barWidth = maxVal > 0 ? (e.value / maxVal) : 0.0;
            final barColor = getColor(e.key);
            final row = Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: barColor,
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
                              size: 10.5, color: c.textFaint)),
                      const SizedBox(width: 6),
                      Text(formatGHS(e.value),
                          style: AppType.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: c.text)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.bgInset,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: barWidth.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                barColor,
                                barColor.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (onTapRow == null) return row;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapRow!(e.key),
              child: row,
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORECAST TAB
// ═══════════════════════════════════════════════════════════════════════════

class _ForecastTab extends StatelessWidget {
  final CashFlowForecastData forecast;
  final List<ForecastRecommendation> recommendations;
  final bool loading;
  final VoidCallback onViewFullForecast;

  const _ForecastTab({
    required this.forecast,
    required this.recommendations,
    required this.loading,
    required this.onViewFullForecast,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(c.teal)),
            ),
            const SizedBox(height: 12),
            Text('Calculating forecast…',
                style: AppType.body(size: 13, color: c.textMuted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // ── Hero with explicit sign ──
        _forecastHero(context, c),
        const SizedBox(height: 16),

        // ── 30-day chart (stops the tab from being a stripped preview) ──
        if (forecast.dailyForecast.isNotEmpty) ...[
          _ForecastChartCard(forecast: forecast),
          const SizedBox(height: 20),
        ],

        // ── Quick stats ──
        Row(
          children: [
            Expanded(
              child: _ForecastStatTile(
                label: 'Inflows (30d)',
                amount: forecast.accountsReceivableDue + forecast.pipelineValue,
                color: c.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ForecastStatTile(
                label: 'Outflows (30d)',
                amount: forecast.fixedOperatingCosts,
                color: c.rose,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ForecastStatTile(
                label: 'Safety line',
                amount: forecast.safetyLine,
                color: c.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Recommendations ──
        if (recommendations.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What to do next',
                  style: AppType.heading(size: 14, color: c.text)),
              const SizedBox(height: 10),
              ...recommendations.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _forecastRecCard(context, e.value, c),
                  )),
              const SizedBox(height: 8),
            ],
          ),

        // ── Overdue invoices ──
        if (forecast.overdueInvoices.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overdue invoices',
                  style: AppType.heading(size: 14, color: c.text)),
              const SizedBox(height: 10),
              ...forecast.overdueInvoices.map((inv) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _overdueRow(context, inv, c),
                  )),
            ],
          ),

        const SizedBox(height: 16),

        // ── Deep-dive link ──
        Center(
          child: AppBtn('Open full forecast',
              variant: BtnVariant.secondary,
              icon: 'trending_up',
              onTap: onViewFullForecast),
        ),

        // ── Data quality note ──
        if (forecast.dataQuality == 'low') ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: c.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Improve accuracy',
                          style: AppType.body(
                              size: 13,
                              weight: FontWeight.w600,
                              color: c.text)),
                      const SizedBox(height: 4),
                      Text(
                        'Record expenses and log sales consistently for better cash flow predictions.',
                        style: AppType.body(size: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _forecastHero(BuildContext context, AppColorsX c) {
    final isAtRisk = forecast.isAtRisk;
    final projected = forecast.projectedCash30Days;
    final positive = projected >= 0;
    final signLabel = isAtRisk
        ? 'AT RISK — below safety line'
        : (positive ? 'ON TRACK' : 'AT RISK');

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isAtRisk
                ? [c.rose.withValues(alpha: 0.85), c.roseInk]
                : [c.navyDeep, c.navy],
          ),
          boxShadow: AppShadows.navy,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isAtRisk
                        ? Icons.warning_amber_rounded
                        : Icons.trending_up,
                    size: 18,
                    color: Colors.white),
                const SizedBox(width: 8),
                Text(signLabel,
                    style: AppType.label(
                        size: 10,
                        color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text(
                    positive ? '+' : '−',
                    style: AppType.display(size: 28, color: Colors.white),
                  ),
                ),
                Flexible(
                  child: Text(
                    formatGHS(projected.abs().round()),
                    style: AppType.display(size: 32, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isAtRisk
                  ? 'Below safety line of ${formatGHS(forecast.safetyLine.round())}'
                  : 'Safety line: ${formatGHS(forecast.safetyLine.round())}',
              style: AppType.body(
                  size: 12, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forecastRecCard(
      BuildContext context, ForecastRecommendation rec, AppColorsX c) {
    final (tone, dotColor) = switch (rec.urgency) {
      'critical' => (PillTone.rose, c.rose),
      'high' => (PillTone.orange, c.orange),
      'medium' => (PillTone.orange, c.orange),
      _ => (PillTone.teal, c.teal),
    };
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.title,
                    style: AppType.body(
                        size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 4),
                Text(rec.description,
                    style: AppType.body(size: 12, color: c.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppPill(rec.urgency.toUpperCase(),
                        tone: tone, small: true),
                    const SizedBox(width: 8),
                    Text('+GHS ${rec.impact.round()} impact',
                        style: AppType.body(
                            size: 11,
                            weight: FontWeight.w600,
                            color: c.green)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overdueRow(BuildContext context, OverdueInvoice inv, AppColorsX c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv.clientName,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text)),
                Text(inv.invoiceNumber,
                    style: AppType.mono(size: 10, color: c.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatGHS(inv.amount.round()),
                  style: AppType.body(
                      size: 13.5, weight: FontWeight.w600, color: c.text)),
              Text('${inv.daysPastDue}d overdue',
                  style: AppType.body(size: 11, color: c.rose)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastStatTile extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;
  const _ForecastStatTile(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.label(size: 10, color: c.textMuted)),
          const SizedBox(height: 4),
          Text(formatGHS(amount.toInt()),
              style: AppType.heading(size: 16, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Forecast chart (inlined from cash_flow_screen — no duplication) ──────

class _ForecastChartCard extends StatelessWidget {
  final CashFlowForecastData forecast;
  const _ForecastChartCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final points = forecast.dailyForecast;
    if (points.isEmpty) return const SizedBox.shrink();

    final maxVal = points.fold(
        0.0,
        (m, p) => (p.projected > m
            ? p.projected
            : p.withPipeline > m
                ? p.withPipeline
                : m));
    final minVal = points.fold(
        0.0,
        (m, p) => (p.projected < m
            ? p.projected
            : p.withPipeline < m
                ? p.withPipeline
                : m));
    final range = (maxVal - minVal).abs().clamp(1, double.infinity);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('30-day projection',
                    style: AppType.heading(size: 13, color: c.text)),
              ),
              _LegendDot(color: c.amber, label: 'With pipeline'),
              const SizedBox(width: 10),
              _LegendDot(color: c.teal, label: 'Projected'),
              const SizedBox(width: 10),
              _LegendDot(color: c.rose, label: 'Safety'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: Size(double.infinity, 140),
              painter: _ForecastChartPainter(
                points: points,
                safetyLine: forecast.safetyLine.toDouble(),
                minVal: minVal,
                range: range.toDouble(),
                teal: c.teal,
                rose: c.rose,
                amber: c.amber,
                surfaceColor: c.bgElevated,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final step = (points.length / 4).ceil();
            return Row(
              children: [
                for (int i = 0; i < points.length; i += step)
                  Expanded(
                    child: Text(points[i].date,
                        textAlign: TextAlign.center,
                        style: AppType.body(size: 9, color: c.textFaint)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: AppType.body(size: 9.5, color: c.textMuted)),
      ],
    );
  }
}

class _ForecastChartPainter extends CustomPainter {
  final List<DailyForecastPoint> points;
  final double safetyLine, minVal, range;
  final Color teal, rose, amber, surfaceColor;

  _ForecastChartPainter({
    required this.points,
    required this.safetyLine,
    required this.minVal,
    required this.range,
    required this.teal,
    required this.rose,
    required this.amber,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    if (points.isEmpty) return;

    final yScale = (h - 20) / range;
    final xStep = w / (points.length - 1);

    Offset toPosProjected(DailyForecastPoint p, int i) {
      final x = i * xStep;
      final y = h - 10 - ((p.projected - minVal) * yScale);
      return Offset(x, y);
    }

    Offset toPosPipeline(DailyForecastPoint p, int i) {
      final x = i * xStep;
      final y = h - 10 - ((p.withPipeline - minVal) * yScale);
      return Offset(x, y);
    }

    // Safety line (dashed)
    final safetyY = h - 10 - ((safetyLine - minVal) * yScale);
    if (safetyY > 0 && safetyY < h) {
      final dashPaint = Paint()
        ..color = rose.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      _drawDashedLine(canvas, Offset(0, safetyY), Offset(w, safetyY), dashPaint);
    }

    // Pipeline line (dashed amber)
    final pipelinePaint = Paint()
      ..color = amber.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final pipelinePath = Path();
    for (int i = 0; i < points.length; i++) {
      final pos = toPosPipeline(points[i], i);
      if (i == 0) {
        pipelinePath.moveTo(pos.dx, pos.dy);
      } else {
        pipelinePath.lineTo(pos.dx, pos.dy);
      }
    }
    _drawDashedPath(canvas, pipelinePath, pipelinePaint);

    // Projected line (solid teal with area fill)
    final projectedPath = Path();
    for (int i = 0; i < points.length; i++) {
      final pos = toPosProjected(points[i], i);
      if (i == 0) {
        projectedPath.moveTo(pos.dx, pos.dy);
      } else {
        projectedPath.lineTo(pos.dx, pos.dy);
      }
    }
    final fillPath = Path.from(projectedPath)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [teal.withValues(alpha: 0.18), teal.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    final projectedPaint = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(projectedPath, projectedPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final distance = (dx * dx + dy * dy).abs();
    if (distance == 0) return;
    final totalLength = distance.sqrt();
    final dashCount = (totalLength / (dashWidth + dashSpace)).floor();
    final stepX = dx / dashCount / 2;
    final stepY = dy / dashCount / 2;
    for (int i = 0; i < dashCount; i++) {
      final start = Offset(a.dx + stepX * 2 * i, a.dy + stepY * 2 * i);
      final end = Offset(start.dx + stepX, start.dy + stepY);
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastChartPainter old) =>
      old.points != points ||
      old.safetyLine != safetyLine ||
      old.minVal != minVal;
}

extension on double {
  double sqrt() {
    if (this <= 0) return 0;
    // Newton's method
    var x = this;
    for (var i = 0; i < 8; i++) {
      x = 0.5 * (x + this / x);
    }
    return x;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REPORTS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _ReportsTab extends StatelessWidget {
  final AppState state;
  final int periodMonths;
  final List<Invoice> invoices;

  const _ReportsTab({
    required this.state,
    required this.periodMonths,
    required this.invoices,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final summary = state.computePeriodSummary(periodMonths);
    final hasData = summary.revenue > 0 || summary.expenses > 0;

    if (!hasData) {
      return _EmptyState(
        icon: Icons.assessment,
        title: 'No reports yet',
        hint: 'Log transactions to generate reports.',
      );
    }

    final periodReceipts = receiptsInPeriod(state.receiptList, periodMonths);
    final periodExpenses = expensesInPeriod(state.expenseList, periodMonths);

    // P&L calculations
    final revenue = summary.revenue;
    final netIncome = summary.net;
    final margin = revenue > 0 ? (netIncome / revenue * 100) : 0.0;

    num cogs = 0;
    num otherOpex = 0;
    for (final e in periodExpenses) {
      if (e.mappedCategory == 'cogs') {
        cogs += e.amount;
      } else {
        otherOpex += e.amount;
      }
    }
    final grossProfit = revenue - cogs;

    // Build ledger entries
    final ledger = <_LedgerEntry>[
      for (final r in periodReceipts)
        _LedgerEntry(
          date: r.paidDate,
          account: r.clientName ?? 'Received payment',
          description: r.methodLabel,
          credit: r.totalAmount.toDouble(),
          debit: 0,
          reference: r.receiptNumber ?? '',
        ),
      for (final e in periodExpenses)
        _LedgerEntry(
          date: e.expenseDate,
          account: e.description ?? e.category,
          description: '${e.category} · ${e.paymentSource}',
          credit: 0,
          debit: e.amount.toDouble(),
          reference: '',
        ),
      for (final inv in invoices
          .where((i) => i.status == 'pending' || i.status == 'overdue'))
        _LedgerEntry(
          date: inv.dueDate ?? inv.createdAt ?? DateTime.now(),
          account: inv.customer,
          description: '${inv.status} · due ${inv.due}',
          credit: inv.amount.toDouble(),
          debit: 0,
          reference: inv.id,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final (cfSections, cfNet, cfOpening, cfClosing) =
        computeCashFlowData(periodExpenses, periodReceipts);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // ── P&L card ──
        _ReportCard(
          icon: Icons.assessment,
          iconColor: c.teal,
          title: 'Profit & Loss',
          badge: currentMonthShort(),
          actions: [
            _CardAction(
              icon: Icons.visibility_outlined,
              tooltip: 'Preview',
              onTap: () => previewPnLReport(
                context,
                summary: summary,
                periodExpenses: periodExpenses,
                periodReceipts: periodReceipts,
                periodMonths: periodMonths,
              ),
            ),
            _CardAction(
              icon: Icons.ios_share,
              tooltip: 'Share',
              onTap: () => sharePnLReport(
                context,
                summary: summary,
                periodExpenses: periodExpenses,
                periodReceipts: periodReceipts,
                periodMonths: periodMonths,
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    Text(
                        '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}% margin',
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

        // ── Cash Flow Statement card ──
        if (cfSections.isNotEmpty)
          _ReportCard(
            icon: Icons.account_balance,
            iconColor: c.blue,
            title: 'Cash Flow Statement',
            badge: periodLabel(periodMonths),
            actions: [
              _CardAction(
                icon: Icons.visibility_outlined,
                tooltip: 'Preview',
                onTap: () => previewCashFlowReport(
                  context,
                  sections: cfSections,
                  netCashFlow: cfNet,
                  openingCash: cfOpening,
                  closingCash: cfClosing,
                  periodMonths: periodMonths,
                ),
              ),
              _CardAction(
                icon: Icons.ios_share,
                tooltip: 'Share',
                onTap: () => shareCashFlowReport(
                  context,
                  sections: cfSections,
                  netCashFlow: cfNet,
                  openingCash: cfOpening,
                  closingCash: cfClosing,
                  periodMonths: periodMonths,
                ),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in cfSections) ...[
                  _cfSectionHeader(c, section.title, section.total),
                  const SizedBox(height: 8),
                  for (final item in section.items)
                    _cfRow(c, item.label, item.amount,
                        item.amount >= 0 ? c.green : c.rose),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                            label: 'Inflow',
                            value: formatGHS(
                                periodReceipts.fold<num>(0, (s, r) => s + r.totalAmount)),
                            color: c.green),
                      ),
                      Container(width: 1, height: 32, color: c.border),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStat(
                            label: 'Outflow',
                            value: formatGHS(
                                periodExpenses.fold<num>(0, (s, e) => s + e.amount)),
                            color: c.rose),
                      ),
                      Container(width: 1, height: 32, color: c.border),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStat(
                            label: 'Net',
                            value: formatGHS(cfNet),
                            color: cfNet >= 0 ? c.teal : c.rose),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // ── General Ledger card ──
        _ReportCard(
          icon: Icons.book,
          iconColor: c.navy,
          title: 'General Ledger',
          badge: '${ledger.length} entries',
          actions: [
            _CardAction(
              icon: Icons.visibility_outlined,
              tooltip: 'Preview',
              onTap: () => previewLedgerReport(
                context,
                ledger: ledger,
                periodMonths: periodMonths,
              ),
            ),
            _CardAction(
              icon: Icons.ios_share,
              tooltip: 'Share',
              onTap: () => shareLedgerReport(
                context,
                ledger: ledger,
                periodMonths: periodMonths,
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
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
              ...ledger.take(50).map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom:
                              BorderSide(color: c.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text(fmtShortDate(e.date),
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
                                  style:
                                      AppType.body(size: 9, color: c.textFaint)),
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
          Text(value, style: AppType.mono(size: size, color: color)),
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

  Widget _cfSectionHeader(AppColorsX c, String label, num sectionTotal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(label, style: AppType.label(size: 12, color: c.text)),
          const Spacer(),
          Text(formatGHS(sectionTotal),
              style: AppType.mono(
                size: 11,
                color: sectionTotal >= 0 ? c.teal : c.rose,
              )),
        ],
      ),
    );
  }

  Widget _cfRow(AppColorsX c, String label, num amount, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppType.body(
                    size: 11.5,
                    weight: bold ? FontWeight.w600 : FontWeight.w400,
                    color: c.textMuted)),
          ),
          Text(formatGHS(amount),
              style: AppType.mono(
                size: 11.5,
                weight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ── Reusable report card with header + actions + body ────────────────────

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? badge;
  final List<Widget> actions;
  final Widget child;

  const _ReportCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.actions,
    this.badge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: AppType.heading(size: 14, color: c.text)),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge!,
                      style: AppType.label(size: 10, color: c.textMuted)),
                ),
              for (final action in actions) ...[
                const SizedBox(width: 4),
                action,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: AnimatedPress(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: c.bgInset,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: c.textMuted),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label(size: 10, color: c.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: AppType.heading(size: 14, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _LedgerEntry {
  final DateTime date;
  final String account, description, reference;
  final double debit, credit;

  const _LedgerEntry({
    required this.date,
    required this.account,
    required this.description,
    required this.reference,
    required this.debit,
    required this.credit,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED REPORT BUILDERS
// ═══════════════════════════════════════════════════════════════════════════

String periodLabel(int periodMonths) => periodMonths <= 0
    ? 'YTD (${currentMonthName()})'
    : 'Last $periodMonths months';

void sharePnLReport(
  BuildContext context, {
  required PeriodSummary summary,
  required List<Expense> periodExpenses,
  required List<Receipt> periodReceipts,
  required int periodMonths,
}) {
  final state = context.read<AppState>();
  final expenseBreakdown = _buildExpenseBreakdown(periodExpenses);
  final incomeBreakdown = _buildIncomeBreakdown(periodReceipts);

  FinancialReportService.sharePnL(
    businessName: state.business.name,
    periodLabel: periodLabel(periodMonths),
    revenue: summary.revenue,
    expenses: summary.expenses,
    expenseBreakdown: expenseBreakdown,
    incomeBreakdown: incomeBreakdown,
    logoUrl: state.business.logoUrl ?? '',
  );
}

void previewPnLReport(
  BuildContext context, {
  required PeriodSummary summary,
  required List<Expense> periodExpenses,
  required List<Receipt> periodReceipts,
  required int periodMonths,
}) {
  final state = context.read<AppState>();
  final expenseBreakdown = _buildExpenseBreakdown(periodExpenses);
  final incomeBreakdown = _buildIncomeBreakdown(periodReceipts);

  FinancialReportService.previewPnL(
    businessName: state.business.name,
    periodLabel: periodLabel(periodMonths),
    revenue: summary.revenue,
    expenses: summary.expenses,
    expenseBreakdown: expenseBreakdown,
    incomeBreakdown: incomeBreakdown,
    logoUrl: state.business.logoUrl ?? '',
  );
}

void shareCashFlowReport(
  BuildContext context, {
  required List<CashFlowSection> sections,
  required double netCashFlow,
  required double openingCash,
  required double closingCash,
  required int periodMonths,
}) {
  final state = context.read<AppState>();
  FinancialReportService.shareCashFlow(
    businessName: state.business.name,
    periodLabel: periodLabel(periodMonths),
    sections: sections,
    netCashFlow: netCashFlow,
    openingCash: openingCash,
    closingCash: closingCash,
  );
}

void previewCashFlowReport(
  BuildContext context, {
  required List<CashFlowSection> sections,
  required double netCashFlow,
  required double openingCash,
  required double closingCash,
  required int periodMonths,
}) {
  final state = context.read<AppState>();
  FinancialReportService.previewCashFlow(
    businessName: state.business.name,
    periodLabel: periodLabel(periodMonths),
    sections: sections,
    netCashFlow: netCashFlow,
    openingCash: openingCash,
    closingCash: closingCash,
  );
}

void shareLedgerReport(
  BuildContext context, {
  required List<_LedgerEntry> ledger,
  required int periodMonths,
}) {
  final state = context.read<AppState>();
  FinancialReportService.shareLedger(
    businessName: state.business.name,
    periodLabel: periodLabel(periodMonths),
    entries: ledger
        .map((e) => GeneralLedgerLine(
              dateLabel: fmtShortDate(e.date),
              account: e.account,
              description: e.description,
              reference: e.reference,
              debit: e.debit,
              credit: e.credit,
            ))
        .toList(),
  );
}

void previewLedgerReport(
  BuildContext context, {
  required List<_LedgerEntry> ledger,
  required int periodMonths,
}) {
  final state = context.read<AppState>();
  FinancialReportService.previewLedger(
    businessName: state.business.name,
    periodLabel: periodLabel(periodMonths),
    entries: ledger
        .map((e) => GeneralLedgerLine(
              dateLabel: fmtShortDate(e.date),
              account: e.account,
              description: e.description,
              reference: e.reference,
              debit: e.debit,
              credit: e.credit,
            ))
        .toList(),
  );
}

List<MapEntry<String, double>> _buildExpenseBreakdown(
    List<Expense> periodExpenses) {
  final catTotals = <String, double>{};
  for (final e in periodExpenses) {
    catTotals[e.mappedCategory] =
        (catTotals[e.mappedCategory] ?? 0) + e.amount;
  }
  return [
    for (final entry in catTotals.entries) MapEntry(entry.key, entry.value),
  ];
}

List<MapEntry<String, double>> _buildIncomeBreakdown(
    List<Receipt> periodReceipts) {
  final sourceTotals = <String, double>{};
  for (final r in periodReceipts) {
    final label = r.isInvoicePayment ? 'Invoice payment' : 'Direct sale';
    sourceTotals[label] = (sourceTotals[label] ?? 0) + r.totalAmount;
  }
  return [
    for (final entry in sourceTotals.entries) MapEntry(entry.key, entry.value),
  ];
}

/// Compute cash flow data from period-filtered expenses and receipts.
/// Returns (sections, netCashFlow, openingCash, closingCash).
(List<CashFlowSection>, double, double, double) computeCashFlowData(
  List<Expense> periodExpenses,
  List<Receipt> periodReceipts,
) {
  final cashFromCustomers =
      periodReceipts.where((r) => r.isInvoicePayment).fold<double>(
          0.0, (s, r) => s + r.totalAmount);
  final cashFromDirectSales =
      periodReceipts.where((r) => !r.isInvoicePayment).fold<double>(
          0.0, (s, r) => s + r.totalAmount);
  final totalCashIn = cashFromCustomers + cashFromDirectSales;

  double labor = 0, rent = 0, utilities = 0;
  double marketing = 0, transport = 0, compliance = 0, other = 0;
  for (final e in periodExpenses) {
    switch (e.mappedCategory) {
      case 'labor':
        labor += e.amount;
      case 'opex_rent':
        rent += e.amount;
      case 'opex_utilities':
        utilities += e.amount;
      case 'marketing':
        marketing += e.amount;
      case 'logistics':
        transport += e.amount;
      case 'compliance':
        compliance += e.amount;
      default:
        other += e.amount;
    }
  }
  final totalOpEx =
      labor + rent + utilities + marketing + transport + compliance + other;
  final netOperating = totalCashIn - totalOpEx;

  const investingItems = <CashFlowLine>[];
  const financingItems = <CashFlowLine>[];

  final operatingItems = <CashFlowLine>[
    CashFlowLine(
        label: 'Cash from customers (invoices)', amount: cashFromCustomers),
    CashFlowLine(label: 'Cash from direct sales', amount: cashFromDirectSales),
    if (labor > 0)
      CashFlowLine(
          label: 'Staff wages & salaries',
          amount: -labor,
          description: 'Includes salaries, wages, and benefits'),
    if (rent > 0) CashFlowLine(label: 'Rent & property', amount: -rent),
    if (utilities > 0)
      CashFlowLine(label: 'Utilities', amount: -utilities),
    if (marketing > 0)
      CashFlowLine(label: 'Marketing & advertising', amount: -marketing),
    if (transport > 0)
      CashFlowLine(label: 'Transport & logistics', amount: -transport),
    if (compliance > 0)
      CashFlowLine(label: 'Compliance & permits', amount: -compliance),
    if (other > 0)
      CashFlowLine(label: 'Other operating expenses', amount: -other),
  ];

  final sections = <CashFlowSection>[
    CashFlowSection(
      title: 'Operating Activities',
      items: operatingItems,
      total: netOperating,
    ),
  ];

  if (investingItems.isNotEmpty) {
    sections.add(CashFlowSection(
      title: 'Investing Activities',
      items: investingItems,
      total: 0,
    ));
  }
  if (financingItems.isNotEmpty) {
    sections.add(CashFlowSection(
      title: 'Financing Activities',
      items: financingItems,
      total: 0,
    ));
  }

  final netCashFlow = netOperating;
  final openingCash = netCashFlow > 0
      ? (totalOpEx * 0.5).roundToDouble()
      : (totalCashIn * 0.3).roundToDouble();
  final closingCash = openingCash + netCashFlow;

  return (sections, netCashFlow, openingCash, closingCash);
}
