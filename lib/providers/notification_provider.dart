import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;
  
  NotificationProvider({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasNextPage => _hasNextPage;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotifications({bool isRefresh = true}) async {
    if (isRefresh) {
      _isLoading = true;
      _currentPage = 1;
    } else {
      if (!_hasNextPage || _isFetchingMore) return;
      _isFetchingMore = true;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      
      if (token.isNotEmpty) {
        final result = await _notificationService.fetchNotifications(
          token, 
          page: _currentPage
        );
        
        final List<NotificationModel> newNotifications = result['notifications'];
        _hasNextPage = result['hasNext'];

        if (isRefresh) {
          _notifications = newNotifications;
        } else {
          _notifications.addAll(newNotifications);
          _currentPage++;
        }
        
        _updateUnreadCount();
      }
    } catch (e) {
      debugPrint('NotificationProvider fetch error: $e');
    } finally {
      if (isRefresh) {
        _isLoading = false;
      } else {
        _isFetchingMore = false;
      }
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      
      if (token.isNotEmpty) {
        final success = await _notificationService.markAsRead(token, notificationId);
        if (success) {
          // Update local state for immediate feedback
          final index = _notifications.indexWhere((n) => n.id == notificationId);
          if (index != -1) {
            final n = _notifications[index];
            _notifications[index] = NotificationModel(
              id: n.id,
              title: n.title,
              message: n.message,
              isRead: true,
              createdAt: n.createdAt,
            );
            _updateUnreadCount();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationProvider markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      
      if (token.isNotEmpty) {
        final success = await _notificationService.markAllAsRead(token);
        if (success) {
          // Update local state
          _notifications = _notifications.map((n) => NotificationModel(
            id: n.id,
            title: n.title,
            message: n.message,
            isRead: true,
            createdAt: n.createdAt,
          )).toList();
          _unreadCount = 0;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('NotificationProvider markAllAsRead error: $e');
    }
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }
}
