import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_cache.dart';

class OfflineAction {
  final String id;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int ownerUserId;
  final String server;

  OfflineAction(
      {required this.id,
      required this.actionType,
      required this.payload,
      required this.createdAt,
      required this.ownerUserId,
      required this.server});

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'ownerUserId': ownerUserId,
        'server': server
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
      id: json['id'] ?? '',
      actionType: json['actionType'] ?? '',
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      ownerUserId: json['ownerUserId'] ?? 0,
      server: json['server'] ?? '');
}

class OfflineSyncManager {
  static const _queueKey = 'offline_sync_queue';
  static Timer? _autoSyncTimer;
  static Future<int>? _syncFuture;
  static Future<void> _queueTail = Future.value();
  static bool _stopping = false;
  static final pendingActionsCount = ValueNotifier<int>(0);
  static final lastSyncError = ValueNotifier<String?>(null);

  static Future<T> _locked<T>(Future<T> Function() task) {
    final result = Completer<T>();
    _queueTail = _queueTail.then((_) async {
      try {
        result.complete(await task());
      } catch (e, trace) {
        result.completeError(e, trace);
      }
    });
    return result.future;
  }

  static void initialize() {
    _autoSyncTimer?.cancel();
    if (ApiService.currentUser == null) return;
    _stopping = false;
    _locked(() async {
      pendingActionsCount.value = (await getQueuedActions()).length;
    });
    _autoSyncTimer = Timer.periodic(
        const Duration(seconds: 45), (_) => syncPendingActions());
  }

  static Future<void> stop() async {
    _stopping = true;
    _autoSyncTimer?.cancel();
    final active = _syncFuture;
    if (active != null) await active;
    await _queueTail;
    pendingActionsCount.value = 0;
    lastSyncError.value = null;
  }

  static Future<List<OfflineAction>> getQueuedActions() async {
    final raw = await OfflineCache.load(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    final List data = jsonDecode(raw);
    return data
        .map((item) => OfflineAction.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> _save(List<OfflineAction> actions) async {
    await OfflineCache.save(
        _queueKey, jsonEncode(actions.map((a) => a.toJson()).toList()));
    pendingActionsCount.value = actions.length;
  }

  static Future<void> queueAction(
      {required String actionType,
      required Map<String, dynamic> payload}) async {
    final user = ApiService.currentUser;
    final server = ApiService.baseUrl;
    if (user == null || user.id <= 0 || _stopping) {
      throw StateError('يلزم تسجيل الدخول قبل حفظ عملية مؤجلة.');
    }
    final action = OfflineAction(
        id: base64UrlEncode(
            List.generate(24, (_) => Random.secure().nextInt(256))),
        actionType: actionType,
        payload: Map<String, dynamic>.from(payload),
        createdAt: DateTime.now(),
        ownerUserId: user.id,
        server: server);
    await _locked(() async {
      if (ApiService.currentUser?.id != user.id ||
          ApiService.baseUrl != server ||
          _stopping) {
        throw StateError('تغيرت جلسة الدخول أثناء الحفظ.');
      }
      final current = await getQueuedActions();
      current.add(action);
      await _save(current);
    });
    unawaited(syncPendingActions());
  }

  static Future<int> syncPendingActions() {
    if (_stopping ||
        ApiService.currentUser == null ||
        ApiService.authToken == null) {
      return Future.value(0);
    }
    return _syncFuture ??= _sync().whenComplete(() => _syncFuture = null);
  }

  static Future<int> _sync() async {
    final userId = ApiService.currentUser!.id;
    final server = ApiService.baseUrl;
    final token = ApiService.authToken;
    final completed = <String>{};
    try {
      final snapshot = await _locked(getQueuedActions);
      for (final action in snapshot) {
        if (_stopping ||
            ApiService.currentUser?.id != userId ||
            ApiService.baseUrl != server ||
            ApiService.authToken != token) {
          break;
        }
        if (action.ownerUserId != userId || action.server != server) {
          lastSyncError.value = 'عملية محفوظة لحساب مختلف؛ لم يتم إرسالها.';
          continue;
        }
        try {
          if (await _send(action)) {
            completed.add(action.id);
          } else {
            lastSyncError.value =
                'تعذر الحفظ على الخادم؛ العملية ما زالت محفوظة محلياً.';
          }
        } catch (_) {
          lastSyncError.value = 'تعذر الاتصال؛ ستُعاد محاولة المزامنة.';
        }
      }
      // Merge into the latest queue so additions made during HTTP requests survive.
      await _locked(() async {
        final current = await getQueuedActions();
        await _save(current.where((a) => !completed.contains(a.id)).toList());
        if (current.length == completed.length) lastSyncError.value = null;
      });
    } catch (_) {
      lastSyncError.value = 'تعذر قراءة العمليات المحفوظة؛ لم يتم حذفها.';
    }
    return completed.length;
  }

  static Future<bool> _send(OfflineAction action) async {
    final p = action.payload;
    switch (action.actionType) {
      case 'circle_attendance':
        return ApiService.saveCircleAttendance(p['circleId'], p['date'],
            (p['records'] as List).cast<Map<String, dynamic>>(),
            operationId: action.id);
      case 'course_attendance':
        return ApiService.saveCourseAttendance(p['courseId'], p['date'],
            (p['records'] as List).cast<Map<String, dynamic>>(),
            operationId: action.id);
      case 'recitation_session':
        return ApiService.saveRecitationSession(
            studentId: p['studentId'],
            sessionDate: p['sessionDate'],
            surahName: p['surahName'],
            fromVerse: p['fromVerse'],
            toVerse: p['toVerse'],
            assessment: p['assessment'],
            notes: p['notes'],
            viaLottery: p['viaLottery'] ?? false,
            recitationType: p['recitationType'] ?? 1,
            operationId: action.id);
      case 'create_announcement':
        return ApiService.createAnnouncement(
            title: p['title'],
            content: p['content'],
            targetType: p['targetType'] ?? 1,
            targetId: p['targetId'],
            operationId: action.id);
      default:
        lastSyncError.value = 'نوع عملية غير مدعوم؛ بقيت محفوظة للمراجعة.';
        return Future.value(false);
    }
  }
}
