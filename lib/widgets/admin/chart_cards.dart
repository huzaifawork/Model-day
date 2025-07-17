import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';

// Line Chart Card for User Growth
class UserGrowthLineChart extends StatelessWidget {
  final int totalUsers;
  final int newUsersThisMonth;
  final String title;

  const UserGrowthLineChart({
    super.key,
    required this.totalUsers,
    required this.newUsersThisMonth,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.goldColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people,
                    color: AppTheme.goldColor, size: 24),
              ),
              const Spacer(),
              Text(
                '+$newUsersThisMonth',
                style: const TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            totalUsers.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateUserGrowthData(),
                    isCurved: true,
                    color: AppTheme.goldColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.goldColor.withValues(alpha: 0.1),
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

  List<FlSpot> _generateUserGrowthData() {
    // Generate sample growth data
    final baseUsers = totalUsers - newUsersThisMonth;
    return [
      FlSpot(0, baseUsers * 0.7),
      FlSpot(1, baseUsers * 0.8),
      FlSpot(2, baseUsers * 0.85),
      FlSpot(3, baseUsers * 0.9),
      FlSpot(4, baseUsers * 0.95),
      FlSpot(5, totalUsers.toDouble()),
    ];
  }
}

// Pie Chart Card for Support Messages
class SupportMessagesPieChart extends StatelessWidget {
  final int totalMessages;
  final int pendingMessages;
  final String title;

  const SupportMessagesPieChart({
    super.key,
    required this.totalMessages,
    required this.pendingMessages,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedMessages = totalMessages - pendingMessages;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (pendingMessages > 0
                              ? AppTheme.errorColor
                              : AppTheme.successColor)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.support,
                      color: pendingMessages > 0
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: pendingMessages > 0
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingMessages pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                totalMessages.toString(),
                style: TextStyle(
                  fontSize: constraints.maxHeight > 200 ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: constraints.maxHeight > 200 ? 11 : 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Fixed height container for the chart
              SizedBox(
                height: constraints.maxHeight > 200 ? 85 : 75,
                child: totalMessages > 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius:
                                constraints.maxHeight > 200 ? 25 : 20,
                            sections: [
                              PieChartSectionData(
                                color: AppTheme.successColor,
                                value: resolvedMessages.toDouble(),
                                title: resolvedMessages > 0
                                    ? '$resolvedMessages'
                                    : '',
                                radius: constraints.maxHeight > 200 ? 30 : 25,
                                titleStyle: TextStyle(
                                  fontSize:
                                      constraints.maxHeight > 200 ? 12 : 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (pendingMessages > 0)
                                PieChartSectionData(
                                  color: AppTheme.errorColor,
                                  value: pendingMessages.toDouble(),
                                  title: '$pendingMessages',
                                  radius: constraints.maxHeight > 200 ? 30 : 25,
                                  titleStyle: TextStyle(
                                    fontSize:
                                        constraints.maxHeight > 200 ? 12 : 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'No messages',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),

              // Legend section
              if (totalMessages > 0 && constraints.maxHeight > 160) ...[
                SizedBox(height: constraints.maxHeight > 200 ? 6 : 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(
                          'Resolved', AppTheme.successColor, resolvedMessages),
                      if (pendingMessages > 0)
                        _buildLegendItem(
                            'Pending', AppTheme.errorColor, pendingMessages),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($value)',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Bar Chart Card for Jobs vs Castings
class JobsCastingsBarChart extends StatelessWidget {
  final int totalJobs;
  final int totalCastings;
  final int newJobs;
  final int newCastings;

  const JobsCastingsBarChart({
    super.key,
    required this.totalJobs,
    required this.totalCastings,
    required this.newJobs,
    required this.newCastings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.work,
                    color: AppTheme.successColor, size: 24),
              ),
              const Spacer(),
              Text(
                '+${newJobs + newCastings} this month',
                style: const TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${totalJobs + totalCastings}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jobs & Castings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY:
                        (totalJobs > totalCastings ? totalJobs : totalCastings)
                                .toDouble() *
                            1.3,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String label = groupIndex == 0 ? 'Jobs' : 'Castings';
                          return BarTooltipItem(
                            '$label\n${rod.toY.round()}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('Jobs',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                );
                              case 1:
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('Castings',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                );
                              default:
                                return const Text('');
                            }
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: totalJobs.toDouble(),
                            color: AppTheme.successColor,
                            width: 40,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                            rodStackItems: totalJobs > 0
                                ? [
                                    BarChartRodStackItem(
                                        0,
                                        totalJobs.toDouble(),
                                        AppTheme.successColor),
                                  ]
                                : [],
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: totalCastings.toDouble(),
                            color: AppTheme.goldColor,
                            width: 40,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                            rodStackItems: totalCastings > 0
                                ? [
                                    BarChartRodStackItem(
                                        0,
                                        totalCastings.toDouble(),
                                        AppTheme.goldColor),
                                  ]
                                : [],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Value labels on bars
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(
                                bottom: totalJobs > 0 ? totalJobs * 2.0 : 0),
                            child: totalJobs > 0
                                ? Text(
                                    '$totalJobs',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(
                                bottom: totalCastings > 0
                                    ? totalCastings * 2.0
                                    : 0),
                            child: totalCastings > 0
                                ? Text(
                                    '$totalCastings',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Donut Chart Card for User Activity Status
class UserActivityDonutChart extends StatelessWidget {
  final int totalUsers;
  final int activeUsers;
  final String title;

  const UserActivityDonutChart({
    super.key,
    required this.totalUsers,
    required this.activeUsers,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveUsers = totalUsers - activeUsers;
    final activePercentage =
        totalUsers > 0 ? (activeUsers / totalUsers * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.people,
                        color: AppTheme.goldColor, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    '$activePercentage% active',
                    style: const TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                totalUsers.toString(),
                style: TextStyle(
                  fontSize: constraints.maxHeight > 200 ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: constraints.maxHeight > 200 ? 11 : 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Fixed height container for the chart
              SizedBox(
                height: constraints.maxHeight > 200 ? 85 : 75,
                child: totalUsers > 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 4,
                                centerSpaceRadius:
                                    constraints.maxHeight > 200 ? 25 : 20,
                                startDegreeOffset: -90,
                                sections: [
                                  PieChartSectionData(
                                    color: AppTheme.successColor,
                                    value: activeUsers.toDouble(),
                                    title: '',
                                    radius:
                                        constraints.maxHeight > 200 ? 20 : 18,
                                  ),
                                  if (inactiveUsers > 0)
                                    PieChartSectionData(
                                      color: AppTheme.textMuted,
                                      value: inactiveUsers.toDouble(),
                                      title: '',
                                      radius:
                                          constraints.maxHeight > 200 ? 20 : 18,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$activePercentage%',
                                  style: TextStyle(
                                    fontSize:
                                        constraints.maxHeight > 200 ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize:
                                        constraints.maxHeight > 200 ? 10 : 9,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Text(
                          'No users',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
              // Legend section
              if (totalUsers > 0 && constraints.maxHeight > 160) ...[
                SizedBox(height: constraints.maxHeight > 200 ? 6 : 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem(
                          'Active', AppTheme.successColor, activeUsers),
                      if (inactiveUsers > 0)
                        _buildLegendItem(
                            'Inactive', AppTheme.textMuted, inactiveUsers),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColorLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label ($value)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
