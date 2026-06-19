import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/activity.dart';
import '../../core/notifications.dart' as notif;
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/app_state.dart';

/// Notifications sheet — real notifications derived from AppState data.
/// Shows expiring quotes, overdue invoices, recent payments, and low-stock
/// alerts grouped by time period (Today / This week / Earlier).
class NotificationsSheet extends StatefulWidget {
  final void Function(String action)? onAction;

  const NotificationsSheet({super.key, this.onAction});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  @override
  void initState() {
    super.initState();
    // Mark notifications as seen when the sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().markNotificationsSeen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final items = notif.buildNotifications(
      invoices: state.invoices,
      receipts: state.receipts,
      inventory: state.inventory,
      sinceEpochMs: state.lastSeenNotificationEpochMs,
      showExpiringQuotes: state.notifyExpiringQuotes,
      showOverdueInvoices: state.notifyOverdueInvoices,
      showRecentPayments: state.notifyPaymentReceived,
      showLowStock: state.notifyLowStock,
    );

    // Group by time period
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));

    final today = <notif.NotificationItem>[];
    final thisWeek = <notif.NotificationItem>[];
    final earlier = <notif.NotificationItem>[];

    for (final item in items) {
      if (!item.time.isBefore(todayStart)) {
        today.add(item);
      } else if (!item.time.isBefore(weekStart)) {
        thisWeek.add(item);
      } else {
        earlier.add(item);
      }
    }

    final hasAny = today.isNotEmpty || thisWeek.isNotEmpty || earlier.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Notifications',
                      style: AppType.heading(size: 20, color: c.text)),
                ),
                if (hasAny)
                  GestureDetector(
                    onTap: () => state.markNotificationsSeen(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Mark all read',
                          style: AppType.body(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: c.tealDeep)),
                    ),
                  ),
              ],
            ),
          ),
          // ── Divider ──
          Divider(height: 1, thickness: 0.5, color: c.border),
          // ── List ──
          if (!hasAny)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 48, 20, MediaQuery.of(context).padding.bottom + 32),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none,
                        size: 30, color: c.textFaint),
                  ),
                  const SizedBox(height: 16),
                  Text("You're all caught up",
                      style: AppType.heading(size: 17, color: c.text)),
                  const SizedBox(height: 6),
                  Text(
                    'Expiring proformas, overdue invoices, and payments will appear here.',
                    textAlign: TextAlign.center,
                    style: AppType.body(size: 13, color: c.textMuted),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    0, 4, 0, MediaQuery.of(context).padding.bottom + 32),
                children: [
                  if (today.isNotEmpty) ..._section(context, 'Today', today, c),
                  if (thisWeek.isNotEmpty)
                    ..._section(context, 'This week', thisWeek, c),
                  if (earlier.isNotEmpty)
                    ..._section(context, 'Earlier', earlier, c),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _section(
      BuildContext ctx, String label, List<notif.NotificationItem> items, AppColorsX c) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(label,
            style: AppType.body(
                size: 12,
                weight: FontWeight.w700,
                color: c.textMuted)),
      ),
      ...items.map((item) => _NotificationRow(
            item: item,
            onAction: () {
              if (widget.onAction != null && item.ctaAction != null) {
                widget.onAction!(item.ctaAction!);
              }
            },
            c: c,
          )),
    ];
  }
}

// ── Notification row — cleaner, lighter, no card nesting ─────────────────────

class _NotificationRow extends StatelessWidget {
  final notif.NotificationItem item;
  final VoidCallback onAction;
  final AppColorsX c;

  const _NotificationRow({
    required this.item,
    required this.onAction,
    required this.c,
  });

  (IconData, Color, Color) get _iconStyle {
    return switch (item.type) {
      'expiring_quote' => (
        Icons.schedule,
        c.amber.withValues(alpha: 0.12),
        c.amber,
      ),
      'overdue_invoice' => (
        Icons.warning_amber_rounded,
        c.rose.withValues(alpha: 0.12),
        c.rose,
      ),
      'payment_received' => (
        Icons.payments,
        c.greenSurface,
        c.green,
      ),
      'low_stock' => (
        Icons.inventory_2,
        c.orangeSurface,
        c.orange,
      ),
      _ => (
        Icons.circle_notifications,
        c.bgInset,
        c.textMuted,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _iconStyle;
    final hasCta = item.ctaLabel != null && item.ctaAction != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: InkWell(
        onTap: hasCta ? onAction : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.border, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(item.title,
                              style: AppType.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: c.text)),
                        ),
                        const SizedBox(width: 6),
                        Text(formatRelativeTime(item.time),
                            style: AppType.body(
                                size: 10.5, color: c.textFaint)),
                      ],
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(item.subtitle!,
                          style: AppType.body(size: 11.5, color: c.textMuted)),
                    ],
                    if (hasCta) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: fg.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(item.ctaLabel!,
                              style: AppType.body(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: fg)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
