import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';

class ScoreUpOverlay extends StatefulWidget {
  final ScoreUpEvent event;
  final VoidCallback onClose;

  const ScoreUpOverlay({
    super.key,
    required this.event,
    required this.onClose,
  });

  @override
  State<ScoreUpOverlay> createState() => _ScoreUpOverlayState();
}

class _ScoreUpOverlayState extends State<ScoreUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    // Auto-close after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) widget.onClose();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tier = getTier(widget.event.to);
    final tierColor = Color(tier.color);

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: GestureDetector(
                onTap: () {}, // absorb taps on card
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: c.bgElevated,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3000A99D),
                        blurRadius: 60,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Emoji burst
                      const Text('🎉',
                          style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),

                      // Points earned
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.tealSurface,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: c.tealSurfaceStrong),
                        ),
                        child: Text(
                          '+${widget.event.pts} pts',
                          style: AppType.display(
                              size: 32, color: c.tealDeep),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Great work!',
                          style: AppType.heading(size: 22, color: c.text)),
                      const SizedBox(height: 8),

                      // Score progress bar
                      Text(
                        '${widget.event.from} → ${widget.event.to} pts',
                        style: AppType.body(size: 14, color: c.textMuted),
                      ),
                      const SizedBox(height: 12),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          height: 10,
                          child: Stack(
                            children: [
                              // Track
                              Container(color: c.bgInset),
                              // Fill
                              FractionallySizedBox(
                                widthFactor:
                                    widget.event.to / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: tierColor,
                                    borderRadius:
                                        BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Score: ${widget.event.to}/100',
                              style: AppType.body(
                                  size: 12, color: c.textMuted)),
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: tierColor,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(tier.label,
                                  style: AppType.body(
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: c.text)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Dismiss hint
                      Text('Tap anywhere to continue',
                          style: AppType.body(
                              size: 12, color: c.textFaint)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
