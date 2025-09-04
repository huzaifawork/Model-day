import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service to handle password linking for Google-authenticated users
/// This service processes password link requests and manages the linking flow
class PasswordLinkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _passwordLinkRequestsCollection = 'password_link_requests';
  static const String _usersCollection = 'users';
  
  /// Process pending password link requests
  /// This method should be called periodically or triggered by cloud functions
  static Future<void> processPendingRequests() async {
    try {
      debugPrint('🔄 PasswordLinkService - Processing pending password link requests');
      
      // Get all pending requests
      final pendingRequests = await _firestore
          .collection(_passwordLinkRequestsCollection)
          .where('status', isEqualTo: 'pending')
          .where('request_type', isEqualTo: 'google_account_linking')
          .limit(10) // Process in batches
          .get();
      
      if (pendingRequests.docs.isEmpty) {
        debugPrint('✅ No pending password link requests found');
        return;
      }
      
      debugPrint('📋 Found ${pendingRequests.docs.length} pending requests');
      
      for (final requestDoc in pendingRequests.docs) {
        await _processPasswordLinkRequest(requestDoc);
      }
      
    } catch (e) {
      debugPrint('❌ PasswordLinkService - Error processing requests: $e');
      rethrow;
    }
  }
  
  /// Process a single password link request
  static Future<void> _processPasswordLinkRequest(QueryDocumentSnapshot requestDoc) async {
    try {
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final email = requestData['email'] as String;
      final userId = requestData['user_id'] as String;
      final tempPassword = requestData['temp_password'] as String;
      
      debugPrint('🔗 Processing password link for user: ${email.split('@')[0]}@...');
      
      // Update request status to processing
      await requestDoc.reference.update({
        'status': 'processing',
        'processed_at': FieldValue.serverTimestamp(),
      });
      
      // Check if user still exists and is Google-only
      bool isGoogleAccount = false;
      bool hasPasswordAuth = false;
      bool userExists = false;
      
      try {
        // Try to sign in with email to check if it exists
        try {
          // This will throw an exception if the email doesn't exist
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: 'dummy-password-that-will-fail'
          );
          // We should never reach here as the password is incorrect
          userExists = true;
        } catch (signInError) {
          if (signInError is FirebaseAuthException) {
            if (signInError.code == 'user-not-found') {
              // Email doesn't exist
              userExists = false;
            } else if (signInError.code == 'wrong-password') {
              // Email exists but password is wrong (which is expected)
              userExists = true;
              
              // For wrong password, we know the user exists
              // Check if this is a Google account by examining the error
              if (signInError.message?.contains('Google') ?? false) {
                isGoogleAccount = true;
              }
              
              // Since we got 'wrong-password', there must be a password provider
              hasPasswordAuth = true;
            }
          }
        }
      } catch (e) {
        // User likely doesn't exist
        await _markRequestFailed(requestDoc.reference, 'User not found');
        return;
      }
      
      if (!userExists) {
        await _markRequestFailed(requestDoc.reference, 'User not found');
        return;
      }
      
      if (hasPasswordAuth) {
        // User already has password authentication
        await _markRequestCompleted(requestDoc.reference, 'Password already exists');
        return;
      }
      
      if (!isGoogleAccount) {
        await _markRequestFailed(requestDoc.reference, 'Not a Google account');
        return;
      }
      
      // Create a secure password hash for storage
      final hashedPassword = _hashPassword(tempPassword);
      
      // Update user document with password linking information
      await _firestore.collection(_usersCollection).doc(userId).update({
        'password_linked': true,
        'password_linked_at': FieldValue.serverTimestamp(),
        'auth_methods': FieldValue.arrayUnion(['google.com', 'password']),
        'temp_password_hash': hashedPassword,
        'password_link_completed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send password reset email through Firebase Auth
      await _auth.sendPasswordResetEmail(email: email);
      
      // Mark request as completed
      await _markRequestCompleted(requestDoc.reference, 'Password linked successfully');
      
      debugPrint('✅ Password linking completed for user: ${email.split('@')[0]}@...');
      
    } catch (e) {
      debugPrint('❌ Error processing password link request: $e');
      await _markRequestFailed(requestDoc.reference, e.toString());
    }
  }
  
  /// Mark a request as completed
  static Future<void> _markRequestCompleted(DocumentReference requestRef, String message) async {
    await requestRef.update({
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
      'completion_message': message,
    });
  }
  
  /// Mark a request as failed
  static Future<void> _markRequestFailed(DocumentReference requestRef, String error) async {
    await requestRef.update({
      'status': 'failed',
      'failed_at': FieldValue.serverTimestamp(),
      'error_message': error,
    });
  }
  
  /// Hash password for secure storage
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Get password link request status for a user
  static Future<Map<String, dynamic>?> getPasswordLinkStatus(String email) async {
    try {
      final requests = await _firestore
          .collection(_passwordLinkRequestsCollection)
          .where('email', isEqualTo: email)
          .where('request_type', isEqualTo: 'google_account_linking')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();
      
      if (requests.docs.isEmpty) {
        return null;
      }
      
      final requestData = requests.docs.first.data();
      return {
        'status': requestData['status'],
        'created_at': requestData['created_at'],
        'processed_at': requestData['processed_at'],
        'completed_at': requestData['completed_at'],
        'failed_at': requestData['failed_at'],
        'error_message': requestData['error_message'],
        'completion_message': requestData['completion_message'],
      };
    } catch (e) {
      debugPrint('❌ Error getting password link status: $e');
      return null;
    }
  }
  
  /// Check if a user has a pending password link request
  static Future<bool> hasPendingPasswordLinkRequest(String email) async {
    try {
      final requests = await _firestore
          .collection(_passwordLinkRequestsCollection)
          .where('email', isEqualTo: email)
          .where('status', whereIn: ['pending', 'processing'])
          .where('request_type', isEqualTo: 'google_account_linking')
          .limit(1)
          .get();
      
      return requests.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking pending requests: $e');
      return false;
    }
  }
  
  /// Clean up old completed/failed requests (older than 30 days)
  static Future<void> cleanupOldRequests() async {
    try {
      debugPrint('🧹 PasswordLinkService - Cleaning up old requests');
      
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final oldRequests = await _firestore
          .collection(_passwordLinkRequestsCollection)
          .where('status', whereIn: ['completed', 'failed'])
          .where('created_at', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .limit(50)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in oldRequests.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('✅ Cleaned up ${oldRequests.docs.length} old requests');
      
    } catch (e) {
      debugPrint('❌ Error cleaning up old requests: $e');
    }
  }
  
  /// Verify if a Google user can have password linked
  static Future<bool> canLinkPasswordToGoogleAccount(String email) async {
    try {
      // Check if user exists and is Google-only
      bool isGoogleAccount = false;
      bool hasPasswordAuth = false;
      bool userExists = false;
      
      try {
        // Try to sign in with email to check if it exists
        try {
          // This will throw an exception if the email doesn't exist
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: 'dummy-password-that-will-fail'
          );
          // We should never reach here as the password is incorrect
          userExists = true;
        } catch (signInError) {
          if (signInError is FirebaseAuthException) {
            if (signInError.code == 'user-not-found') {
              // Email doesn't exist
              userExists = false;
            } else if (signInError.code == 'wrong-password') {
              // Email exists but password is wrong (which is expected)
              userExists = true;
              
              // For wrong password, we know the user exists
              // Check if this is a Google account by examining the error
              if (signInError.message?.contains('Google') ?? false) {
                isGoogleAccount = true;
              }
              
              // Since we got 'wrong-password', there must be a password provider
              hasPasswordAuth = true;
            }
          }
        }
      } catch (e) {
        // User likely doesn't exist
        return false; // No account exists
      }
      
      if (!userExists) {
        return false; // No account exists
      }
      
      if (hasPasswordAuth) {
        return false; // Already has password
      }
      
      if (!isGoogleAccount) {
        return false; // Not a Google account
      }
      
      // Check if there's already a pending request
      final hasPending = await hasPendingPasswordLinkRequest(email);
      if (hasPending) {
        return false; // Already has pending request
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error checking if password can be linked: $e');
      return false;
    }
  }
  
  /// Initialize the service (call this on app startup)
  static Future<void> initialize() async {
    try {
      debugPrint('🚀 PasswordLinkService - Initializing');
      
      // Process any pending requests on startup
      await processPendingRequests();
      
      // Clean up old requests
      await cleanupOldRequests();
      
      debugPrint('✅ PasswordLinkService - Initialized successfully');
      
    } catch (e) {
      debugPrint('❌ PasswordLinkService - Initialization error: $e');
    }
  }
}