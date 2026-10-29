import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'offline_cache.dart';

class OfflineAction {
  final String id;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int ownerUserId;
  final String server;
  final String? reviewError;
  final int attempts;

  OfflineAction(
      {required this.id,
      required this.actionType,
      required this.payload,
      required this.createdAt,
      required this.ownerUserId,
      required this.server,
      this.reviewError,
      this.attempts = 0});

  OfflineAction copyWith({String? reviewError, int? attempts}) => OfflineAction(
      id: id, actionType: actionType, payload: payload, createdAt: createdAt,
      ownerUserId: ownerUserId, server: server,
      reviewError: reviewError, attempts: attempts ?? this.attempts);

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionType': actionType,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'ownerUserId': ownerUserId,
        'server': server,
        'reviewError': reviewError,
        'attempts': attempts,
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
      id: json['id'] ?? '',
      actionType: json['actionType'] ?? '',
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      ownerUserId: json['ownerUserId'] ?? 0,
      server: json['server'] ?? '',
      reviewError: json['reviewError']?.toString(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0);
}

class OfflineSyncManager {
  static const _queueKey = 'offline_sync_queue';
  static const _historyKey = 'offline_sync_history';
  static const _studentIdsKey = 'offline_student_ids';
  static Timer? _autoSyncTimer;
  static Future<int>? _syncFuture;
  static Future<void> _queueTail = Future.value();
  static bool _stopping = false;
  static final pendingActionsCount = ValueNotifier<int>(0);
  static final reviewActionsCount = ValueNotifier<int>(0);
  static final lastSyncError = ValueNotifier<String?>(null);

  static String newOperationId() => base64UrlEncode(
      List.generate(24, (_) => Random.secure().nextInt(256)));

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
    unawaited(_locked(() async {
      final actions = await getQueuedActions();
      pendingActionsCount.value = actions.where((a) => a.reviewError == null).length;
      reviewActionsCount.value = actions.where((a) => a.reviewError != null).length;
    }).catchError((_) {
      lastSyncError.value = 'تعذر قراءة العمليات المحفوظة؛ لم تُحذف.';
    }));
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
    reviewActionsCount.value = 0;
    lastSyncError.value = null;
  }

  static Future<List<OfflineAction>> getQueuedActions() async {
    var raw = await OfflineCache.loadSensitive(_queueKey);
    if (raw == null) {
      // Upgrade queues created by older releases without discarding pending work.
      raw = await OfflineCache.load(_queueKey);
      if (raw != null) {
        await OfflineCache.saveSensitive(_queueKey, raw);
        await OfflineCache.remove(_queueKey);
      }
    }
    if (raw == null || raw.isEmpty) return [];
    final List data = jsonDecode(raw);
    return data
        .map((item) => OfflineAction.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> _save(List<OfflineAction> actions) async {
    await OfflineCache.saveSensitive(
        _queueKey, jsonEncode(actions.map((a) => a.toJson()).toList()));
    pendingActionsCount.value = actions.where((a) => a.reviewError == null).length;
    reviewActionsCount.value = actions.where((a) => a.reviewError != null).length;
  }

  static Future<List<Map<String, dynamic>>> getRecentSynced() async {
    final raw = await OfflineCache.loadSensitive(_historyKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, int>> _studentIdMap() async {
    final raw = await OfflineCache.loadSensitive(_studentIdsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, (value as num).toInt()));
  }

  static Future<int?> _serverStudentId(Object? localId) async {
    if (localId is! num) return null;
    final id = localId.toInt();
    if (id > 0) return id;
    return (await _studentIdMap())['$id'];
  }

  static Future<List<Map<String, dynamic>>> pendingStudents() async {
    final actions = await getQueuedActions();
    return actions.where((a) => a.actionType == 'create_student').map((a) => {
      ...a.payload, 'id': a.payload['_localId'],
      'isActive': true, 'pendingSync': true,
    }).toList();
  }

  static Future<OfflineAction> queueAction(
      {required String actionType,
      required Map<String, dynamic> payload,
      String? operationId}) async {
    final user = ApiService.currentUser;
    final server = ApiService.baseUrl;
    if (user == null || user.id <= 0 || _stopping) {
      throw StateError('يلزم تسجيل الدخول قبل حفظ عملية مؤجلة.');
    }
    final savedPayload = Map<String, dynamic>.from(payload);
    if (actionType == 'create_student') {
      savedPayload['_localId'] = -DateTime.now().microsecondsSinceEpoch;
    }
    final action = OfflineAction(
        id: operationId ?? newOperationId(),
        actionType: actionType,
        payload: savedPayload,
        createdAt: DateTime.now(),
        ownerUserId: user.id,
        server: server,
        reviewError: actionType == 'exam_evaluation_draft'
            ? 'مسودة تقييم؛ يلزم كلمة المرور لاعتمادها عند توفر الاتصال.'
            : null);
    var stored = action;
    await _locked(() async {
      if (ApiService.currentUser?.id != user.id ||
          ApiService.baseUrl != server ||
          _stopping) {
        throw StateError('تغيرت جلسة الدخول أثناء الحفظ.');
      }
      final current = await getQueuedActions();
      final businessKey = _businessKey(action);
      if (businessKey != null) {
        for (final existing in current) {
          if ((existing.reviewError == null ||
                  actionType == 'exam_evaluation_draft') &&
              _businessKey(existing) == businessKey) {
            stored = existing;
            return;
          }
        }
      }
      current.add(action);
      await _save(current);
    });
    unawaited(syncPendingActions());
    return stored;
  }

  static String? _businessKey(OfflineAction action) {
    final p = action.payload;
    switch (action.actionType) {
      case 'create_student':
        final identity = p['studentIdentityNumber']?.toString().trim();
        return identity == null || identity.isEmpty ? null : 'student:$identity';
      case 'circle_enrollment':
        return 'circle:${p['circleId']}:${p['studentId']}';
      case 'course_enrollment':
        return 'course:${p['courseId']}:${p['studentId']}:${p['circleId']}';
      case 'exam_nomination':
        return 'exam:${p['studentId']}:${p['nominationType']}:${p['courseId']}:${p['juzStart']}:${p['juzEnd']}';
      case 'exam_evaluation_draft':
        return 'evaluation:${p['nominationId']}';
      default:
        return null;
    }
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
        if (action.reviewError != null) {
          if (action.actionType == 'exam_evaluation_draft') continue;
          break;
        }
        try {
          final result = await _send(action);
          if (result == null) {
            lastSyncError.value = 'تعذر الاتصال؛ ستُعاد محاولة المزامنة.';
            break;
          }
          final status = result.statusCode;
          if (status >= 200 && status < 300) {
            completed.add(action.id);
          } else if (status == 400 || status == 403 || status == 404 ||
              status == 409 || status == 422) {
            String reason = 'رفض الخادم العملية ($status). راجع البيانات أو الصلاحية.';
            try {
              final body = jsonDecode(result.body);
              if (body is Map) {
                reason = (body['error'] ?? body['message'] ?? reason).toString();
              }
            } catch (_) {}
            await _locked(() async {
              final current = await getQueuedActions();
              await _save(current.map((a) => a.id == action.id
                  ? a.copyWith(reviewError: reason,
                      attempts: a.attempts + 1)
                  : a).toList());
            });
            lastSyncError.value = 'بعض العمليات تحتاج مراجعة.';
            break;
          } else {
            lastSyncError.value = status == 401
                ? 'انتهت جلسة الدخول؛ سجّل الدخول مجدداً للمزامنة.'
                : 'تعذر الحفظ على الخادم؛ ستُعاد المحاولة.';
            break;
          }
        } catch (_) {
          lastSyncError.value = 'تعذر الاتصال؛ ستُعاد محاولة المزامنة.';
          break;
        }
      }
      // Merge into the latest queue so additions made during HTTP requests survive.
      await _locked(() async {
        final current = await getQueuedActions();
        await _save(current.where((a) => !completed.contains(a.id)).toList());
        if (completed.isNotEmpty) {
          try {
            final history = await getRecentSynced();
            history.insertAll(0, snapshot.where((a) => completed.contains(a.id)).map((a) => {
              'type': a.actionType,
              'at': DateTime.now().toIso8601String(),
            }));
            await OfflineCache.saveSensitive(_historyKey,
                jsonEncode(history.take(30).toList()));
          } catch (_) { /* The receipt history is informational. */ }
        }
        if (current.length == completed.length) lastSyncError.value = null;
      });
    } catch (_) {
      lastSyncError.value = 'تعذر قراءة العمليات المحفوظة؛ لم يتم حذفها.';
    }
    return completed.length;
  }

  static Future<http.Response?> _send(OfflineAction action) async {
    final p = action.payload;
    Future<http.Response> send(String method, String path, Map<String, dynamic> body,
        [String? key]) => ApiService.sendOfflineRequest(
        method: method, path: path, body: body,
        operationId: key ?? action.id);
    switch (action.actionType) {
      case 'circle_attendance':
        for (final record in (p['records'] as List)) {
          final studentId = await _serverStudentId(record['studentId']);
          if (studentId == null) return null;
          final response = await send('POST', 'attendance', {
            'studentId': studentId, 'circleId': p['circleId'],
            'sessionDate': p['date'], 'status': record['status'],
          }, '${action.id}-${record['studentId']}');
          if (response.statusCode < 200 || response.statusCode >= 300) return response;
        }
        return http.Response('{}', 200);
      case 'course_attendance':
        final items = <Map<String, dynamic>>[];
        for (final record in (p['records'] as List)) {
          final studentId = await _serverStudentId(record['studentId']);
          if (studentId == null) return null;
          items.add({...Map<String, dynamic>.from(record), 'studentId': studentId});
        }
        return send('POST', 'courses/attendance', {
          'courseId': p['courseId'], 'sessionDate': p['date'], 'items': items});
      case 'recitation_session':
        final studentId = await _serverStudentId(p['studentId']);
        if (studentId == null) return null;
        return send('POST', 'sessions', {...p, 'studentId': studentId});
      case 'create_announcement':
        return send('POST', 'announcements', p);
      case 'create_student':
        final response = await send('POST', 'students',
            {...p}..remove('_localId'));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(response.body);
          final id = body is Map ? (body['student']?['id'] ?? body['id']) : null;
          if (id is! num || id.toInt() <= 0) return null;
          final mapping = await _studentIdMap();
          mapping['${p['_localId']}'] = id.toInt();
          await OfflineCache.saveSensitive(_studentIdsKey, jsonEncode(mapping));
          ApiService.invalidateCache();
        }
        return response;
      case 'circle_enrollment':
        final studentId = await _serverStudentId(p['studentId']);
        if (studentId == null) return null;
        return send('POST', 'circles/${p['circleId']}/students',
            {'studentId': studentId});
      case 'course_enrollment':
        final studentId = p['studentId'] == null ? null
            : await _serverStudentId(p['studentId']);
        if (p['studentId'] != null && studentId == null) return null;
        return send('POST', 'courses/enroll', {...p, 'studentId': studentId});
      case 'exam_nomination':
        final studentId = await _serverStudentId(p['studentId']);
        if (studentId == null) return null;
        return send('POST', 'exams/nominate', {...p, 'studentId': studentId});
      case 'exam_schedule':
        return send('PUT', 'exams/schedule', p);
      case 'quality_visit':
        return send('POST', 'quality/visits', p);
      default:
        lastSyncError.value = 'نوع عملية غير مدعوم؛ بقيت محفوظة للمراجعة.';
        return http.Response('{"error":"نوع عملية غير مدعوم"}', 422);
    }
  }

  static Future<void> retryReviewAction(String id) => _locked(() async {
    final current = await getQueuedActions();
    await _save(current.map((a) => a.id == id
        ? OfflineAction(id: a.id, actionType: a.actionType,
            payload: a.payload, createdAt: a.createdAt,
            ownerUserId: a.ownerUserId, server: a.server,
            attempts: a.attempts)
        : a).toList());
  });

  static Future<void> approveEvaluationDraft(String id, String password) async {
    if (password.isEmpty) throw StateError('أدخل كلمة المرور الحالية للاعتماد.');
    final actions = await _locked(getQueuedActions);
    OfflineAction? draft;
    for (final action in actions) {
      if (action.id == id && action.actionType == 'exam_evaluation_draft') {
        draft = action;
        break;
      }
    }
    if (draft == null) throw StateError('المسودة غير موجودة.');
    if (draft.ownerUserId != ApiService.currentUser?.id ||
        draft.server != ApiService.baseUrl) {
      throw StateError('هذه المسودة تخص حساباً آخر.');
    }
    final p = draft.payload;
    final ok = await ApiService.evaluateExam(
      nominationId: (p['nominationId'] as num).toInt(),
      majorMistakes: (p['majorMistakes'] as num).toInt(),
      minorMistakes: (p['minorMistakes'] as num).toInt(),
      grade: (p['grade'] as num).toDouble(),
      notes: p['notes']?.toString(),
      code2FA: password,
      operationId: draft.id,
    );
    if (!ok) throw StateError('تعذر اعتماد التقييم.');
    await _locked(() async {
      final current = await getQueuedActions();
      await _save(current.where((a) => a.id != id).toList());
      final history = await getRecentSynced();
      history.insert(0, {'type': 'exam_evaluation_draft',
        'at': DateTime.now().toIso8601String()});
      await OfflineCache.saveSensitive(_historyKey,
          jsonEncode(history.take(30).toList()));
    });
  }

  static Future<Map<int, int>> pendingAttendance({
    required String actionType,
    required int targetId,
    required String date,
  }) async {
    final actions = await getQueuedActions();
    for (final action in actions.reversed) {
      if (action.actionType != actionType || action.payload['date'] != date ||
          action.payload[actionType == 'circle_attendance' ? 'circleId' : 'courseId'] != targetId) {
        continue;
      }
      return {
        for (final record in (action.payload['records'] as List))
          (record['studentId'] as num).toInt(): (record['status'] as num).toInt(),
      };
    }
    return {};
  }
}
