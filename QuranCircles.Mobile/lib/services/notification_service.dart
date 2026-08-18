import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'offline_cache.dart';

class CenterNotification {
  final String id;
  final String title;
  final String body;
  final String category; // 'announcement', 'exam', 'profile_request', 'system'
  final DateTime timestamp;
  bool isRead;

  CenterNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory CenterNotification.fromJson(Map<String, dynamic> json) => CenterNotification(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        category: json['category'] ?? 'system',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        isRead: json['isRead'] ?? false,
      );
}

class NotificationService {
  static const String _notificationsKey = 'user_notifications_store';
  static Timer? _pollingTimer;

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static final ValueNotifier<List<CenterNotification>> notificationsList = ValueNotifier<List<CenterNotification>>([]);

  static void start(User user) {
    loadLocalNotifications();
    _pollingTimer?.cancel();
    // Poll every 30 seconds for live notifications
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchLiveNotifications(user);
    });
    fetchLiveNotifications(user);
  }

  static void stop() {
    _pollingTimer?.cancel();
  }

  static Future<void> loadLocalNotifications() async {
    final str = await OfflineCache.load(_notificationsKey);
    if (str != null && str.isNotEmpty) {
      try {
        final List data = jsonDecode(str);
        final list = data.map((item) => CenterNotification.fromJson(item)).toList();
        notificationsList.value = list;
        unreadCount.value = list.where((n) => !n.isRead).length;
      } catch (_) {}
    }
  }

  static Future<void> fetchLiveNotifications(User user) async {
    try {
      final announcements = await ApiService.getAnnouncements();
      final currentList = List<CenterNotification>.from(notificationsList.value);

      bool hasNew = false;
      for (var a in announcements) {
        final nid = 'ann_${a.id}';
        if (!currentList.any((n) => n.id == nid)) {
          currentList.insert(
            0,
            CenterNotification(
              id: nid,
              title: a.title,
              body: a.content,
              category: 'announcement',
              timestamp: DateTime.tryParse(a.datePosted) ?? DateTime.now(),
              isRead: false,
            ),
          );
          hasNew = true;
        }
      }

      if (user.role == 'Admin' || user.role == 'Developer') {
        try {
          final requests = await ApiService.getProfileUpdateRequests();
          final pending = requests.where((r) => r['status'] == 'Pending' || r['status'] == 'معلق');
          for (var req in pending) {
            final rid = 'req_${req['id']}';
            if (!currentList.any((n) => n.id == rid)) {
              currentList.insert(
                0,
                CenterNotification(
                  id: rid,
                  title: 'طلب تعديل بيانات جديد',
                  body: 'قدم ${req['requestedByName']} طلباً لتحديث بيانات الطالب.',
                  category: 'profile_request',
                  timestamp: DateTime.now(),
                  isRead: false,
                ),
              );
              hasNew = true;
            }
          }
        } catch (_) {}
      }

      if (hasNew || currentList.length != notificationsList.value.length) {
        notificationsList.value = currentList;
        unreadCount.value = currentList.where((n) => !n.isRead).length;
        await OfflineCache.save(_notificationsKey, jsonEncode(currentList.map((n) => n.toJson()).toList()));
      }
    } catch (_) {}
  }

  static Future<void> markAllAsRead() async {
    final list = notificationsList.value;
    for (var n in list) {
      n.isRead = true;
    }
    notificationsList.value = List.from(list);
    unreadCount.value = 0;
    await OfflineCache.save(_notificationsKey, jsonEncode(list.map((n) => n.toJson()).toList()));
  }

  static Future<void> markAsRead(String id) async {
    final list = notificationsList.value;
    final item = list.firstWhere((n) => n.id == id, orElse: () => list.first);
    item.isRead = true;
    notificationsList.value = List.from(list);
    unreadCount.value = list.where((n) => !n.isRead).length;
    await OfflineCache.save(_notificationsKey, jsonEncode(list.map((n) => n.toJson()).toList()));
  }

  static Future<void> clearAll() async {
    notificationsList.value = [];
    unreadCount.value = 0;
    await OfflineCache.remove(_notificationsKey);
  }
}
