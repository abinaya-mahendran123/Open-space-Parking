import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/admin/domain/entities/admin_statistics.dart';
import 'package:open_space_parking/features/admin/presentation/providers/admin_providers.dart';

class AdminStatisticsPage extends ConsumerWidget {
  const AdminStatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatisticsProvider);

    return statsAsync.when(
      loading: () => const AppLoadingWidget(message: 'Loading statistics...'),
      error: (_, __) => AppErrorWidget(
        message: 'Failed to load statistics',
        onRetry: () => ref.invalidate(adminStatisticsProvider),
      ),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminStatisticsProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.isDesktop ? 1000 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistics & Charts',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceOf(context),
                          ),
                    ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Ticket Status Distribution',
                      child: SizedBox(
                        height: 260,
                        child: _StatusPieChart(stats: stats),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Request Type Breakdown',
                      child: SizedBox(
                        height: 300,
                        child: _HoverBarChart(
                          labels: const ['Build', 'Existing'],
                          values: [
                            stats.buildParkingCount,
                            stats.existingParkingCount,
                          ],
                          colors: [
                            AppColors.primaryOf(context),
                            AppColors.info(Theme.of(context).brightness),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Operational Snapshot',
                      child: SizedBox(
                        height: 300,
                        child: _HoverBarChart(
                          labels: const [
                            'Employees',
                            'Unassigned',
                            'Docs Pending',
                          ],
                          values: [
                            stats.activeEmployees,
                            stats.unassignedTickets,
                            stats.documentsPendingVerification,
                          ],
                          colors: [
                            Theme.of(context).colorScheme.onSurfaceVariant,
                            AppColors.primaryOf(context),
                            AppColors.info(Theme.of(context).brightness),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceOf(context),
                  ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  const _StatusPieChart({required this.stats});

  final AdminStatistics stats;

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[
      _section(stats.submittedCount, AppColors.primary),
      _section(stats.underReviewCount, AppColors.limited),
      _section(stats.approvedCount, AppColors.available),
      _section(stats.rejectedCount, AppColors.full),
      _section(stats.inProgressCount, AppColors.primaryOf(context)),
      _section(stats.completedCount, AppColors.info(Theme.of(context).brightness)),
    ].where((s) => s.value > 0).toList();

    if (sections.isEmpty) {
      return Center(
        child: Text(
          'No ticket data yet.',
          style: TextStyle(color: AppColors.onSurfaceVariantOf(context)),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(
              color: AppColors.primary,
              label: 'Submitted (${stats.submittedCount})',
            ),
            _Legend(
              color: AppColors.limited,
              label: 'Review (${stats.underReviewCount})',
            ),
            _Legend(
              color: AppColors.available,
              label: 'Approved (${stats.approvedCount})',
            ),
            _Legend(
              color: AppColors.full,
              label: 'Rejected (${stats.rejectedCount})',
            ),
            _Legend(
              color: AppColors.primaryOf(context),
              label: 'In Progress (${stats.inProgressCount})',
            ),
            _Legend(
              color: AppColors.info(Theme.of(context).brightness),
              label: 'Completed (${stats.completedCount})',
            ),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _section(int value, Color color) {
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      title: value > 0 ? '$value' : '',
      radius: 52,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}

/// Clean rectangular bars with value tooltip only while hovering.
class _HoverBarChart extends StatefulWidget {
  const _HoverBarChart({
    required this.labels,
    required this.values,
    required this.colors,
  });

  final List<String> labels;
  final List<int> values;
  final List<Color> colors;

  @override
  State<_HoverBarChart> createState() => _HoverBarChartState();
}

class _HoverBarChartState extends State<_HoverBarChart> {
  int? _hoveredIndex;

  double get _maxY {
    final peak = widget.values.fold<int>(0, (m, v) => v > m ? v : m);
    return (peak < 3 ? 3 : peak + 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8),
      child: BarChart(
        BarChartData(
          maxY: _maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: 28,
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: AppColors.borderOf(context),
                strokeWidth: 1.2,
              ),
            ],
          ),
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchExtraThreshold: const EdgeInsets.all(18),
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions ||
                  response?.spot == null) {
                if (_hoveredIndex != null) {
                  setState(() => _hoveredIndex = null);
                }
                return;
              }
              final index = response!.spot!.touchedBarGroupIndex;
              if (_hoveredIndex != index) {
                setState(() => _hoveredIndex = index);
              }
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
              tooltipRoundedRadius: 8,
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tooltipMargin: 10,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (_hoveredIndex != group.x) return null;
                if (rod.toY <= 0) return null;
                return BarTooltipItem(
                  rod.toY.toInt().toString(),
                  TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            checkToShowHorizontalLine: (value) => value % 1 == 0,
            getDrawingHorizontalLine: (value) => FlLine(
              color: value == 0
                  ? Colors.transparent
                  : AppColors.borderOf(context).withValues(alpha: 0.9),
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value % 1 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toInt().toString(),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.onSurfaceVariantOf(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= widget.labels.length) {
                    return const SizedBox.shrink();
                  }
                  final active = _hoveredIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      widget.labels[i],
                      style: TextStyle(
                        color: active
                            ? AppColors.onSurfaceOf(context)
                            : AppColors.onSurfaceVariantOf(context),
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < widget.values.length; i++)
              BarChartGroupData(
                x: i,
                showingTooltipIndicators:
                    _hoveredIndex == i && widget.values[i] > 0 ? const [0] : const [],
                barRods: [
                  BarChartRodData(
                    toY: widget.values[i].toDouble(),
                    width: 42,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    color: _hoveredIndex == null || _hoveredIndex == i
                        ? widget.colors[i]
                        : widget.colors[i].withValues(alpha: 0.35),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppColors.onSurfaceOf(context))),
        ],
      ),
    );
  }
}
