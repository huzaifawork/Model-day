import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin.dart';
import 'admin_service.dart';

class AdminAuthService extends ChangeNotifier {
  Admin? _currentAdmin;
  bool _loading = false;
  bool _isInitialized = false;

  Admin? get currentAdmin => _currentAdmin;
  bool get loading => _loading;
  bool get isAdminAuthenticated => _currentAdmin != null;
  bool get isInitialized => _isInitialized;

  static AdminAuthService? _instance;
  static AdminAuthService get instance {
    _instance ??= AdminAuthService._internal();
    return _instance!;
  }

  AdminAuthService._internal() {
    debugPrint('🔐 AdminAuthService singleton constructor called');
    _init();
  }

  factory AdminAuthService() {
    debugPrint('🔐 AdminAuthService factory called - returning singleton');
    return instance;
  }

  void _init() async {
    try {
      debugPrint('🔄 AdminAuthService._init() started');

      // Create initial admin if none exists
      await AdminService.createInitialAdmin();

      // Only listen for auth state changes when explicitly needed for admin operations
      // This prevents interference with regular user authentication
      _isInitialized = true;
      notifyListeners();

      debugPrint('✅ AdminAuthService initialized');
    } catch (e) {
      debugPrint('❌ AdminAuthService initialization error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Admin sign in
  Future<void> signIn({required String email, required String password}) async {
    try {
      _loading = true;
      notifyListeners();

      debugPrint('🔄 AdminAuthService - Attempting admin sign in for: $email');

      // Use AdminService to handle admin login
      final admin = await AdminService.adminLogin(email, password);

      if (admin != null) {
        _currentAdmin = admin;
        debugPrint('✅ Admin sign in successful: ${admin.email}, ID: ${admin.id}');

        // Log admin activity
        await AdminService.logActivity(
          type: 'admin_login',
          description: 'Admin ${admin.name} logged in',
          userEmail: admin.email,
        );
      } else {
        throw Exception('Admin login failed');
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Admin sign in error: $e');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Admin sign out
  Future<void> signOut() async {
    try {
      debugPrint('🔄 AdminAuthService - Signing out admin');

      if (_currentAdmin != null) {
        // Log admin activity
        await AdminService.logActivity(
          type: 'admin_logout',
          description: 'Admin ${_currentAdmin!.name} logged out',
          userEmail: _currentAdmin!.email,
        );
      }

      await FirebaseAuth.instance.signOut();
      _currentAdmin = null;

      debugPrint('✅ Admin signed out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Admin sign out error: $e');
      rethrow;
    }
  }

  /// Check if current user has specific permission (all super admins have all permissions)
  bool hasPermission(String permission) {
    return _currentAdmin != null; // All admins are super admins now
  }

  /// Check if current user can access admin routes
  Future<bool> canAccessAdminRoutes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final admin = await AdminService.getAdminByEmail(user.email!);
    return admin != null && admin.isActive;
  }

  /// Manually check and set admin status for current user
  Future<void> checkCurrentUserAdminStatus() async {
    debugPrint('🔍 AdminAuthService.checkCurrentUserAdminStatus() called');
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      debugPrint('🔍 Current Firebase user: ${user.email}');
      final admin = await AdminService.getAdminByEmail(user.email!);

      if (admin != null && admin.isActive) {
        _currentAdmin = admin;
        debugPrint('✅ Admin status confirmed: ${admin.email}');
        debugPrint('✅ Admin role: ${admin.role}');
        debugPrint('✅ Admin ID: ${admin.id}');
      } else {
        _currentAdmin = null;
        debugPrint('❌ User is not an admin or admin is inactive');
      }
      notifyListeners();
    } else {
      debugPrint('❌ No Firebase user found');
      _currentAdmin = null;
      notifyListeners();
    }
  }

  /// Sign out user if they're trying to access admin routes but are not admin
  Future<void> signOutIfNotAdmin() async {
    final canAccess = await canAccessAdminRoutes();
    if (!canAccess) {
      debugPrint('🚫 Non-admin user trying to access admin routes, signing out');
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Check if current user is super admin
  bool get isSuperAdmin => _currentAdmin?.isSuperAdmin ?? false;

  /// Check if current user is admin
  bool get isAdmin => _currentAdmin?.isAdmin ?? false;

  /// Check if current user is moderator
  bool get isModerator => _currentAdmin?.isModerator ?? false;

  /// Get current admin role
  String? get currentAdminRole => _currentAdmin?.role;

  /// Refresh current admin data
  Future<void> refreshAdminData() async {
    try {
      if (_currentAdmin != null) {
        final updatedAdmin = await AdminService.getAdminByEmail(_currentAdmin!.email);
        if (updatedAdmin != null) {
          _currentAdmin = updatedAdmin;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing admin data: $e');
    }
  }
}
