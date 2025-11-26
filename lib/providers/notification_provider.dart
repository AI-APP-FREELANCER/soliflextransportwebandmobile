import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<NotificationModel> get unreadNotifications => 
      _notifications.where((n) => n.isUnread).toList();
  
  List<NotificationModel> get readNotifications => 
      _notifications.where((n) => n.isRead).toList();

  // Load notifications for a department
  Future<void> loadNotificationsForDepartment(String department) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getNotificationsByDepartment(department);
      if (result['success'] == true) {
        _notifications = result['notifications'] as List<NotificationModel>;
        _unreadCount = _notifications.where((n) => n.isUnread).length;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load notifications';
      }
    } catch (e) {
      _error = 'Error loading notifications: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load notifications for a user (based on user's department)
  Future<void> loadNotificationsForUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getNotificationsForUser(userId);
      if (result['success'] == true) {
        _notifications = result['notifications'] as List<NotificationModel>;
        _unreadCount = _notifications.where((n) => n.isUnread).length;
        _error = null;
      } else {
        _error = result['message'] ?? 'Failed to load notifications';
      }
    } catch (e) {
      _error = 'Error loading notifications: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load unread count for a department
  Future<void> loadUnreadCount(String department) async {
    try {
      final result = await _apiService.getUnreadNotificationCount(department);
      if (result['success'] == true) {
        _unreadCount = result['count'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - unread count is not critical
      print('Error loading unread count: ${e.toString()}');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final result = await _apiService.markNotificationAsRead(notificationId);
      if (result['success'] == true) {
        // Update local state
        final index = _notifications.indexWhere((n) => n.notificationId == notificationId);
        if (index >= 0) {
          final notification = _notifications[index];
          _notifications[index] = NotificationModel(
            notificationId: notification.notificationId,
            orderId: notification.orderId,
            recipientDepartment: notification.recipientDepartment,
            notificationType: notification.notificationType,
            message: notification.message,
            status: 'read',
            createdAt: notification.createdAt,
            relatedUserId: notification.relatedUserId,
          );
          _unreadCount = _notifications.where((n) => n.isUnread).length;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error marking notification as read: ${e.toString()}');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final unreadIds = _notifications.where((n) => n.isUnread).map((n) => n.notificationId).toList();
    for (final id in unreadIds) {
      await markAsRead(id);
    }
  }
}

