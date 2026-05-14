import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';
import '../sheets/new_invoice_sheet.dart';
import 'invoice_detail_screen.dart';

/// Full invoices list — pushed from the Tools tab when the user taps the
/// "Invoicing" tool card. Groups by effective status (Overdue → Pending →
/// Paid), supports pull-to-refresh, and lets the user create a new invoice
/// via the existing NewInvoiceSheet flow.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  @override
  void initState() {
    super.initState();
    // Most of the time AppState already has invoices loaded (loadBusiness
    // triggers loadInvoices on auth), but if the user lands here cold we
    // refresh just in case.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.invoices.isEmpty && !state.invoicesLoading) {
        state.loadInvoices();
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<AppState>().loadInvoices();
  }

  void _openNewInvoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewInvoiceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final groups = _groupByStatus(state.invoices);
    final totalCount = state.invoices.length;
    final outstandingTotal = state.financials.outstanding;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Invoices',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.teal,
                child: state.invoicesLoading && state.invoices.isEmpty
                    ? const _LoadingState()
                    : state.invoices.isEmpty
                        ? _EmptyState(onCreate: _openNewInvoice)
                        : _ListBody(
                            groups: groups,
                            totalCount: totalCount,
                            outstandingTotal: outstandingTotal,
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: AppBtn(
                'New invoice',
                full: true,
                icon: 'add',
                onTap: _openNewInvoice,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Group invoices by effective status with a deterministic display order:
  /// overdue first (needs attention), then pending, then paid.
  Map<_StatusGroup, List<Invoice>> _groupByStatus(List<Invoice> invoices) {
    final out = <_StatusGroup, List<Invoice>>{
      _StatusGroup.overdue: [],
      _StatusGroup.pending: [],
      _StatusGroup.paid: [],
    };
    for (final inv in invoices) {
      final g = switch (inv.status) {
        'overdue' => _StatusGroup.overdue,
        'paid' => _StatusGroup.paid,
        _ => _StatusGroup.pending,
      };
      out[g]!.add(inv);
    }
    return out;
  }
}

enum _StatusGroup { overdue, pending, paid }

class _ListBody extends StatelessWidget {
  final Map<_StatusGroup, List<Invoice>> groups;
  final int totalCount;
  final int outstandingTotal;

  const _ListBody({
    required this.groups,
    required this.totalCount,
    required this.outstandingTotal,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                    Text('Outstanding',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatGHS(outstandingTotal),
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
                    Text('Total invoices',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(totalCount.toString(),
                        style: AppType.heading(size: 20, color: c.text)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Status groups — render only groups with rows so empty buckets don't
        // pollute the list.
        for (final entry in groups.entries)
          if (entry.value.isNotEmpty) ...[
            _GroupHeader(group: entry.key, count: entry.value.length),
            const SizedBox(height: 8),
            ...entry.value.map((inv) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Builder(
                    builder: (ctx) => _InvoiceCard(
                      invoice: inv,
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              InvoiceDetailScreen(initialInvoice: inv),
                        ),
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final _StatusGroup group;
  final int count;

  const _GroupHeader({required this.group, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, dotColor) = switch (group) {
      _StatusGroup.overdue => ('Overdue', c.rose),
      _StatusGroup.pending => ('Pending', c.orange),
      _StatusGroup.paid => ('Paid', c.green),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: AppType.body(
                size: 13, weight: FontWeight.w700, color: c.text)),
        const SizedBox(width: 6),
        Text('· $count',
            style: AppType.body(size: 12, color: c.textMuted)),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback? onTap;

  const _InvoiceCard({required this.invoice, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (pillTone, pillLabel) = switch (invoice.status) {
      'paid' => (PillTone.green, 'Paid'),
      'overdue' => (PillTone.rose, 'Overdue'),
      'pending' || 'sent' => (PillTone.orange, 'Pending'),
      _ => (PillTone.neutral, 'Draft'),
    };

    // Human due/age sub-line.
    final dueSub = switch (invoice.status) {
      'overdue' => invoice.days > 0
          ? 'Overdue by ${invoice.days}d · was due ${invoice.due}'
          : 'Overdue · was due ${invoice.due}',
      'paid' => 'Paid · due was ${invoice.due}',
      _ => invoice.days < 0
          ? 'Due ${invoice.due} (${-invoice.days}d to go)'
          : invoice.days == 0
              ? 'Due today · ${invoice.due}'
              : 'Due ${invoice.due}',
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.customer,
                        style: AppType.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: c.text)),
                    const SizedBox(height: 2),
                    Text(invoice.id,
                        style: AppType.mono(size: 11, color: c.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatGHS(invoice.amount),
                      style: AppType.body(
                          size: 15,
                          weight: FontWeight.w700,
                          color: c.text)),
                  const SizedBox(height: 4),
                  AppPill(pillLabel, tone: pillTone, small: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(dueSub,
              style: AppType.body(size: 11.5, color: c.textMuted)),
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
          Text('Loading invoices…',
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
    // Wrapped in ListView so RefreshIndicator can still kick in via overscroll.
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
                child: Icon(Icons.description_outlined,
                    size: 26, color: c.tealDeep),
              ),
              const SizedBox(height: 16),
              Text('No invoices yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Send your first invoice to a customer — payments flow in via Paystack and update your cash flow automatically.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AppBtn(
                  'Send your first invoice',
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
