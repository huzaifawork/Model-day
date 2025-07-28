import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user.dart';

class UserService {
  static const String _collectionName = 'users';
  static final _firestore = FirebaseFirestore.instance;

  /// Get all users (for admin use)
  static Future<List<User>> getAllUsers() async {
    try {
      debugPrint('🔍 UserService.getAllUsers() - Starting to fetch users...');

      // First try without ordering to see if there are any users at all
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .get();

      debugPrint('🔍 UserService.getAllUsers() - Found ${querySnapshot.docs.length} documents');

      final users = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        debugPrint('🔍 UserService.getAllUsers() - Processing user: ${data['email']} (ID: ${doc.id})');

        // Convert Firestore timestamps
        if (data['created_date'] is Timestamp) {
          data['created_date'] = (data['created_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_date'] is Timestamp) {
          data['updated_date'] = (data['updated_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['last_login'] is Timestamp) {
          data['last_login'] = (data['last_login'] as Timestamp).toDate().toIso8601String();
        }

        return User.fromJson(data);
      }).toList();

      // Sort by created date in memory if available
      users.sort((a, b) {
        if (a.createdDate == null && b.createdDate == null) return 0;
        if (a.createdDate == null) return 1;
        if (b.createdDate == null) return -1;
        return b.createdDate!.compareTo(a.createdDate!);
      });

      debugPrint('🔍 UserService.getAllUsers() - Returning ${users.length} users');
      return users;
    } catch (e) {
      debugPrint('❌ Error getting all users: $e');
      return [];
    }
  }

  /// Get user by ID
  static Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;

        // Convert Firestore timestamps
        if (data['created_date'] is Timestamp) {
          data['created_date'] = (data['created_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_date'] is Timestamp) {
          data['updated_date'] = (data['updated_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['last_login'] is Timestamp) {
          data['last_login'] = (data['last_login'] as Timestamp).toDate().toIso8601String();
        }

        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Get user by email
  static Future<User?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id;

        // Convert Firestore timestamps
        if (data['created_date'] is Timestamp) {
          data['created_date'] = (data['created_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_date'] is Timestamp) {
          data['updated_date'] = (data['updated_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['last_login'] is Timestamp) {
          data['last_login'] = (data['last_login'] as Timestamp).toDate().toIso8601String();
        }

        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by email: $e');
      return null;
    }
  }

  /// Update user status (activate/deactivate)
  static Future<bool> updateUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        'is_active': isActive,
        'updated_date': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating user status: $e');
      return false;
    }
  }

  /// Delete user
  static Future<bool> deleteUser(String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  /// Get user statistics
  static Future<Map<String, int>> getUserStats() async {
    try {
      final allUsers = await getAllUsers();
      final activeUsers = allUsers.where((user) => user.isActive).length;
      final inactiveUsers = allUsers.where((user) => !user.isActive).length;

      return {
        'total': allUsers.length,
        'active': activeUsers,
        'inactive': inactiveUsers,
      };
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
      };
    }
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('🔑 UserService.sendPasswordResetEmail() - Sending reset email to: $email');
      await auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      debugPrint('✅ UserService.sendPasswordResetEmail() - Reset email sent successfully');
    } catch (e) {
      debugPrint('❌ UserService.sendPasswordResetEmail() - Error: $e');
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Set user password (Admin function)
  /// Note: This requires Firebase Admin SDK in production
  static Future<void> setUserPassword(String userId, String newPassword) async {
    try {
      debugPrint('🔑 UserService.setUserPassword() - Setting password for user: $userId');

      // For now, we'll simulate this functionality
      // In a real implementation, this would require Firebase Admin SDK
      // which can only be used on the server side

      // Since we can't directly set passwords from client-side Flutter,
      // we'll store a temporary password reset request in Firestore
      // and handle it on the backend

      await _firestore.collection('password_reset_requests').add({
        'user_id': userId,
        'new_password': newPassword, // In production, this should be hashed
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending',
        'created_by': auth.FirebaseAuth.instance.currentUser?.uid,
      });

      debugPrint('✅ UserService.setUserPassword() - Password reset request created');

      // For demo purposes, we'll also send a password reset email
      final user = await getUserById(userId);
      if (user != null) {
        await sendPasswordResetEmail(user.email);
      }

    } catch (e) {
      debugPrint('❌ UserService.setUserPassword() - Error: $e');
      throw Exception('Failed to set user password: $e');
    }
  }
}
