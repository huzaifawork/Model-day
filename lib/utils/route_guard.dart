import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../pages/sign_in_page.dart';

/// Route guard to handle authentication and prevent unwanted redirects
class RouteGuard {
  static Widget guardRoute(BuildContext context, Widget page, String routeName) {
    debugPrint('🛡️ RouteGuard - Guarding route: $routeName');
    
    final authService = context.read<AuthService>();
    final isAuthenticated = authService.isAuthenticated;
    
    debugPrint('🔍 RouteGuard - Auth status: $isAuthenticated for route: $routeName');
    
    // Public routes that don't require authentication
    final publicRoutes = [
      '/',
      '/landing',
      '/signin',
      '/signup',
      '/forgot-password',
      '/register',
      '/auth/callback',
    ];
    
    // If it's a public route, allow access
    if (publicRoutes.contains(routeName)) {
      debugPrint('✅ RouteGuard - Public route allowed: $routeName');
      return page;
    }
    
    // For protected routes, check authentication
    if (!isAuthenticated) {
      debugPrint('🚫 RouteGuard - Unauthorized access to: $routeName, redirecting to sign-in');
      return const SignInPage();
    }
    
    debugPrint('✅ RouteGuard - Authenticated access allowed to: $routeName');
    return page;
  }
  
  /// Check if user should be redirected based on auth status and current route
  static String? getRedirectRoute(BuildContext context, String currentRoute) {
    final authService = context.read<AuthService>();
    final isAuthenticated = authService.isAuthenticated;
    
    debugPrint('🔍 RouteGuard - Checking redirect for: $currentRoute, auth: $isAuthenticated');
    
    // If user is authenticated and on landing/signin/signup, redirect to welcome
    if (isAuthenticated && ['/landing', '/signin', '/signup'].contains(currentRoute)) {
      debugPrint('➡️ RouteGuard - Authenticated user on public page, redirecting to welcome');
      return '/welcome';
    }
    
    // If user is not authenticated and on protected route, redirect to signin
    final publicRoutes = ['/', '/landing', '/signin', '/signup', '/forgot-password', '/register', '/auth/callback'];
    if (!isAuthenticated && !publicRoutes.contains(currentRoute)) {
      debugPrint('➡️ RouteGuard - Unauthenticated user on protected page, redirecting to signin');
      return '/signin';
    }
    
    debugPrint('✅ RouteGuard - No redirect needed for: $currentRoute');
    return null;
  }
}

/// Widget that wraps pages with route guarding
class GuardedRoute extends StatelessWidget {
  final Widget child;
  final String routeName;
  
  const GuardedRoute({
    super.key,
    required this.child,
    required this.routeName,
  });
  
  @override
  Widget build(BuildContext context) {
    return RouteGuard.guardRoute(context, child, routeName);
  }
}
