import 'models.dart';

/// A single business event surfaced in the home Activity Feed. Derived from
/// real Supabase data — invoices, receipts, expenses — never mocked.
class ActivityEvent {
  final ActivityKind kind;
  final String title;
  final String? subtitle;
  final DateTime time;
  final num? amount;
  /// Backend UUID of the related invoice, if any (invoiceSent / invoicePaid).
  final String? invoiceId;
  /// Backend UUID of the related receipt, if any (saleLogged).
  final String? receiptId;
  /// Backend UUID of the related expense, if any (expenseLogged).
  final String? expenseId;

  const ActivityEvent({
    required this.kind,
    required this.title,
    required this.time,
    this.subtitle,
    this.amount,
    this.invoiceId,
    this.receiptId,
    this.expenseId,
  });
}

enum ActivityKind { invoiceSent, invoicePaid, saleLogged, expenseLogged }

/// Build a unified, time-sorted activity feed from the three source streams.
///
/// Dedup rule: when a receipt has `invoice_id` set, it represents the payment
/// of an invoice we already surface as `invoicePaid`. We skip that receipt
/// so the same event doesn't appear twice. Receipts with `invoice_id == null`
/// are direct sales (Quick Sale) and get their own `saleLogged` entry.
List<ActivityEvent> buildActivityFeed({
  required List<Invoice> invoices,
  required List<Map<String, dynamic>> receipts,
  required List<Map<String, dynamic>> expenses,
  int limit = 8,
}) {
  final events = <ActivityEvent>[];

  // ── Invoices ────────────────────────────────────────────────────────────
  for (final inv in invoices) {
    if (inv.status == 'void') continue;
    final t = inv.createdAt;
    if (t == null) continue;

    if (inv.status == 'paid') {
      events.add(ActivityEvent(
        kind: ActivityKind.invoicePaid,
        title: '${inv.customer} paid ${inv.id}',
        subtitle: null,
        time: t,
        amount: inv.amount,
        invoiceId: inv.backendId,
      ));
    } else {
      // pending / sent / overdue → "invoice sent" event
      events.add(ActivityEvent(
        kind: ActivityKind.invoiceSent,
        title: 'Invoice ${inv.id} sent to ${inv.customer}',
        subtitle: inv.status == 'overdue' ? 'Overdue' : null,
        time: t,
        amount: inv.amount,
        invoiceId: inv.backendId,
      ));
    }
  }

  // ── Receipts (direct sales only — invoice-paid receipts are dedup'd) ────
  for (final r in receipts) {
    final invoiceId = r['invoice_id'];
    if (invoiceId != null) continue; // Already surfaced as invoicePaid above.

    final paidIso = r['paid_date'] as String?;
    final t = paidIso != null ? DateTime.tryParse(paidIso) : null;
    if (t == null) continue;

    final amount = (r['total_amount'] as num?) ?? 0;
    final method = (r['payment_method'] as String?) ?? 'cash';
    final customer = (r['client_name'] as String?)?.trim();
    final methodLabel = switch (method) {
      'momo' => 'MoMo',
      'bank' => 'Bank',
      _ => 'Cash',
    };

    events.add(ActivityEvent(
      kind: ActivityKind.saleLogged,
      title: customer != null && customer.isNotEmpty
          ? 'Sale to $customer · $methodLabel'
          : '$methodLabel sale logged',
      subtitle: null,
      time: t,
      amount: amount,
      receiptId: r['id'] as String?,
    ));
  }

  // ── Expenses ────────────────────────────────────────────────────────────
  for (final e in expenses) {
    final dateStr = e['expense_date'] as String?;
    final t = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (t == null) continue;

    final amount = (e['amount_ghs'] as num?) ?? 0;
    final desc = (e['description'] as String?)?.trim();

    events.add(ActivityEvent(
      kind: ActivityKind.expenseLogged,
      title: desc != null && desc.isNotEmpty
          ? 'Expense · $desc'
          : 'Expense logged',
      subtitle: null,
      time: t,
      amount: amount,
      expenseId: e['id'] as String?,
    ));
  }

  // Sort newest-first, truncate to limit.
  events.sort((a, b) => b.time.compareTo(a.time));
  if (events.length > limit) {
    return events.sublist(0, limit);
  }
  return events;
}

/// "3m" / "2h" / "yesterday" / "May 12". Compact relative-time formatting.
String formatRelativeTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);

  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[t.month - 1]} ${t.day}';
}
