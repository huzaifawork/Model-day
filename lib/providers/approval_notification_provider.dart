import 'package:flutter/material.dart';
import 'dart:async';
import '../models/approval_notification.dart';
import '../services/approval_notification_service.dart';
import '../services/auth_service.dart';
import '../services/logging_service.dart';

class ApprovalNotificationProvider with ChangeNotifier {
  final ApprovalNotificationService _notificationService =
      ApprovalNotificationService();
  final AuthService _authService = AuthService();

  List<ApprovalNotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  StreamSubscription<List<ApprovalNotificationModel>>?
      _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;

  List<ApprovalNotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  /// Initialize the provider and start listening to notifications
  Future<void> initialize() async {
    final user = _authService.currentUser;
    if (user == null) {
      LoggingService.logError('No user logged in, cannot initialize approval notifications', null);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Listen to notifications stream
      _notificationsSubscription?.cancel();
      _notificationsSubscription =
          _notificationService.getUserApprovalNotifications(user.uid).listen(
        (notifications) {
          _notifications = notifications;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          LoggingService.logError('Error listening to approval notifications', error);
          _isLoading = false;
          notifyListeners();
        },
      );

      // Listen to unread count stream
      _unreadCountSubscription?.cancel();
      _unreadCountSubscription = _notificationService
          .getUnreadApprovalNotificationCount(user.uid)
          .listen(
        (count) {
          _unreadCount = count;
          notifyListeners();
        },
        onError: (error) {
          LoggingService.logError('Error listening to unread approval notification count', error);
        },
      );

      LoggingService.logInfo('Approval notification provider initialized for user: ${user.email}');
    } catch (e) {
      LoggingService.logError('Error initializing approval notification provider', e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      // Immediately update local state for instant UI feedback
      final notificationIndex =
          _notifications.indexWhere((n) => n.id == notificationId);
      if (notificationIndex != -1) {
        _notifications[notificationIndex] =
            _notifications[notificationIndex].copyWith(isRead: true);
        notifyListeners();
      }

      // Then update database
      await _notificationService.markApprovalNotificationAsRead(notificationId);
      LoggingService.logInfo('Approval notification marked as read: $notificationId');
    } catch (e) {
      LoggingService.logError('Error marking approval notification as read', e);
      // If database operation fails, the stream will automatically reload
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // Immediately update local state for instant UI feedback
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      notifyListeners();

      // Then update database
      await _notificationService.markAllApprovalNotificationsAsRead(user.uid);
      LoggingService.logInfo('All approval notifications marked as read');
    } catch (e) {
      LoggingService.logError('Error marking all approval notifications as read', e);
      // If database operation fails, the stream will automatically reload
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // Immediately clear local state for instant UI feedback
      _notifications.clear();
      notifyListeners();

      // Then clear from database
      await _notificationService.clearAllApprovalNotifications(user.uid);
      LoggingService.logInfo('All approval notifications cleared');
    } catch (e) {
      LoggingService.logError('Error clearing all approval notifications', e);
      // If database operation fails, the stream will automatically reload
    }
  }

  /// Delete a specific notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteApprovalNotification(notificationId);
      LoggingService.logInfo('Approval notification deleted: $notificationId');
    } catch (e) {
      LoggingService.logError('Error deleting approval notification', e);
    }
  }

  /// Create a notification when an approval is sent
  Future<bool> createApprovalSentNotification({
    required String recipientUserId,
    required String senderUserId,
    required String senderUserName,
    required String senderUserEmail,
    required dynamic event,
  }) async {
    return await _notificationService.createApprovalSentNotification(
      recipientUserId: recipientUserId,
      senderUserId: senderUserId,
      senderUserName: senderUserName,
      senderUserEmail: senderUserEmail,
      event: event,
    );
  }

  /// Create a notification when an approval is approved
  Future<bool> createApprovalApprovedNotification({
    required String recipientUserId,
    required String approverUserId,
    required String approverUserName,
    required String approverUserEmail,
    required dynamic event,
  }) async {
    return await _notificationService.createApprovalApprovedNotification(
      recipientUserId: recipientUserId,
      approverUserId: approverUserId,
      approverUserName: approverUserName,
      approverUserEmail: approverUserEmail,
      event: event,
    );
  }

  /// Create a notification when an approval is rejected
  Future<bool> createApprovalRejectedNotification({
    required String recipientUserId,
    required String rejecterUserId,
    required String rejecterUserName,
    required String rejecterUserEmail,
    required dynamic event,
    String? rejectionReason,
  }) async {
    return await _notificationService.createApprovalRejectedNotification(
      recipientUserId: recipientUserId,
      rejecterUserId: rejecterUserId,
      rejecterUserName: rejecterUserName,
      rejecterUserEmail: rejecterUserEmail,
      event: event,
      rejectionReason: rejectionReason,
    );
  }

  /// Get notifications by event ID
  Future<List<ApprovalNotificationModel>> getNotificationsByEventId(
      String eventId) async {
    return await _notificationService.getNotificationsByEventId(eventId);
  }

  /// Refresh notifications manually
  Future<void> refresh() async {
    await initialize();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }
}
