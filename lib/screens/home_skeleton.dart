import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/tokens.dart';

/// Shimmer-animated placeholder shown while the signed-in user's business
/// profile is loading from Supabase. Prevents the ~500ms flash of mock
/// "Akwaaba Threads" data on first sign-in.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Header: avatar + name lines + bell
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _Skel(width: 40, height: 40, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Skel(width: 140, height: 13),
                      SizedBox(height: 6),
                      _Skel(width: 100, height: 11),
                    ],
                  ),
                ),
                const _Skel(width: 36, height: 36, radius: 18),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Layout switcher pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Skel(width: double.infinity, height: 32, radius: 16),
          ),

          const SizedBox(height: 28),

          // Sustainability dial
          Center(
            child: _Skel(width: 200, height: 200, radius: 100),
          ),

          const SizedBox(height: 32),

          // Quick actions row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                    child: _Skel(
                        width: double.infinity, height: 86, radius: 14),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Recommendation cards
          ...List.generate(
            2,
            (_) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _Skel(width: double.infinity, height: 96, radius: 16),
            ),
          ),

          const SizedBox(height: 12),

          // Quests
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                _Skel(width: double.infinity, height: 140, radius: 16),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1400),
          color: c.bgElevated.withValues(alpha: 0.55),
        );
  }
}

class _Skel extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Skel({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
