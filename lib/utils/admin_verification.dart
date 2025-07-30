import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

/// Utility class to verify and debug admin authentication setup
class AdminVerification {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Comprehensive admin verification and debugging
  static Future<void> verifyAdminSetup() async {
    developer.log('🔍 ADMIN VERIFICATION STARTING...', name: 'AdminVerification');
    developer.log('=' * 50, name: 'AdminVerification');

    // 1. Check Firebase Auth user
    await _checkAuthUser();

    // 2. Check Firestore permissions
    await _checkFirestorePermissions();

    // 3. Check admin document
    await _checkAdminDocument();

    // 4. Test admin query
    await _testAdminQuery();

    developer.log('=' * 50, name: 'AdminVerification');
    developer.log('🔍 ADMIN VERIFICATION COMPLETE', name: 'AdminVerification');
  }

  static Future<void> _checkAuthUser() async {
    developer.log('\n1. 👤 CHECKING FIREBASE AUTH USER...', name: 'AdminVerification');

    final user = _auth.currentUser;
    if (user != null) {
      developer.log('✅ User authenticated: ${user.email}', name: 'AdminVerification');
      developer.log('   - UID: ${user.uid}', name: 'AdminVerification');
      developer.log('   - Email verified: ${user.emailVerified}', name: 'AdminVerification');
    } else {
      developer.log('❌ No user authenticated', name: 'AdminVerification');
    }
  }

  static Future<void> _checkFirestorePermissions() async {
    developer.log('\n2. 🔒 CHECKING FIRESTORE PERMISSIONS...', name: 'AdminVerification');

    try {
      // Try to read from a test collection
      await _firestore.collection('test').limit(1).get();
      developer.log('✅ Basic Firestore read permissions: OK', name: 'AdminVerification');
    } catch (e) {
      developer.log('❌ Basic Firestore permissions failed: $e', name: 'AdminVerification');
    }
  }

  static Future<void> _checkAdminDocument() async {
    developer.log('\n3. 📄 CHECKING ADMIN DOCUMENT...', name: 'AdminVerification');

    final user = _auth.currentUser;
    if (user == null) {
      developer.log('❌ Cannot check admin document - no authenticated user', name: 'AdminVerification');
      return;
    }

    try {
      // Check if admin document exists by email
      final adminQuery = await _firestore
          .collection('admins')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final adminDoc = adminQuery.docs.first;
        developer.log('✅ Admin document found:', name: 'AdminVerification');
        developer.log('   - Document ID: ${adminDoc.id}', name: 'AdminVerification');
        developer.log('   - Email: ${adminDoc.data()['email']}', name: 'AdminVerification');
        developer.log('   - Role: ${adminDoc.data()['role']}', name: 'AdminVerification');
        developer.log('   - Active: ${adminDoc.data()['is_active']}', name: 'AdminVerification');
        developer.log('   - Permissions: ${adminDoc.data()['permissions']}', name: 'AdminVerification');
      } else {
        developer.log('❌ Admin document NOT found for email: ${user.email}', name: 'AdminVerification');
        developer.log('   📋 TO FIX: Create admin document in Firestore', name: 'AdminVerification');
        developer.log('   Collection: admins', name: 'AdminVerification');
        developer.log('   Document ID: ${user.email}', name: 'AdminVerification');
        developer.log('   Required fields: email, role, is_active, permissions', name: 'AdminVerification');
      }
    } catch (e) {
      developer.log('❌ Error checking admin document: $e', name: 'AdminVerification');
      if (e.toString().contains('permission-denied')) {
        developer.log('   📋 TO FIX: Apply Firestore security rules', name: 'AdminVerification');
        developer.log('   Rules file: firestore.rules', name: 'AdminVerification');
      }
    }
  }

  static Future<void> _testAdminQuery() async {
    developer.log('\n4. 🧪 TESTING ADMIN QUERY...', name: 'AdminVerification');

    final user = _auth.currentUser;
    if (user == null) {
      developer.log('❌ Cannot test admin query - no authenticated user', name: 'AdminVerification');
      return;
    }

    try {
      // Test the exact query used by AdminService
      developer.log('   Testing query: admins where email == ${user.email}', name: 'AdminVerification');

      final querySnapshot = await _firestore
          .collection('admins')
          .where('email', isEqualTo: user.email)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        developer.log('✅ Admin query successful - user is admin', name: 'AdminVerification');
        final doc = querySnapshot.docs.first;
        developer.log('   - Found document: ${doc.id}', name: 'AdminVerification');
        developer.log('   - Role: ${doc.data()['role']}', name: 'AdminVerification');
      } else {
        developer.log('❌ Admin query returned no results', name: 'AdminVerification');
        developer.log('   Either document doesn\'t exist or is_active = false', name: 'AdminVerification');
      }
    } catch (e) {
      developer.log('❌ Admin query failed: $e', name: 'AdminVerification');
    }
  }

  /// Quick admin status check
  static Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final querySnapshot = await _firestore
          .collection('admins')
          .where('email', isEqualTo: user.email)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      developer.log('❌ Error checking admin status: $e', name: 'AdminVerification');
      return false;
    }
  }
}
