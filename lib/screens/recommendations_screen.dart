import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';

/// Full list of recommendations — pushed from Home when the user taps
/// "View all" in the Top actions section. Recs are computed by
/// [buildRecommendations] on the home screen and passed in, so this screen
/// stays presentational.
class RecommendationsScreen extends StatelessWidget {
  final List<Recommendation> recs;
  final void Function(String actionId) onAction;

  const RecommendationsScreen({
    super.key,
    required this.recs,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Top actions',
                onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: recs
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _Card(rec: r, onAction: (id) {
                            // Run the parent's action handler, then pop back
                            // so the action surface (e.g. invoice sheet) lands
                            // over the Home tab rather than over this list.
                            Navigator.pop(context);
                            onAction(id);
                          }),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Recommendation rec;
  final void Function(String) onAction;

  const _Card({required this.rec, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (tone, dotColor) = switch (rec.priority) {
      'urgent' => (PillTone.rose, c.rose),
      'high' => (PillTone.orange, c.orange),
      'medium' => (PillTone.amber, c.amber),
      _ =>      (PillTone.neutral, c.navy),
    };
    final priorityLabel =
        rec.priority[0].toUpperCase() + rec.priority.substring(1);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              AppPill(priorityLabel, tone: tone, small: true),
              const Spacer(),
              Text('${rec.minutes} min',
                  style: AppType.body(size: 11.5, color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(rec.title,
              style: AppType.body(
                  size: 14, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 6),
          Text(rec.why,
              style: AppType.body(size: 12.5, color: c.textMuted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppBtn(rec.cta,
                    variant: BtnVariant.secondary,
                    fontSize: 12.5,
                    onTap: () => onAction(rec.id)),
              ),
              const SizedBox(width: 8),
              AppPill(rec.impact, tone: PillTone.green, small: true),
            ],
          ),
        ],
      ),
    );
  }
}
