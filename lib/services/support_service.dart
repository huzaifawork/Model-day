import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/support_message.dart';
import 'firebase_service_template.dart';

class SupportService {
  static const String _collectionName = 'support_messages';

  /// Submit a new support message
  static Future<SupportMessage?> submitSupportMessage({
    required String title,
    required String message,
    required String userEmail,
    required String userId,
  }) async {
    try {
      debugPrint('🎧 SupportService.submitSupportMessage() - Creating support message');

      final messageData = {
        'title': title,
        'message': message,
        'userEmail': userEmail,
        'userId': userId,
        'status': 'pending',
        // Note: createdAt and updatedAt are automatically added by FirebaseServiceTemplate.createDocument
      };

      final docId = await FirebaseServiceTemplate.createDocument(_collectionName, messageData);

      if (docId != null) {
        debugPrint('🎧 SupportService.submitSupportMessage() - Message created with ID: $docId');

        // Fetch the created document to return it
        final doc = await FirebaseServiceTemplate.getDocument(_collectionName, docId);
        if (doc != null) {
          // Convert Firestore timestamps to DateTime strings for JSON parsing
          final docWithStringDate = Map<String, dynamic>.from(doc);
          if (docWithStringDate['createdAt'] is Timestamp) {
            docWithStringDate['createdAt'] = (docWithStringDate['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          if (docWithStringDate['updatedAt'] is Timestamp) {
            docWithStringDate['updatedAt'] = (docWithStringDate['updatedAt'] as Timestamp).toDate().toIso8601String();
          }
          return SupportMessage.fromJson(docWithStringDate);
        }
      }

      debugPrint('🎧 SupportService.submitSupportMessage() - Failed to create message');
      return null;
    } catch (e) {
      debugPrint('❌ Error submitting support message: $e');
      return null;
    }
  }

  /// Get all support messages for the current user
  static Future<List<SupportMessage>> getUserSupportMessages() async {
    try {
      debugPrint('🎧 SupportService.getUserSupportMessages() - Fetching user messages');
      final documents = await FirebaseServiceTemplate.getUserDocuments(_collectionName);
      debugPrint('🎧 SupportService.getUserSupportMessages() - Found ${documents.length} messages');

      final messages = documents.map<SupportMessage>((doc) {
        // Convert Firestore timestamp to DateTime string for JSON parsing
        final docWithStringDate = Map<String, dynamic>.from(doc);
        if (docWithStringDate['createdAt'] is Timestamp) {
          docWithStringDate['createdAt'] = (docWithStringDate['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (docWithStringDate['updatedAt'] is Timestamp) {
          docWithStringDate['updatedAt'] = (docWithStringDate['updatedAt'] as Timestamp).toDate().toIso8601String();
        }
        return SupportMessage.fromJson(docWithStringDate);
      }).toList();

      // Sort by creation date (newest first)
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('🎧 SupportService.getUserSupportMessages() - Returning ${messages.length} messages');
      return messages;
    } catch (e) {
      debugPrint('❌ Error fetching user support messages: $e');
      return [];
    }
  }

  /// Update support message status
  static Future<bool> updateMessageStatus(String messageId, String status) async {
    try {
      debugPrint('🎧 SupportService.updateMessageStatus() - Updating message $messageId to $status');

      final success = await FirebaseServiceTemplate.updateDocument(_collectionName, messageId, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🎧 SupportService.updateMessageStatus() - Update ${success ? 'successful' : 'failed'}');
      return success;
    } catch (e) {
      debugPrint('❌ Error updating support message status: $e');
      return false;
    }
  }
}
