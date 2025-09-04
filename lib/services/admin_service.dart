import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin.dart';
import '../models/admin_stats.dart';
import '../models/support_message.dart';

class AdminService {
  static const String _collectionName = 'admins';
  static const String _activitiesCollectionName = 'admin_activities';

  // Default admin credentials (for initial setup)
  static const String defaultAdminEmail = 'admin@modelday.com';
  static const String defaultAdminPassword = 'admin123';

  /// Check if user is admin
  static Future<Admin?> getAdminByEmail(String email) async {
    try {
      debugPrint('🔍 AdminService.getAdminByEmail() called for: $email');
      final firestore = FirebaseFirestore.instance;

      debugPrint('🔍 Querying admins collection...');
      final querySnapshot = await firestore
          .collection(_collectionName)
          .where('email', isEqualTo: email)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      debugPrint('🔍 Query completed. Found ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id;

        debugPrint('✅ Admin document found:');
        debugPrint('   Document ID: ${doc.id}');
        debugPrint('   Email: ${data['email']}');
        debugPrint('   Name: ${data['name']}');
        debugPrint('   Role: ${data['role']}');
        debugPrint('   Active: ${data['is_active']}');

        // Convert Firestore timestamps to strings
        if (data['created_date'] is Timestamp) {
          data['created_date'] = (data['created_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_date'] is Timestamp) {
          data['updated_date'] = (data['updated_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['last_login'] is Timestamp) {
          data['last_login'] = (data['last_login'] as Timestamp).toDate().toIso8601String();
        }

        final admin = Admin.fromJson(data);
        debugPrint('✅ Admin object created successfully');
        return admin;
      } else {
        debugPrint('❌ No admin document found for email: $email');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting admin by email: $e');
      return null;
    }
  }

  /// Create initial admin if none exists
  static Future<bool> createInitialAdmin() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;

      // Check if any admin exists
      final existingAdmins = await firestore
          .collection(_collectionName)
          .limit(1)
          .get();

      if (existingAdmins.docs.isNotEmpty) {
        debugPrint('Admin already exists, skipping creation');
        return true;
      }

      debugPrint('Creating initial admin with email: $defaultAdminEmail');

      // First create Firebase Auth user
      try {
        await auth.createUserWithEmailAndPassword(
          email: defaultAdminEmail,
          password: defaultAdminPassword,
        );
        debugPrint('Firebase Auth user created successfully');

        // Update display name
        final user = auth.currentUser;
        if (user != null) {
          await user.updateDisplayName('Admin');
        }

        // Sign out immediately to avoid interfering with current session
        await auth.signOut();
      } catch (authError) {
        // If user already exists, that's fine
        if (authError.toString().contains('email-already-in-use')) {
          debugPrint('Firebase Auth user already exists, continuing...');
        } else {
          debugPrint('Error creating Firebase Auth user: $authError');
          // Continue anyway, maybe the user exists
        }
      }

      // Create default admin in Firestore
      final adminData = {
        'email': defaultAdminEmail,
        'name': 'Admin',
        'role': 'super_admin',
        'is_active': true,
        'created_date': FieldValue.serverTimestamp(),
        'updated_date': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
        'permissions': {
          'manage_admins': true,
          'manage_support': true,
          'manage_users': true,
          'system_settings': true,
          'view_stats': true,
        },
      };

      await firestore.collection(_collectionName).doc('admin').set(adminData);
      debugPrint('Initial admin created successfully in Firestore with document ID: admin');
      return true;
    } catch (e) {
      debugPrint('Error creating initial admin: $e');
      return false;
    }
  }

  /// Force create initial admin (for debugging)
  static Future<bool> forceCreateInitialAdmin() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;

      debugPrint('Force creating initial admin...');

      // Delete existing admin documents
      final existingAdmins = await firestore.collection(_collectionName).get();
      for (final doc in existingAdmins.docs) {
        await doc.reference.delete();
      }

      // Create Firebase Auth user
      try {
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: defaultAdminEmail,
          password: defaultAdminPassword,
        );

        if (userCredential.user != null) {
          await userCredential.user!.updateDisplayName('Admin');
        }

        // Sign out immediately
        await auth.signOut();
        debugPrint('Firebase Auth user created and signed out');
      } catch (authError) {
        debugPrint('Auth error (may be expected): $authError');
      }

      // Create admin in Firestore
      final adminData = {
        'email': defaultAdminEmail,
        'name': 'Admin',
        'role': 'super_admin',
        'is_active': true,
        'created_date': FieldValue.serverTimestamp(),
        'updated_date': FieldValue.serverTimestamp(),
        'last_login': FieldValue.serverTimestamp(),
        'permissions': {
          'manage_admins': true,
          'manage_support': true,
          'manage_users': true,
          'system_settings': true,
          'view_stats': true,
        },
      };

      await firestore.collection(_collectionName).doc('admin').set(adminData);
      debugPrint('Force created initial admin successfully with document ID: admin');
      return true;
    } catch (e) {
      debugPrint('Error force creating initial admin: $e');
      return false;
    }
  }

  /// Admin login
  static Future<Admin?> adminLogin(String email, String password) async {
    try {
      // First check if user is admin
      final admin = await getAdminByEmail(email);
      if (admin == null) {
        throw Exception('Admin not found');
      }

      // Try to sign in with Firebase Auth
      final auth = FirebaseAuth.instance;
      await auth.signInWithEmailAndPassword(email: email, password: password);

      // Update last login
      await updateAdminLastLogin(admin.id!);

      return admin;
    } catch (e) {
      debugPrint('Admin login error: $e');
      rethrow;
    }
  }

  /// Update admin last login
  static Future<void> updateAdminLastLogin(String adminId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection(_collectionName).doc(adminId).update({
        'last_login': FieldValue.serverTimestamp(),
        'updated_date': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating admin last login: $e');
    }
  }

  /// Get admin emails for filtering purposes
  static Future<Set<String>> _getAdminEmails() async {
    try {
      debugPrint('🔍 AdminService._getAdminEmails() - Fetching admin emails...');
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore.collection(_collectionName).get();
      
      final adminEmails = querySnapshot.docs
          .map((doc) => doc.data()['email'] as String?)
          .where((email) => email != null)
          .cast<String>()
          .toSet();
      
      debugPrint('🔍 AdminService._getAdminEmails() - Found ${adminEmails.length} admin emails: $adminEmails');
      return adminEmails;
    } catch (e) {
      debugPrint('❌ Error getting admin emails: $e');
      return <String>{};
    }
  }

  /// Get all admins
  static Future<List<Admin>> getAllAdmins() async {
    try {
      final firestore = FirebaseFirestore.instance;
      debugPrint('🔍 AdminService.getAllAdmins() - Fetching all admins...');

      final querySnapshot = await firestore
          .collection(_collectionName)
          .orderBy('created_date', descending: true)
          .get();

      debugPrint('🔍 AdminService.getAllAdmins() - Found ${querySnapshot.docs.length} admin documents');

      final admins = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        debugPrint('🔍 AdminService.getAllAdmins() - Processing admin: ${data['email']} (${data['name']}) - Role: ${data['role']}');

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

        return Admin.fromJson(data);
      }).toList();

      debugPrint('🔍 AdminService.getAllAdmins() - Returning ${admins.length} admins');
      return admins;
    } catch (e) {
      debugPrint('Error getting all admins: $e');
      return [];
    }
  }

  /// Create new admin
  static Future<Admin?> createAdmin(Map<String, dynamic> adminData) async {
    try {
      final firestore = FirebaseFirestore.instance;

      adminData['created_date'] = FieldValue.serverTimestamp();
      adminData['updated_date'] = FieldValue.serverTimestamp();
      adminData['is_active'] = true;

      final docRef = await firestore.collection(_collectionName).add(adminData);

      // Get the created document
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;

        // Convert timestamps
        if (data['created_date'] is Timestamp) {
          data['created_date'] = (data['created_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_date'] is Timestamp) {
          data['updated_date'] = (data['updated_date'] as Timestamp).toDate().toIso8601String();
        }

        return Admin.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating admin: $e');
      return null;
    }
  }

  /// Create new admin with Firebase Auth account
  static Future<Admin?> createAdminWithAuth(Map<String, dynamic> adminData) async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // Store current user to restore later
      final currentUser = auth.currentUser;

      // Extract password from admin data
      final password = adminData['password'] as String;
      final email = adminData['email'] as String;
      final name = adminData['name'] as String;

      // Remove password from admin data before storing in Firestore
      adminData.remove('password');

      // First, add admin data to Firestore while current admin is still authenticated
      adminData['created_date'] = FieldValue.serverTimestamp();
      adminData['updated_date'] = FieldValue.serverTimestamp();
      adminData['is_active'] = true;

      final docRef = await firestore.collection(_collectionName).add(adminData);

      // Now create Firebase Auth user
      try {
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          // Update display name
          await userCredential.user!.updateDisplayName(name);

          // Sign out the newly created user immediately
          await auth.signOut();

          // Re-authenticate the current admin if they were signed in
          if (currentUser != null) {
            // The admin auth service will handle re-authentication automatically
            debugPrint('Admin creation successful, current admin session will be restored');
          }
        }
      } catch (authError) {
        // If Firebase Auth creation fails, delete the Firestore document
        await docRef.delete();
        rethrow;
      }

      // Get the created document
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;

        // Convert timestamps
        if (data['created_date'] is Timestamp) {
          data['created_date'] = (data['created_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_date'] is Timestamp) {
          data['updated_date'] = (data['updated_date'] as Timestamp).toDate().toIso8601String();
        }

        return Admin.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating admin with auth: $e');
      return null;
    }
  }

  /// Update admin
  static Future<Admin?> updateAdmin(String adminId, Map<String, dynamic> adminData) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Create a copy of adminData to avoid modifying the original
      final updateData = Map<String, dynamic>.from(adminData);
      updateData['updated_date'] = FieldValue.serverTimestamp();

      await firestore.collection(_collectionName).doc(adminId).update(updateData);

      // Get the updated document after a short delay to ensure timestamp is processed
      await Future.delayed(const Duration(milliseconds: 100));
      final doc = await firestore.collection(_collectionName).doc(adminId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;

        // Convert timestamps
        if (data['created_date'] is Timestamp) {
          data['created_date'] = (data['created_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['updated_date'] is Timestamp) {
          data['updated_date'] = (data['updated_date'] as Timestamp).toDate().toIso8601String();
        }
        if (data['last_login'] is Timestamp) {
          data['last_login'] = (data['last_login'] as Timestamp).toDate().toIso8601String();
        }

        return Admin.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating admin: $e');
      return null;
    }
  }

  /// Delete admin (deactivate)
  static Future<bool> deleteAdmin(String adminId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection(_collectionName).doc(adminId).update({
        'is_active': false,
        'updated_date': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error deleting admin: $e');
      return false;
    }
  }

  /// Get admin statistics with time filter
  static Future<AdminStats> getAdminStats([String timeFilter = 'Month']) async {
    try {
      debugPrint('🔍 AdminService.getAdminStats() - Starting with filter: $timeFilter');
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Calculate start date based on filter
      DateTime startDate;
      switch (timeFilter) {
        case 'Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        case 'Month':
        default:
          startDate = DateTime(now.year, now.month, 1);
          break;
      }
      debugPrint('🔍 AdminService.getAdminStats() - Start date for filter: $startDate');

      // Get total users count (excluding admin users)
      debugPrint('🔍 AdminService.getAdminStats() - Fetching users collection...');
      final usersSnapshot = await firestore.collection('users').get();
      
      // Get admin emails to exclude from user count
      final adminEmails = await _getAdminEmails();
      
      // Filter out admin users from total count
      final nonAdminUsers = usersSnapshot.docs.where((doc) {
        final data = doc.data();
        final email = data['email'] as String?;
        return email != null && !adminEmails.contains(email);
      }).toList();
      
      final totalUsers = nonAdminUsers.length;
      debugPrint('🔍 AdminService.getAdminStats() - Total users found: $totalUsers (excluded ${adminEmails.length} admin users)');

      // Get new users in selected period - try both 'created_date' and 'createdAt' fields (excluding admin users)
      debugPrint('🔍 AdminService.getAdminStats() - Fetching new users since $startDate...');
      
      // Try with 'created_date' first (as seen in UserService)
      var newUsersSnapshot = await firestore
          .collection('users')
          .where('created_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();
      
      // If no results, try with 'createdAt' field
      if (newUsersSnapshot.docs.isEmpty) {
        debugPrint('🔍 AdminService.getAdminStats() - No users found with created_date, trying createdAt...');
        newUsersSnapshot = await firestore
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();
      }
      
      // Filter out admin users from new users count
      final newNonAdminUsers = newUsersSnapshot.docs.where((doc) {
        final data = doc.data();
        final email = data['email'] as String?;
        return email != null && !adminEmails.contains(email);
      }).toList();
      
      final newUsersThisMonth = newNonAdminUsers.length;
      debugPrint('🔍 AdminService.getAdminStats() - New users in period: $newUsersThisMonth (excluded admin users)');

      // Get total jobs count from root collection
      debugPrint('🔍 AdminService.getAdminStats() - Fetching jobs from root collection...');
      final jobsSnapshot = await firestore.collection('jobs').get();
      final totalJobs = jobsSnapshot.docs.length;
      debugPrint('🔍 AdminService.getAdminStats() - Total jobs found: $totalJobs');

      // Get new jobs in selected period using 'createdAt' field
      debugPrint('🔍 AdminService.getAdminStats() - Fetching new jobs since $startDate...');
      final newJobsSnapshot = await firestore
          .collection('jobs')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();
      final newJobsThisMonth = newJobsSnapshot.docs.length;
      debugPrint('🔍 AdminService.getAdminStats() - New jobs in period: $newJobsThisMonth');

      // Get total castings count from root collection
      debugPrint('🔍 AdminService.getAdminStats() - Fetching castings from root collection...');
      final castingsSnapshot = await firestore.collection('castings').get();
      final totalCastings = castingsSnapshot.docs.length;
      debugPrint('🔍 AdminService.getAdminStats() - Total castings found: $totalCastings');

      // Get new castings in selected period using 'createdAt' field
      debugPrint('🔍 AdminService.getAdminStats() - Fetching new castings since $startDate...');
      final newCastingsSnapshot = await firestore
          .collection('castings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();
      final newCastingsThisMonth = newCastingsSnapshot.docs.length;
      debugPrint('🔍 AdminService.getAdminStats() - New castings in period: $newCastingsThisMonth');

      // Get support messages count
      debugPrint('🔍 AdminService.getAdminStats() - Fetching support messages collection...');
      final supportSnapshot = await firestore.collection('support_messages').get();
      final supportMessages = supportSnapshot.docs.length;
      debugPrint('🔍 AdminService.getAdminStats() - Total support messages found: $supportMessages');

      // Get pending support messages
      debugPrint('🔍 AdminService.getAdminStats() - Fetching pending support messages...');
      final pendingSupportSnapshot = await firestore
          .collection('support_messages')
          .where('status', isEqualTo: 'pending')
          .get();
      final pendingSupportMessages = pendingSupportSnapshot.docs.length;
      debugPrint('🔍 AdminService.getAdminStats() - Pending support messages found: $pendingSupportMessages');

      // Get recent activities
      final activitiesSnapshot = await firestore
          .collection(_activitiesCollectionName)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final recentActivities = activitiesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        return RecentActivity.fromJson(data);
      }).toList();

      return AdminStats(
        totalUsers: totalUsers,
        totalJobs: totalJobs,
        totalCastings: totalCastings,
        supportMessages: supportMessages,
        pendingSupportMessages: pendingSupportMessages,
        activeUsers: totalUsers, // For now, assume all users are active
        newUsersThisMonth: newUsersThisMonth,
        newJobsThisMonth: newJobsThisMonth,
        newCastingsThisMonth: newCastingsThisMonth,
        recentActivities: recentActivities,
      );
    } catch (e) {
      debugPrint('Error getting admin stats: $e');
      return AdminStats();
    }
  }

  /// Get real-time stream of admin statistics
  static Stream<AdminStats> getAdminStatsStream([String timeFilter = 'Month']) async* {
    try {
      // Yield initial stats
      yield await getAdminStats(timeFilter);

      // Then yield updated stats every 30 seconds
      await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
        yield await getAdminStats(timeFilter);
      }
    } catch (e) {
      debugPrint('Error getting admin stats stream: $e');
      yield AdminStats();
    }
  }

  /// Get all support messages for admin
  static Future<List<SupportMessage>> getAllSupportMessages() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('support_messages')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        // Convert Firestore timestamp
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }

        return SupportMessage.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting all support messages: $e');
      return [];
    }
  }

  /// Get real-time stream of support messages
  static Stream<List<SupportMessage>> getSupportMessagesStream() {
    try {
      final firestore = FirebaseFirestore.instance;
      return firestore
          .collection('support_messages')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;

          // Convert Firestore timestamp
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          if (data['updatedAt'] is Timestamp) {
            data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
          }

          return SupportMessage.fromJson(data);
        }).toList();
      });
    } catch (e) {
      debugPrint('Error getting support messages stream: $e');
      return Stream.value([]);
    }
  }

  /// Update support message status
  static Future<bool> updateSupportMessageStatus(String messageId, String status) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('support_messages').doc(messageId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating support message status: $e');
      return false;
    }
  }

  /// Add admin response to support message
  static Future<bool> addSupportMessageResponse(String messageId, String response, String adminId) async {
    try {
      debugPrint('📝 Adding admin response - MessageID: $messageId, AdminID: $adminId, Response: $response');

      final firestore = FirebaseFirestore.instance;
      await firestore.collection('support_messages').doc(messageId).update({
        'admin_response': response,
        'admin_id': adminId,
        'status': 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Admin response added successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding support message response: $e');
      return false;
    }
  }

  /// Get real-time stream of recent activities
  static Stream<List<RecentActivity>> getRecentActivitiesStream() {
    try {
      final firestore = FirebaseFirestore.instance;
      return firestore
          .collection(_activitiesCollectionName)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;

          // Convert Firestore timestamp
          if (data['timestamp'] is Timestamp) {
            data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
          }

          return RecentActivity.fromJson(data);
        }).toList();
      });
    } catch (e) {
      debugPrint('Error getting recent activities stream: $e');
      return Stream.value([]);
    }
  }

  /// Log admin activity
  static Future<void> logActivity({
    required String type,
    required String description,
    String? userEmail,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection(_activitiesCollectionName).add({
        'type': type,
        'description': description,
        'user_email': userEmail,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging admin activity: $e');
    }
  }
}
