import 'package:flutter/material.dart';
import '../core/tokens.dart';

/// Animated brand reveal — staggered entrance for monogram, wordmark, tagline,
/// and loading indicator. Each element fades + slides in sequentially using
/// AnimationController, so the screen feels alive even when Supabase init
/// blocks the main thread for 10-17 s on cold start.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _monoAnim;
  late final Animation<double> _wordAnim;
  late final Animation<double> _tagAnim;
  late final Animation<double> _loadAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _monoAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
    );
    _wordAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOutCubic),
    );
    _tagAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
    _loadAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.3, -0.3),
            radius: 1.8,
            colors: [
              c.navySurface.withValues(alpha: 0.4),
              c.bg,
              c.bg,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Logo monogram ─────────────────────────
              Center(
                child: FadeTransition(
                  opacity: _monoAnim,
                  child: ScaleTransition(
                    scale: _monoAnim,
                    child: _SplashMonogram(c: c),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Wordmark ───────────────────────────────
              FadeTransition(
                opacity: _wordAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 16),
                    end: Offset.zero,
                  ).animate(_wordAnim),
                  child: Text(
                    'AscendSME',
                    style: AppType.display(
                      size: 34,
                      color: c.text,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Tagline + badge ─────────────────────────
              FadeTransition(
                opacity: _tagAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 12),
                    end: Offset.zero,
                  ).animate(_tagAnim),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.navySurface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: c.navySurfaceStrong),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇬🇭', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              'Built for Ghana SMEs',
                              style: AppType.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: c.navyDeep),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Grow. Verify. Unlock capital.',
                        style: AppType.body(size: 13, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 4),

              // ── Loading indicator ─────────────────────
              FadeTransition(
                opacity: _loadAnim,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      _PulsingLoader(c: c),
                      const SizedBox(height: 12),
                      Text(
                        'Preparing your business…',
                        style: AppType.body(size: 11.5, color: c.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashMonogram extends StatefulWidget {
  final AppColorsX c;
  const _SplashMonogram({required this.c});

  @override
  State<_SplashMonogram> createState() => _SplashMonogramState();
}

class _SplashMonogramState extends State<_SplashMonogram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, _) => Transform.scale(
        scale: _pulseAnim.value,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.c.navy, widget.c.navyDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: widget.c.navy.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'AS',
            style: AppType.display(size: 38, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Subtle pulsing dots — more engaging than a plain spinner.
class _PulsingLoader extends StatefulWidget {
  final AppColorsX c;
  const _PulsingLoader({required this.c});

  @override
  State<_PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<_PulsingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.15;
          final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
          final scale = 0.5 + 0.5 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: scale,                child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: widget.c.teal,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
