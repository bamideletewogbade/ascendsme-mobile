import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';

/// Shimmer-animated placeholder shown while the signed-in user's business
/// profile is loading from Supabase. Prevents the ~500ms flash of mock
/// "Akwaaba Threads" data on first sign-in.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Header: avatar + name lines + bell
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                AppShimmer(width: 40, height: 40, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(width: 140, height: 13),
                      const SizedBox(height: 6),
                      AppShimmer(width: 100, height: 11),
                    ],
                  ),
                ),
                AppShimmer(width: 36, height: 36, radius: 18),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Layout switcher pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppShimmer(width: double.infinity, height: 32, radius: 16),
          ),

          const SizedBox(height: 28),

          // Sustainability dial
          Center(
            child: AppShimmer(width: 200, height: 200, radius: 100),
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
                    child: AppShimmer(
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
              child: AppShimmer(width: double.infinity, height: 96, radius: 16),
            ),
          ),

          const SizedBox(height: 12),

          // Quests
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                AppShimmer(width: double.infinity, height: 140, radius: 16),
          ),
        ],
      ),
    );
  }
}
