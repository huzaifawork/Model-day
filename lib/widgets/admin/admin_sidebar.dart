import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_auth_service.dart';
import '../../theme/app_theme.dart';

class AdminSidebar extends StatelessWidget {
  final VoidCallback? onCloseSidebar;

  const AdminSidebar({
    super.key,
    this.onCloseSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final adminAuth = context.watch<AdminAuthService>();
    final currentAdmin = adminAuth.currentAdmin;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          right: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: AppTheme.goldColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onCloseSidebar != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: onCloseSidebar,
                  ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildNavItem(
                    context,
                    'Dashboard',
                    Icons.home,
                    '/admin/dashboard',
                  ),
                  _buildNavItem(
                    context,
                    'User Management',
                    Icons.account_circle,
                    '/admin/users',
                  ),
                  _buildNavItem(
                    context,
                    'Recent Activity',
                    Icons.access_time,
                    '/admin/activity',
                  ),
                  _buildNavItem(
                    context,
                    'Support Messages',
                    Icons.email,
                    '/admin/support',
                  ),
                  _buildNavItem(
                    context,
                    'Profile Management',
                    Icons.person,
                    '/admin/profile',
                  ),
                ],
              ),
            ),
          ),

          // User profile section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.goldColor,
                      child: Text(
                        currentAdmin?.name.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentAdmin?.name ?? 'Admin',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            currentAdmin?.role.replaceAll('_', ' ').toUpperCase() ?? 'ADMIN',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await adminAuth.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/signin');
                      }
                    },
                    icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon,
    String route, {
    bool isSecondary = false,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isSelected = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? AppTheme.goldColor
              : isSecondary
                  ? AppTheme.textSecondary
                  : AppTheme.textPrimary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? AppTheme.goldColor
                : isSecondary
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.goldColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: () {
          if (onCloseSidebar != null) {
            onCloseSidebar!();
          }
          Navigator.pushReplacementNamed(context, route);
        },
      ),
    );
  }
}
