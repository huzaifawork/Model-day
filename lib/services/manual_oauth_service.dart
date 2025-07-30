import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_auth_storage_service.dart';

class ManualOAuthService {
  // OAuth Configuration - Now enabled with actual credentials
  static const String _clientId =
      '373125623062-6tlqmnc91u973gtdivp9urfilorekb3e.apps.googleusercontent.com'; // Web client ID
  static const String _clientSecret =
      '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'; // OAuth client secret

  // OAuth Endpoints
  static const String _authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String _userInfoEndpoint =
      'https://www.googleapis.com/oauth2/v2/userinfo';

  // Redirect URIs - Fully dynamic based on current URL
  static String _getWebRedirectUri() {
    if (kIsWeb) {
      final currentUrl = Uri.base;
      // Always use the current URL dynamically
      return '${currentUrl.scheme}://${currentUrl.host}/auth/callback';
    }
    return 'http://localhost:3000/auth/callback'; // Fallback for non-web
  }
  // Mobile redirect URI for future implementation
  // static const String _mobileRedirectUri = 'com.example.newFlutter://oauth';

  // Scopes
  static const List<String> _scopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar'
  ];

  static final FirebaseAuthStorageService _storageService =
      FirebaseAuthStorageService();

  /// Generate a secure random string for state parameter
  static String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Generate PKCE code verifier and challenge
  static Map<String, String> _generatePKCE() {
    final codeVerifier = _generateRandomString(128);
    // For simplicity, using plain challenge (in production, use S256)
    return {
      'code_verifier': codeVerifier,
      'code_challenge': codeVerifier,
      'code_challenge_method': 'plain'
    };
  }

  /// Build authorization URL
  static String _buildAuthUrl({
    required String redirectUri,
    required String state,
    String? codeChallenge,
    String? codeChallengeMethod,
  }) {
    final params = {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'state': state,
      'access_type': 'offline',
      'prompt': 'consent',
      'include_granted_scopes': 'true',
    };

    if (codeChallenge != null) {
      params['code_challenge'] = codeChallenge;
      params['code_challenge_method'] = codeChallengeMethod ?? 'plain';
    }

    final uri = Uri.parse(_authEndpoint).replace(queryParameters: params);
    return uri.toString();
  }

  /// Start OAuth flow for web
  static Future<Map<String, dynamic>?> signInWeb() async {
    try {
      debugPrint('🌐 Starting web OAuth flow...');

      final state = _generateRandomString(32);
      final pkce = _generatePKCE();

      // Store state and PKCE for verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('oauth_state', state);
      await prefs.setString('oauth_code_verifier', pkce['code_verifier']!);

      final redirectUri = _getWebRedirectUri();
      final authUrl = _buildAuthUrl(
        redirectUri: redirectUri,
        state: state,
        codeChallenge: pkce['code_challenge'],
        codeChallengeMethod: pkce['code_challenge_method'],
      );

      debugPrint('🔗 Auth URL: $authUrl');
      debugPrint('🔗 Redirect URI: $redirectUri');
      debugPrint('🔗 Client ID: $_clientId');

      // Copy URL to clipboard for manual testing if needed
      debugPrint('🔗 COPY THIS URL TO TEST MANUALLY: $authUrl');

      // Launch OAuth URL
      if (await canLaunchUrl(Uri.parse(authUrl))) {
        if (kIsWeb) {
          // For web, use external application mode to open in same tab
          await launchUrl(
            Uri.parse(authUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          // For mobile, use platform default
          await launchUrl(
            Uri.parse(authUrl),
            mode: LaunchMode.platformDefault,
          );
        }
        return {'status': 'redirect_initiated'};
      } else {
        throw Exception('Could not launch OAuth URL');
      }
    } catch (e) {
      debugPrint('❌ Web OAuth error: $e');
      rethrow;
    }
  }

  /// Handle OAuth callback (authorization code)
  static Future<Map<String, dynamic>?> handleCallback({
    required String code,
    required String state,
  }) async {
    try {
      debugPrint('🔄 Handling OAuth callback...');

      // Verify state parameter
      final prefs = await SharedPreferences.getInstance();
      final storedState = prefs.getString('oauth_state');
      if (storedState != state) {
        throw Exception('Invalid state parameter');
      }

      final codeVerifier = prefs.getString('oauth_code_verifier');

      // Exchange authorization code for tokens
      final tokenData = await _exchangeCodeForTokens(
        code: code,
        redirectUri: _getWebRedirectUri(),
        codeVerifier: codeVerifier,
      );

      // Get user info
      final userInfo = await _getUserInfo(tokenData['access_token']);

      // Store user data in Firebase Storage
      final userData = {
        'id': userInfo['id'],
        'email': userInfo['email'],
        'name': userInfo['name'],
        'picture': userInfo['picture'],
        'verified_email': userInfo['verified_email'],
        'tokens': tokenData,
        'last_login': DateTime.now().toIso8601String(),
      };

      await _storageService.storeUserData(userInfo['id'], userData);

      // Clean up stored state
      await prefs.remove('oauth_state');
      await prefs.remove('oauth_code_verifier');

      debugPrint('✅ OAuth callback handled successfully');
      return userData;
    } catch (e) {
      debugPrint('❌ OAuth callback error: $e');
      rethrow;
    }
  }

  /// Exchange authorization code for access and refresh tokens
  static Future<Map<String, dynamic>> _exchangeCodeForTokens({
    required String code,
    required String redirectUri,
    String? codeVerifier,
  }) async {
    try {
      debugPrint('🔄 Exchanging code for tokens...');

      final body = {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      };

      if (codeVerifier != null) {
        body['code_verifier'] = codeVerifier;
      }

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Token exchange successful');
        return data;
      } else {
        debugPrint('❌ Token exchange failed: ${response.body}');
        throw Exception('Token exchange failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Token exchange error: $e');
      rethrow;
    }
  }

  /// Get user information using access token
  static Future<Map<String, dynamic>> _getUserInfo(String accessToken) async {
    try {
      debugPrint('👤 Getting user info...');

      final response = await http.get(
        Uri.parse(_userInfoEndpoint),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final userInfo = json.decode(response.body);
        debugPrint('✅ User info retrieved: ${userInfo['email']}');
        return userInfo;
      } else {
        throw Exception('Failed to get user info: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Get user info error: $e');
      rethrow;
    }
  }

  /// Refresh access token using refresh token
  static Future<Map<String, dynamic>?> refreshToken(String refreshToken) async {
    try {
      debugPrint('🔄 Refreshing access token...');

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Token refresh successful');
        return data;
      } else {
        debugPrint('❌ Token refresh failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Token refresh error: $e');
      return null;
    }
  }

  /// Sign out user
  static Future<void> signOut(String userId) async {
    try {
      debugPrint('👋 Signing out user: $userId');
      await _storageService.clearUserData(userId);

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('oauth_state');
      await prefs.remove('oauth_code_verifier');
      await prefs.remove('current_user_id');

      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');

      if (userId != null) {
        return await _storageService.getUserData(userId);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Get current user error: $e');
      return null;
    }
  }
}
