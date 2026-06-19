import 'models.dart';

/// A derived notification — computed client-side from AppState data.
class NotificationItem {
  final String id;
  final String title;
  final String? subtitle;
  final String type; // 'expiring_quote' | 'overdue_invoice' | 'payment_received' | 'low_stock'
  final String? ctaLabel;
  final String? ctaAction;
  final DateTime time;
  final String? icon;

  const NotificationItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.ctaLabel,
    this.ctaAction,
    required this.time,
    this.icon,
  });

  /// Unique stable key for dedup across builds.
  String get dedupKey => '$type-$id';
}

/// Build notifications from real AppState data. No network calls — derived
/// client-side from already-loaded invoices, receipts, and inventory.
///
/// [showExpiringQuotes], [showOverdueInvoices], [showRecentPayments],
/// [showLowStock] control which notification types are included — these
/// map to the user's notification preferences in Settings.
List<NotificationItem> buildNotifications({
  required List<Invoice> invoices,
  required List<Map<String, dynamic>> receipts,
  required List<InventoryItem> inventory,
  int? sinceEpochMs,
  bool showExpiringQuotes = true,
  bool showOverdueInvoices = true,
  bool showRecentPayments = true,
  bool showLowStock = true,
}) {
  final now = DateTime.now();
  final out = <NotificationItem>[];
  final seenTime = sinceEpochMs != null
      ? DateTime.fromMillisecondsSinceEpoch(sinceEpochMs)
      : null;

  // ── Expiring quotes (validUntil ≤ 3 days away) ────────────────────────
  if (showExpiringQuotes) {
  for (final inv in invoices) {
    if (!inv.isProforma) continue;
    if (inv.validUntil == null) continue;
    if (inv.validUntil!.isBefore(now)) continue; // already expired
    final daysLeft = inv.validUntil!.difference(now).inDays;
    if (daysLeft > 3) continue;

    final isNew = seenTime == null || inv.validUntil!.isAfter(seenTime);
    if (!isNew) continue;

    out.add(NotificationItem(
      id: inv.backendId ?? inv.id,          title: daysLeft == 0
          ? 'Proforma for ${inv.customer} expires today'
          : 'Proforma for ${inv.customer} expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
      subtitle: '${formatGHS(inv.amount)} · ${formatLongDate(inv.validUntil!)}',
      type: 'expiring_quote',
      ctaLabel: 'View proforma',
      ctaAction: 'invoicing',
      time: inv.validUntil!,
      icon: 'schedule',
    ));
  }}

  // ── Overdue invoices (past due ≥ 7 days) ──────────────────────────────
  if (showOverdueInvoices) {
  for (final inv in invoices) {
    if (inv.status != 'overdue') continue;
    if (inv.days < 7) continue; // only surface long-overdue

    final isNew = seenTime == null ||
        (inv.dueDate != null && inv.dueDate!.isAfter(seenTime));
    if (!isNew) continue;

    out.add(NotificationItem(
      id: inv.backendId ?? inv.id,
      title: '${inv.customer} overdue by ${inv.days}d',
      subtitle: '${formatGHS(inv.amount)} · was due ${inv.due}',
      type: 'overdue_invoice',
      ctaLabel: 'Follow up',
      ctaAction: 'followup',
      time: inv.dueDate ?? inv.createdAt ?? now,
      icon: 'schedule',
    ));
  }}

  // ── Recent payments (last 24h) ────────────────────────────────────────
  if (showRecentPayments) {
  final yesterday = now.subtract(const Duration(hours: 24));
  for (final r in receipts) {
    final paidStr = r['paid_date'] as String?;
    if (paidStr == null) continue;
    final paid = DateTime.tryParse(paidStr);
    if (paid == null || paid.isBefore(yesterday)) continue;

    final isNew = seenTime == null || paid.isAfter(seenTime);
    if (!isNew) continue;

    final amount = (r['total_amount'] as num?) ?? 0;
    final customer = (r['client_name'] as String?)?.trim();
    out.add(NotificationItem(
      id: r['id'] as String,
      title: customer != null && customer.isNotEmpty
          ? 'Payment of ${formatGHS(amount)} from $customer'
          : 'Payment of ${formatGHS(amount)} received',
      subtitle: 'via ${(r['payment_method'] as String?) ?? 'cash'}',
      type: 'payment_received',
      ctaLabel: 'View',
      ctaAction: 'invoicing',
      time: paid,
      icon: 'payments',
    ));
  }}

  // ── Low stock alerts ──────────────────────────────────────────────────
  if (showLowStock) {
  for (final item in inventory) {
    if (!item.lowStock) continue;

    out.add(NotificationItem(
      id: item.id,
      title: 'Low stock: ${item.name}',
      subtitle: '${item.currentStock} remaining${item.lowStockThreshold != null ? ' (threshold: ${item.lowStockThreshold})' : ''}',
      type: 'low_stock',
      ctaLabel: 'Restock',
      ctaAction: 'inventory',
      time: now,
      icon: 'inventory_2',
    ));
  }}

  // Sort newest-first
  out.sort((a, b) => b.time.compareTo(a.time));
  return out;
}
