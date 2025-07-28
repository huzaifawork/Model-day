import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../pages/splash_page.dart';
import '../pages/landing_page.dart';
import '../pages/sign_in_page.dart';
import '../pages/sign_up_page.dart';
import '../pages/welcome_page.dart';

/// Custom route information parser to handle browser refresh properly
class AppRouteInformationParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) async {
    final location = routeInformation.uri.path;
    debugPrint('🧭 AppRouteInformationParser - Parsing route: $location');
    return location;
  }

  @override
  RouteInformation restoreRouteInformation(String configuration) {
    debugPrint('🧭 AppRouteInformationParser - Restoring route: $configuration');
    return RouteInformation(uri: Uri.parse(configuration));
  }
}

/// Custom router delegate to handle navigation and authentication
class AppRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  String _currentPath = '/';
  AuthService? _authService;
  
  String get currentPath => _currentPath;
  
  void setAuthService(AuthService authService) {
    if (_authService != authService) {
      _authService?.removeListener(_handleAuthChange);
      _authService = authService;
      _authService?.addListener(_handleAuthChange);
    }
  }
  
  void _handleAuthChange() {
    debugPrint('🔔 AppRouterDelegate - Auth state changed, notifying listeners');
    notifyListeners();
  }
  
  @override
  String get currentConfiguration => _currentPath;
  
  @override
  Future<void> setNewRoutePath(String path) async {
    debugPrint('🧭 AppRouterDelegate - Setting new route path: $path');
    _currentPath = path;
    notifyListeners();
  }
  
  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ AppRouterDelegate.build() - Current path: $_currentPath');
    
    return Navigator(
      key: navigatorKey,
      pages: _buildPages(context),
      onDidRemovePage: (page) {
        // Handle back navigation
        if (_currentPath != '/') {
          _currentPath = '/';
          notifyListeners();
        }
      },
    );
  }
  
  List<Page> _buildPages(BuildContext context) {
    final authService = context.read<AuthService>();
    final isAuthenticated = authService.isAuthenticated;
    final isInitialized = authService.isInitialized;
    
    debugPrint('🔍 AppRouterDelegate - Auth status: $isAuthenticated, initialized: $isInitialized');
    debugPrint('🔍 AppRouterDelegate - Building pages for path: $_currentPath');
    
    // Show splash while initializing
    if (!isInitialized) {
      return [
        const MaterialPage(
          key: ValueKey('splash'),
          child: SplashPage(),
        ),
      ];
    }
    
    // Handle authentication-based routing
    if (!isAuthenticated) {
      // User not authenticated - show public pages
      switch (_currentPath) {
        case '/signin':
          return [
            const MaterialPage(key: ValueKey('landing'), child: LandingPage()),
            const MaterialPage(key: ValueKey('signin'), child: SignInPage()),
          ];
        case '/signup':
          return [
            const MaterialPage(key: ValueKey('landing'), child: LandingPage()),
            const MaterialPage(key: ValueKey('signup'), child: SignUpPage()),
          ];
        default:
          return [
            const MaterialPage(key: ValueKey('landing'), child: LandingPage()),
          ];
      }
    } else {
      // User authenticated - show protected pages
      switch (_currentPath) {
        case '/':
        case '/landing':
        case '/signin':
        case '/signup':
          // Redirect authenticated users to welcome
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setNewRoutePath('/welcome');
          });
          return [
            const MaterialPage(key: ValueKey('welcome'), child: WelcomePage()),
          ];
        case '/welcome':
          return [
            const MaterialPage(key: ValueKey('welcome'), child: WelcomePage()),
          ];
        default:
          // For other routes, show welcome as base and the requested page
          return [
            const MaterialPage(key: ValueKey('welcome'), child: WelcomePage()),
            MaterialPage(
              key: ValueKey(_currentPath),
              child: _getPageForRoute(_currentPath),
            ),
          ];
      }
    }
  }
  
  Widget _getPageForRoute(String route) {
    // Return the appropriate page for the route
    // For now, return welcome page as fallback
    debugPrint('🔍 AppRouterDelegate - Getting page for route: $route');
    return const WelcomePage();
  }
  
  @override
  void dispose() {
    _authService?.removeListener(_handleAuthChange);
    super.dispose();
  }
}
