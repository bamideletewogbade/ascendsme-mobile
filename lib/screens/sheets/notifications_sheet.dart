import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';

/// Notifications sheet. v0.1 is an empty state — we don't yet have real
/// notification data wired up (no `notifications` table reads, no push
/// integration). Phase 4+ will derive notifications from real events:
/// new payments, overdue invoices, funding opportunities, GRA filing
/// reminders.
class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('Notifications',
                      style: AppType.heading(size: 20, color: c.text)),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.of(context).padding.bottom + 32),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_none,
                      size: 36, color: c.textFaint),
                ),
                const SizedBox(height: 16),
                Text(
                  "You're all caught up",
                  style: AppType.heading(size: 17, color: c.text),
                ),
                const SizedBox(height: 6),
                Text(
                  'Payments, overdue invoices, and funding updates will show up here as they happen.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
