import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';
import 'receipt_detail_screen.dart';

/// Full receipts list — pushed from the Tools tab or Finance screen.
/// Groups receipts by month (newest first), shows payment method, amount,
/// client name, and whether it's an invoice payment or direct sale.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  String _methodFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.receipts.isEmpty && !state.financialsLoading) {
        state.loadReceipts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<AppState>().loadReceipts();
  }

  List<Receipt> get _filteredReceipts {
    var result = context.read<AppState>().receiptList;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((r) =>
          (r.clientName?.toLowerCase().contains(q) ?? false) ||
          (r.receiptNumber?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (_methodFilter != 'all') {
      result = result.where((r) => r.paymentMethod == _methodFilter).toList();
    }
    return result;
  }

  Map<String, int> get _methodCounts {
    final counts = <String, int>{};
    for (final r in context.read<AppState>().receiptList) {
      counts[r.paymentMethod] = (counts[r.paymentMethod] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final allReceipts = state.receiptList;
    final filtered = _filteredReceipts;
    final counts = _methodCounts;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Receipts',
              onBack: () => Navigator.pop(context),
            ),
            if (allReceipts.isNotEmpty) ...[
              // ── Payment method filter chips ──
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  children: [
                    _MethodChip(
                      label: 'All',
                      active: _methodFilter == 'all',
                      count: allReceipts.length,
                      onTap: () => setState(() => _methodFilter = 'all'),
                    ),
                    _MethodChip(
                      label: 'Cash',
                      active: _methodFilter == 'cash',
                      count: counts['cash'] ?? 0,
                      onTap: () => setState(() => _methodFilter = 'cash'),
                    ),
                    _MethodChip(
                      label: 'Mobile Money',
                      active: _methodFilter == 'momo',
                      count: counts['momo'] ?? 0,
                      onTap: () => setState(() => _methodFilter = 'momo'),
                    ),
                    _MethodChip(
                      label: 'Bank',
                      active: _methodFilter == 'bank',
                      count: counts['bank'] ?? 0,
                      onTap: () => setState(() => _methodFilter = 'bank'),
                    ),
                    _MethodChip(
                      label: 'Card',
                      active: _methodFilter == 'paystack',
                      count: counts['paystack'] ?? 0,
                      onTap: () => setState(() => _methodFilter = 'paystack'),
                    ),
                  ],
                ),
              ),
              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: AppType.body(size: 13, color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Search by name or receipt…',
                      hintStyle: AppType.body(size: 13, color: c.textFaint),
                      prefixIcon: Icon(Icons.search, size: 16, color: c.textFaint),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(Icons.close, size: 16, color: c.textMuted),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: c.teal,
                child: allReceipts.isEmpty
                    ? _EmptyState()
                    : filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off, size: 36, color: c.textFaint),
                                    const SizedBox(height: 8),
                                    Text('No receipts match',
                                        style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text)),
                                    const SizedBox(height: 4),
                                    Text('Try a different filter or search.',
                                        style: AppType.body(size: 12, color: c.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : _ListBody(
                            receipts: filtered,
                            allRawReceipts: state.receipts,
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Group receipts by year-month for a clean chronological list.
Map<String, List<Receipt>> _groupByMonth(List<Receipt> receipts) {
  final map = <String, List<Receipt>>{};
  for (final r in receipts) {
    final key = '${r.paidDate.year}-${r.paidDate.month.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => []).add(r);
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

// ── List body ──────────────────────────────────────────────────────────────

class _ListBody extends StatelessWidget {
  final List<Receipt> receipts;
  final List<Map<String, dynamic>> allRawReceipts;

  const _ListBody({required this.receipts, required this.allRawReceipts});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = _groupByMonth(receipts);
    // Sort keys descending (newest month first)
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    // Summary bar
    final totalReceived = receipts.fold<num>(0, (s, r) => s + r.totalAmount);

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
                    Text('Total received',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(formatGHS(totalReceived),
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
                    Text('Receipts',
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(receipts.length.toString(),
                        style: AppType.heading(size: 20, color: c.text)),
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
                    color: c.teal,
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
                  child: _ReceiptCard(
                    receipt: e.value,
                    rawRow: allRawReceipts.firstWhere(
                      (r) => r['id'] == e.value.id,
                      orElse: () => <String, dynamic>{'id': e.value.id},
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

// ── Receipt card ───────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final Map<String, dynamic> rawRow;

  const _ReceiptCard({required this.receipt, required this.rawRow});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Icon & color based on payment method
    final (IconData icon, Color iconBg, Color iconFg) =
        switch (receipt.paymentMethod) {
      'momo' => (Icons.phone_android_rounded, c.tealSurface, c.tealDeep),
      'bank' => (Icons.account_balance_rounded, c.navySurface, c.navyTint),
      'paystack' => (Icons.credit_card_rounded, c.blueSurface, c.blueDeep),
      _ => (Icons.money_rounded, c.greenSurface, c.greenDeep),
    };

    // Label showing whether this is an invoice payment or direct sale
    final typeLabel = receipt.isInvoicePayment ? 'Invoice payment' : 'Direct sale';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${receipt.paidDate.day} ${months[receipt.paidDate.month - 1]}';

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptDetailScreen(
            receipt: receipt,
            rawRow: rawRow,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
                Text(
                  receipt.clientName ?? typeLabel,
                  style: AppType.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: c.text),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(typeLabel,
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
                    Text(receipt.methodLabel,
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
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatGHS(receipt.totalAmount),
                  style: AppType.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: c.tealDeep)),
              if (receipt.receiptNumber != null) ...[
                const SizedBox(height: 4),
                Text(receipt.receiptNumber!,
                    style: AppType.mono(size: 10, color: c.textFaint)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Method filter chip ──────────────────────────────────────────────────────

class _MethodChip extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? c.navy : c.bgInset,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? c.navy : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                switch (label) {
                  'Cash'        => Icons.money_rounded,
                  'Mobile Money' => Icons.phone_android_rounded,
                  'Bank'        => Icons.account_balance_rounded,
                  'Card'        => Icons.credit_card_rounded,
                  _             => Icons.receipt_long_outlined,
                },
                size: 12,
                color: active ? Colors.white : c.textMuted,
              ),
              const SizedBox(width: 4),
              Text(label,
                  style: AppType.body(size: 11.5, weight: FontWeight.w600,
                      color: active ? Colors.white : c.textMuted)),
              if (count > 0) ...[
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withValues(alpha: 0.2) : c.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$count',
                      style: AppType.label(size: 8.5, color: active ? Colors.white : c.textFaint)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
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
                  'Receipts appear here when you mark an invoice as paid or log a direct sale. Every receipt builds your financial track record.',
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
