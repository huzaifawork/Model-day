import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseAuthStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _usersPath = 'oauth_users';

  /// Store user authentication data in Firebase Storage
  Future<void> storeUserData(String userId, Map<String, dynamic> userData) async {
    try {
      debugPrint('💾 Storing user data for: $userId');
      
      // Create user directory structure
      final userPath = '$_usersPath/$userId';
      
      // Store profile data
      final profileData = {
        'id': userData['id'],
        'email': userData['email'],
        'name': userData['name'],
        'picture': userData['picture'],
        'verified_email': userData['verified_email'],
        'created_at': userData['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _uploadJsonFile('$userPath/profile.json', profileData);
      
      // Store token data (sensitive)
      final tokenData = {
        'access_token': userData['tokens']['access_token'],
        'refresh_token': userData['tokens']['refresh_token'],
        'expires_in': userData['tokens']['expires_in'],
        'token_type': userData['tokens']['token_type'],
        'scope': userData['tokens']['scope'],
        'expires_at': _calculateExpiryTime(userData['tokens']['expires_in']),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _uploadJsonFile('$userPath/tokens.json', tokenData);
      
      // Store verification and session data
      final verificationData = {
        'verified': true,
        'last_login': userData['last_login'],
        'login_count': await _incrementLoginCount(userId),
        'device_info': {
          'platform': kIsWeb ? 'web' : 'mobile',
          'user_agent': kIsWeb ? 'web_browser' : 'mobile_app',
        },
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _uploadJsonFile('$userPath/verification.json', verificationData);
      
      debugPrint('✅ User data stored successfully');
      
    } catch (e) {
      debugPrint('❌ Error storing user data: $e');
      rethrow;
    }
  }

  /// Retrieve user authentication data from Firebase Storage
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      debugPrint('📖 Retrieving user data for: $userId');
      
      final userPath = '$_usersPath/$userId';
      
      // Get profile data
      final profileData = await _downloadJsonFile('$userPath/profile.json');
      if (profileData == null) {
        debugPrint('❌ User profile not found');
        return null;
      }
      
      // Get token data
      final tokenData = await _downloadJsonFile('$userPath/tokens.json');
      
      // Get verification data
      final verificationData = await _downloadJsonFile('$userPath/verification.json');
      
      // Combine all data
      final userData = {
        ...profileData,
        'tokens': tokenData,
        'verification': verificationData,
      };
      
      debugPrint('✅ User data retrieved successfully');
      return userData;
      
    } catch (e) {
      debugPrint('❌ Error retrieving user data: $e');
      return null;
    }
  }

  /// Update user tokens (for token refresh)
  Future<void> updateUserTokens(String userId, Map<String, dynamic> newTokens) async {
    try {
      debugPrint('🔄 Updating tokens for user: $userId');
      
      final userPath = '$_usersPath/$userId';
      
      final tokenData = {
        'access_token': newTokens['access_token'],
        'refresh_token': newTokens['refresh_token'] ?? await _getExistingRefreshToken(userId),
        'expires_in': newTokens['expires_in'],
        'token_type': newTokens['token_type'],
        'scope': newTokens['scope'],
        'expires_at': _calculateExpiryTime(newTokens['expires_in']),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _uploadJsonFile('$userPath/tokens.json', tokenData);
      
      debugPrint('✅ User tokens updated successfully');
      
    } catch (e) {
      debugPrint('❌ Error updating user tokens: $e');
      rethrow;
    }
  }

  /// Clear user data (for sign out)
  Future<void> clearUserData(String userId) async {
    try {
      debugPrint('🗑️ Clearing user data for: $userId');
      
      final userPath = '$_usersPath/$userId';
      
      // Delete all user files
      await _deleteFile('$userPath/profile.json');
      await _deleteFile('$userPath/tokens.json');
      await _deleteFile('$userPath/verification.json');
      
      debugPrint('✅ User data cleared successfully');
      
    } catch (e) {
      debugPrint('❌ Error clearing user data: $e');
      // Don't rethrow - clearing should be best effort
    }
  }

  /// Check if user exists and is verified
  Future<bool> isUserVerified(String userId) async {
    try {
      final verificationData = await _downloadJsonFile('$_usersPath/$userId/verification.json');
      return verificationData?['verified'] == true;
    } catch (e) {
      debugPrint('❌ Error checking user verification: $e');
      return false;
    }
  }

  /// Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      debugPrint('🔍 Searching for user by email: $email');
      
      // List all users and find by email
      final listResult = await _storage.ref(_usersPath).listAll();
      
      for (final item in listResult.prefixes) {
        final userId = item.name;
        final profileData = await _downloadJsonFile('$_usersPath/$userId/profile.json');
        
        if (profileData != null && profileData['email'] == email) {
          return await getUserData(userId);
        }
      }
      
      debugPrint('❌ User not found by email');
      return null;
      
    } catch (e) {
      debugPrint('❌ Error searching user by email: $e');
      return null;
    }
  }

  /// Upload JSON data to Firebase Storage
  Future<void> _uploadJsonFile(String path, Map<String, dynamic> data) async {
    try {
      final jsonString = json.encode(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      final ref = _storage.ref(path);
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/json',
          customMetadata: {
            'uploaded_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      
    } catch (e) {
      debugPrint('❌ Error uploading JSON file: $e');
      rethrow;
    }
  }

  /// Download JSON data from Firebase Storage
  Future<Map<String, dynamic>?> _downloadJsonFile(String path) async {
    try {
      final ref = _storage.ref(path);
      final bytes = await ref.getData();
      
      if (bytes != null) {
        final jsonString = utf8.decode(bytes);
        return json.decode(jsonString);
      }
      
      return null;
      
    } catch (e) {
      if (e.toString().contains('object-not-found')) {
        debugPrint('📄 File not found: $path');
        return null;
      }
      debugPrint('❌ Error downloading JSON file: $e');
      rethrow;
    }
  }

  /// Delete file from Firebase Storage
  Future<void> _deleteFile(String path) async {
    try {
      final ref = _storage.ref(path);
      await ref.delete();
    } catch (e) {
      if (!e.toString().contains('object-not-found')) {
        debugPrint('❌ Error deleting file: $e');
      }
    }
  }

  /// Calculate token expiry time
  String _calculateExpiryTime(dynamic expiresIn) {
    try {
      final expiresInSeconds = int.parse(expiresIn.toString());
      final expiryTime = DateTime.now().add(Duration(seconds: expiresInSeconds));
      return expiryTime.toIso8601String();
    } catch (e) {
      // Default to 1 hour if parsing fails
      final expiryTime = DateTime.now().add(const Duration(hours: 1));
      return expiryTime.toIso8601String();
    }
  }

  /// Get existing refresh token
  Future<String?> _getExistingRefreshToken(String userId) async {
    try {
      final tokenData = await _downloadJsonFile('$_usersPath/$userId/tokens.json');
      return tokenData?['refresh_token'];
    } catch (e) {
      return null;
    }
  }

  /// Increment login count
  Future<int> _incrementLoginCount(String userId) async {
    try {
      final verificationData = await _downloadJsonFile('$_usersPath/$userId/verification.json');
      final currentCount = verificationData?['login_count'] ?? 0;
      return currentCount + 1;
    } catch (e) {
      return 1;
    }
  }

  /// List all users (admin function)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      debugPrint('📋 Listing all users...');
      
      final users = <Map<String, dynamic>>[];
      final listResult = await _storage.ref(_usersPath).listAll();
      
      for (final item in listResult.prefixes) {
        final userId = item.name;
        final userData = await getUserData(userId);
        if (userData != null) {
          users.add(userData);
        }
      }
      
      debugPrint('✅ Found ${users.length} users');
      return users;
      
    } catch (e) {
      debugPrint('❌ Error listing users: $e');
      return [];
    }
  }
}
