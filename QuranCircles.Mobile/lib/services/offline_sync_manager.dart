import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_cache.dart';

class OfflineAction {
  final String id;
  final String actionType; // 'circle_attendance', 'course_attendance', 'recitation_session', 'create_announcement'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  OfflineAction({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
        id: json['id'] ?? '',
        actionType: json['actionType'] ?? '',
        payload: Map<String, dynamic>.from(json['payload'] ?? {}),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class OfflineSyncManager {
  static const String _queueKey = 'offline_sync_queue';
  static bool _isSyncing = false;
  static Timer? _autoSyncTimer;

  static final ValueNotifier<int> pendingActionsCount = ValueNotifier<int>(0);

  static void initialize() {
    _loadPendingCount();
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      syncPendingActions();
    });
  }

  static Future<void> _loadPendingCount() async {
    final list = await getQueuedActions();
    pendingActionsCount.value = list.length;
  }

  static Future<List<OfflineAction>> getQueuedActions() async {
    final jsonStr = await OfflineCache.load(_queueKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List data = jsonDecode(jsonStr);
      return data.map((item) => OfflineAction.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> queueAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final current = await getQueuedActions();
    final action = OfflineAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${current.length}',
      actionType: actionType,
      payload: payload,
      createdAt: DateTime.now(),
    );
    current.add(action);
    await OfflineCache.save(_queueKey, jsonEncode(current.map((a) => a.toJson()).toList()));
    pendingActionsCount.value = current.length;

    // Trigger immediate sync attempt in background
    syncPendingActions();
  }

  static Future<int> syncPendingActions() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;
    try {
      final list = await getQueuedActions();
      if (list.isEmpty) {
        _isSyncing = false;
        pendingActionsCount.value = 0;
        return 0;
      }

      final remaining = <OfflineAction>[];

      for (var action in list) {
        bool success = false;
        try {
          switch (action.actionType) {
            case 'circle_attendance':
              success = await ApiService.saveAttendance(
                action.payload['circleId'],
                action.payload['date'],
                (action.payload['records'] as List).cast<Map<String, dynamic>>(),
              );
              break;

            case 'course_attendance':
              success = await ApiService.saveCourseAttendance(
                action.payload['courseId'],
                action.payload['date'],
                (action.payload['records'] as List).cast<Map<String, dynamic>>(),
              );
              break;

            case 'recitation_session':
              success = await ApiService.saveRecitationSession(
                studentId: action.payload['studentId'],
                sessionDate: action.payload['sessionDate'],
                surahName: action.payload['surahName'],
                fromVerse: action.payload['fromVerse'],
                toVerse: action.payload['toVerse'],
                assessment: action.payload['assessment'],
                notes: action.payload['notes'],
                viaLottery: action.payload['viaLottery'] ?? false,
              );
              break;

            case 'create_announcement':
              success = await ApiService.createAnnouncement(
                title: action.payload['title'],
                content: action.payload['content'],
                targetType: action.payload['targetType'] ?? 1,
                targetId: action.payload['targetId'],
              );
              break;

            default:
              success = true; // Unknown, discard
          }
        } catch (_) {
          success = false;
        }

        if (success) {
          syncedCount++;
        } else {
          remaining.add(action);
        }
      }

      await OfflineCache.save(_queueKey, jsonEncode(remaining.map((a) => a.toJson()).toList()));
      pendingActionsCount.value = remaining.length;
    } catch (_) {}

    _isSyncing = false;
    return syncedCount;
  }
}
