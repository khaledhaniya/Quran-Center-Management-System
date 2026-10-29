import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_circles_mobile/models/models.dart';
import 'package:quran_circles_mobile/services/api_service.dart';
import 'package:quran_circles_mobile/services/auth_storage.dart';
import 'package:quran_circles_mobile/services/offline_cache.dart';
import 'package:quran_circles_mobile/services/offline_sync_manager.dart';

User user(int id) => User(
    id: id,
    username: 'test$id',
    fullName: 'test',
    role: 'Teacher',
    isActive: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await OfflineSyncManager.stop();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.baseUrl = 'https://test.example/api';
    ApiService.currentUser = user(1);
    ApiService.authToken =
        null; // Queue locally until the test explicitly enables sync.
    ApiService.httpClient = MockClient((_) async => http.Response('{}', 503));
    OfflineCache.configure(server: ApiService.baseUrl, userId: 1);
    OfflineSyncManager.initialize();
  });
  tearDown(() async {
    await OfflineSyncManager.stop();
    ApiService.httpClient.close();
    ApiService.currentUser = null;
    ApiService.authToken = null;
    OfflineCache.resetScope();
  });

  test('Cache and queued operations are isolated by account and server',
      () async {
    await OfflineCache.save('students_list', 'private-account-one');
    await OfflineSyncManager.queueAction(
        actionType: 'create_announcement',
        payload: {'title': 'test', 'content': 'one'});
    OfflineCache.configure(server: ApiService.baseUrl, userId: 2);
    expect(await OfflineCache.load('students_list'), isNull);
    expect(await OfflineSyncManager.getQueuedActions(), isEmpty);
    OfflineCache.configure(server: 'https://other.example/api', userId: 1);
    expect(await OfflineCache.load('students_list'), isNull);
    OfflineCache.configure(server: ApiService.baseUrl, userId: 1);
    final queue = await OfflineSyncManager.getQueuedActions();
    expect(queue.single.ownerUserId, 1);
    expect(queue.single.server, ApiService.baseUrl);
    expect(await OfflineCache.load('students_list'), 'private-account-one');
  });

  test('Logout removes secure credentials and legacy temporary login file',
      () async {
    final oldFile =
        File('${Directory.systemTemp.path}/albayan_cache_user_login.json');
    // This test only writes synthetic credentials; it never reads existing ones.
    if (await oldFile.exists()) return;
    await oldFile.writeAsString('synthetic-test-login');
    await AuthStorage.save(ApiService.baseUrl, 'synthetic-secure-login');
    await ApiService.logout();
    expect(await AuthStorage.load(ApiService.baseUrl), isNull);
    expect(await oldFile.exists(), isFalse);
    expect(ApiService.currentUser, isNull);
    expect(await OfflineCache.load('students_list'), isNull);
  });

  test('Concurrent enqueue survives sync and retries carry the same key',
      () async {
    await OfflineSyncManager.queueAction(
        actionType: 'create_announcement',
        payload: {'title': 'first', 'content': 'one'});
    final first = (await OfflineSyncManager.getQueuedActions()).single;
    final started = Completer<void>();
    final release = Completer<void>();
    final seenKeys = <String?>[];
    ApiService.httpClient = MockClient((request) async {
      seenKeys.add(request.headers['Idempotency-Key'] ??
          request.headers['idempotency-key']);
      if (!started.isCompleted) started.complete();
      await release.future;
      return http.Response('{}', 200);
    });
    ApiService.authToken = 'synthetic-token';
    final sync = OfflineSyncManager.syncPendingActions();
    await started.future;
    await OfflineSyncManager.queueAction(
        actionType: 'create_announcement',
        payload: {'title': 'second', 'content': 'two'});
    release.complete();
    expect(await sync, 1);
    final remaining = await OfflineSyncManager.getQueuedActions();
    expect(remaining.length, 1);
    expect(remaining.single.payload['title'], 'second');
    expect(seenKeys.single, first.id);
    expect(await OfflineSyncManager.syncPendingActions(), 1);
    expect(await OfflineSyncManager.getQueuedActions(), isEmpty);
  });

  test('Unknown and foreign operations are retained without sending', () async {
    await OfflineSyncManager.queueAction(actionType: 'unknown', payload: {});
    final foreign = OfflineAction(
        id: 'foreign',
        actionType: 'create_announcement',
        payload: {},
        createdAt: DateTime.now(),
        ownerUserId: 2,
        server: ApiService.baseUrl);
    final queue = await OfflineSyncManager.getQueuedActions();
    queue.add(foreign);
    await OfflineCache.saveSensitive('offline_sync_queue',
        jsonEncode(queue.map((a) => a.toJson()).toList()));
    var requests = 0;
    ApiService.httpClient = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    ApiService.authToken = 'synthetic-token';
    expect(await OfflineSyncManager.syncPendingActions(), 0);
    expect(requests, 0);
    final retained = await OfflineSyncManager.getQueuedActions();
    expect(retained.length, 2);
    expect(retained.first.reviewError, 'نوع عملية غير مدعوم');
  });

  test('Duplicate offline nominations are stored only once', () async {
    final payload = {
      'studentId': 14, 'nominationType': 'Quran', 'courseId': null,
      'juzStart': 2, 'juzEnd': 2,
    };
    final first = await OfflineSyncManager.queueAction(
        actionType: 'exam_nomination', payload: payload);
    final second = await OfflineSyncManager.queueAction(
        actionType: 'exam_nomination', payload: payload);
    expect(second.id, first.id);
    expect((await OfflineSyncManager.getQueuedActions()).length, 1);
  });

  test('Circle enrollment stays visible until a 204 server receipt confirms it',
      () async {
    var serverHasEnrollment = false;
    ApiService.httpClient = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/circles/3/students')) {
        expect(jsonDecode(request.body)['studentId'], 14);
        serverHasEnrollment = true;
        return http.Response('', 204);
      }
      if (request.url.path.endsWith('/circles')) {
        return http.Response('[{"id":3,"name":"حلقة الفجر"}]', 200);
      }
      if (request.url.path.endsWith('/students')) {
        return http.Response(jsonEncode([{
          'id': 14, 'fullName': 'طالب تجريبي', 'isActive': true,
          'circleId': serverHasEnrollment ? 3 : null,
          'circleName': serverHasEnrollment ? 'حلقة الفجر' : null,
        }]), 200);
      }
      return http.Response('[]', 200);
    });
    await ApiService.getCircles(forceRefresh: true);
    await OfflineSyncManager.queueAction(actionType: 'circle_enrollment', payload: {
      'circleId': 3, 'studentId': 14,
    });
    final pending = (await ApiService.getStudents(forceRefresh: true)).single;
    expect(pending.circleId, 3);
    expect(pending.circleName, 'حلقة الفجر');
    expect(pending.isPendingSync, isTrue);
    ApiService.authToken = 'synthetic-token';
    expect(await OfflineSyncManager.syncPendingActions(), 1);
    expect(serverHasEnrollment, isTrue);
    expect(await OfflineSyncManager.getQueuedActions(), isEmpty);
    final synced = (await ApiService.getStudents(forceRefresh: true)).single;
    expect(synced.circleId, 3);
    expect(synced.isPendingSync, isFalse);
  });

  test('Rejected operation stays visible while independent writes continue', () async {
    await OfflineSyncManager.queueAction(actionType: 'exam_nomination', payload: {
      'studentId': 14, 'nominationType': 'Quran', 'courseId': null,
      'juzStart': 2, 'juzEnd': 2,
    });
    await OfflineSyncManager.queueAction(actionType: 'quality_visit', payload: {
      'circleId': 1, 'punctualityScore': 95,
    });
    var calls = 0;
    ApiService.httpClient = MockClient((_) async {
      calls++;
      return calls == 1
          ? http.Response('{"message":"الترشيح مكرر"}', 400,
              headers: {'content-type': 'application/json; charset=utf-8'})
          : http.Response('{}', 200);
    });
    ApiService.authToken = 'synthetic-token';
    expect(await OfflineSyncManager.syncPendingActions(), 1);
    expect(calls, 2);
    final queue = await OfflineSyncManager.getQueuedActions();
    expect(queue.length, 1);
    expect(queue.first.reviewError, 'الترشيح مكرر',
        reason: 'آخر خطأ مزامنة: ${OfflineSyncManager.lastSyncError.value}; '
            'العملية الأولى: ${queue.first.actionType}');
    expect(OfflineSyncManager.reviewActionsCount.value, 1);
    expect(await OfflineSyncManager.syncPendingActions(), 0);
    expect(calls, 2);
  });

  test('Pending queue is kept in protected storage', () async {
    await OfflineSyncManager.queueAction(
        actionType: 'create_student', payload: {'fullName': 'مؤقت'});
    expect(await OfflineCache.load('offline_sync_queue'), isNull);
    expect((await OfflineCache.loadSensitive('offline_sync_queue')),
        contains('مؤقت'));
  });

  test('Actions for a locally created student use the server ID after sync',
      () async {
    final created = await OfflineSyncManager.queueAction(
        actionType: 'create_student', payload: {
      'fullName': 'طالب جديد', 'studentIdentityNumber': 'offline-01',
      'circleId': 3,
    });
    final localId = created.payload['_localId'] as int;
    expect(localId, lessThan(0));
    await OfflineSyncManager.queueAction(actionType: 'recitation_session', payload: {
      'studentId': localId, 'sessionDate': '2026-10-29',
      'surahName': 'الفاتحة', 'fromVerse': 1, 'toVerse': 7,
      'assessment': 1,
    });
    final sent = <http.Request>[];
    ApiService.httpClient = MockClient((request) async {
      sent.add(request);
      if (request.url.path.endsWith('/students')) {
        return http.Response('{"student":{"id":51}}', 201);
      }
      return http.Response('{}', 201);
    });
    ApiService.authToken = 'synthetic-token';
    expect(await OfflineSyncManager.syncPendingActions(), 2);
    expect(jsonDecode(sent.last.body)['studentId'], 51);
    expect(await OfflineSyncManager.getQueuedActions(), isEmpty);
  });

  test('Exam evaluation draft never stores the confirmation password', () async {
    await OfflineSyncManager.queueAction(
        actionType: 'exam_evaluation_draft', payload: {
      'nominationId': 7, 'majorMistakes': 0, 'minorMistakes': 1,
      'grade': 96.0, 'notes': 'مسودة',
    });
    final raw = await OfflineCache.loadSensitive('offline_sync_queue');
    expect(raw, contains('exam_evaluation_draft'));
    expect(raw, isNot(contains('code2FA')));
    expect(OfflineSyncManager.reviewActionsCount.value, 1);
  });
}
