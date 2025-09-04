import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';
import '../services/logging_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'notifications';

  /// Create a new notification
  Future<bool> createNotification({
    required String userId,
    required String type,
    required String message,
    String? postId,
    String? commentId,
    String? fromUserId,
    String? fromUserName,
  }) async {
    try {
      final notification = NotificationModel(
        id: '', // Will be set by Firestore
        userId: userId,
        type: type,
        message: message,
        isRead: false,
        createdAt: DateTime.now(),
        postId: postId,
        commentId: commentId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
      );

      await _firestore.collection(_collection).add(notification.toMap());
      LoggingService.logInfo('Notification created for user: $userId');
      return true;
    } catch (e) {
      LoggingService.logError('Error creating notification', e);
      return false;
    }
  }

  /// Get notifications for a specific user
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Get unread notification count for a user
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(notificationId)
          .update({'isRead': true});
      LoggingService.logInfo('Notification marked as read: $notificationId');
      return true;
    } catch (e) {
      LoggingService.logError('Error marking notification as read', e);
      return false;
    }
  }

  /// Mark all notifications as read for a user
  Future<bool> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      LoggingService.logInfo('All notifications marked as read for user: $userId');
      return true;
    } catch (e) {
      LoggingService.logError('Error marking all notifications as read', e);
      return false;
    }
  }

  /// Clear all notifications for a user (delete them)
  Future<bool> clearAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      LoggingService.logInfo('All notifications cleared for user: $userId');
      return true;
    } catch (e) {
      LoggingService.logError('Error clearing all notifications', e);
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
      LoggingService.logInfo('Notification deleted: $notificationId');
      return true;
    } catch (e) {
      LoggingService.logError('Error deleting notification', e);
      return false;
    }
  }

  /// Create a comment notification
  Future<bool> createCommentNotification({
    required String postOwnerId,
    required String postId,
    required String commentId,
    required String commenterUserId,
    required String commenterName,
    required String postTitle,
  }) async {
    // Don't create notification if user is commenting on their own post
    if (postOwnerId == commenterUserId) {
      return true;
    }

    return await createNotification(
      userId: postOwnerId,
      type: 'comment',
      message: '$commenterName commented on your post "$postTitle"',
      postId: postId,
      commentId: commentId,
      fromUserId: commenterUserId,
      fromUserName: commenterName,
    );
  }
}