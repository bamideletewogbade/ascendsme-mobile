import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/expense_mapping.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../sheets/log_expense_sheet.dart';

/// Full expenses list — pushed from the Tools tab or Finance screen.
/// Groups expenses by month (newest first), shows category icons, amount,
/// description, sustainability tag, search, category filtering, category
/// breakdown chart, and tap-to-detail for editing/deleting.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'All';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<AppState>().loadExpenses();
  }

  void _openLogExpense() {
    LogExpenseSheet.show(context, onSaved: () {
      if (!mounted) return;
      unawaited(_refresh());
    });
  }

  void _openExpenseDetail(Expense expense) {
    ExpenseDetailSheet.show(context, expense: expense, onDeleted: () {
      if (!mounted) return;
      unawaited(_refresh());
    }, onUpdated: () {
      if (!mounted) return;
      unawaited(_refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final expenses = state.expenseList;

    // Apply filters
    final filtered = expenses.where((e) {
      if (_categoryFilter != 'All' && e.category != _categoryFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesDesc =
            (e.description ?? '').toLowerCase().contains(q);
        final matchesCat = e.category.toLowerCase().contains(q);
        final matchesMapped = e.mappedCategory.toLowerCase().contains(q);
        if (!matchesDesc && !matchesCat && !matchesMapped) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Expenses',
              onBack: () => Navigator.pop(context),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: c.bgInset,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: AppType.body(size: 13, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Search expenses…',
                    hintStyle: AppType.body(size: 13, color: c.textFaint),
                    prefixIcon:
                        Icon(Icons.search, size: 18, color: c.textFaint),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.close,
                                size: 16, color: c.textFaint),
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            // Category filter chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _categoryFilter == 'All',
                    onTap: () => setState(() => _categoryFilter = 'All'),
                  ),
                  ...kManualExpenseCategories.map((cat) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _FilterChip(
                          label: cat,
                          selected: _categoryFilter == cat,
                          onTap: () =>
                              setState(() => _categoryFilter = cat),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.teal,
                child: filtered.isEmpty
                    ? _EmptyState(
                        hasExpenses: expenses.isNotEmpty,
                        onLogExpense: _openLogExpense,
                      )
                    : _ListBody(
                        expenses: filtered,
                        onTapExpense: _openExpenseDetail,
                      ),
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

// ── Filter chip ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            size: 12,
            weight: FontWeight.w600,
            color: selected ? c.tealDeep : c.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Group by month ────────────────────────────────────────────────────────

Map<String, List<Expense>> _groupByMonth(List<Expense> expenses) {
  final map = <String, List<Expense>>{};
  for (final e in expenses) {
    final key =
        '${e.expenseDate.year}-${e.expenseDate.month.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => []).add(e);
  }
  return map;
}

String _monthLabel(String ym) {
  final parts = ym.split('-');
  if (parts.length != 2) return ym;
  final m = int.tryParse(parts[1]) ?? 1;
  return monthLabel(int.parse(parts[0]), m);
}

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

// ── Category breakdown chart ───────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final List<Expense> expenses;

  const _CategoryBreakdown({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (expenses.isEmpty) return const SizedBox.shrink();

    // Aggregate by mapped category
    final catTotals = <String, num>{};
    for (final e in expenses) {
      catTotals[e.mappedCategory] =
          (catTotals[e.mappedCategory] ?? 0) + e.amount;
    }
    final total = catTotals.values.fold<num>(0, (s, v) => s + v);
    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    final catColors = <String, Color>{
      'cogs': c.orange,
      'opex_rent': c.blueDeep,
      'opex_utilities': c.amber,
      'labor': c.tealDeep,
      'marketing': c.rose,
      'logistics': c.navyTint,
      'compliance': c.greenDeep,
      'other': c.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category breakdown',
                style: AppType.body(
                    size: 14, weight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 14),
            // Pie chart
            SizedBox(
              height: 100,
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _PieChartPainter(
                        segments: top.map((e) => _PieSegment(
                          value: e.value.toDouble(),
                          color: catColors[e.key] ?? c.textMuted,
                          label: e.key,
                        )).toList(),
                        total: total.toDouble(),
                        centerColor: c.bgElevated,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: top.map((e) {
                        final pct = total > 0
                            ? (e.value / total * 100).round()
                            : 0;
                        final color = catColors[e.key] ?? c.textMuted;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _categoryLabel(e.key),
                                  style: AppType.body(
                                      size: 11.5, color: c.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('$pct%',
                                  style: AppType.mono(
                                      size: 11, color: c.text)),
                            ],
                          ),
                        );
                      }).toList(),
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

  String _categoryLabel(String mapped) => switch (mapped) {
        'cogs' => 'Stock',
        'opex_rent' => 'Rent',
        'opex_utilities' => 'Utilities',
        'labor' => 'Wages',
        'marketing' => 'Marketing',
        'logistics' => 'Transport',
        'compliance' => 'Compliance',
        _ => 'Other',
      };
}

class _PieSegment {
  final double value;
  final Color color;
  final String label;

  const _PieSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSegment> segments;
  final double total;

  final Color centerColor;

  const _PieChartPainter({
    required this.segments,
    required this.total,
    required this.centerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || segments.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -3.14159 / 2;
    for (final seg in segments) {
      final sweepAngle = (seg.value / total) * 2 * 3.14159;
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.fill,
      );
      startAngle += sweepAngle;
    }

    // Center hole for donut effect
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()..color = centerColor,
    );
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => old.total != total;
}

// ── List body ──────────────────────────────────────────────────────────────

class _ListBody extends StatelessWidget {
  final List<Expense> expenses;
  final void Function(Expense) onTapExpense;

  const _ListBody({
    required this.expenses,
    required this.onTapExpense,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = _groupByMonth(expenses);
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final totalSpent = expenses.fold<num>(0, (s, e) => s + e.amount);
    final sustainableCount =
        expenses.where((e) => e.sustainabilityTagged).length;

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
                        style: AppType.body(
                            size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatGHS(totalSpent),
                        style: AppType.heading(
                            size: 20, color: c.text)),
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
                        style: AppType.body(
                            size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(expenses.length.toString(),
                            style: AppType.heading(
                                size: 20, color: c.text)),
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

        // Category breakdown chart
        _CategoryBreakdown(expenses: expenses),

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
                    style: AppType.body(
                        size: 12, color: c.textMuted)),
              ],
            ),
          ),
          ...groups[key]!.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeInSlide(
                  index: e.key,
                  child: _ExpenseCard(
                    expense: e.value,
                    onTap: () => onTapExpense(e.value),
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ---- Expense card (tappable) -----------------------------------------------

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;

  const _ExpenseCard({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (iconBg, iconFg) =
        _categoryColors(expense.mappedCategory, c);
    final iconName = expense.categoryIcon;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
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
                    Text(
                      '${expense.expenseDate.day} ${_monthLabel('${expense.expenseDate.year}-${expense.expenseDate.month.toString().padLeft(2, '0')}')}',
                      style: AppType.body(
                          size: 11, color: c.textFaint),
                    ),
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

// ── Expense Detail Sheet ───────────────────────────────────────────────────

/// Bottom sheet shown when tapping an expense card. Shows full details and
/// offers Edit / Delete actions.
class ExpenseDetailSheet extends StatefulWidget {
  final Expense expense;
  final VoidCallback? onDeleted;
  final VoidCallback? onUpdated;

  const ExpenseDetailSheet({
    super.key,
    required this.expense,
    this.onDeleted,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required Expense expense,
    VoidCallback? onDeleted,
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseDetailSheet(
        expense: expense,
        onDeleted: onDeleted,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends State<ExpenseDetailSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete expense?',
            style: AppType.heading(
                size: 18, color: context.colors.text)),
        content: Text(
          'This will permanently remove the expense of ${formatGHS(widget.expense.amount)}.',
          style: AppType.body(
              size: 13, color: context.colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.body(
                    size: 13, color: context.colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppType.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: context.colors.rose)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _deleting = true);

    try {
      await SupabaseService.deleteExpense(
          expenseId: widget.expense.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e',
              style: AppType.body(size: 13, color: Colors.white)),
          backgroundColor: context.colors.rose,
        ),
      );
    }
  }

  void _edit() {
    Navigator.pop(context);
    EditExpenseSheet.show(context, expense: widget.expense,
        onSaved: widget.onUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.expense;
    final (iconBg, iconFg) = _categoryColors(e.mappedCategory, c);

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              children: [
                // Icon + Amount
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AppIcon(e.categoryIcon,
                      size: 28, color: iconFg),
                ),
                const SizedBox(height: 12),
                Text(formatGHS(e.amount),
                    style: AppType.heading(
                        size: 28, color: c.text)),
                const SizedBox(height: 6),
                Text(e.description ?? e.category,
                    style: AppType.body(
                        size: 14, color: c.textMuted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),

                // Detail rows
                _detailRow(c, 'Category', e.category),
                _detailRow(c, 'Payment',
                    e.paymentSource == 'momo'
                        ? 'Mobile Money'
                        : e.paymentSource == 'bank'
                            ? 'Bank transfer'
                            : 'Cash'),
                _detailRow(
                    c,
                    'Date',
                    '${e.expenseDate.day} ${_monthLabel('${e.expenseDate.year}-${e.expenseDate.month.toString().padLeft(2, '0')}')}'),
                if (e.sustainabilityTagged)
                  _detailRow(c, 'Eco', 'Sustainable',
                      icon: Icons.eco, iconColor: c.green),

                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: AppBtn('Edit',
                          variant: BtnVariant.secondary,
                          icon: 'tune',
                          onTap: _edit),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _deleting
                          ? Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(c.rose),
                                ),
                              ),
                            )
                          : AppBtn('Delete',
                              variant: BtnVariant.outline,
                              icon: 'close',
                              onTap: _delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(AppColorsX c, String label, String value,
      {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: AppType.body(
                    size: 12, color: c.textMuted)),
          ),
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? c.green),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(value,
                style: AppType.body(
                    size: 13,
                    weight: FontWeight.w500,
                    color: c.text)),
          ),
        ],
      ),
    );
  }
}

// ── Edit Expense Sheet ─────────────────────────────────────────────────────

/// Bottom sheet for editing an existing expense — pre-fills current values,
/// reuses the same form UI as [LogExpenseSheet].
class EditExpenseSheet extends StatefulWidget {
  final Expense expense;
  final VoidCallback? onSaved;

  const EditExpenseSheet({
    super.key,
    required this.expense,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required Expense expense,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditExpenseSheet(
        expense: expense,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<EditExpenseSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late DateTime _date;
  late String _category;
  late String _paymentSource;

  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: widget.expense.amount.toString());
    _descCtrl =
        TextEditingController(text: widget.expense.description ?? '');
    _date = widget.expense.expenseDate;
    _category = widget.expense.category;
    _paymentSource = widget.expense.paymentSource;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  num? _parseAmount() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return num.tryParse(raw);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      setState(() {
        _saving = false;
        _error = 'Enter a valid amount greater than 0.';
      });
      return;
    }

    try {
      await SupabaseService.updateExpense(
        expenseId: widget.expense.id,
        amount: amount,
        date: _date,
        description: _descCtrl.text.trim(),
        category: _category,
        paymentSource: _paymentSource,
      );
      if (!mounted) return;
      context.read<AppState>().loadExpenses();
      widget.onSaved?.call();
      setState(() {
        _saving = false;
        _saved = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(msg);
    final extracted = match?.group(1)?.trim();
    if (extracted != null && extracted.isNotEmpty) return extracted;
    return 'Could not save. Check your connection and try again.';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Today';
    }
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _saved ? _buildSaved(c) : _buildForm(c),
    );
  }

  Widget _buildForm(AppColorsX c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text('Edit expense',
              style: AppType.heading(size: 20, color: c.text)),
        ),
        const SizedBox(height: 6),

        // Amount
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount (GHS)',
                  style: AppType.body(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: c.textMuted)),
              const SizedBox(height: 6),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: AppType.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: c.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description',
                  style: AppType.body(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: c.textMuted)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _descCtrl,
                  style: AppType.body(size: 14, color: c.text),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Fabric purchase from Makola',
                    hintStyle:
                        AppType.body(size: 13, color: c.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Category
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category',
                  style: AppType.body(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: c.textMuted)),
              const SizedBox(height: 6),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    dropdownColor: c.bgElevated,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: c.textFaint, size: 20),
                    style: AppType.body(
                        size: 14,
                        weight: FontWeight.w500,
                        color: c.text),
                    items: kManualExpenseCategories
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Payment source
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paid with',
                  style: AppType.body(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: c.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PaymentChip(
                    label: 'Cash',
                    selected: _paymentSource == 'cash',
                    onTap: () =>
                        setState(() => _paymentSource = 'cash'),
                  ),
                  const SizedBox(width: 8),
                  _PaymentChip(
                    label: 'MoMo',
                    selected: _paymentSource == 'momo',
                    onTap: () =>
                        setState(() => _paymentSource = 'momo'),
                  ),
                  const SizedBox(width: 8),
                  _PaymentChip(
                    label: 'Bank',
                    selected: _paymentSource == 'bank',
                    onTap: () =>
                        setState(() => _paymentSource = 'bank'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Date
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date',
                  style: AppType.body(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: c.textMuted)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 17, color: c.textFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_formatDate(_date),
                            style: AppType.body(
                                size: 14,
                                weight: FontWeight.w500,
                                color: c.text)),
                      ),
                      Icon(Icons.expand_more,
                          size: 18, color: c.textFaint),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.rose.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: c.rose.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 16, color: c.rose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style:
                            AppType.body(size: 13, color: c.rose)),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _saving
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation(c.teal),
                    ),
                  ),
                )
              : AppBtn('Save changes',
                  full: true, onTap: _save),
        ),
      ],
    );
  }

  Widget _buildSaved(AppColorsX c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.greenSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 32, color: c.green),
          ),
          const SizedBox(height: 16),
          Text('Expense updated',
              style: AppType.heading(size: 22, color: c.text)),
          const SizedBox(height: 12),
          Text('Your changes have been saved.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted)),
          const SizedBox(height: 24),
          AppBtn('Done',
              full: true,
              variant: BtnVariant.secondary,
              onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected ? c.tealSurface : c.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? c.teal : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.body(
              size: 13,
              weight: FontWeight.w600,
              color: selected ? c.tealDeep : c.text,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasExpenses;
  final VoidCallback onLogExpense;

  const _EmptyState({
    required this.hasExpenses,
    required this.onLogExpense,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (hasExpenses) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
              height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              children: [
                Icon(Icons.search_off,
                    size: 40, color: c.textFaint),
                const SizedBox(height: 12),
                Text('No matching expenses',
                    style: AppType.heading(
                        size: 17, color: c.text)),
                const SizedBox(height: 4),
                Text('Try a different search or filter.',
                    style: AppType.body(
                        size: 13, color: c.textMuted)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
            height: MediaQuery.of(context).size.height * 0.18),
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
                  style: AppType.heading(
                      size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Record your business expenses to track spending, see cash flow insights, and build your sustainability score.',
                  textAlign: TextAlign.center,
                  style: AppType.body(
                      size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 60),
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
