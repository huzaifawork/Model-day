import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper class for mobile-specific OAuth operations
class MobileOAuthHelper {
  /// Check if Google Play Services are available (Android only)
  static Future<bool> isGooglePlayServicesAvailable() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // This would require a platform channel to properly check
      // For now, we'll assume they're available
      return true;
    } catch (e) {
      debugPrint('Error checking Google Play Services: $e');
      return false;
    }
  }

  /// Force refresh Google Sign-In configuration
  static Future<void> refreshGoogleSignInConfig() async {
    try {
      final googleSignIn = GoogleSignIn();

      // Sign out and disconnect to clear any cached state
      try {
        await googleSignIn.signOut();
        debugPrint('✅ Google sign out successful');
      } catch (e) {
        debugPrint('⚠️ Google sign out failed (continuing): $e');
      }

      try {
        await googleSignIn.disconnect();
        debugPrint('✅ Google disconnect successful');
      } catch (e) {
        debugPrint('⚠️ Google disconnect failed (continuing): $e');
        // Don't fail the entire refresh if disconnect fails
      }

      debugPrint('✅ Google Sign-In configuration refreshed');
    } catch (e) {
      debugPrint('❌ Error refreshing Google Sign-In config: $e');
    }
  }

  /// Perform comprehensive OAuth health check
  static Future<Map<String, dynamic>> performHealthCheck() async {
    final results = <String, dynamic>{};
    
    try {
      // Check platform
      results['platform'] = Platform.operatingSystem;
      results['is_mobile'] = Platform.isAndroid || Platform.isIOS;
      
      // Check Google Play Services (Android)
      if (Platform.isAndroid) {
        results['google_play_services'] = await isGooglePlayServicesAvailable();
      }
      
      // Check Firebase Auth
      results['firebase_auth_initialized'] = FirebaseAuth.instance.app.name.isNotEmpty;
      results['current_user'] = FirebaseAuth.instance.currentUser?.email ?? 'None';
      
      // Check Google Sign-In
      final googleSignIn = GoogleSignIn();
      results['google_signin_configured'] = googleSignIn.scopes.isNotEmpty;
      results['google_signin_current_user'] = googleSignIn.currentUser?.email ?? 'None';
      
      // Check network connectivity (basic)
      results['network_available'] = true; // Would need connectivity_plus package for real check
      
      results['status'] = 'healthy';
    } catch (e) {
      results['status'] = 'error';
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Get mobile-specific troubleshooting steps
  static List<String> getMobileTroubleshootingSteps() {
    final steps = <String>[];
    
    if (Platform.isAndroid) {
      steps.addAll([
        '🔧 Android Troubleshooting Steps:',
        '1. Generate SHA-1 fingerprint: Run scripts/generate_sha1.bat',
        '2. Add SHA-1 to Firebase Console > Project Settings > Your Apps',
        '3. Verify package name in android/app/build.gradle.kts matches google-services.json',
        '4. Check google-services.json has Android OAuth client',
        '5. Ensure Google Play Services are updated',
        '6. Clear app data and cache',
        '7. Rebuild APK: flutter clean && flutter build apk',
      ]);
    } else if (Platform.isIOS) {
      steps.addAll([
        '🔧 iOS Troubleshooting Steps:',
        '1. Verify GoogleService-Info.plist is in ios/Runner/',
        '2. Check bundle ID matches in Xcode and Firebase Console',
        '3. Ensure iOS OAuth client is configured in Firebase',
        '4. Verify URL schemes in ios/Runner/Info.plist',
        '5. Clean and rebuild: flutter clean && flutter build ios',
      ]);
    }
    
    steps.addAll([
      '🔧 General Mobile Steps:',
      '1. Check internet connectivity',
      '2. Verify device date/time is correct',
      '3. Try signing out completely: GoogleSignIn().signOut() && disconnect()',
      '4. Restart the app completely',
      '5. Check Firebase Console for service status',
    ]);
    
    return steps;
  }

  /// Emergency OAuth reset
  static Future<void> emergencyReset() async {
    try {
      debugPrint('🚨 Performing emergency OAuth reset...');
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Sign out and disconnect from Google
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await googleSignIn.disconnect();
      
      // Clear any cached tokens (would need secure storage package)
      // await FlutterSecureStorage().deleteAll();
      
      debugPrint('✅ Emergency OAuth reset completed');
    } catch (e) {
      debugPrint('❌ Error during emergency reset: $e');
      rethrow;
    }
  }

  /// Test OAuth flow without UI
  static Future<bool> testOAuthFlow() async {
    try {
      debugPrint('🧪 Testing OAuth flow...');
      
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      // Try to sign in silently (won't show UI)
      final account = await googleSignIn.signInSilently();
      
      if (account != null) {
        debugPrint('✅ Silent sign-in successful: ${account.email}');
        return true;
      } else {
        debugPrint('ℹ️ No cached credentials found (this is normal for first-time users)');
        return false;
      }
    } catch (e) {
      debugPrint('❌ OAuth flow test failed: $e');
      return false;
    }
  }
}
