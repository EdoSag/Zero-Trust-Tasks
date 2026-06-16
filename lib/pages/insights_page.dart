import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zero_trust_tasks/globals/task_manager.dart';
import 'package:zero_trust_tasks/task_priority.dart';
import 'package:zero_trust_tasks/task_priority_extension.dart';

/// Productivity insights: completion trend + priority distribution (item 35).
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  static const int _trendDays = 14;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskManager>(
      builder: (context, taskManager, child) {
        final trend = taskManager.getCompletionTrend(_trendDays);
        final priorities = taskManager.activePriorityBreakdown;
        final totalActive =
            priorities.values.fold(0, (sum, c) => sum + c);
        final totalCompleted = taskManager.completedTasksCount;
        final trendTotal = trend.fold(0, (sum, e) => sum + e.value);
        final avgPerDay =
            trendTotal == 0 ? 0.0 : trendTotal / _trendDays;

        return Scaffold(
          appBar: AppBar(title: const Text('Insights')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatsRow(
                totalActive: totalActive,
                totalCompleted: totalCompleted,
                avgPerDay: avgPerDay,
                overdueCount: taskManager.overdueTasksCount,
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                'Completions – Last $_trendDays Days',
                subtitle: '$trendTotal completed',
              ),
              const SizedBox(height: 12),
              _CompletionBarChart(trend: trend),
              const SizedBox(height: 24),
              _SectionTitle(
                'Active Tasks by Priority',
                subtitle: '$totalActive tasks',
              ),
              const SizedBox(height: 12),
              _PriorityPieChart(
                priorities: priorities,
                total: totalActive,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalActive,
    required this.totalCompleted,
    required this.avgPerDay,
    required this.overdueCount,
  });

  final int totalActive;
  final int totalCompleted;
  final double avgPerDay;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Active',
          value: '$totalActive',
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Done',
          value: '$totalCompleted',
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Overdue',
          value: '$overdueCount',
          color: Colors.red,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Avg/day',
          value: avgPerDay.toStringAsFixed(1),
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompletionBarChart extends StatelessWidget {
  const _CompletionBarChart({required this.trend});

  final List<MapEntry<DateTime, int>> trend;

  @override
  Widget build(BuildContext context) {
    final maxY = trend.fold(0, (m, e) => e.value > m ? e.value : m).toDouble();
    final effectiveMax = maxY < 3 ? 3.0 : maxY + 1;
    final barColor = Theme.of(context).colorScheme.primary;
    final labelFormat = DateFormat('d/M');

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: effectiveMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = trend[groupIndex].key;
                return BarTooltipItem(
                  '${labelFormat.format(day)}\n${rod.toY.toInt()} done',
                  const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: effectiveMax <= 5 ? 1 : null,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (trend.length / 4).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= trend.length) return const SizedBox();
                  return Text(
                    labelFormat.format(trend[i].key),
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: effectiveMax <= 5 ? 1 : null,
          ),
          borderData: FlBorderData(show: false),
          barGroups: trend.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: barColor,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PriorityPieChart extends StatefulWidget {
  const _PriorityPieChart({required this.priorities, required this.total});

  final Map<TaskPriority, int> priorities;
  final int total;

  @override
  State<_PriorityPieChart> createState() => _PriorityPieChartState();
}

class _PriorityPieChartState extends State<_PriorityPieChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    if (widget.total == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No active tasks',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final sections = TaskPriority.values
        .where((p) => (widget.priorities[p] ?? 0) > 0)
        .map((p) {
          final count = widget.priorities[p]!;
          final isTouched = _touched == p.index;
          return PieChartSectionData(
            value: count.toDouble(),
            color: p.getColor(context),
            title: isTouched ? '$count' : '',
            radius: isTouched ? 68 : 56,
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        })
        .toList();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 36,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touched = null;
                        return;
                      }
                      _touched =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: TaskPriority.values
              .where((p) => (widget.priorities[p] ?? 0) > 0)
              .map((p) {
                final count = widget.priorities[p]!;
                final pct = (count / widget.total * 100).round();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: p.getColor(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.displayName} ($pct%)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              })
              .toList(),
        ),
      ],
    );
  }
}
