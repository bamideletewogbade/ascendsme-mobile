import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/crm_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../sheets/new_invoice_sheet.dart';
import 'invoice_detail_screen.dart';
import 'receipt_detail_screen.dart';

/// Unified invoicing tool — an all-in-one screen that replaces the separate
/// Invoices, Receipts, and Proformas screens. Tabs for quick switching,
/// search/filter on the Invoices tab, and inline quick actions on cards.
///
/// Inspired by the web's InvoicingTool.tsx (4,703-line unified tool).
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── Search & filter ──
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; // null = all, 'overdue', 'pending', 'paid'

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.invoices.isEmpty && !state.invoicesLoading) {
        state.loadInvoices();
      }
      if (state.receipts.isEmpty) {
        state.loadReceipts();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshInvoices() async {
    await context.read<AppState>().loadInvoices();
  }

  Future<void> _refreshReceipts() async {
    await context.read<AppState>().loadReceipts();
  }

  void _openNewInvoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewInvoiceSheet(),
    );
  }

  // ── Quick actions ──

  Future<void> _quickMarkPaid(Invoice inv, AppState state) async {
    final businessId = state.business.id;
    if (businessId == null || inv.backendId == null) return;

    final method = await _showPaymentMethodSheet(context);
    if (method == null || !mounted) return;

    try {
      await SupabaseService.markInvoicePaid(
        invoiceId: inv.backendId!,
        businessId: businessId,
        paymentMethod: method,
      );
      if (!mounted) return;
      // Sync CRM metrics in background
      unawaited(CrmService.syncAfterPurchase(
        businessId: businessId,
        customerName: inv.customer,
        customerEmail: inv.clientEmail,
        amountGhs: inv.amount.toDouble(),
      ));
      // Fulfill inventory reservations
      unawaited(SupabaseService.fulfillReservationsByReference(
        referenceId: inv.backendId!,
        reservationType: 'invoice',
      ));
      await Future.wait([state.loadInvoices(), state.loadFinancials()]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not mark as paid'),
          backgroundColor: context.colors.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _quickCopyPayLink(Invoice inv) async {
    if (!inv.hasPayLink) return;
    final url = '${AppConfig.payLinkBaseUrl}${inv.payToken}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pay link copied'),
        backgroundColor: context.colors.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _quickConvertProforma(Invoice inv, AppState state) async {
    if (inv.backendId == null) return;
    try {
      await SupabaseService.convertProformaToInvoice(invoiceId: inv.backendId!);
      if (!mounted) return;
      await state.loadInvoices();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not convert quote'),
          backgroundColor: context.colors.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final invoices = state.invoices;
    final receipts = state.receiptList;
    final proformas = invoices.where((i) => i.isProforma).toList();
    final regularInvoices = invoices.where((i) => !i.isProforma).toList();
    final isLoading = state.invoicesLoading && invoices.isEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Invoicing', onBack: () => Navigator.pop(context)),

            // ── Tab bar ──
            Container(
              color: c.bg,
              child: TabBar(
                controller: _tabCtrl,
                labelColor: c.text,
                unselectedLabelColor: c.textMuted,
                indicatorColor: c.teal,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle:
                    AppType.body(size: 13, weight: FontWeight.w700),
                unselectedLabelStyle:
                    AppType.body(size: 13, weight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  Tab(text: 'Invoices (${regularInvoices.length})'),
                  Tab(text: 'Quotes (${proformas.length})'),
                  Tab(text: 'Receipts (${receipts.length})'),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 1: Invoices ──
                  _InvoicesTab(
                    invoices: regularInvoices,
                    searchQuery: _searchQuery,
                    statusFilter: _statusFilter,
                    searchCtrl: _searchCtrl,
                    isLoading: isLoading,
                    onRefresh: _refreshInvoices,
                    onSearchChanged: (q) => setState(() => _searchQuery = q),
                    onStatusFilter: (f) =>
                        setState(() => _statusFilter = f),
                    onOpenDetail: (inv) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InvoiceDetailScreen(initialInvoice: inv),
                      ),
                    ),
                    onMarkPaid: (inv) => _quickMarkPaid(inv, state),
                    onCopyPayLink: (inv) => _quickCopyPayLink(inv),
                    onCreateNew: _openNewInvoice,
                  ),

                  // ── Tab 2: Quotes ──
                  _QuotesTab(
                    proformas: proformas,
                    isLoading: isLoading,
                    onRefresh: _refreshInvoices,
                    onConvert: (p) => _quickConvertProforma(p, state),
                    onOpenDetail: (p) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InvoiceDetailScreen(initialInvoice: p),
                      ),
                    ),
                  ),

                  // ── Tab 3: Receipts ──
                  _ReceiptsTab(
                    receipts: receipts,
                    rawReceipts: state.receipts,
                    isLoading: state.financialsLoading && receipts.isEmpty,
                    onRefresh: _refreshReceipts,
                    onOpenDetail: (r, raw) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReceiptDetailScreen(receipt: r, rawRow: raw),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom action ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1: INVOICES
// ═══════════════════════════════════════════════════════════════════════════════

class _InvoicesTab extends StatefulWidget {
  final List<Invoice> invoices;
  final String searchQuery;
  final String? statusFilter;
  final TextEditingController searchCtrl;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusFilter;
  final void Function(Invoice) onOpenDetail;
  final void Function(Invoice) onMarkPaid;
  final void Function(Invoice) onCopyPayLink;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreateNew;

  const _InvoicesTab({
    required this.invoices,
    required this.searchQuery,
    required this.statusFilter,
    required this.searchCtrl,
    required this.isLoading,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.onStatusFilter,
    required this.onOpenDetail,
    required this.onMarkPaid,
    required this.onCopyPayLink,
    required this.onCreateNew,
  });

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

enum _StatusGroup { overdue, pending, paid }

class _InvoicesTabState extends State<_InvoicesTab> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<Invoice> get _filtered {
    var list = widget.invoices;
    // Apply status filter
    if (widget.statusFilter != null) {
      list = list.where((i) => i.status == widget.statusFilter).toList();
    }
    // Apply search query
    final q = widget.searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((i) =>
              i.customer.toLowerCase().contains(q) ||
              i.id.toLowerCase().contains(q) ||
              (i.clientEmail?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  Map<_StatusGroup, List<Invoice>> get _groups {
    final out = <_StatusGroup, List<Invoice>>{
      _StatusGroup.overdue: [],
      _StatusGroup.pending: [],
      _StatusGroup.paid: [],
    };
    for (final inv in _filtered) {
      final g = switch (inv.status) {
        'overdue' => _StatusGroup.overdue,
        'paid' => _StatusGroup.paid,
        _ => _StatusGroup.pending,
      };
      out[g]!.add(inv);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = _groups;
    final hasOverdue = groups[_StatusGroup.overdue]!.isNotEmpty;
    final totalOutstanding = _filtered
        .where((i) => i.status != 'paid')
        .fold<int>(0, (s, i) => s + i.amount);
    final hasData = widget.invoices.isNotEmpty;

    if (widget.isLoading && !hasData) {
      return const _LoadingState();
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: c.teal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // ── Search bar ──
          _SearchBar(
            controller: widget.searchCtrl,
            focusNode: _focusNode,
            onChanged: widget.onSearchChanged,
            onCleared: () {
              widget.searchCtrl.clear();
              widget.onSearchChanged('');
              _focusNode.unfocus();
            },
          ),
          const SizedBox(height: 10),

          // ── Status filter chips ──
          _StatusFilterRow(
            current: widget.statusFilter,
            overdueCount: groups[_StatusGroup.overdue]!.length,
            pendingCount: groups[_StatusGroup.pending]!.length,
            paidCount: groups[_StatusGroup.paid]!.length,
            onSelect: widget.onStatusFilter,
          ),
          const SizedBox(height: 16),

          if (!hasData) ...[
            _EmptyState(onCreate: widget.onCreateNew),
          ] else if (_filtered.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text('No invoices match your search.',
                    style: AppType.body(size: 13, color: c.textMuted)),
              ),
            ),
          ] else ...[
            // ── Summary strip ──
            if (widget.searchQuery.isEmpty && widget.statusFilter == null)
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
                          Text(formatGHS(totalOutstanding),
                              style: AppType.heading(
                                  size: 20, color: hasOverdue ? c.rose : c.text)),
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
                              style: AppType.body(
                                  size: 11.5, color: c.textMuted)),
                          const SizedBox(height: 4),
                          Text(widget.invoices.length.toString(),
                              style: AppType.heading(
                                  size: 20, color: c.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.searchQuery.isEmpty && widget.statusFilter == null)
              const SizedBox(height: 16),

            // ── Grouped list ──
            for (final entry in groups.entries)
              if (entry.value.isNotEmpty) ...[
                _GroupHeader(
                  group: entry.key,
                  count: entry.value.length,
                ),
                const SizedBox(height: 8),
                ...entry.value.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FadeInSlide(
                        index: e.key,
                        child: _InvoiceCard(
                          invoice: e.value,
                          onTap: () => widget.onOpenDetail(e.value),
                          onMarkPaid: widget.onMarkPaid,
                          onCopyPayLink: widget.onCopyPayLink,
                        ),
                      ),
                    )),
                const SizedBox(height: 12),
              ],
          ],
        ],
      ),
    );
  }
}

// ── Search bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: c.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: AppType.body(size: 13.5, color: c.text),
              decoration: InputDecoration(
                hintText: 'Search by customer or invoice number',
                hintStyle: AppType.body(size: 13, color: c.textFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onCleared,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.textFaint.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 14, color: c.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Status filter chips ─────────────────────────────────────────────────────

class _StatusFilterRow extends StatelessWidget {
  final String? current;
  final int overdueCount, pendingCount, paidCount;
  final ValueChanged<String?> onSelect;

  const _StatusFilterRow({
    required this.current,
    required this.overdueCount,
    required this.pendingCount,
    required this.paidCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chips = <_FilterChip>[
      _FilterChip(label: 'All', active: current == null, onTap: () => onSelect(null)),
      if (overdueCount > 0)
        _FilterChip(
          label: 'Overdue',
          count: overdueCount,
          active: current == 'overdue',
          color: c.rose,
          onTap: () => onSelect('overdue'),
        ),
      if (pendingCount > 0)
        _FilterChip(
          label: 'Pending',
          count: pendingCount,
          active: current == 'pending',
          color: c.orange,
          onTap: () => onSelect('pending'),
        ),
      if (paidCount > 0)
        _FilterChip(
          label: 'Paid',
          count: paidCount,
          active: current == 'paid',
          color: c.green,
          onTap: () => onSelect('paid'),
        ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map((chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ))
            .toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.count,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (color ?? c.teal).withValues(alpha: 0.12)
              : c.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? (color ?? c.teal).withValues(alpha: 0.4)
                : c.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppType.body(
                    size: 12,
                    weight: FontWeight.w600,
                    color: active ? (color ?? c.teal) : c.textMuted)),
            if (count != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: (color ?? c.teal).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: AppType.body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: active ? (color ?? c.teal) : c.textMuted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Invoice card with quick actions ────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback? onTap;
  final void Function(Invoice)? onMarkPaid;
  final void Function(Invoice)? onCopyPayLink;

  const _InvoiceCard({
    required this.invoice,
    this.onTap,
    this.onMarkPaid,
    this.onCopyPayLink,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (pillTone, pillLabel) = switch (invoice.status) {
      'paid' => (PillTone.green, 'Paid'),
      'overdue' => (PillTone.rose, 'Overdue'),
      'pending' || 'sent' => (PillTone.orange, 'Pending'),
      _ => (PillTone.neutral, 'Draft'),
    };

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

    final isOpen = invoice.status == 'pending' ||
        invoice.status == 'sent' ||
        invoice.status == 'overdue';

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
          Row(
            children: [
              Expanded(
                child: Text(dueSub,
                    style: AppType.body(size: 11.5, color: c.textMuted)),
              ),
              // ── Quick action buttons ──
              if (isOpen) ...[
                if (onMarkPaid != null)
                  _QuickIconBtn(
                    icon: Icons.check_circle_outline,
                    color: c.green,
                    tooltip: 'Mark paid',
                    onTap: () => onMarkPaid!(invoice),
                  ),
                if (invoice.hasPayLink && onCopyPayLink != null) ...[
                  const SizedBox(width: 4),
                  _QuickIconBtn(
                    icon: Icons.link,
                    color: c.teal,
                    tooltip: 'Copy pay link',
                    onTap: () => onCopyPayLink!(invoice),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _QuickIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
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
          width: 8, height: 8,
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

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2: QUOTES (Proformas)
// ═══════════════════════════════════════════════════════════════════════════════

class _QuotesTab extends StatelessWidget {
  final List<Invoice> proformas;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final void Function(Invoice) onConvert;
  final void Function(Invoice) onOpenDetail;

  const _QuotesTab({
    required this.proformas,
    required this.isLoading,
    required this.onRefresh,
    required this.onConvert,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (isLoading && proformas.isEmpty) return const _LoadingState();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: c.teal,
      child: proformas.isEmpty
          ? _QuotesEmptyState()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Summary
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, size: 20, color: c.navy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${proformas.length} quote${proformas.length == 1 ? '' : 's'}',
                                style: AppType.body(
                                    size: 13, weight: FontWeight.w600, color: c.text)),
                            Text('Convert to invoice when the client approves.',
                                style: AppType.body(size: 11.5, color: c.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ...proformas.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FadeInSlide(
                        index: e.key,
                        child: _QuoteCard(
                          invoice: e.value,
                          onTap: () => onOpenDetail(e.value),
                          onConvert: () => onConvert(e.value),
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onConvert;

  const _QuoteCard({
    required this.invoice,
    required this.onTap,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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
                            size: 14, weight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 2),
                    Text(invoice.id,
                        style: AppType.mono(size: 11, color: c.textMuted)),
                  ],
                ),
              ),
              AppPill('Quote', tone: PillTone.neutral, small: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(formatGHS(invoice.amount),
                  style: AppType.heading(size: 18, color: c.text)),
              const Spacer(),
              if (invoice.validUntil != null)
                Text('Valid until ${formatLongDate(invoice.validUntil!)}',
                    style: AppType.body(size: 11, color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          AppBtn(
            'Convert to invoice',
            full: true,
            icon: 'north_east',
            fontSize: 12.5,
            onTap: onConvert,
          ),
        ],
      ),
    );
  }
}

class _QuotesEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: c.navySurface,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.description_outlined, size: 26, color: c.navy),
              ),
              const SizedBox(height: 16),
              Text('No quotes yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Create an invoice as a proforma quote first — your client can review before you convert it to a real invoice.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3: RECEIPTS
// ═══════════════════════════════════════════════════════════════════════════════

class _ReceiptsTab extends StatelessWidget {
  final List<Receipt> receipts;
  final List<Map<String, dynamic>> rawReceipts;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final void Function(Receipt, Map<String, dynamic>) onOpenDetail;

  const _ReceiptsTab({
    required this.receipts,
    required this.rawReceipts,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (isLoading && receipts.isEmpty) return const _LoadingState();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: c.teal,
      child: receipts.isEmpty
          ? _ReceiptsEmptyState()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Summary
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 20, color: c.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'GHS ${receipts.fold<num>(0, (s, r) => s + r.totalAmount).toString().replaceAllMapped(RegExp(r'(\\d)(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]},')} received',
                                style: AppType.body(
                                    size: 13, weight: FontWeight.w600, color: c.text)),
                            Text('${receipts.length} receipt${receipts.length == 1 ? '' : 's'}',
                                style: AppType.body(size: 11.5, color: c.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ...receipts.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FadeInSlide(
                        index: e.key,
                        child: _ReceiptCard(
                          receipt: e.value,
                          rawRow: rawReceipts.firstWhere(
                            (r) => r['id'] == e.value.id,
                            orElse: () => <String, dynamic>{'id': e.value.id},
                          ),
                          onTap: () => onOpenDetail(e.value,
                              rawReceipts.firstWhere(
                                (r) => r['id'] == e.value.id,
                                orElse: () =>
                                    <String, dynamic>{'id': e.value.id},
                              )),
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final Map<String, dynamic> rawRow;
  final VoidCallback onTap;

  const _ReceiptCard({
    required this.receipt,
    required this.rawRow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (IconData icon, Color iconBg, Color iconFg) =
        switch (receipt.paymentMethod) {
      'momo' => (Icons.phone_android_rounded, c.tealSurface, c.tealDeep),
      'bank' => (Icons.account_balance_rounded, c.navySurface, c.navyTint),
      'paystack' => (Icons.credit_card_rounded, c.blueSurface, c.blueDeep),
      _ => (Icons.money_rounded, c.greenSurface, c.greenDeep),
    };

    final typeLabel =
        receipt.isInvoicePayment ? 'Invoice payment' : 'Direct sale';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${receipt.paidDate.day} ${months[receipt.paidDate.month - 1]}';

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(receipt.clientName ?? typeLabel,
                    style: AppType.body(
                        size: 14, weight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(typeLabel,
                        style: AppType.body(size: 11, color: c.textFaint)),
                    const SizedBox(width: 6),
                    Container(
                        width: 3, height: 3,
                        decoration: BoxDecoration(
                            color: c.textFaint, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(receipt.methodLabel,
                        style: AppType.body(size: 11, color: c.textFaint)),
                    const SizedBox(width: 6),
                    Container(
                        width: 3, height: 3,
                        decoration: BoxDecoration(
                            color: c.textFaint, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(dateStr,
                        style: AppType.body(size: 11, color: c.textFaint)),
                  ],
                ),
              ],
            ),
          ),
          Text(formatGHS(receipt.totalAmount),
              style: AppType.body(
                  size: 15, weight: FontWeight.w700, color: c.tealDeep)),
        ],
      ),
    );
  }
}

class _ReceiptsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: c.tealSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_outlined,
                    size: 26, color: c.teal),
              ),
              const SizedBox(height: 16),
              Text('No receipts yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Receipts appear here when you mark an invoice as paid or log a direct sale.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

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
            width: 28, height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(c.teal)),
          ),
          const SizedBox(height: 12),
          Text('Loading…',
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
    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.08),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: c.tealSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.description_outlined, size: 26, color: c.teal),
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

// ── Payment method picker ────────────────────────────────────────────────────

Future<String?> _showPaymentMethodSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.colors;
      const options = [
        ('cash', 'Cash', Icons.money),
        ('momo', 'Mobile Money', Icons.phone_android),
        ('bank', 'Bank transfer', Icons.account_balance),
      ];
      return Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding:
            EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 4),
            Text('How was it paid?',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 6),
            Text('This creates a receipt linked to the invoice.',
                style: AppType.body(size: 12.5, color: c.textMuted)),
            const SizedBox(height: 16),
            for (final (value, label, icon) in options)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, value),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c.navySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: c.navy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label,
                            style: AppType.body(
                                size: 14, weight: FontWeight.w600, color: c.text)),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: c.textFaint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
