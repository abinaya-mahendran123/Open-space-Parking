import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/layout/responsive_page.dart';
import 'package:open_space_parking/core/widgets/loading/app_shimmer.dart';

class AppSkeleton {
  AppSkeleton._();

  static Widget statGrid(BuildContext context, {int count = 4}) {
    final crossAxisCount = responsiveGridCount(context);
    return AppShimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.5,
        ),
        itemCount: count,
        itemBuilder: (_, __) => const _SkeletonStatCard(),
      ),
    );
  }

  static Widget listTiles({int count = 5}) {
    return AppShimmer(
      child: Column(
        children: List.generate(
          count,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: const _SkeletonListTile(),
          ),
        ),
      ),
    );
  }

  static Widget actionCards({int count = 3}) {
    return AppShimmer(
      child: Column(
        children: List.generate(
          count,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: const _SkeletonActionCard(),
          ),
        ),
      ),
    );
  }

  static Widget parkingCards({int count = 3}) {
    return AppShimmer(
      child: Column(
        children: List.generate(
          count,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: const _SkeletonParkingCard(),
          ),
        ),
      ),
    );
  }
}

class _SkeletonStatCard extends StatelessWidget {
  const _SkeletonStatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(width: 40, height: 40, borderRadius: 20),
          Spacer(),
          AppShimmerBox(width: 48, height: 28),
          SizedBox(height: 8),
          AppShimmerBox(width: 80, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonListTile extends StatelessWidget {
  const _SkeletonListTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          AppShimmerBox(width: 44, height: 44, borderRadius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(width: double.infinity, height: 16),
                SizedBox(height: 8),
                AppShimmerBox(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonActionCard extends StatelessWidget {
  const _SkeletonActionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          AppShimmerBox(width: 56, height: 56, borderRadius: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppShimmerBox(width: 160, height: 16),
                SizedBox(height: 8),
                AppShimmerBox(width: double.infinity, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonParkingCard extends StatelessWidget {
  const _SkeletonParkingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(width: double.infinity, height: 140, borderRadius: 16),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(width: 140, height: 18),
                SizedBox(height: 8),
                AppShimmerBox(width: 200, height: 14),
                SizedBox(height: 12),
                AppShimmerBox(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
