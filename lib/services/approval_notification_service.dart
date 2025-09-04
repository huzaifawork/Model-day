import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/approval_notification.dart';
import '../models/event.dart';
import 'events_service.dart';
import 'logging_service.dart';

class ApprovalNotificationService {
  static final ApprovalNotificationService _instance =
      ApprovalNotificationService._internal();
  factory ApprovalNotificationService() => _instance;
  ApprovalNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'approval_notifications';

  /// Create a notification when an approval is sent
  Future<bool> createApprovalSentNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderUserName,
    required String senderUserEmail,
    required Event event,
  }) async {
    try {
      final notification = ApprovalNotificationModel(
        id: '', // Will be set by Firestore
        userId: recipientUserId,
        type: 'approval_sent',
        message:
            '$senderUserName has sent you an approval request for "${event.clientName ?? 'Event'}"',
        isRead: false,
        createdAt: DateTime.now(),
        eventId: event.id,
        eventTitle: event.clientName,
        eventDescription: event.notes,
        eventDate: event.date,
        eventLocation: event.location,
        fromUserId: senderUserId,
        fromUserName: senderUserName,
        fromUserEmail: senderUserEmail,
        approvalStatus: 'pending',
        eventDetails: {
          'type': event.type.displayName,
          'dayRate': event.dayRate,
          'currency': event.currency,
          'startTime': event.startTime,
          'endTime': event.endTime,
        },
      );

      await _firestore.collection(_collection).add(notification.toMap());
      LoggingService.logInfo('Approval sent notification created for user: $recipientUserId');
      return true;
    } catch (e) {
      LoggingService.logError('Error creating approval sent notification', e);
      return false;
    }
  }

  /// Create a notification when an approval is approved
  Future<bool> createApprovalApprovedNotification({
    required String recipientUserId,
    required String approverUserId,
    required String approverUserName,
    required String approverUserEmail,
    required Event event,
  }) async {
    try {
      // Update event status to approved and sync to Google Calendar
      final eventsService = EventsService();
      final statusUpdateSuccess =
          await eventsService.approveEventWithCalendarSync(event.id!);

      if (!statusUpdateSuccess) {
        LoggingService.logError(
            'Failed to update event status to approved and sync to calendar');
        return false;
      }

      final notification = ApprovalNotificationModel(
        id: '', // Will be set by Firestore
        userId: recipientUserId,
        type: 'approval_approved',
        message:
            '$approverUserName has approved your event "${event.clientName ?? 'Event'}"',
        isRead: false,
        createdAt: DateTime.now(),
        eventId: event.id,
        eventTitle: event.clientName,
        eventDescription: event.notes,
        eventDate: event.date,
        eventLocation: event.location,
        fromUserId: approverUserId,
        fromUserName: approverUserName,
        fromUserEmail: approverUserEmail,
        approvalStatus: 'approved',
        eventDetails: {
          'type': event.type.displayName,
          'dayRate': event.dayRate,
          'currency': event.currency,
          'startTime': event.startTime,
          'endTime': event.endTime,
        },
      );

      await _firestore.collection(_collection).add(notification.toMap());
      LoggingService.logInfo(
          'Approval approved notification created and event status updated for user: $recipientUserId');
      return true;
    } catch (e) {
      LoggingService.logError('Error creating approval approved notification', e);
      return false;
    }
  }

  /// Create a notification when an approval is rejected
  Future<bool> createApprovalRejectedNotification({
    required String recipientUserId,
    required String rejecterUserId,
    required String rejecterUserName,
    required String rejecterUserEmail,
    required Event event,
    String? rejectionReason,
  }) async {
    try {
      // Update event status to rejected
      final eventsService = EventsService();
      final statusUpdateSuccess = await eventsService.rejectEvent(event.id!);

      if (!statusUpdateSuccess) {
        LoggingService.logError('Failed to update event status to rejected');
        return false;
      }

      final reasonText = rejectionReason != null && rejectionReason.isNotEmpty
          ? ' Reason: $rejectionReason'
          : '';

      final notification = ApprovalNotificationModel(
        id: '', // Will be set by Firestore
        userId: recipientUserId,
        type: 'approval_rejected',
        message:
            '$rejecterUserName has rejected your event "${event.clientName ?? 'Event'}"$reasonText',
        isRead: false,
        createdAt: DateTime.now(),
        eventId: event.id,
        eventTitle: event.clientName,
        eventDescription: event.notes,
        eventDate: event.date,
        eventLocation: event.location,
        fromUserId: rejecterUserId,
        fromUserName: rejecterUserName,
        fromUserEmail: rejecterUserEmail,
        approvalStatus: 'rejected',
        eventDetails: {
          'type': event.type.displayName,
          'dayRate': event.dayRate,
          'currency': event.currency,
          'startTime': event.startTime,
          'endTime': event.endTime,
          'rejectionReason': rejectionReason,
        },
      );

      await _firestore.collection(_collection).add(notification.toMap());
      LoggingService.logInfo(
          'Approval rejected notification created and event status updated for user: $recipientUserId');
      return true;
    } catch (e) {
      LoggingService.logError('Error creating approval rejected notification', e);
      return false;
    }
  }

  /// Get approval notifications for a specific user
  Stream<List<ApprovalNotificationModel>> getUserApprovalNotifications(
      String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ApprovalNotificationModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Get unread approval notification count for a user
  Stream<int> getUnreadApprovalNotificationCount(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark an approval notification as read
  Future<bool> markApprovalNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(notificationId)
          .update({'isRead': true});
      LoggingService.logInfo('Approval notification marked as read: $notificationId');
      return true;
    } catch (e) {
      LoggingService.logError('Error marking approval notification as read', e);
      return false;
    }
  }

  /// Mark all approval notifications as read for a user
  Future<bool> markAllApprovalNotificationsAsRead(String userId) async {
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
      LoggingService.logInfo('All approval notifications marked as read for user: $userId');
      return true;
    } catch (e) {
      LoggingService.logError('Error marking all approval notifications as read', e);
      return false;
    }
  }

  /// Clear all approval notifications for a user
  Future<bool> clearAllApprovalNotifications(String userId) async {
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
      LoggingService.logInfo('All approval notifications cleared for user: $userId');
      return true;
    } catch (e) {
      LoggingService.logError('Error clearing all approval notifications', e);
      return false;
    }
  }

  /// Delete a specific approval notification
  Future<bool> deleteApprovalNotification(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
      LoggingService.logInfo('Approval notification deleted: $notificationId');
      return true;
    } catch (e) {
      LoggingService.logError('Error deleting approval notification', e);
      return false;
    }
  }

  /// Get approval notifications by event ID
  Future<List<ApprovalNotificationModel>> getNotificationsByEventId(
      String eventId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('eventId', isEqualTo: eventId)
          .get();

      return snapshot.docs.map((doc) {
        return ApprovalNotificationModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      LoggingService.logError('Error getting notifications by event ID', e);
      return [];
    }
  }
}
