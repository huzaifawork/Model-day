import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Debug service to diagnose Firebase connectivity and data issues
class DebugService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// Run comprehensive Firebase diagnostics
  static Future<void> runFirebaseDiagnostics() async {
    debugPrint('🔍 ===== FIREBASE DIAGNOSTICS START =====');
    
    try {
      // 1. Check Firebase initialization
      await _checkFirebaseInitialization();
      
      // 2. Check authentication
      await _checkAuthentication();
      
      // 3. Check Firestore connectivity
      await _checkFirestoreConnectivity();
      
      // 4. Check agents collection
      await _checkAgentsCollection();
      
    } catch (e) {
      debugPrint('❌ Diagnostics failed: $e');
    }
    
    debugPrint('🔍 ===== FIREBASE DIAGNOSTICS END =====');
  }

  static Future<void> _checkFirebaseInitialization() async {
    debugPrint('📱 1. Checking Firebase initialization...');
    
    try {
      final app = Firebase.app();
      debugPrint('✅ Firebase app initialized: ${app.name}');
      debugPrint('🔧 Project ID: ${app.options.projectId}');
      debugPrint('🔧 Auth Domain: ${app.options.authDomain}');
      debugPrint('🔧 API Key: ${app.options.apiKey.substring(0, 10)}...');
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
    }
  }

  static Future<void> _checkAuthentication() async {
    debugPrint('🔐 2. Checking authentication...');
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('✅ User authenticated: ${user.email}');
        debugPrint('🔧 User ID: ${user.uid}');
        debugPrint('🔧 Email verified: ${user.emailVerified}');
        debugPrint('🔧 Provider: ${user.providerData.map((p) => p.providerId).join(', ')}');
      } else {
        debugPrint('❌ No authenticated user');
      }
    } catch (e) {
      debugPrint('❌ Authentication check error: $e');
    }
  }

  static Future<void> _checkFirestoreConnectivity() async {
    debugPrint('🗄️ 3. Checking Firestore connectivity...');
    
    try {
      // Test basic Firestore connectivity
      final testDoc = await _firestore.collection('test').doc('connectivity').get();
      debugPrint('✅ Firestore connectivity test passed');
      debugPrint('🔧 Test document exists: ${testDoc.exists}');
      
      // Check Firestore settings
      final settings = _firestore.settings;
      debugPrint('🔧 Firestore host: ${settings.host}');
      debugPrint('🔧 SSL enabled: ${settings.sslEnabled}');
      debugPrint('🔧 Persistence enabled: ${settings.persistenceEnabled}');
      
    } catch (e) {
      debugPrint('❌ Firestore connectivity error: $e');
    }
  }

  static Future<void> _checkAgentsCollection() async {
    debugPrint('👥 4. Checking agents collection...');
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ Cannot check agents - user not authenticated');
        return;
      }

      // Check all agents (without user filter)
      final allAgentsSnapshot = await _firestore.collection('agents').get();
      debugPrint('🔧 Total agents in database: ${allAgentsSnapshot.docs.length}');
      
      if (allAgentsSnapshot.docs.isNotEmpty) {
        debugPrint('📋 Agent documents:');
        for (int i = 0; i < allAgentsSnapshot.docs.length && i < 3; i++) {
          final doc = allAgentsSnapshot.docs[i];
          final data = doc.data();
          debugPrint('   - ID: ${doc.id}');
          debugPrint('   - Name: ${data['name'] ?? 'N/A'}');
          debugPrint('   - UserID: ${data['userId'] ?? 'N/A'}');
        }
      }

      // Check user-specific agents
      final userAgentsSnapshot = await _firestore
          .collection('agents')
          .where('userId', isEqualTo: user.uid)
          .get();
      debugPrint('🔧 User-specific agents: ${userAgentsSnapshot.docs.length}');
      
      if (userAgentsSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No agents found for current user');
        debugPrint('🔧 Current user ID: ${user.uid}');
        
        // Check if there are agents with different userIds
        if (allAgentsSnapshot.docs.isNotEmpty) {
          debugPrint('🔧 Found agents with different userIds:');
          final userIds = allAgentsSnapshot.docs
              .map((doc) => doc.data()['userId'])
              .toSet()
              .toList();
          for (final userId in userIds) {
            debugPrint('   - UserID: $userId');
          }
        }
      }
      
    } catch (e) {
      debugPrint('❌ Agents collection check error: $e');
    }
  }



  /// Quick connectivity test
  static Future<bool> quickConnectivityTest() async {
    try {
      debugPrint('⚡ Running quick connectivity test...');
      
      // Test Firestore read
      await _firestore.collection('test').doc('ping').get();
      debugPrint('✅ Firestore read test passed');
      
      // Test Firestore write
      await _firestore.collection('test').doc('ping').set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': 'connectivity',
      });
      debugPrint('✅ Firestore write test passed');
      
      return true;
    } catch (e) {
      debugPrint('❌ Quick connectivity test failed: $e');
      return false;
    }
  }


}
