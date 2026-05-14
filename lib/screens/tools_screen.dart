import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../core/mock_data.dart';

class ToolsScreen extends StatefulWidget {
  final void Function(String) onTool;
  final VoidCallback onNewInvoice;

  const ToolsScreen({
    super.key,
    required this.onTool,
    required this.onNewInvoice,
  });

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered =
        kTools.where((t) => _filter == 'all' || t.tier == _filter).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text('Tools',
                      style: AppType.display(size: 28, color: c.text)),
                ),
                GestureDetector(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 16, color: c.textFaint),
                        const SizedBox(width: 6),
                        Text('Search',
                            style:
                                AppType.body(size: 13, color: c.textFaint)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final (f, label) in [
                  ('all', 'All tools'),
                  ('free', 'Free'),
                  ('lite', 'Lite'),
                  ('plus', 'Plus'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              _filter == f ? c.teal : c.bgElevated,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color:
                                  _filter == f ? c.teal : c.border),
                        ),
                        child: Text(label,
                            style: AppType.body(
                                size: 12,
                                weight: FontWeight.w600,
                                color: _filter == f
                                    ? Colors.white
                                    : c.textMuted)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tools grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => _ToolCard(
                tool: filtered[i],
                onTap: () => widget.onTool(filtered[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final AppTool tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isTeal = tool.tone == 'teal';
    final iconBg = isTeal ? c.tealSurface : c.orangeSurface;
    final iconFg = isTeal ? c.tealDeep : c.orange;
    final isPlus = tool.tier == 'plus';

    final (tierTone, tierLabel) = switch (tool.tier) {
      'free' => (PillTone.teal, 'Free'),
      'lite' => (PillTone.orange, 'Lite'),
      _      => (PillTone.neutral, 'Plus'),
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11)),
                child: Center(child: AppIcon(tool.icon, size: 18, color: iconFg)),
              ),
              const SizedBox(height: 10),
              Text(tool.name,
                  style: AppType.body(
                      size: 14, weight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 3),
              Expanded(
                child: Text(tool.desc,
                    style: AppType.body(size: 11.5, color: c.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Positioned(
            top: 0, right: 0,
            child: AppPill(tierLabel, tone: tierTone, small: true),
          ),
          if (isPlus)
            Positioned(
              bottom: 0, right: 0,
              child: Icon(Icons.lock_outline, size: 14, color: c.textFaint),
            ),
        ],
      ),
    );
  }
}
