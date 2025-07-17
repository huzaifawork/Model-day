import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/admin/admin_layout.dart';
import '../widgets/admin/user_card.dart';
import '../widgets/admin/chart_cards.dart';

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({super.key});

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            user.displayNameOrEmail
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (user.email.toLowerCase().contains(_searchQuery.toLowerCase()));

        // Status filter
        final matchesStatus = _statusFilter == 'all' ||
            (_statusFilter == 'active' && user.isActive) ||
            (_statusFilter == 'inactive' && !user.isActive);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _loadUsers() async {
    try {
      debugPrint(
          '🔍 AdminManagementPage._loadUsers() - Starting to load users...');
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final users = await UserService.getAllUsers();
      debugPrint(
          '🔍 AdminManagementPage._loadUsers() - Received ${users.length} users');

      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _isLoading = false;
        });
        debugPrint(
            '🔍 AdminManagementPage._loadUsers() - State updated with ${_filteredUsers.length} filtered users');
      }
    } catch (e) {
      debugPrint('❌ AdminManagementPage._loadUsers() - Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    try {
      final success = await UserService.updateUserStatus(
        user.id!,
        !user.isActive,
      );

      if (success) {
        _loadUsers(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                user.isActive
                    ? 'User ${user.displayNameOrEmail} deactivated'
                    : 'User ${user.displayNameOrEmail} activated',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete User',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete user ${user.displayNameOrEmail}? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await UserService.deleteUser(user.id!);
        if (success) {
          _loadUsers(); // Refresh the list
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'User ${user.displayNameOrEmail} deleted successfully'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'User Management',
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            )
          : _error != null
              ? Center(
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
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh, color: Colors.black),
                        label: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildUserContent(),
    );
  }

  Widget _buildUserContent() {
    final activeUsers = _filteredUsers.where((user) => user.isActive).toList();
    final inactiveUsers =
        _filteredUsers.where((user) => !user.isActive).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search users by name or email...',
                    prefixIcon: Icon(Icons.search, color: AppTheme.goldColor),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.goldColor),
                    ),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterUsers();
                  },
                ),

                const SizedBox(height: 16),

                // Status filter
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 400;

                    if (isNarrow) {
                      // Stack vertically on narrow screens
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter by status:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: AppTheme.goldColor),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All Users')),
                              DropdownMenuItem(
                                  value: 'active', child: Text('Active Users')),
                              DropdownMenuItem(
                                  value: 'inactive',
                                  child: Text('Inactive Users')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _statusFilter = value;
                                });
                                _filterUsers();
                              }
                            },
                          ),
                        ],
                      );
                    } else {
                      // Horizontal layout for wider screens
                      return Row(
                        children: [
                          const Text(
                            'Filter by status:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _statusFilter,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: AppTheme.goldColor),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'all', child: Text('All Users')),
                                DropdownMenuItem(
                                    value: 'active',
                                    child: Text('Active Users')),
                                DropdownMenuItem(
                                    value: 'inactive',
                                    child: Text('Inactive Users')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _statusFilter = value;
                                  });
                                  _filterUsers();
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistics Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1200;
              final isTablet = constraints.maxWidth > 600;
              final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 1.1 : (isTablet ? 1.0 : 0.9),
                children: [
                  UserGrowthLineChart(
                    totalUsers: _filteredUsers.length,
                    newUsersThisMonth: 0, // You can calculate this if needed
                    title: 'Total Users',
                  ),
                  UserActivityDonutChart(
                    totalUsers: _filteredUsers.length,
                    activeUsers: activeUsers.length,
                    title: 'User Activity',
                  ),
                  _buildInactiveUsersCard(inactiveUsers.length),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // Users section
          const Text(
            'Application Users',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          if (_filteredUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: AppTheme.cardDecoration,
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: AppTheme.textMuted,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No users found',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: _filteredUsers.map((user) {
                  return UserCard(
                    user: user,
                    onToggleStatus: () => _toggleUserStatus(user),
                    onDelete: () => _deleteUser(user),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInactiveUsersCard(int inactiveCount) {
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
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_remove,
                    color: AppTheme.errorColor, size: 24),
              ),
              const Spacer(),
              if (inactiveCount == 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'All Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            inactiveCount.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inactive Users',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            inactiveCount == 0
                ? 'All users are active'
                : 'Users requiring attention',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
