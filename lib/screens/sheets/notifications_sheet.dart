import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/mock_data.dart';

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
                Text('Mark all read',
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.teal)),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.62,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, MediaQuery.of(context).padding.bottom + 24),
              itemCount: kActivity.length,
              separatorBuilder: (ctx2, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = kActivity[i];
                final dotColor = switch (item.kind) {
                  'payment' => c.green,
                  'alert'   => c.amber,
                  'booking' => c.teal,
                  _         => c.textMuted,
                };
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                              color: dotColor, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.text,
                            style: AppType.body(size: 13, color: c.text)),
                      ),
                      const SizedBox(width: 8),
                      Text(item.time,
                          style:
                              AppType.body(size: 11.5, color: c.textMuted)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
