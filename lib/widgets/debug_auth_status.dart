import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/admin_auth_service.dart';

/// Debug widget to show current authentication status
/// Only shows in debug mode
class DebugAuthStatus extends StatelessWidget {
  const DebugAuthStatus({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!const bool.fromEnvironment('dart.vm.product')) {
      return Consumer2<AuthService, AdminAuthService>(
        builder: (context, authService, adminAuthService, child) {
          return Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🔍 DEBUG AUTH STATUS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Auth: ${authService.isAuthenticated ? "✅" : "❌"}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  Text(
                    'User: ${authService.currentUser?.email ?? "null"}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  Text(
                    'Admin: ${adminAuthService.isAdminAuthenticated ? "✅" : "❌"}',
                    style: TextStyle(
                      color: adminAuthService.isAdminAuthenticated 
                          ? Colors.green 
                          : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Admin User: ${adminAuthService.currentAdmin?.email ?? "null"}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  Text(
                    'Role: ${adminAuthService.currentAdmin?.role ?? "null"}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}
