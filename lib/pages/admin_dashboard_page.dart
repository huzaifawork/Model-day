import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../services/admin_auth_service.dart';
import '../models/admin_stats.dart';
import '../theme/app_theme.dart';
import '../widgets/admin/admin_layout.dart';
import '../widgets/admin/chart_cards.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String _selectedTimeFilter = 'Month';
  final List<String> _timeFilters = ['Week', 'Month', 'Year'];
  late StreamController<AdminStats> _statsController;
  StreamSubscription<AdminStats>? _statsSubscription;

  @override
  void initState() {
    super.initState();
    _statsController = StreamController<AdminStats>.broadcast();
    _initializeAdminDashboard();
  }

  Future<void> _initializeAdminDashboard() async {
    // Check admin status
    final adminAuth = context.read<AdminAuthService>();
    await adminAuth.checkCurrentUserAdminStatus();

    // Load stats
    _loadStats();
  }

  @override
  void dispose() {
    _statsController.close();
    _statsSubscription?.cancel();
    super.dispose();
  }

  void _loadStats() {
    _statsSubscription?.cancel();
    _statsSubscription =
        AdminService.getAdminStatsStream(_selectedTimeFilter).listen(
      (stats) {
        if (!_statsController.isClosed) {
          _statsController.add(stats);
        }
      },
      onError: (error) {
        if (!_statsController.isClosed) {
          _statsController.addError(error);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Dashboard Overview',
      actions: [
        // Time filter dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTimeFilter,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppTheme.goldColor),
              style: const TextStyle(color: AppTheme.textPrimary),
              dropdownColor: AppTheme.surfaceColor,
              items: _timeFilters.map((String filter) {
                return DropdownMenuItem<String>(
                  value: filter,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter == 'Week'
                            ? Icons.calendar_today
                            : filter == 'Month'
                                ? Icons.calendar_today
                                : Icons.calendar_today,
                        size: 16,
                        color: AppTheme.goldColor,
                      ),
                      const SizedBox(width: 8),
                      Text(filter),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedTimeFilter = newValue;
                  });
                  _loadStats(); // Reload stats with new filter
                }
              },
            ),
          ),
        ),
      ],
      child: StreamBuilder<AdminStats>(
        stream: _statsController.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading dashboard: ${snapshot.error}',
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final stats = snapshot.data ?? AdminStats();
          return _buildDashboardContent(stats);
        },
      ),
    );
  }

  Widget _buildDashboardContent(AdminStats stats) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1200;
              final isTablet = constraints.maxWidth > 768;
              final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 1.1 : (isTablet ? 1.0 : 0.9),
                children: [
                  UserGrowthLineChart(
                    totalUsers: stats.totalUsers,
                    newUsersThisMonth: stats.newUsersThisMonth,
                    title: 'Total Users',
                  ),
                  SupportMessagesPieChart(
                    totalMessages: stats.supportMessages,
                    pendingMessages: stats.pendingSupportMessages,
                    title: 'Support Messages',
                  ),
                  JobsCastingsBarChart(
                    totalJobs: stats.totalJobs,
                    totalCastings: stats.totalCastings,
                    newJobs: stats.newJobsThisMonth,
                    newCastings: stats.newCastingsThisMonth,
                  ),
                  UserActivityDonutChart(
                    totalUsers: stats.totalUsers,
                    activeUsers: stats.activeUsers,
                    title: 'User Activity',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
