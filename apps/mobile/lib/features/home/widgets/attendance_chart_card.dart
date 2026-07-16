import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';
import '../../../core/theme/app_theme.dart';

class AttendanceChartRow extends ConsumerWidget {
  const AttendanceChartRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(attendanceChartProvider);
    return SizedBox(
      height: 200,
      child: PageView(
        children: [
          data.when(
            data: (d) => _ChartCard(title: 'Student Attendance', rows: (d['studentAttendance'] as List? ?? []).cast()),
            loading: () => const _ChartCard(title: 'Student Attendance', rows: []),
            error: (_, __) => const _ChartCard(title: 'Student Attendance', rows: []),
          ),
          data.when(
            data: (d) => _ChartCard(title: 'Teacher Attendance', rows: (d['teacherAttendance'] as List? ?? []).cast()),
            loading: () => const _ChartCard(title: 'Teacher Attendance', rows: []),
            error: (_, __) => const _ChartCard(title: 'Teacher Attendance', rows: []),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;

  const _ChartCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final hasData = rows.isNotEmpty;

    // Build last 7 days x-axis labels even if no data
    final labels = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DateFormat('dd MMM').format(d);
    });

    // Map data by date
    final pctByDate = <String, double>{};
    for (final r in rows) {
      final d = DateTime.tryParse(r['date']?.toString() ?? '');
      if (d != null) pctByDate[DateFormat('dd MMM').format(d)] = double.tryParse(r['pct']?.toString() ?? '0') ?? 0;
    }

    // B3: plot the real percentage per day. Days with no session are skipped
    // (not forced to 0), so the line never shows a misleading spike to zero.
    final spots = <FlSpot>[];
    for (int i = 0; i < labels.length; i++) {
      final pct = pctByDate[labels[i]];
      if (pct != null) spots.add(FlSpot(i.toDouble(), pct));
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0, maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 0.8),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: AppColors.divider),
                    left: BorderSide(color: AppColors.divider),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  // B2 fix: percentage axis 0–100 with a fixed 20-step interval so
                  // labels render once (0/20/40/60/80/100) instead of every 0.5.
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 20,
                      getTitlesWidget: (v, meta) {
                        // Only draw the canonical 0..100 step labels; skip anything else.
                        if (v < 0 || v > 100 || v % 20 != 0) return const SizedBox.shrink();
                        return Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final idx = v.round();
                        if (idx < 0 || idx >= labels.length || (v - idx).abs() > 0.01) return const SizedBox.shrink();
                        final parts = labels[idx].split(' ');
                        return Column(children: [
                          Text(parts[0], style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                          Text(parts[1], style: const TextStyle(fontSize: 7, color: AppColors.textSecondary)),
                        ]);
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: hasData ? spots : const [],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(show: hasData),
                    belowBarData: BarAreaData(
                      show: hasData,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
