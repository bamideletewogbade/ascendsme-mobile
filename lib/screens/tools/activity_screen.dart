import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/activity.dart';
import '../../core/models.dart' show formatGHS, Invoice, Receipt;
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';
import 'invoice_detail_screen.dart';
import 'receipt_detail_screen.dart';

/// Full-screen unified activity feed — shows every business event (invoices,
/// receipts, expenses) in one scrollable timeline with filter pills.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  /// Which activity kinds to show. Empty set = show all.
  Set<ActivityKind> _filters = {};

  static final _filterOptions = <String, Set<ActivityKind>>{
    'All': <ActivityKind>{},
    'Income': {ActivityKind.saleLogged, ActivityKind.invoicePaid},
    'Expenses': {ActivityKind.expenseLogged},
    'Invoices': {ActivityKind.invoiceSent, ActivityKind.invoicePaid},
  };

  bool get _hasFilter => _filters.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final allEvents = buildActivityFeed(
      invoices: state.invoices,
      receipts: state.receipts,
      expenses: state.expenses,
      limit: 999, // no limit
    );

    // Apply period filter from AppState
    final periodMonths = state.effectivePeriodMonths;
    final now_ = DateTime.now();
    final periodEnd = DateTime(now_.year, now_.month + 1, 1);
    final periodStart = periodMonths <= 0
        ? DateTime(now_.year, 1, 1)
        : DateTime(now_.year, now_.month - periodMonths + 1, 1);
    final periodFiltered = allEvents
        .where((e) => !e.time.isBefore(periodStart) && e.time.isBefore(periodEnd))
        .toList();

    // Apply kind filter
    final filtered = _hasFilter
        ? periodFiltered.where((e) => _filters.contains(e.kind)).toList()
        : periodFiltered;

    // Compute stats from filtered results
    double totalIncome = 0;
    double totalExpenses = 0;
    for (final e in filtered) {
      if (e.amount != null && e.amount! > 0) {
        switch (e.kind) {
          case ActivityKind.expenseLogged:
            totalExpenses += e.amount!;
          case ActivityKind.saleLogged:
          case ActivityKind.invoicePaid:
            totalIncome += e.amount!;
          case ActivityKind.invoiceSent:
          case ActivityKind.quoteCreated:
          case ActivityKind.quoteExpired:
          case ActivityKind.quoteConverted:
            break;
        }
      }
    }
    final net = totalIncome - totalExpenses;

    // Count per filter group
    int countForGroup(Set<ActivityKind> kinds) => kinds.isEmpty
        ? periodFiltered.length
        : periodFiltered.where((e) => kinds.contains(e.kind)).length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: c.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Activity',
                      style: AppType.display(size: 28, color: c.text)),
                  const Spacer(),
                  Text('${filtered.length} ${filtered.length == 1 ? 'event' : 'events'}',
                      style: AppType.body(size: 13, color: c.textMuted)),
                ],
              ),
            ),

            // ── Stats summary ──
            if (filtered.isNotEmpty && (totalIncome > 0 || totalExpenses > 0))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      _statCol(c, 'Income', formatGHS(totalIncome.round()), c.green),
                      Container(width: 1, height: 28, color: c.border),
                      _statCol(c, 'Expenses', formatGHS(totalExpenses.round()), c.rose),
                      Container(width: 1, height: 28, color: c.border),
                      _statCol(c, 'Net', formatGHS(net.round()), net >= 0 ? c.teal : c.rose),
                    ],
                  ),
                ),
              ),

            // ── Period pills (shared with Finance) ──
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: AppPeriodSelector(),
            ),

            // ── Kind filter chips ──
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                children: [
                  for (final entry in _filterOptions.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: entry.key,
                      active: _filtersEqual(_filters, entry.value),
                      count: countForGroup(entry.value),
                      onTap: () => setState(() {
                        _filters = Set.from(entry.value);
                      }),
                    ),
                  ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            // ── Feed list ──
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyActivity(
                      allEmpty: allEvents.isEmpty,
                      filterActive: _hasFilter,
                      onClearFilter: () => setState(() {
                        _filters = {};
                      }),
                    )
                  : RefreshIndicator(
                      onRefresh: state.refreshAll,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final event = filtered[i];
                          final showDateHeader = i == 0 ||
                              _isNewDay(filtered[i - 1].time, event.time);
                          return Column(
                            children: [
                              if (showDateHeader)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 12, bottom: 6),
                                  child: _DateHeader(time: event.time),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: FadeInSlide(
                                  index: i,
                                  child: _ActivityRow(
                                    event: event,
                                    onTap: () => _navigateToDetail(event),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCol(AppColorsX c, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppType.body(size: 14, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: AppType.label(size: 9.5, color: c.textMuted)),
        ],
      ),
    );
  }

  bool _filtersEqual(Set<ActivityKind> a, Set<ActivityKind> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  bool _isNewDay(DateTime a, DateTime b) =>
      a.year != b.year || a.month != b.month || a.day != b.day;

  void _navigateToDetail(ActivityEvent event) {
    final state = context.read<AppState>();

    if (event.invoiceId != null) {
      Invoice? found;
      for (final inv in state.invoices) {
        if (inv.backendId == event.invoiceId) {
          found = inv;
          break;
        }
      }
      if (found != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(initialInvoice: found!),
          ),
        );
        return;
      }
    }

    if (event.receiptId != null) {
      for (final raw in state.receipts) {
        final rawId = raw['id'];
        if (rawId != null && rawId.toString() == event.receiptId) {
          final receipt = Receipt.fromRow(raw);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ReceiptDetailScreen(receipt: receipt, rawRow: raw),
            ),
          );
          return;
        }
      }
    }
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimation.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.teal : c.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? c.teal : c.border,
            width: active ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppType.body(
                size: 13,
                weight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : c.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.2)
                    : c.bgInset,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: AppType.body(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: active ? Colors.white : c.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date header ────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final DateTime time;
  const _DateHeader({required this.time});

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = date.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Text(_formatDate(time),
              style: AppType.label(size: 11, color: c.textMuted)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: c.border)),
        ],
      ),
    );
  }
}

// ── Activity row ───────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final ActivityEvent event;
  final VoidCallback? onTap;

  const _ActivityRow({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, iconBg, iconFg, amountColor, amountPrefix) = switch (event.kind) {
      ActivityKind.invoicePaid => (
        Icons.check_circle,
        c.greenSurface,
        c.green,
        c.green,
        '+',
      ),
      ActivityKind.saleLogged => (
        Icons.payments,
        c.tealSurface,
        c.tealDeep,
        c.tealDeep,
        '+',
      ),
      ActivityKind.invoiceSent => (
        Icons.description_outlined,
        c.bgInset,
        c.textMuted,
        c.textMuted,
        '',
      ),
      ActivityKind.expenseLogged => (
        Icons.receipt_long,
        c.orangeSurface,
        c.orange,
        c.rose,
        '−',
      ),
      ActivityKind.quoteCreated => (
        Icons.description_outlined,
        c.tealSurface,
        c.tealDeep,
        c.tealDeep,
        '',
      ),
      ActivityKind.quoteExpired => (
        Icons.warning_amber_rounded,
        c.rose.withValues(alpha: 0.12),
        c.rose,
        c.rose,
        '',
      ),
      ActivityKind.quoteConverted => (
        Icons.north_east,
        c.greenSurface,
        c.green,
        c.green,
        '',
      ),
    };
    final amount = event.amount;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(formatRelativeTime(event.time),
                        style: AppType.body(size: 11, color: c.textFaint)),
                    if (event.subtitle != null) ...[
                      Text(' · ',
                          style: AppType.body(size: 11, color: c.textFaint)),
                      Text(event.subtitle!,
                          style: AppType.body(
                              size: 11,
                              weight: FontWeight.w600,
                              color: c.rose)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (amount != null && amount > 0)
            Text('${amountPrefix}GHS ${amount.round()}',
                style: AppType.body(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: amountColor)),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyActivity extends StatelessWidget {
  final bool allEmpty;
  final bool filterActive;
  final VoidCallback onClearFilter;

  const _EmptyActivity({
    required this.allEmpty,
    required this.filterActive,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: c.bgInset,
                shape: BoxShape.circle,
              ),
              child: Icon(
                filterActive ? Icons.filter_alt_off : Icons.history,
                size: 36, color: c.textFaint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              allEmpty
                  ? 'No activity yet'
                  : (filterActive ? 'No matching activity' : 'No activity yet'),
              style: AppType.heading(size: 17, color: c.text),
            ),
            const SizedBox(height: 6),
            Text(
              filterActive
                  ? 'Try a different filter to see more events.'
                  : 'As you log sales, send invoices, and record expenses, your activity will appear here.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            if (filterActive) ...[
              const SizedBox(height: 16),
              AppBtn(
                'Clear filter',
                variant: BtnVariant.secondary,
                onTap: onClearFilter,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
