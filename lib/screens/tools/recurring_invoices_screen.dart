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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.recurringTemplates.isEmpty && !state.recurringTemplatesLoading) {
        state.loadRecurringTemplates();
      }
    });
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

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Recurring invoices',
              onBack: () => Navigator.pop(context),
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
                            active: active,
                            paused: paused,
                            onToggle: _toggleActive,
                            onDelete: _deleteTemplate,
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
}

class _ListBody extends StatelessWidget {
  final List<RecurringTemplate> active, paused;
  final void Function(RecurringTemplate) onToggle;
  final void Function(RecurringTemplate) onDelete;

  const _ListBody({
    required this.active,
    required this.paused,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Summary card
        if (active.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 20, color: c.teal),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${active.length} active recurring invoice${active.length == 1 ? '' : 's'}',
                          style: AppType.body(
                              size: 13, weight: FontWeight.w600, color: c.text)),
                      Text(
                        'Next: ${active.first.frequencyLabel.toLowerCase()} · ${_fmtDate(active.first.nextInvoiceDate)}',
                        style: AppType.body(size: 11.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Active templates
        if (active.isNotEmpty) ...[
          Text('Active',
              style: AppType.body(
                  size: 12, weight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 8),
          ...active.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TemplateCard(
                  template: t,
                  onToggle: () => onToggle(t),
                  onDelete: () => onDelete(t),
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
          ...paused.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TemplateCard(
                  template: t,
                  onToggle: () => onToggle(t),
                  onDelete: () => onDelete(t),
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



class _TemplateCard extends StatelessWidget {
  final RecurringTemplate template;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onToggle,
    required this.onDelete,
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
