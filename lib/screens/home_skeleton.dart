import 'package:flutter/material.dart';
import '../core/widgets/common.dart';

/// Shimmer-animated placeholder shown while the signed-in user's business
/// profile is loading from Supabase. Prevents the ~500ms flash of mock
/// "Akwaaba Threads" data on first sign-in.
///
/// Mirrors the actual [HomeScreen] layout structure exactly so the transition
/// from skeleton → content feels seamless with no layout shift.
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
          // Header: avatar + greeting lines + notification bell
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppShimmer(width: 42, height: 42, radius: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(width: 140, height: 14),
                      const SizedBox(height: 7),
                      AppShimmer(width: 110, height: 12),
                    ],
                  ),
                ),
                AppShimmer(width: 38, height: 38, radius: 19),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Cash flow hero card (navy gradient rectangle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppShimmer(
                width: double.infinity, height: 200, radius: 24),
          ),

          const SizedBox(height: 22),

          // Daily Brief AI card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                AppShimmer(width: double.infinity, height: 120, radius: 16),
          ),

          const SizedBox(height: 22),

          // Quick actions row (4 tiles)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmer(width: 100, height: 14),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        child: AppShimmer(
                            width: double.infinity, height: 78, radius: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Top actions header + recommendation cards (3)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                AppShimmer(width: 100, height: 14),
                const Spacer(),
                AppShimmer(width: 50, height: 12),
              ],
            ),
          ),
          ...List.generate(
            2,
            (_) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: AppShimmer(
                  width: double.infinity, height: 130, radius: 16),
            ),
          ),

          const SizedBox(height: 22),

          // Recent activity section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                AppShimmer(width: 100, height: 14),
                const Spacer(),
                AppShimmer(width: 50, height: 12),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                AppShimmer(width: double.infinity, height: 80, radius: 16),
          ),
        ],
      ),
    );
  }
}
