import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';
import '../sheets/log_expense_sheet.dart';

/// Full expenses list — pushed from the Tools tab or Finance screen.
/// Groups expenses by month (newest first), shows category icons, amount,
/// description, and sustainability tag where applicable.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.expenses.isEmpty && !state.financialsLoading) {
        state.loadExpenses();
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<AppState>().loadExpenses();
  }

  void _openLogExpense() {
    LogExpenseSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final expenses = state.expenseList;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Expenses',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.teal,
                child: expenses.isEmpty
                    ? _EmptyState(onLogExpense: _openLogExpense)
                    : _ListBody(expenses: expenses),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: AppBtn(
                'Log expense',
                full: true,
                icon: 'receipt',
                onTap: _openLogExpense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Group expenses by year-month for a clean chronological list.
Map<String, List<Expense>> _groupByMonth(List<Expense> expenses) {
  final map = <String, List<Expense>>{};
  for (final e in expenses) {
    final key = '${e.expenseDate.year}-${e.expenseDate.month.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => []).add(e);
  }
  return map;
}

/// Format "May 2026" from a "2026-05" key.
String _monthLabel(String ym) {
  final parts = ym.split('-');
  if (parts.length != 2) return ym;
  final m = int.tryParse(parts[1]) ?? 1;
  return monthLabel(int.parse(parts[0]), m);
}

// ── Helper: map category icon to (Color, Color) pair ─────────────────────────

(Color, Color) _categoryColors(String mappedCategory, AppColorsX c) =>
    switch (mappedCategory) {
      'cogs' => (c.orangeSurface, c.orange),
      'opex_rent' => (c.blueSurface, c.blueDeep),
      'opex_utilities' => (c.amberSurface, c.amber),
      'labor' => (c.tealSurface, c.tealDeep),
      'marketing' => (c.roseSurface, c.rose),
      'logistics' => (c.navySurface, c.navyTint),
      'compliance' => (c.greenSurface, c.greenDeep),
      _ => (c.bgInset, c.textMuted),
    };

// ── List body ──────────────────────────────────────────────────────────────

class _ListBody extends StatelessWidget {
  final List<Expense> expenses;

  const _ListBody({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = _groupByMonth(expenses);
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    // Summary bar — total spent
    final totalSpent = expenses.fold<num>(0, (s, e) => s + e.amount);
    // Count sustainable items
    final sustainableCount = expenses.where((e) => e.sustainabilityTagged).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                    Text('Total spent',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatGHS(totalSpent),
                        style: AppType.heading(size: 20, color: c.text)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: c.border),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expenses',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(expenses.length.toString(),
                            style: AppType.heading(size: 20, color: c.text)),
                        if (sustainableCount > 0) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.eco, size: 14, color: c.green),
                          const SizedBox(width: 2),
                          Text('$sustainableCount',
                              style: AppType.body(
                                  size: 11, color: c.green)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Month groups
        for (final key in keys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_monthLabel(key),
                    style: AppType.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: c.text)),
                const SizedBox(width: 6),
                Text('· ${groups[key]!.length}',
                    style: AppType.body(size: 12, color: c.textMuted)),
              ],
            ),
          ),
          ...groups[key]!.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeInSlide(
                  index: e.key,
                  child: _ExpenseCard(expense: e.value),
                ),
              )),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ── Expense card ───────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (iconBg, iconFg) = _categoryColors(expense.mappedCategory, c);
    final iconName = expense.categoryIcon;

    final dateStr = '${expense.expenseDate.day} ${_monthLabel('${expense.expenseDate.year}-${expense.expenseDate.month.toString().padLeft(2, '0')}')}';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppIcon(iconName, size: 20, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description ?? expense.category,
                  style: AppType.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(expense.category,
                        style: AppType.body(
                            size: 11, color: c.textFaint)),
                    const SizedBox(width: 6),
                    Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                            color: c.textFaint,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(dateStr,
                        style: AppType.body(
                            size: 11, color: c.textFaint)),
                    if (expense.sustainabilityTagged) ...[
                      const SizedBox(width: 6),
                      Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                              color: c.textFaint,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco, size: 12, color: c.green),
                          const SizedBox(width: 2),
                          Text('Sustainable',
                              style: AppType.body(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: c.green)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatGHS(expense.amount),
                  style: AppType.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: c.rose)),
              if (expense.paymentSource != 'cash') ...[
                const SizedBox(height: 4),
                Text(
                  expense.paymentSource == 'momo' ? 'MoMo' : 'Bank',
                  style: AppType.mono(size: 10, color: c.textFaint),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onLogExpense;

  const _EmptyState({required this.onLogExpense});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.orangeSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_outlined,
                    size: 26, color: c.orange),
              ),
              const SizedBox(height: 16),
              Text('No expenses yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Record your business expenses to track spending, see cash flow insights, and build your sustainability score.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AppBtn(
                  'Log your first expense',
                  full: true,
                  icon: 'receipt',
                  onTap: onLogExpense,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
