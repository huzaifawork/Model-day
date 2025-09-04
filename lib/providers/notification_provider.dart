import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/logging_service.dart';
import 'dart:async';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _unreadCountSubscription;
  StreamSubscription<User?>? _authSubscription;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  List<NotificationModel> get recentNotifications => 
      _notifications.take(5).toList();
  List<NotificationModel> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();
  bool get hasUnreadNotifications => _unreadCount > 0;

  NotificationProvider() {
    _initializeNotifications();
  }

  void initialize() {
    _initializeNotifications();
  }

  void _initializeNotifications() {
    // Listen to auth state changes
    _authSubscription = _firebaseAuth.authStateChanges().listen((user) {
      if (user != null) {
        _startListening(user.uid);
      } else {
        _stopListening();
      }
    });
  }

  void _startListening(String userId) {
    _stopListening(); // Stop any existing subscriptions
    
    _isLoading = true;
    notifyListeners();

    // Listen to notifications
    _notificationSubscription = _notificationService
        .getUserNotifications(userId)
        .listen(
      (notifications) {
        _notifications = notifications;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        LoggingService.logError('Error listening to notifications', error);
        _isLoading = false;
        notifyListeners();
      },
    );

    // Listen to unread count - convert to QuerySnapshot stream
    _unreadCountSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
      (snapshot) {
        _unreadCount = snapshot.docs.length;
        notifyListeners();
      },
      onError: (error) {
        LoggingService.logError('Error listening to unread count', error);
      },
    );
  }

  void _stopListening() {
    _notificationSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _authSubscription?.cancel();
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    notifyListeners();
  }

  /// Mark a notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (success) {
        // Update local state immediately for better UX
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      LoggingService.logError('Error marking notification as read', e);
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    final user = _authService.currentUser;
    if (user == null) return false;

    try {
      final success = await _notificationService.markAllAsRead(user.uid);
      if (success) {
        // Update local state immediately for better UX
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
        notifyListeners();
      }
      return success;
    } catch (e) {
      LoggingService.logError('Error marking all notifications as read', e);
      return false;
    }
  }

  /// Clear all notifications (delete them from database)
  Future<bool> clearAllNotifications() async {
    final user = _authService.currentUser;
    if (user == null) return false;

    try {
      final success = await _notificationService.clearAllNotifications(user.uid);
      if (success) {
        // Clear all notifications from local state since they're deleted from database
        _notifications.clear();
        _unreadCount = 0;
        notifyListeners();
      }
      return success;
    } catch (e) {
      LoggingService.logError('Error clearing all notifications', e);
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final success = await _notificationService.deleteNotification(notificationId);
      if (success) {
        // Update local state immediately for better UX
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final wasUnread = !_notifications[index].isRead;
          _notifications.removeAt(index);
          if (wasUnread) {
            _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
          }
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      LoggingService.logError('Error deleting notification', e);
      return false;
    }
  }



  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}