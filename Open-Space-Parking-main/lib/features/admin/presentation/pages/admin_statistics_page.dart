import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                      style: Theme.of(context).textTheme.headlineSmall,
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
                        height: 260,
                        child: _TypeBarChart(stats: stats),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Operational Snapshot',
                      child: SizedBox(
                        height: 260,
                        child: _OpsBarChart(stats: stats),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
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
      _section(stats.submittedCount, Colors.blue, 'Submitted'),
      _section(stats.underReviewCount, Colors.orange, 'Review'),
      _section(stats.approvedCount, Colors.green, 'Approved'),
      _section(stats.rejectedCount, Colors.red, 'Rejected'),
      _section(stats.inProgressCount, Colors.indigo, 'In Progress'),
      _section(stats.completedCount, Colors.teal, 'Completed'),
    ].where((s) => s.value > 0).toList();

    if (sections.isEmpty) {
      return const Center(child: Text('No ticket data yet.'));
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: Colors.blue, label: 'Submitted (${stats.submittedCount})'),
            _Legend(color: Colors.orange, label: 'Review (${stats.underReviewCount})'),
            _Legend(color: Colors.green, label: 'Approved (${stats.approvedCount})'),
            _Legend(color: Colors.red, label: 'Rejected (${stats.rejectedCount})'),
            _Legend(color: Colors.indigo, label: 'In Progress (${stats.inProgressCount})'),
            _Legend(color: Colors.teal, label: 'Completed (${stats.completedCount})'),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _section(int value, Color color, String title) {
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      title: value > 0 ? '$value' : '',
      radius: 55,
      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}

class _TypeBarChart extends StatelessWidget {
  const _TypeBarChart({required this.stats});

  final AdminStatistics stats;

  @override
  Widget build(BuildContext context) {
    final maxY = [
      stats.buildParkingCount,
      stats.existingParkingCount,
      1,
    ].reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Text('Build');
                  case 1:
                    return const Text('Existing');
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: stats.buildParkingCount.toDouble(),
                color: Colors.indigo,
                width: 28,
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: stats.existingParkingCount.toDouble(),
                color: Colors.teal,
                width: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpsBarChart extends StatelessWidget {
  const _OpsBarChart({required this.stats});

  final AdminStatistics stats;

  @override
  Widget build(BuildContext context) {
    final values = [
      stats.activeEmployees,
      stats.unassignedTickets,
      stats.documentsPendingVerification,
    ];
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 1).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Text('Employees');
                  case 1:
                    return const Text('Unassigned');
                  case 2:
                    return const Text('Docs Pending');
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  color: [Colors.brown, Colors.purple, Colors.teal][i],
                  width: 28,
                ),
              ],
            ),
        ],
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
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
