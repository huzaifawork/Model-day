import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage_service.dart';
import 'oauth_config_service.dart';
import 'admin_auth_service.dart';
import 'manual_oauth_service.dart';
import 'firebase_auth_storage_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class AuthService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _loading = false;
  bool _isInitialized = false;
  bool _connectivityTested = false;
  bool _profileCreationInProgress = false;

  User? get currentUser => _currentUser;
  bool get loading => _loading;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }

  AuthService._internal() {
    debugPrint('🔐 AuthService singleton constructor called');
    _init();
    // Initialize API client
    _initializeApiClient();
  }

  void _initializeApiClient() {
    try {
      // Import and initialize API client here if needed
      debugPrint('🔗 API Client initialization skipped for now');
    } catch (e) {
      debugPrint('❌ API Client initialization error: $e');
    }
  }

  // Factory constructor for Provider compatibility
  factory AuthService() {
    debugPrint('🔐 AuthService factory called - returning singleton');
    return instance;
  }

  void _init() async {
    try {
      debugPrint('🔄 AuthService._init() started');

      // Listen for auth state changes
      _auth.authStateChanges().listen((User? user) async {
        debugPrint('🔔 AuthService - Auth state changed');
        debugPrint('🔍 Previous user: ${_currentUser?.email ?? 'null'}');
        debugPrint('🔍 New user: ${user?.email ?? 'null'}');

        final previousUser = _currentUser;
        _currentUser = user;

        // Only process if the user actually changed
        if (previousUser?.uid != user?.uid) {
          debugPrint('✅ AuthService - User actually changed, processing...');
          if (user != null) {
            debugPrint('👤 User signed in: ${user.email}');
            // Create user profile if it doesn't exist
            await _createUserProfileIfNeeded(user);
            // Check admin status
            await _checkAndSetAdminStatus();
          } else {
            debugPrint('👋 User signed out');
            await TokenStorageService.clearAll();
            // Clear admin status on logout
            AdminAuthService.instance.signOut();
          }

          debugPrint('📢 AuthService - Notifying listeners...');
          notifyListeners();
        } else {
          debugPrint('⏭️ AuthService - Same user, skipping processing');
        }
      });

      // Check for existing user
      _currentUser = _auth.currentUser;
      debugPrint(
          '🔍 AuthService - Initial user: ${_currentUser?.email ?? 'null'}');

      // Handle redirect result for web OAuth
      if (kIsWeb) {
        _handleRedirectResult();
      }

      _isInitialized = true;
      debugPrint('✅ AuthService - Initialization complete');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Auth initialization error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Handle redirect result for web OAuth
  Future<void> _handleRedirectResult() async {
    try {
      final result = await _auth.getRedirectResult();
      if (result.user != null) {
        _currentUser = result.user;
        debugPrint(
            '✅ Google sign in successful via redirect: ${_currentUser?.email}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error handling redirect result: $e');
    }
  }

  /// Check if current user is admin and update admin auth service
  Future<void> _checkAndSetAdminStatus() async {
    try {
      if (_currentUser?.email != null) {
        final adminAuthService = AdminAuthService.instance;
        await adminAuthService.checkCurrentUserAdminStatus();
        debugPrint('🔍 Admin status checked for: ${_currentUser?.email}');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking admin status: $e');
      // Don't throw - this is not critical for regular user login
    }
  }

  /// Create user profile in Firestore if it doesn't exist
  Future<void> _createUserProfileIfNeeded(User user) async {
    // Prevent multiple simultaneous profile creation attempts
    if (_profileCreationInProgress) {
      debugPrint('Profile creation already in progress, skipping...');
      return;
    }

    try {
      _profileCreationInProgress = true;
      debugPrint('Attempting to create/check user profile for: ${user.email}');

      // Test Firestore connectivity first (only once)
      if (!_connectivityTested) {
        await _testFirestoreConnectivity();
        _connectivityTested = true;
      }

      // Use direct Firestore calls for all platforms - simpler and more reliable
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      debugPrint('User document exists: ${userDoc.exists}');

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'onboarding_tour_seen': false,
          'onboarding_completed': false,
        });
        debugPrint('User profile created for: ${user.email}');
      } else {
        debugPrint('User profile already exists for: ${user.email}');
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      // Don't rethrow - this is not critical for authentication
    } finally {
      _profileCreationInProgress = false;
    }
  }

  /// Test Firestore connectivity
  Future<void> _testFirestoreConnectivity() async {
    try {
      debugPrint('Testing Firestore connectivity...');

      // Try to write a simple test document
      await FirebaseFirestore.instance
          .collection('test')
          .doc('connectivity')
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': true,
      });

      debugPrint('✅ Firestore write test successful');

      // Try to read it back
      final testDoc = await FirebaseFirestore.instance
          .collection('test')
          .doc('connectivity')
          .get();

      debugPrint('✅ Firestore read test successful: ${testDoc.exists}');
    } catch (e) {
      debugPrint('❌ Firestore connectivity test failed: $e');
    }
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      _loading = true;
      notifyListeners();

      debugPrint(
          'Attempting to sign up with email: ${email.split('@')[0]}@...');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Sign up failed - no user returned');
      }

      _currentUser = credential.user;

      // Update display name if provided
      if (fullName != null && fullName.trim().isNotEmpty) {
        await _currentUser!.updateDisplayName(fullName.trim());
        await _currentUser!.reload();
        _currentUser = _auth.currentUser;
      }

      debugPrint('Sign up successful for user: ${_currentUser?.uid}');

      _loading = false;
      notifyListeners();

      // Don't navigate here - let the auth state listener handle navigation
    } catch (e) {
      debugPrint('Sign up error: $e');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<void> signIn({required String email, required String password}) async {
    try {
      _loading = true;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Sign in failed - no user returned');
      }

      _currentUser = credential.user;

      // Check if user is admin and update admin auth service
      await _checkAndSetAdminStatus();

      debugPrint('Sign in successful for user: ${_currentUser?.email}');

      _loading = false;
      notifyListeners();

      // Don't navigate here - let the auth state listener handle navigation
    } catch (e) {
      debugPrint('Sign in error: $e');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Alternative mobile Google Sign-In without disconnect
  Future<void> _signInWithGoogleMobileAlternative() async {
    final GoogleSignIn googleSignIn =
        OAuthConfigService.getGoogleSignInInstance();

    debugPrint(
        '🔄 Attempting alternative mobile Google Sign-In (no disconnect)...');

    // Try silent sign-in first, fallback to regular sign-in
    GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
    googleUser ??= await googleSignIn.signIn();

    if (googleUser == null) {
      throw Exception('Google sign in cancelled by user');
    }

    debugPrint('✅ Alternative Google user obtained: ${googleUser.email}');

    final googleAuth = await googleUser.authentication;

    if (googleAuth.accessToken == null || googleAuth.idToken == null) {
      throw Exception(
          'Failed to get Google authentication tokens. Check SHA-1 fingerprints in Firebase Console.');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    _currentUser = userCredential.user;
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      _loading = true;
      notifyListeners();

      debugPrint('🚀 OAuth ENABLED - Starting Google Sign-In - Build v3');
      debugPrint(
          '🔍 OAuth Platform Config: ${OAuthConfigService.getPlatformConfig()}');

      if (kIsWeb) {
        // Web implementation with improved CORS handling
        try {
          // Try popup method first
          GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          googleProvider.addScope('https://www.googleapis.com/auth/calendar');
          googleProvider.setCustomParameters({
            'prompt': 'select_account',
          });

          final credential = await _auth.signInWithPopup(googleProvider);
          _currentUser = credential.user;
        } catch (popupError) {
          debugPrint('Popup failed, trying redirect: $popupError');
          // Fallback to redirect method if popup fails due to CORS
          GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          googleProvider.addScope('https://www.googleapis.com/auth/calendar');

          await _auth.signInWithRedirect(googleProvider);
          // Note: signInWithRedirect will reload the page, so we won't reach here
          return;
        }
      } else {
        // Mobile implementation with enhanced error handling
        final GoogleSignIn googleSignIn =
            OAuthConfigService.getGoogleSignInInstance();

        debugPrint('🔄 Starting mobile Google Sign-In...');

        // Try to sign out and disconnect, but don't fail if disconnect fails
        try {
          await googleSignIn.signOut();
          debugPrint('✅ Google sign out successful');
        } catch (e) {
          debugPrint('⚠️ Google sign out failed (continuing anyway): $e');
        }

        try {
          await googleSignIn.disconnect();
          debugPrint('✅ Google disconnect successful');
        } catch (e) {
          debugPrint('⚠️ Google disconnect failed (continuing anyway): $e');
          // Don't throw here - disconnect failure is common and not critical
        }

        debugPrint('🔄 Attempting Google Sign-In...');
        GoogleSignInAccount? googleUser;

        // Try sign-in with retry logic
        int retryCount = 0;
        const maxRetries = 2;

        while (retryCount <= maxRetries) {
          try {
            googleUser = await googleSignIn.signIn();
            if (googleUser != null) {
              break; // Success!
            }
          } catch (e) {
            debugPrint('❌ Google sign-in attempt ${retryCount + 1} failed: $e');
            if (retryCount == maxRetries) {
              rethrow; // Final attempt failed
            }
            retryCount++;
            await Future.delayed(
                Duration(seconds: retryCount)); // Brief delay before retry
            continue;
          }

          if (googleUser == null && retryCount < maxRetries) {
            debugPrint('⚠️ Google sign-in returned null, retrying...');
            retryCount++;
            await Future.delayed(Duration(seconds: retryCount));
          } else {
            break;
          }
        }

        if (googleUser == null) {
          throw Exception(
              'Google sign in cancelled by user or failed after $maxRetries attempts');
        }

        debugPrint('✅ Google user obtained: ${googleUser.email}');

        final googleAuth = await googleUser.authentication;

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception(
              'Failed to get Google authentication tokens. Check SHA-1 fingerprints in Firebase Console.');
        }

        debugPrint('✅ Google authentication tokens obtained');

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        debugPrint('🔄 Signing in with Firebase...');
        final userCredential = await _auth.signInWithCredential(credential);
        _currentUser = userCredential.user;

        debugPrint('✅ Firebase sign-in successful');
      }

      debugPrint('Google sign in successful for user: ${_currentUser?.email}');

      _loading = false;
      notifyListeners();

      // Don't navigate here - let the auth state listener handle navigation
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');

      // If this is a mobile platform and we got a disconnect error, try alternative approach
      if (!kIsWeb && e.toString().contains('Failed to disconnect')) {
        debugPrint('🔄 Trying alternative mobile sign-in approach...');
        try {
          await _signInWithGoogleMobileAlternative();
          debugPrint('✅ Alternative mobile sign-in successful');
          _loading = false;
          notifyListeners();
          return; // Success with alternative approach
        } catch (altError) {
          debugPrint('❌ Alternative mobile sign-in also failed: $altError');
          // Continue with original error handling
        }
      }

      // Provide specific error messages for common issues
      String errorMessage = _getOAuthErrorMessage(e);
      debugPrint('📝 Error details: $errorMessage');

      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get user-friendly error message for OAuth errors
  String _getOAuthErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('cors')) {
      return 'CORS error: Please check your domain configuration in Google Cloud Console';
    } else if (errorString.contains('popup')) {
      return 'Popup blocked: Please allow popups for this site or try again';
    } else if (errorString.contains('network')) {
      return 'Network error: Please check your internet connection';
    } else if (errorString.contains('cancelled')) {
      return 'Sign-in was cancelled by user';
    } else if (errorString.contains('invalid_client')) {
      return 'Invalid client configuration: Please check your OAuth client ID';
    } else if (errorString.contains('unauthorized')) {
      return 'Unauthorized: Please check your app configuration in Google Cloud Console';
    } else if (errorString.contains('play services')) {
      return 'Google Play Services required: Please update Google Play Services';
    } else if (errorString.contains('sha-1') ||
        errorString.contains('fingerprint')) {
      return 'Android configuration error: SHA-1 fingerprints missing from Firebase Console';
    } else if (errorString.contains('package name')) {
      return 'App configuration error: Package name mismatch detected';
    } else if (errorString.contains('authentication tokens')) {
      return 'Authentication error: Check Firebase configuration and SHA-1 fingerprints';
    } else if (errorString.contains('google-services.json')) {
      return 'Configuration error: google-services.json may be outdated or missing';
    } else {
      return 'OAuth error: ${error.toString()}';
    }
  }

  /// Sign in with Manual OAuth (bypasses Firebase Auth Google Sign-In)
  Future<void> signInWithManualOAuth() async {
    try {
      _loading = true;
      notifyListeners();

      debugPrint('🔐 Starting manual OAuth sign-in...');

      if (kIsWeb) {
        // For web, initiate OAuth flow
        final result = await ManualOAuthService.signInWeb();
        if (result != null && result['status'] == 'redirect_initiated') {
          debugPrint('✅ OAuth redirect initiated');
          // The callback will be handled by OAuthCallbackPage
        }
      } else {
        // For mobile, implement mobile OAuth flow
        throw UnimplementedError('Mobile OAuth not yet implemented');
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Manual OAuth sign-in error: $e');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Handle successful manual OAuth callback
  Future<void> handleManualOAuthSuccess(Map<String, dynamic> userData) async {
    try {
      debugPrint('🎉 Handling manual OAuth success for: ${userData['email']}');

      // Create a custom user object for compatibility
      _currentUser = await _createCustomFirebaseUser(userData);

      // Store user session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', userData['id']);
      await prefs.setString('auth_method', 'manual_oauth');

      // Check admin status
      await _checkAndSetAdminStatus();

      debugPrint('✅ Manual OAuth success handled');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error handling manual OAuth success: $e');
      rethrow;
    }
  }

  /// Create a custom Firebase user from OAuth data
  Future<User?> _createCustomFirebaseUser(Map<String, dynamic> userData) async {
    try {
      // For now, we'll create a Firebase user with email/password
      // This is a workaround to maintain compatibility with existing code

      // Try to create a new Firebase user
      // If user already exists, this will throw an exception
      try {
        final tempPassword = _generateTempPassword();
        final credential = await _auth.createUserWithEmailAndPassword(
          email: userData['email'],
          password: tempPassword,
        );

        // Update display name and photo
        await credential.user?.updateDisplayName(userData['name']);
        await credential.user?.updatePhotoURL(userData['picture']);
        await credential.user?.reload();

        debugPrint('✅ Created new Firebase user for OAuth');
        return _auth.currentUser;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // User already exists, that's fine for OAuth
          debugPrint(
              '⚠️ User already exists in Firebase Auth, using OAuth data');
          return _auth.currentUser;
        } else {
          debugPrint('❌ Firebase user creation failed: ${e.message}');
          return null;
        }
      }
    } catch (e) {
      debugPrint('❌ Error creating custom Firebase user: $e');
      // Return null if Firebase user creation fails
      return null;
    }
  }

  /// Generate temporary password for Firebase user creation
  String _generateTempPassword() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'TempPass$random!';
  }

  /// Check if user is authenticated via manual OAuth
  Future<bool> isManualOAuthUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authMethod = prefs.getString('auth_method');
      return authMethod == 'manual_oauth';
    } catch (e) {
      return false;
    }
  }

  /// Refresh manual OAuth tokens
  Future<void> refreshManualOAuthTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');

      if (userId != null) {
        final storageService = FirebaseAuthStorageService();
        final userData = await storageService.getUserData(userId);

        if (userData != null && userData['tokens'] != null) {
          final refreshToken = userData['tokens']['refresh_token'];
          if (refreshToken != null) {
            final newTokens =
                await ManualOAuthService.refreshToken(refreshToken);
            if (newTokens != null) {
              await storageService.updateUserTokens(userId, newTokens);
              debugPrint('✅ Manual OAuth tokens refreshed');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing manual OAuth tokens: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      _loading = true;
      notifyListeners();

      debugPrint(
          '🔄 AuthService - Sending password reset email to: ${email.split('@')[0]}@...');

      await _auth.sendPasswordResetEmail(email: email.trim());

      debugPrint('✅ AuthService - Password reset email sent successfully');

      _loading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ AuthService - Password reset email error: $e');
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await TokenStorageService.clearAll();

      // Check if this is a manual OAuth user
      final prefs = await SharedPreferences.getInstance();
      final authMethod = prefs.getString('auth_method');
      final userId = prefs.getString('current_user_id');

      if (authMethod == 'manual_oauth' && userId != null) {
        // Sign out from manual OAuth
        await ManualOAuthService.signOut(userId);
      } else {
        // Regular Firebase Auth sign out
        await _auth.signOut();

        // Also sign out from Google if needed
        if (!kIsWeb) {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          await googleSignIn.signOut();
        }
      }

      _currentUser = null;
      notifyListeners();

      navigatorKey.currentState?.pushReplacementNamed('/');
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      _loading = true;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Check if user has seen onboarding tour
  Future<bool> hasSeenOnboardingTour() async {
    try {
      if (_currentUser == null) return false;

      // Use direct Firestore calls for all platforms
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (!userDoc.exists) return false;

      final data = userDoc.data();
      if (data is Map<String, dynamic>) {
        return data['onboarding_tour_seen'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking onboarding tour status: $e');
      return false;
    }
  }

  /// Mark onboarding tour as seen
  Future<void> markOnboardingTourAsSeen() async {
    try {
      if (_currentUser == null) return;

      // Use direct Firestore calls for all platforms
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'onboarding_tour_seen': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Onboarding tour marked as seen');
    } catch (e) {
      debugPrint('Error marking onboarding tour as seen: $e');
      rethrow;
    }
  }

  /// Update onboarding completion status
  Future<void> updateOnboardingCompleted(bool completed) async {
    try {
      if (_currentUser == null) return;

      // Use direct Firestore calls for all platforms
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'onboarding_completed': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Onboarding completion updated: $completed');
    } catch (e) {
      debugPrint('Error updating onboarding completion: $e');
      rethrow;
    }
  }

  /// Check if onboarding is completed
  Future<bool> isOnboardingCompleted() async {
    try {
      if (_currentUser == null) return false;

      // Use direct Firestore calls for all platforms
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (!userDoc.exists) return false;

      final data = userDoc.data();
      if (data is Map<String, dynamic>) {
        return data['onboarding_completed'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking onboarding completion: $e');
      return false;
    }
  }

  /// Update user profile data
  Future<void> updateUserData(Map<String, dynamic> data) async {
    try {
      if (_currentUser == null) return;

      final updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
        ...data,
      };

      // Use direct Firestore calls for all platforms
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updateData);

      debugPrint('User data updated successfully');
    } catch (e) {
      debugPrint('Error updating user data: $e');
      rethrow;
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (_currentUser == null) return null;

      // Use direct Firestore calls for all platforms
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      final data = userDoc.data();
      if (data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  /// Refresh user data from Firebase Auth
  Future<void> refreshUserData() async {
    try {
      if (_currentUser != null) {
        await _currentUser!.reload();
        _currentUser = _auth.currentUser;
        debugPrint('✅ User data refreshed');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing user data: $e');
    }
  }
}
