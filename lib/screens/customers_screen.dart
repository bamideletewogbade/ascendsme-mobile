import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'customer_detail_screen.dart';

/// Customers tab — derived from invoices for now (group by client_name).
/// A real `customers` table + dedicated CRM lands in Phase 3; this v0.1
/// surface lets the user see who they bill, how much is outstanding per
/// customer, and tap to drill into history.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  void _showAddStub(BuildContext context) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Adding customers — coming soon.',
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final customers = _deriveCustomers(state.invoices);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Customers',
                      style: AppType.display(size: 28, color: c.text)),
                ),
                GestureDetector(
                  onTap: () => _showAddStub(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.teal,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Add',
                            style: AppType.body(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Summary chip
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Text(
              customers.isEmpty
                  ? 'No customers yet'
                  : '${customers.length} ${customers.length == 1 ? "customer" : "customers"} · derived from your invoices',
              style: AppType.body(size: 12.5, color: c.textMuted),
            ),
          ),

          if (customers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 36, color: c.textFaint),
                    const SizedBox(height: 12),
                    Text('Your customers will appear here',
                        textAlign: TextAlign.center,
                        style: AppType.heading(size: 15, color: c.text)),
                    const SizedBox(height: 4),
                    Text(
                      'Once you send an invoice, the customer shows up in this list with their outstanding balance and payment history.',
                      textAlign: TextAlign.center,
                      style: AppType.body(size: 12.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...customers.map((cust) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Builder(
                    builder: (rowContext) => _CustomerRow(
                      customer: cust,
                      onTap: () => Navigator.push(
                        rowContext,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailScreen(customerName: cust.name),
                        ),
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  static List<_DerivedCustomer> _deriveCustomers(List<Invoice> invoices) {
    final byName = <String, _DerivedCustomer>{};
    for (final inv in invoices) {
      final key = inv.customer.trim();
      if (key.isEmpty) continue;
      final entry = byName.putIfAbsent(
        key,
        () => _DerivedCustomer(name: key, total: 0, outstanding: 0, count: 0),
      );
      entry.count += 1;
      entry.total += inv.amount.toDouble();
      if (inv.status != 'paid' && inv.status != 'void') {
        entry.outstanding += inv.amount.toDouble();
      }
    }
    final list = byName.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }
}

class _DerivedCustomer {
  final String name;
  double total;
  double outstanding;
  int count;

  _DerivedCustomer({
    required this.name,
    required this.total,
    required this.outstanding,
    required this.count,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _CustomerRow extends StatelessWidget {
  final _DerivedCustomer customer;
  final VoidCallback onTap;

  const _CustomerRow({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasOutstanding = customer.outstanding > 0;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AppAvatar(customer.initials, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: AppType.body(
                        size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 2),
                Text(
                  '${customer.count} ${customer.count == 1 ? "invoice" : "invoices"} · GHS ${customer.total.round()}',
                  style: AppType.body(size: 11.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          if (hasOutstanding)
            AppPill('GHS ${customer.outstanding.round()} due',
                tone: PillTone.rose, small: true),
        ],
      ),
    );
  }
}
