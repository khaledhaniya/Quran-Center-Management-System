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
    await OfflineCache.save('offline_sync_queue',
        jsonEncode(queue.map((a) => a.toJson()).toList()));
    var requests = 0;
    ApiService.httpClient = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    ApiService.authToken = 'synthetic-token';
    expect(await OfflineSyncManager.syncPendingActions(), 0);
    expect(requests, 0);
    expect((await OfflineSyncManager.getQueuedActions()).length, 2);
  });
}
