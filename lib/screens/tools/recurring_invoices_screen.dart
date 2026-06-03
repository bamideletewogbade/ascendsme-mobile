import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart' show RecurringTemplate, RecurringFrequency, formatGHS, formatLongDate;
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../sheets/new_recurring_sheet.dart';

/// Lists all recurring invoice templates with their status, next date, and
/// controls to pause/resume or delete. From here users can create new
/// recurring templates or tap one to manage it.
class RecurringInvoicesScreen extends StatefulWidget {
  const RecurringInvoicesScreen({super.key});

  @override
  State<RecurringInvoicesScreen> createState() =>
      _RecurringInvoicesScreenState();
}

class _RecurringInvoicesScreenState extends State<RecurringInvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.recurringTemplates.isEmpty && !state.recurringTemplatesLoading) {
        state.loadRecurringTemplates();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<AppState>().loadRecurringTemplates();
  }

  void _openNew() {
    NewRecurringSheet.show(context, onCreated: () {
      context.read<AppState>().loadRecurringTemplates();
    });
  }

  Future<void> _toggleActive(RecurringTemplate t) async {
    await SupabaseService.updateRecurringTemplate(
      templateId: t.id,
      isActive: !t.isActive,
    );
    if (!mounted) return;
    context.read<AppState>().loadRecurringTemplates();
  }

  Future<void> _deleteTemplate(RecurringTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.bgElevated,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Remove recurring invoice?',
              style: AppType.heading(size: 18, color: c.text)),
          content: Text(
            'This removes the ${t.frequencyLabel.toLowerCase()} template for ${t.customerName}. Future invoices will not be generated.',
            style: AppType.body(size: 13.5, color: c.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep it',
                  style: AppType.body(
                      size: 13, weight: FontWeight.w600, color: c.text)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove',
                  style: AppType.body(
                      size: 13, weight: FontWeight.w600, color: c.rose)),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await SupabaseService.deleteRecurringTemplate(templateId: t.id);
    if (!mounted) return;
    context.read<AppState>().loadRecurringTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final templates = state.recurringTemplates;
    final active = templates.where((t) => t.isActive).toList();
    final paused = templates.where((t) => !t.isActive).toList();

    // Filter by search query
    List<RecurringTemplate> filterByQuery(List<RecurringTemplate> list) =>
        _searchQuery.isEmpty
            ? list
            : list
                .where((t) =>
                    t.customerName.toLowerCase().contains(_searchQuery))
                .toList();

    final filteredActive = filterByQuery(active);
    final filteredPaused = filterByQuery(paused);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Recurring invoices',
              onBack: () => Navigator.pop(context),
            ),

            // ── Search bar ──
            if (templates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: AppType.body(size: 13, color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Search by customer name…',
                      hintStyle:
                          AppType.body(size: 13, color: c.textFaint),
                      prefixIcon: Icon(Icons.search,
                          size: 18, color: c.textFaint),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(Icons.close,
                                  size: 18, color: c.textMuted),
                            )
                          : null,
                      filled: true,
                      fillColor: c.bgElevated,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.teal, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.teal,
                child: state.recurringTemplatesLoading && templates.isEmpty
                    ? const _LoadingState()
                    : templates.isEmpty
                        ? _EmptyState(onCreate: _openNew)
                        : _ListBody(
                            active: filteredActive,
                            paused: filteredPaused,
                            onToggle: _toggleActive,
                            onDelete: _deleteTemplate,
                            onGenerate: (t) => _generateNow(t),
                            searchActive: _searchQuery.isNotEmpty,
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: AppBtn(
                'New recurring invoice',
                full: true,
                icon: 'add',
                onTap: _openNew,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateNow(RecurringTemplate template) async {
    final c = context.colors;
    try {
      final result = await SupabaseService.generateRecurringInvoice(
        templateId: template.id,
      );
      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice generated!',
                style: AppType.body(size: 13, color: Colors.white)),
            backgroundColor: c.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.read<AppState>().loadRecurringTemplates();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate invoice',
                style: AppType.body(size: 13, color: Colors.white)),
            backgroundColor: c.rose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate invoice',
              style: AppType.body(size: 13, color: Colors.white)),
          backgroundColor: c.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _ListBody extends StatelessWidget {
  final List<RecurringTemplate> active, paused;
  final void Function(RecurringTemplate) onToggle;
  final void Function(RecurringTemplate) onDelete;
  final void Function(RecurringTemplate) onGenerate;
  final bool searchActive;

  const _ListBody({
    required this.active,
    required this.paused,
    required this.onToggle,
    required this.onDelete,
    required this.onGenerate,
    this.searchActive = false,
  });

  double _monthlyTotal(List<RecurringTemplate> templates) {
    double total = 0;
    for (final t in templates) {
      final monthly = switch (t.frequency) {
        RecurringFrequency.weekly => t.amount * 4.33,
        RecurringFrequency.monthly => t.amount.toDouble(),
        RecurringFrequency.quarterly => t.amount / 3,
        RecurringFrequency.yearly => t.amount / 12,
      };
      total += monthly;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mrr = _monthlyTotal(active);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Summary card
        if (active.isNotEmpty && !searchActive)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${active.length} active',
                          style: AppType.body(
                              size: 13, weight: FontWeight.w600, color: c.text)),
                      Text(
                        'Next: ${_fmtDate(active.first.nextInvoiceDate)}',
                        style: AppType.body(size: 11.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatGHS(mrr.round()),
                        style: AppType.body(size: 16, weight: FontWeight.w700, color: c.teal)),
                    Text('/mo',
                        style: AppType.body(size: 10.5, color: c.textMuted)),
                  ],
                ),
              ],
            ),
          ),

        // MRR breakdown chart
        if (active.length >= 2 && !searchActive)
          _MrrChart(activeTemplates: active),

        const SizedBox(height: 16),

        // Active templates
        if (active.isNotEmpty) ...[
          Text('Active',
              style: AppType.body(
                  size: 12, weight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 8),
          ...active.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeInSlide(
                  index: e.key,
                  child: _TemplateCard(
                    template: e.value,
                    onToggle: () => onToggle(e.value),
                    onDelete: () => onDelete(e.value),
                    onGenerate: () => onGenerate(e.value),
                  ),
                ),
              )),
        ],

        // Paused templates
        if (paused.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Paused',
              style: AppType.body(
                  size: 12, weight: FontWeight.w700, color: c.textFaint)),
          const SizedBox(height: 8),
          ...paused.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeInSlide(
                  index: e.key,
                  child: _TemplateCard(
                    template: e.value,
                    onToggle: () => onToggle(e.value),
                    onDelete: () => onDelete(e.value),
                  ),
                ),
              )),
        ],
      ],
    );
  }
}

/// Shared date formatter for recurring invoice dates (short format).
String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

// ── MRR breakdown chart ──────────────────────────────────────────────────────

/// Horizontal bar chart showing each active template's contribution to the
/// monthly recurring revenue, ordered largest first. Also shows a frequency
/// distribution summary at the bottom.
class _MrrChart extends StatelessWidget {
  final List<RecurringTemplate> activeTemplates;

  const _MrrChart({required this.activeTemplates});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Compute monthly contribution and sort descending
    final breakdown = activeTemplates.map((t) {
      final monthly = switch (t.frequency) {
        RecurringFrequency.weekly => t.amount * 4.33,
        RecurringFrequency.monthly => t.amount.toDouble(),
        RecurringFrequency.quarterly => t.amount / 3,
        RecurringFrequency.yearly => t.amount / 12,
      };
      return (template: t, monthlyAmount: monthly);
    }).toList()
      ..sort((a, b) => b.monthlyAmount.compareTo(a.monthlyAmount));

    final maxAmount = breakdown.first.monthlyAmount;
    final totalMrr = breakdown.fold<double>(0, (s, x) => s + x.monthlyAmount);

    // Frequency distribution
    final freqCounts = <RecurringFrequency, int>{};
    for (final t in activeTemplates) {
      freqCounts[t.frequency] = (freqCounts[t.frequency] ?? 0) + 1;
    }

    // Color per frequency
    Color freqColor(RecurringFrequency f) => switch (f) {
          RecurringFrequency.weekly => c.teal,
          RecurringFrequency.monthly => c.navyTint,
          RecurringFrequency.quarterly => c.orange,
          RecurringFrequency.yearly => c.rose,
        };

    String freqLabel(RecurringFrequency f) => switch (f) {
          RecurringFrequency.weekly => 'Weekly',
          RecurringFrequency.monthly => 'Monthly',
          RecurringFrequency.quarterly => 'Quarterly',
          RecurringFrequency.yearly => 'Yearly',
        };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 16, color: c.text),
                const SizedBox(width: 6),
                Text('MRR Breakdown',
                    style: AppType.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: c.text)),
                const Spacer(),
                Text(formatGHS(totalMrr.round()),
                    style: AppType.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: c.teal)),
                Text('/mo',
                    style: AppType.body(
                        size: 10,
                        color: c.textMuted)),
              ],
            ),
            const SizedBox(height: 12),

            // Bars
            for (final (i, item) in breakdown.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      item.template.customerName,
                      style: AppType.body(
                          size: 11, weight: FontWeight.w600, color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final barWidth = maxAmount > 0
                            ? (item.monthlyAmount / maxAmount *
                                    constraints.maxWidth)
                                .clamp(24.0, constraints.maxWidth)
                            : 24.0;
                        return Row(
                          children: [
                            Container(
                              width: barWidth,
                              height: 20,
                              decoration: BoxDecoration(
                                color: freqColor(item.template.frequency)
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Container(
                                width: barWidth * 0.7,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: freqColor(item.template.frequency),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatGHS(item.monthlyAmount.round()),
                              style: AppType.body(
                                  size: 10.5,
                                  weight: FontWeight.w600,
                                  color: c.textMuted),
                              maxLines: 1,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: c.border, height: 1),
            const SizedBox(height: 10),

            // Frequency distribution chips
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded,
                    size: 14, color: c.textFaint),
                const SizedBox(width: 6),
                Text('By frequency',
                    style: AppType.body(
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: c.textFaint)),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in freqCounts.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: freqColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${freqLabel(entry.key)} · ${entry.value}',
                                  style: AppType.body(
                                      size: 10.5, color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _TemplateCard extends StatelessWidget {
  final RecurringTemplate template;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onGenerate;

  const _TemplateCard({
    required this.template,
    required this.onToggle,
    required this.onDelete,
    this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.customerName,
                        style: AppType.body(
                            size: 14, weight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 2),
                    Text(template.frequencyLabel,
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatGHS(template.amount),
                      style: AppType.body(
                          size: 15, weight: FontWeight.w700, color: c.text)),
                  const SizedBox(height: 4),
                  AppPill(
                    template.isActive ? 'Active' : 'Paused',
                    tone: template.isActive ? PillTone.green : PillTone.neutral,
                    small: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: c.textFaint),
              const SizedBox(width: 6),                      Text('Next: ${formatLongDate(template.nextInvoiceDate)}',
                  style: AppType.body(size: 12, color: c.textMuted)),
              const Spacer(),
              // Generate now (active only)
              if (template.isActive && onGenerate != null) ...[
                GestureDetector(
                  onTap: onGenerate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.tealSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.teal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 13, color: c.teal),
                        const SizedBox(width: 4),
                        Text('Generate',
                            style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.teal)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Toggle button
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: template.isActive ? c.bgInset : c.tealSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        template.isActive
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 13,
                        color: template.isActive ? c.textMuted : c.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        template.isActive ? 'Pause' : 'Resume',
                        style: AppType.body(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color:
                                template.isActive ? c.textMuted : c.teal),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.roseSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.rose.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 13, color: c.rose),
                      const SizedBox(width: 4),
                      Text('Remove',
                          style: AppType.body(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: c.rose)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(c.teal)),
          ),
          const SizedBox(height: 12),
          Text('Loading templates…',
              style: AppType.body(size: 13, color: c.textMuted)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

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
                  color: c.tealSurface,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.repeat, size: 26, color: c.teal),
              ),
              const SizedBox(height: 16),
              Text('No recurring invoices yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Set up recurring invoices for retainers, monthly fees, and standing orders — they\'ll be generated automatically.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AppBtn(
                  'Set up recurring',
                  full: true,
                  icon: 'add',
                  onTap: onCreate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
