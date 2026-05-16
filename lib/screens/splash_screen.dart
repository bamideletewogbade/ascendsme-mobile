import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/tokens.dart';

// Static splash — no AnimationController needed. All content is visible in
// frame 1 so the branding shows even if the main thread is busy with Supabase
// init (which can take 10-17 s on a cold start / slow emulator).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.bg,
              Color.lerp(c.bg, c.teal, 0.06)!,
              c.bg,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Logo + wordmark ─────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    _SplashMonogram(),
                    const SizedBox(height: 20),
                    Text(
                      'AscendSME',
                      style: GoogleFonts.outfit(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Tagline ─────────────────────────────────────────────────
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.tealSurface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.tealSurfaceStrong),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇬🇭', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'Built for Ghana SMEs',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.tealDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Grow. Verify. Unlock capital.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 4),

              // ── Loading indicator ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(c.teal),
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

class _SplashMonogram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.teal, c.tealDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: c.teal.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'AS',
        style: GoogleFonts.outfit(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -1,
        ),
      ),
    );
  }
}
