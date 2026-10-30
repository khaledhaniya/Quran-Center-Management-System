import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'offline_cache.dart';
import 'auth_storage.dart';
import 'notification_service.dart';
import 'offline_sync_manager.dart';

class ApiService {
  static String baseUrl =
      kIsWeb && ['localhost', '127.0.0.1'].contains(Uri.base.host)
          ? '${Uri.base.origin}/api'
          : 'https://albayan-ali-center.tryasp.net/api';
  static http.Client httpClient = http.Client();
  static User? currentUser;
  static String? authToken;
  static final usingOfflineData = ValueNotifier<bool>(false);

  static bool isNetworkError(Object error) =>
      error is TimeoutException || error is SocketException ||
      error is http.ClientException;

  static Future<User?> refreshSessionProfile() async {
    if(authToken==null)return currentUser;
    final response=await httpClient.get(Uri.parse('$baseUrl/auth/me'),headers:_headers()).timeout(const Duration(seconds:10));
    if(response.statusCode==401||response.statusCode==403){await logout();throw Exception('انتهت جلسة الدخول');}
    if(response.statusCode!=200)return currentUser;
    usingOfflineData.value = false;
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    final user=User.fromJson({...data,'id':data['userId']});currentUser=user;
    await AuthStorage.save(baseUrl,jsonEncode({'token':authToken,'user':{...data,'id':data['userId']}}));
    return user;
  }
  static Future<Map<String,dynamic>> getParentPortal({String? from,String? to}) async {
    final uri=Uri.parse('$baseUrl/parent/portal').replace(queryParameters:{if(from!=null&&from.isNotEmpty)'from':from,if(to!=null&&to.isNotEmpty)'to':to});
    final response=await httpClient.get(uri,headers:_headers());final data=jsonDecode(response.body);
    if(response.statusCode!=200)throw Exception(data['error']??'تعذر تحميل متابعة الأبناء');
    return Map<String,dynamic>.from(data);
  }

  static Future<String> resetUserPassword(int userId,String currentPassword) async {
    final response=await httpClient.post(Uri.parse('$baseUrl/users/$userId/reset-password'),headers:_headers(),body:jsonEncode({'currentPassword':currentPassword}));
    final data=jsonDecode(response.body);
    if(response.statusCode!=200)throw Exception(data['error']??'تعذر إعادة تعيين كلمة المرور');
    return data['password'].toString();
  }

  static Future<dynamic> centerOperation(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl/operations/$path');
    final response = body == null ? await httpClient.get(uri,headers:_headers())
        : await httpClient.post(uri,headers:_headers(),body:jsonEncode(body));
    final data = jsonDecode(response.body);
    if(response.statusCode < 200 || response.statusCode >= 300) throw Exception(data is Map ? data['error'] ?? 'تعذر تنفيذ الطلب' : 'تعذر تنفيذ الطلب');
    return data;
  }

  static Future<Uri> createDownloadTicket({required String format, Map<String, dynamic>? filter,
      String? certificateKind, int? certificateId, bool thumbnail = false}) async {
    final response = await httpClient.post(Uri.parse('$baseUrl/exports/ticket'),
        headers: _headers(), body: jsonEncode({'format': format, 'filter': filter,
          'certificateKind': certificateKind, 'certificateId': certificateId, 'thumbnail': thumbnail}));
    if (response.statusCode != 200) throw Exception('تعذر تجهيز الملف (${response.statusCode})');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Uri.parse(baseUrl).resolve(data['url'].toString());
  }

  static Future<Uint8List> fetchCertificatePreview({required String certificateKind,
      required int certificateId, bool thumbnail = false}) async {
    final uri = await createDownloadTicket(format: 'png',
        certificateKind: certificateKind, certificateId: certificateId, thumbnail: thumbnail);
    final response = await httpClient.get(uri);
    if (response.statusCode != 200 ||
        !(response.headers['content-type'] ?? '').contains('image/png')) {
      throw Exception('تعذر عرض صورة الشهادة (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> previewReport(Map<String, dynamic> filter) async {
    final response = await httpClient.post(Uri.parse('$baseUrl/exports/preview'),
        headers: _headers(), body: jsonEncode(filter));
    if (response.statusCode != 200) throw Exception('تعذر عرض التقرير (${response.statusCode})');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> setBaseUrl(String url) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null ||
        !parsed.hasAuthority ||
        !['http', 'https'].contains(parsed.scheme)) {
      throw ArgumentError('رابط الخادم غير صالح.');
    }
    if (parsed.scheme != 'https' &&
        !['localhost', '127.0.0.1', '10.0.2.2'].contains(parsed.host)) {
      throw ArgumentError('يلزم HTTPS لحماية بيانات الدخول على الخادم البعيد.');
    }
    await logout();
    baseUrl = url.trim().replaceFirst(RegExp(r'/+$'), '');
    if (!baseUrl.endsWith('/api')) baseUrl = '$baseUrl/api';
  }

  // Fast In-Memory Cache for Instant UI
  static List<Student>? _cachedStudents;
  static List<Teacher>? _cachedTeachers;
  static List<Circle>? _cachedCircles;
  static int _cacheGeneration = 0;

  static void invalidateCache() {
    _cacheGeneration++;
    _cachedStudents = null;
    _cachedTeachers = null;
    _cachedCircles = null;
  }

  static Map<String, String> _headers({String? code2FA}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    if (code2FA != null && code2FA.isNotEmpty) {
      headers['X-Confirm-Password'] = code2FA;
    }
    return headers;
  }

  static Future<http.Response> sendOfflineRequest({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required String operationId,
  }) {
    final request = http.Request(method, Uri.parse('$baseUrl/$path'));
    request.headers.addAll({..._headers(), 'Idempotency-Key': operationId});
    request.body = jsonEncode(body);
    return httpClient
        .send(request)
        .timeout(const Duration(seconds: 20))
        .then(http.Response.fromStream);
  }

  static Future<dynamic> _getCachedJson(String path, String key,
      {dynamic offlineDefault}) async {
    http.Response response;
    try {
      response = await httpClient.get(Uri.parse('$baseUrl/$path'),
          headers: _headers()).timeout(const Duration(seconds: 8));
    } catch (_) {
      final cached = await OfflineCache.load(key);
      usingOfflineData.value = true;
      if (cached != null) return jsonDecode(cached);
      if (offlineDefault != null) return offlineDefault;
      rethrow;
    }
    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل البيانات (${response.statusCode})');
    }
    usingOfflineData.value = false;
    await OfflineCache.save(key, response.body);
    return jsonDecode(response.body);
  }

  // --- Auth ---
  static bool isTokenCurrent(String? token) {
    if (token == null) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final expiry = claims['exp'];
      return expiry is num &&
          expiry * 1000 > DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  static bool _withinOfflineGrace(String? token) {
    if (token == null) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final expiry = claims['exp'];
      return expiry is num && DateTime.now().millisecondsSinceEpoch <
          (expiry.toInt() + const Duration(days: 30).inSeconds) * 1000;
    } catch (_) {
      return false;
    }
  }

  static Future<User?> tryAutoLogin() async {
    // Do not migrate legacy plaintext credentials into secure storage.
    await OfflineCache.remove('user_login');
    try {
      final cached = await AuthStorage.load(baseUrl);
      if (cached == null) return null;
      final json = jsonDecode(cached);
      final token = json['token']?.toString();
      var user = User.fromJson(json['user'] ?? json);
      if (user.id <= 0) return null;
      if (!_withinOfflineGrace(token)) {
        await AuthStorage.remove(baseUrl);
        return null;
      }
      currentUser = user;
      authToken = isTokenCurrent(token) ? token : null;
      try {
        final response = await httpClient
            .get(Uri.parse('$baseUrl/auth/me'), headers: {
              ..._headers(), 'Authorization': 'Bearer $token',
            })
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 401 || response.statusCode == 403) {
          await logout();
          return null;
        }
        if(response.statusCode==200){final verified=jsonDecode(response.body) as Map<String,dynamic>;
          user=User.fromJson({...((json['user']??json) as Map<String,dynamic>),...verified,'id':verified['userId']});currentUser=user;
        }
      } catch (_) {
        usingOfflineData.value = true;
      }
      OfflineCache.configure(server: baseUrl, userId: user.id);
      NotificationService.start(user);
      OfflineSyncManager.initialize();
      return user;
    } catch (_) {
      currentUser = null;
      authToken = null;
      OfflineCache.resetScope();
      return null;
    }
  }

  static Future<User> login(String username, String password) async {
    await OfflineSyncManager.stop();
    NotificationService.stop();
    invalidateCache();
    usingOfflineData.value = false;
    currentUser = null;
    authToken = null;
    OfflineCache.resetScope();
    final response = await httpClient.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final user = User.fromJson(json['user'] ?? json);
      currentUser = user;
      authToken = json['token']?.toString() ?? '';
      OfflineCache.configure(server: baseUrl, userId: user.id);
      await AuthStorage.save(baseUrl, response.body);
      await OfflineCache.remove('user_login');
      NotificationService.start(user);
      OfflineSyncManager.initialize();
      return user;
    } else {
      String errorMsg =
          'بيانات الدخول غير صحيحة. يرجى التحقق من اسم المستخدم وكلمة المرور.';
      try {
        final err = jsonDecode(response.body);
        errorMsg = err['message'] ?? err['error'] ?? errorMsg;
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  static Future<bool> changePassword(
      {String? currentPassword, required String newPassword}) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: _headers(),
      body: jsonEncode({
        if (currentPassword != null && currentPassword.isNotEmpty)
          'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      await logout();
      return true;
    } else {
      String msg = 'فشل تغيير كلمة المرور.';
      try {
        final err = jsonDecode(response.body);
        msg = err['message'] ?? err['error'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> logout() async {
    await OfflineSyncManager.stop();
    NotificationService.stop();
    currentUser = null;
    authToken = null;
    await AuthStorage.remove(baseUrl);
    await OfflineCache.remove('user_login');
    OfflineCache.resetScope();
    invalidateCache();
    usingOfflineData.value = false;
  }

  // --- Students CRUD ---
  static Future<String?> checkNewStudentIdentity(String identity,
      {String? username}) async {
    final uri = Uri.parse('$baseUrl/students/identity-check').replace(
        queryParameters: {
          'identity': identity.trim(),
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
        });
    final response = await httpClient.get(uri, headers: _headers())
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception('تعذر التحقق من رقم الهوية حالياً.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['available'] == true ? null
        : (data['error']?.toString() ?? 'رقم الهوية أو اسم المستخدم مستخدم بالفعل.');
  }

  static String _pendingCircleName(Object? circleId) {
    for (final circle in _cachedCircles ?? <Circle>[]) {
      if (circle.id == circleId) return circle.name;
    }
    return 'بانتظار المزامنة';
  }

  static Future<List<Student>> _withPendingStudents(List<Student> students,
      {String? search}) async {
    final actions = await OfflineSyncManager.getQueuedActions();
    final pendingCircleIds = <int, int>{};
    for (final action in actions) {
      if (action.actionType != 'circle_enrollment' || action.reviewError != null) continue;
      final studentId = action.payload['studentId'];
      final circleId = action.payload['circleId'];
      if (studentId is int && circleId is int) pendingCircleIds[studentId] = circleId;
    }
    final visibleStudents = students.map((student) {
      final circleId = pendingCircleIds[student.id];
      return circleId == null ? student
          : student.withPendingCircle(circleId, _pendingCircleName(circleId));
    }).toList();
    final pending = await OfflineSyncManager.pendingStudents();
    if (pending.isEmpty) return visibleStudents;
    final identities = visibleStudents.map((s) => s.studentIdentityNumber).toSet();
    return [
      ...visibleStudents,
      ...pending.where((p) => (p['studentIdentityNumber'] == null ||
          !identities.contains(p['studentIdentityNumber'])) &&
          (search == null || search.isEmpty ||
              p['fullName'].toString().contains(search) ||
              p['studentIdentityNumber']?.toString().contains(search) == true))
          .map((p) => Student.fromJson({
            ...p,
            'circleName': _pendingCircleName(p['circleId']),
          })),
    ];
  }

  static Future<List<Student>> getStudents(
      {String? search, bool forceRefresh = false}) async {
    final generation = _cacheGeneration;
    if (!forceRefresh &&
        (search == null || search.isEmpty) &&
        _cachedStudents != null) {
      return _withPendingStudents(_cachedStudents!);
    }

    String url = '$baseUrl/students';
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeComponent(search)}';
    }
    try {
      final response =
          await httpClient.get(Uri.parse(url), headers: _headers())
              .timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 || response.statusCode == 403) {
        invalidateCache();
        return [];
      }
      if (response.statusCode == 200) {
        usingOfflineData.value = false;
        if (generation != _cacheGeneration) return [];
        final List data = jsonDecode(response.body);
        final list = data.map((item) => Student.fromJson(item)).toList();
        if (search == null || search.isEmpty) {
          _cachedStudents = list;
        }
        await OfflineCache.save('students_list', response.body);
        return await _withPendingStudents(list, search: search);
      }
    } catch (_) {
      final cached = await OfflineCache.load('students_list');
      if (cached != null) {
        usingOfflineData.value = true;
        final List data = jsonDecode(cached);
        return await _withPendingStudents(
            data.map((item) => Student.fromJson(item)).toList(), search: search);
      }
    }
    return _withPendingStudents(_cachedStudents ?? [], search: search);
  }

  static Future<List<Student>> getAllStudentsForEnrollment(
      {String? search}) async {
    String url = '$baseUrl/students/all-for-enrollment';
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeComponent(search)}';
    }
    try {
      final response =
          await httpClient.get(Uri.parse(url), headers: _headers());
      if (response.statusCode == 200) {
        usingOfflineData.value = false;
        final List data = jsonDecode(response.body);
        return await _withPendingStudents(
            data.map((item) => Student.fromJson(item)).toList(), search: search);
      }
    } catch (_) {}
    return getStudents(search: search);
  }

  static Future<bool> createStudent(Map<String, dynamic> data) async {
    invalidateCache();
    final response = await httpClient.post(
      Uri.parse('$baseUrl/students'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<bool> updateStudent(int id, Map<String, dynamic> data) async {
    invalidateCache();
    final response = await httpClient.put(
      Uri.parse('$baseUrl/students/$id'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteStudent(int id) async {
    invalidateCache();
    final response = await httpClient.delete(Uri.parse('$baseUrl/students/$id'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Teachers CRUD ---
  static Future<List<Teacher>> getTeachers({bool forceRefresh = false}) async {
    final generation = _cacheGeneration;
    if (!forceRefresh && _cachedTeachers != null) {
      return _cachedTeachers!;
    }
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/teachers'),
          headers: _headers()).timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 || response.statusCode == 403) {
        invalidateCache();
        return [];
      }
      if (response.statusCode == 200) {
        usingOfflineData.value = false;
        if (generation != _cacheGeneration) return [];
        final List data = jsonDecode(response.body);
        final list = data.map((item) => Teacher.fromJson(item)).toList();
        _cachedTeachers = list;
        await OfflineCache.save('teachers_list', response.body);
        return list;
      }
    } catch (_) {
      final cached = await OfflineCache.load('teachers_list');
      if (cached != null) {
        usingOfflineData.value = true;
        final List data = jsonDecode(cached);
        return data.map((item) => Teacher.fromJson(item)).toList();
      }
    }
    return _cachedTeachers ?? [];
  }

  static Future<bool> createTeacher({
    required String fullName,
    String? contact,
    String? address,
    String? dateOfBirth,
    String? username,
    String? password,
    String? identityNumber,
    String? whatsappNumber,
    String? socialStatus,
    int? familyMembersCount,
    String? mosqueName,
    String? qualification,
    String? taskRole,
    String? walletNumber,
    String? walletOwner,
    String? memorizedAjzaa,
    String? studentsCountTarget,
  }) async {
    invalidateCache();
    final response = await httpClient.post(
      Uri.parse('$baseUrl/teachers'),
      headers: _headers(),
      body: jsonEncode({
        'fullName': fullName,
        'contact': contact,
        'address': address,
        'dateOfBirth': dateOfBirth,
        'username': username,
        'password': password,
        'identityNumber': identityNumber,
        'whatsappNumber': whatsappNumber,
        'socialStatus': socialStatus,
        'familyMembersCount': familyMembersCount,
        'mosqueName': mosqueName,
        'qualification': qualification,
        'taskRole': taskRole,
        'walletNumber': walletNumber,
        'walletOwner': walletOwner,
        'memorizedAjzaa': memorizedAjzaa,
        'studentsCountTarget': studentsCountTarget,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<bool> updateTeacher(
    int id, {
    required String fullName,
    String? contact,
    String? address,
    String? dateOfBirth,
    String? identityNumber,
    String? whatsappNumber,
    String? socialStatus,
    int? familyMembersCount,
    String? mosqueName,
    String? qualification,
    String? taskRole,
    String? walletNumber,
    String? walletOwner,
    String? memorizedAjzaa,
    String? studentsCountTarget,
  }) async {
    invalidateCache();
    final response = await httpClient.put(
      Uri.parse('$baseUrl/teachers/$id'),
      headers: _headers(),
      body: jsonEncode({
        'fullName': fullName,
        'contact': contact,
        'address': address,
        'dateOfBirth': dateOfBirth,
        'identityNumber': identityNumber,
        'whatsappNumber': whatsappNumber,
        'socialStatus': socialStatus,
        'familyMembersCount': familyMembersCount,
        'mosqueName': mosqueName,
        'qualification': qualification,
        'taskRole': taskRole,
        'walletNumber': walletNumber,
        'walletOwner': walletOwner,
        'memorizedAjzaa': memorizedAjzaa,
        'studentsCountTarget': studentsCountTarget,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteTeacher(int id) async {
    invalidateCache();
    final response = await httpClient.delete(Uri.parse('$baseUrl/teachers/$id'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Circles CRUD ---
  static Future<List<Circle>> getCircles({bool forceRefresh = false}) async {
    final generation = _cacheGeneration;
    if (!forceRefresh && _cachedCircles != null) {
      return _cachedCircles!;
    }
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/circles'),
          headers: _headers()).timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 || response.statusCode == 403) {
        invalidateCache();
        return [];
      }
      if (response.statusCode == 200) {
        usingOfflineData.value = false;
        if (generation != _cacheGeneration) return [];
        final List data = jsonDecode(response.body);
        final list = data.map((item) => Circle.fromJson(item)).toList();
        _cachedCircles = list;
        await OfflineCache.save('circles_list', response.body);
        return list;
      }
    } catch (_) {
      final cached = await OfflineCache.load('circles_list');
      if (cached != null) {
        usingOfflineData.value = true;
        final List data = jsonDecode(cached);
        return data.map((item) => Circle.fromJson(item)).toList();
      }
    }
    return _cachedCircles ?? [];
  }

  static Future<bool> createCircle({
    required String name,
    String? timing,
    int? teacherId,
    int? assistantTeacherId,
  }) async {
    invalidateCache();
    final response = await httpClient.post(
      Uri.parse('$baseUrl/circles'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'timing': timing ?? 'Fajr',
        'teacherId': teacherId,
        'assistantTeacherId': assistantTeacherId,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<bool> updateCircle(
    int id, {
    required String name,
    String? timing,
    int? teacherId,
    int? assistantTeacherId,
    bool isActive = true,
  }) async {
    invalidateCache();
    final response = await httpClient.put(
      Uri.parse('$baseUrl/circles/$id'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'timing': timing,
        'teacherId': teacherId,
        'assistantTeacherId': assistantTeacherId,
        'isActive': isActive,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteCircle(int id) async {
    final response = await httpClient.delete(Uri.parse('$baseUrl/circles/$id'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Courses CRUD ---
  static Future<List<Map<String, dynamic>>> getCircleLeaderboard() async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/competitions/leaderboard'), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception('فشل تحميل صدارة الحلقات (${response.statusCode})');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  static Future<List<Course>> getCourses() async {
    final List data = await _getCachedJson('courses', 'courses_list');
    return data.map((item) => Course.fromJson(item)).toList();
  }

  static Future<bool> createCourse({
    required String name,
    String? description,
    int? teacherId,
    int? examSupervisorId,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/courses'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'teacherId': teacherId,
        'examSupervisorId': examSupervisorId,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<bool> updateCourse(
    int id, {
    required String name,
    String? description,
    int? teacherId,
    int? examSupervisorId,
  }) async {
    final response = await httpClient.put(
      Uri.parse('$baseUrl/courses/$id'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'teacherId': teacherId,
        'examSupervisorId': examSupervisorId,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteCourse(int id) async {
    final response = await httpClient.delete(Uri.parse('$baseUrl/courses/$id'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> enrollInCourse({
    required int courseId,
    int? studentId,
    int? circleId,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/courses/enroll'),
      headers: _headers(),
      body: jsonEncode({
        'courseId': courseId,
        'studentId': studentId,
        'circleId': circleId,
      }),
    );
    if (response.statusCode == 200) return true;
    try {
      final err = jsonDecode(response.body);
      throw Exception(
          err['message'] ?? err['error'] ?? 'فشل تسجيل الطالب بالدورة');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('فشل الاتصال بالإنترنت لتسجيل الطالب بالدورة');
    }
  }

  static Future<List<Map<String, dynamic>>> getMyCourses() async {
    final List data = await _getCachedJson('courses/my-courses', 'my_courses');
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // --- Attendance & Sessions ---
  static Future<List<CourseAttendanceRecord>> getCourseAttendance(
      int courseId, String date) async {
    final enrollData = await getCourseEnrollments(courseId);
    final List attData = await _getCachedJson(
        'courses/$courseId/attendance?date=${Uri.encodeComponent(date)}',
        'course_attendance_${courseId}_$date', offlineDefault: []);

    final Map<int, int> statusMap = {};
    for (var item in attData) {
      statusMap[item['studentId'] ?? 0] = item['status'] ?? 1;
    }

    return enrollData.map((item) {
        final sId = item['studentId'] ?? 0;
        final statusVal = statusMap[sId] ?? 1;
        String statusTxt = 'حاضر';
        if (statusVal == 2) statusTxt = 'غائب';
        if (statusVal == 3) statusTxt = 'متأخر';
        if (statusVal == 4) statusTxt = 'غائب بعذر';

        return CourseAttendanceRecord(
          id: item['id'] ?? 0,
          studentId: sId,
          studentName: item['studentName'] ?? '',
          courseId: courseId,
          courseName: '',
          sessionDate: date,
          status: statusVal,
          statusText: statusTxt,
        );
      }).toList();
  }

  static Future<bool> saveCourseAttendance(
      int courseId, String sessionDate, List<Map<String, dynamic>> items,
      {String? operationId}) async {
    final response = await httpClient
        .post(
          Uri.parse('$baseUrl/courses/attendance'),
          headers: {
            ..._headers(),
            if (operationId != null) 'Idempotency-Key': operationId
          },
          body: jsonEncode({
            'courseId': courseId,
            'sessionDate': sessionDate,
            'items': items,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return response.statusCode == 200;
  }

  static Future<bool> saveCircleAttendance(
      int circleId, String sessionDate, List<Map<String, dynamic>> records,
      {String? operationId}) async {
    bool ok = true;
    for (var r in records) {
      final resp = await httpClient
          .post(
            Uri.parse('$baseUrl/attendance'),
            headers: {
              ..._headers(),
              if (operationId != null)
                'Idempotency-Key': '$operationId-${r['studentId']}'
            },
            body: jsonEncode({
              'studentId': r['studentId'],
              'circleId': circleId,
              'sessionDate': sessionDate,
              'status': r['status'],
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) ok = false;
    }
    return ok;
  }

  static Future<bool> saveRecitationSession({
    required int studentId,
    required String sessionDate,
    required String surahName,
    required int fromVerse,
    required int toVerse,
    required int assessment,
    String? notes,
    bool viaLottery = false,
    int recitationType = 1,
    String? operationId,
  }) async {
    final response = await httpClient
        .post(
          Uri.parse('$baseUrl/sessions'),
          headers: {
            ..._headers(),
            if (operationId != null) 'Idempotency-Key': operationId
          },
          body: jsonEncode({
            'studentId': studentId,
            'sessionDate': sessionDate,
            'surahName': surahName,
            'fromVerse': fromVerse,
            'toVerse': toVerse,
            'assessment': assessment,
            'notes': notes,
            'viaLottery': viaLottery,
            'recitationType': recitationType,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> enrollStudentInCircle(int circleId, int studentId) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/circles/$circleId/students'),
      headers: _headers(),
      body: jsonEncode({'studentId': studentId}),
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final body = jsonDecode(response.body);
    throw Exception(
        body['error'] ?? body['message'] ?? 'فشل تنسيب الطالب للحلقة');
  }

  static Future<bool> unenrollStudentFromCircle(
      int circleId, int studentId) async {
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/circles/$circleId/students/$studentId'),
      headers: _headers(),
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final body = jsonDecode(response.body);
    throw Exception(
        body['error'] ?? body['message'] ?? 'فشل إلغاء تنسيب الطالب من الحلقة');
  }

  static Future<List<Map<String, dynamic>>> getStudentsForEnrollment(
      {String? search}) async {
    String path = 'students/all-for-enrollment';
    if (search != null && search.trim().isNotEmpty) {
      path += '?search=${Uri.encodeComponent(search.trim())}';
    }
    final List data = await _getCachedJson(path,
        search == null || search.isEmpty ? 'enrollment_candidates'
            : 'enrollment_candidates_${search.trim()}');
    final candidates = data.map((e) => Map<String, dynamic>.from(e)).toList();
    final pending = await OfflineSyncManager.getQueuedActions();
    for (final action in pending) {
      if (action.actionType != 'circle_enrollment' || action.reviewError != null) continue;
      final studentId = action.payload['studentId'];
      final circleId = action.payload['circleId'];
      if (studentId is! int || circleId is! int) continue;
      for (final candidate in candidates.where((c) => c['id'] == studentId)) {
        candidate['circleId'] = circleId;
        candidate['circleName'] = _pendingCircleName(circleId);
        candidate['pendingSync'] = true;
      }
    }
    return candidates;
  }

  static Future<bool> updateRecitationSession({
    required int id,
    required String sessionDate,
    required String surahName,
    required int fromVerse,
    required int toVerse,
    required int assessment,
    String? notes,
    int recitationType = 1,
  }) async {
    final response = await httpClient.put(
      Uri.parse('$baseUrl/sessions/$id'),
      headers: _headers(),
      body: jsonEncode({
        'sessionDate': sessionDate,
        'surahName': surahName,
        'fromVerse': fromVerse,
        'toVerse': toVerse,
        'assessment': assessment,
        'notes': notes,
        'recitationType': recitationType,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteRecitationSession(int id) async {
    final response = await httpClient.delete(
      Uri.parse('$baseUrl/sessions/$id'),
      headers: _headers(),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<Map<String, dynamic>> drawLottery(
      int circleId, String date) async {
    final response = await httpClient.get(
      Uri.parse('$baseUrl/sessions/lottery/$circleId?date=$date'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? body['message'] ?? 'فشل سحب القرعة');
  }

  static Future<List<Map<String, dynamic>>> getStudentSessions(
      int studentId) async {
    final List data = await _getCachedJson('sessions/student/$studentId',
        'student_sessions_$studentId', offlineDefault: []);
    final sessions = data.map((e) => Map<String, dynamic>.from(e)).toList();
    final pending = await OfflineSyncManager.getQueuedActions();
    for (final action in pending.where((a) =>
        a.actionType == 'recitation_session' && a.payload['studentId'] == studentId)) {
      sessions.insert(0, {
        ...action.payload,
        'id': -action.createdAt.millisecondsSinceEpoch,
        'pendingSync': true,
        'syncError': action.reviewError,
      });
    }
    return sessions;
  }

  static Future<Map<String, dynamic>> getQualityOverview() async {
    return Map<String, dynamic>.from(
        await _getCachedJson('quality/overview', 'quality_overview'));
  }

  // --- Exams & Nominations ---
  static Future<List<ExamNomination>> getNominations() async {
    final List data = await _getCachedJson('exams/nominations', 'nominations',
        offlineDefault: []);
    final nominations = data.map((item) => ExamNomination.fromJson(item)).toList();
    final pending = await OfflineSyncManager.getQueuedActions();
    final pendingNominations = pending.where((a) => a.actionType == 'exam_nomination').toList();
    final students = pendingNominations.isEmpty ? <Student>[] : await getStudents();
    for (final action in pendingNominations) {
      final p = action.payload;
      var studentName = 'طالب رقم ${p['studentId']}';
      for (final student in students) {
        if (student.id == p['studentId']) { studentName = student.fullName; break; }
      }
      nominations.insert(0, ExamNomination(
        id: -action.createdAt.millisecondsSinceEpoch,
        studentId: (p['studentId'] as num).toInt(),
        studentName: studentName,
        halaqahName: '', teacherName: '',
        nominationType: p['nominationType']?.toString() ?? 'Quran',
        courseId: (p['courseId'] as num?)?.toInt(),
        juzStart: (p['juzStart'] as num?)?.toInt() ?? 1,
        juzEnd: (p['juzEnd'] as num?)?.toInt() ?? 1,
        status: 'LocalPending',
        nominationDate: action.createdAt.toLocal().toString().substring(0, 16),
      ));
    }
    for (final action in pending.where((a) => a.actionType == 'exam_schedule')) {
      final index = nominations.indexWhere(
          (n) => n.id == action.payload['nominationId']);
      if (index >= 0) {
        nominations[index] = nominations[index]
            .withPendingSchedule(action.payload['examDate'].toString());
      }
    }
    return nominations;
  }

  static Future<bool> nominateExam({
    required int studentId,
    required String nominationType,
    int? courseId,
    required int juzStart,
    required int juzEnd,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/exams/nominate'),
      headers: _headers(),
      body: jsonEncode({
        'studentId': studentId,
        'nominationType': nominationType,
        'courseId': courseId,
        'juzStart': juzStart,
        'juzEnd': juzEnd,
      }),
    );
    if (response.statusCode == 200) return true;
    final err = jsonDecode(response.body);
    throw Exception(err['message'] ?? 'فشل تقديم الترشيح');
  }

  static Future<bool> scheduleExam(int nominationId, String examDate) async {
    final response = await httpClient.put(
      Uri.parse('$baseUrl/exams/schedule'),
      headers: _headers(),
      body: jsonEncode({
        'nominationId': nominationId,
        'examDate': examDate,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> evaluateExam({
    required int nominationId,
    required int majorMistakes,
    required int minorMistakes,
    required double grade,
    String? notes,
    required String code2FA,
    String? operationId,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/exams/evaluate'),
      headers: {..._headers(code2FA: code2FA),
        if (operationId != null) 'Idempotency-Key': operationId},
      body: jsonEncode({
        'nominationId': nominationId,
        'majorMistakes': majorMistakes,
        'minorMistakes': minorMistakes,
        'grade': grade,
        'notes': notes,
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(
          err['error'] ?? err['message'] ?? 'فشل حفظ نتيجة التقييم');
    }
  }

  static Future<List<Map<String, dynamic>>> getCourseEnrollments(
      int courseId) async {
    final List data = await _getCachedJson('courses/$courseId/enrollments',
        'course_enrollments_$courseId', offlineDefault: []);
    final enrollments = data.map((e) => Map<String, dynamic>.from(e)).toList();
    final pending = await OfflineSyncManager.getQueuedActions();
    final courseActions = pending.where((a) => a.actionType == 'course_enrollment' &&
        a.payload['courseId'] == courseId).toList();
    if (courseActions.isEmpty) return enrollments;
    final students = await getStudents();
    final existing = enrollments.map((e) => e['studentId']).toSet();
    for (final action in courseActions) {
      final p = action.payload;
      final candidates = students.where((s) => p['studentId'] != null
          ? s.id == p['studentId'] : s.circleId == p['circleId']);
      for (final student in candidates) {
        if (existing.add(student.id)) {
          enrollments.add({
            'id': -action.createdAt.millisecondsSinceEpoch,
            'studentId': student.id,
            'studentName': student.fullName,
            'pendingSync': true,
          });
        }
      }
    }
    return enrollments;
  }

  // --- Active Toggles ---
  static Future<bool> toggleStudentActive(int id) async {
    final response = await httpClient.post(
        Uri.parse('$baseUrl/students/$id/toggle-active'),
        headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> toggleTeacherActive(int id) async {
    final response = await httpClient.post(
        Uri.parse('$baseUrl/teachers/$id/toggle-active'),
        headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> toggleCircleActive(int id) async {
    final response = await httpClient.post(
        Uri.parse('$baseUrl/circles/$id/toggle-active'),
        headers: _headers());
    return response.statusCode == 200;
  }

  // --- Student 360 View ---
  static Future<Map<String, dynamic>> getStudent360(int studentId) async {
    try {
      final response = await httpClient.get(
          Uri.parse('$baseUrl/students/$studentId/progress'),
          headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    final responseFallback = await httpClient.get(
        Uri.parse('$baseUrl/students/$studentId/360'),
        headers: _headers());
    if (responseFallback.statusCode == 200) {
      return jsonDecode(responseFallback.body);
    }
    throw Exception(
        'فشل جلب الملف الموحد للطالب (${responseFallback.statusCode})');
  }

  // --- Users & Announcements ---
  static Future<List<User>> getUsers() async {
    final response =
        await httpClient.get(Uri.parse('$baseUrl/users'), headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => User.fromJson(item)).toList();
    }
    return [];
  }

  static Future<bool> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/users'),
      headers: _headers(),
      body: jsonEncode({
        'username': username,
        'password': password,
        'fullName': fullName,
        'role': role,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<List<Announcement>> getAnnouncements() async {
    final response = await httpClient
        .get(Uri.parse('$baseUrl/announcements/my'), headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => Announcement.fromJson(item)).toList();
    }
    return [];
  }

  static Future<bool> createAnnouncement({
    required String title,
    required String content,
    int targetType = 1,
    int? targetId,
    String? senderCapacity,
    String? operationId,
  }) async {
    final response = await httpClient
        .post(
          Uri.parse('$baseUrl/announcements'),
          headers: {
            ..._headers(),
            if (operationId != null) 'Idempotency-Key': operationId
          },
          body: jsonEncode({
            'title': title,
            'content': content,
            'targetType': targetType,
            'targetId': targetId,
            'senderCapacity': senderCapacity,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<List<AuditLog>> getAuditLogs() async {
    final response = await httpClient.get(Uri.parse('$baseUrl/audit-logs'),
        headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => AuditLog.fromJson(item)).toList();
    }
    return [];
  }

  // --- Profile Requests ---
  static Future<List<dynamic>> getProfileUpdateRequests() async {
    final response = await httpClient.get(
        Uri.parse('$baseUrl/profile-update-requests'),
        headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
  }

  static Future<bool> approveProfileRequest(int id) async {
    final response = await httpClient.post(
        Uri.parse('$baseUrl/profile-update-requests/$id/approve'),
        headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> rejectProfileRequest(int id) async {
    final response = await httpClient.post(
        Uri.parse('$baseUrl/profile-update-requests/$id/reject'),
        headers: _headers());
    return response.statusCode == 200;
  }

  // --- Parent & Dual-Role Children Data ---
  static Future<List<dynamic>> getMyChildrenProgressDetails() async {
    try {
      final response = await httpClient
          .get(Uri.parse('$baseUrl/parent/children'), headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Student>> getMyChildren() async {
    try {
      final response = await httpClient
          .get(Uri.parse('$baseUrl/parent/children'), headers: _headers());
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) {
          final rawId = item['studentId'] ?? item['childId'] ?? item['id'];
          final int childId = rawId is int
              ? rawId
              : (int.tryParse(rawId?.toString() ?? '0') ?? 0);
          return Student(
            id: childId,
            fullName: (item['studentName'] ?? item['fullName'])?.toString() ?? 'ابن',
            circleName: item['circleName']?.toString(),
            isActive: true,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getMyChildrenTeachers() async {
    try {
      final response = await httpClient
          .get(Uri.parse('$baseUrl/parent/teachers'), headers: _headers());
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (_) {}
    return [];
  }

  // --- Parent Audit Data ---
  static Future<List<dynamic>> getParentAuditData() async {
    final response = await httpClient.get(Uri.parse('$baseUrl/parent/audit'),
        headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
  }

  static Future<bool> unlinkChildFromParent(int studentId) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/parent/unlink-child'),
      headers: _headers(),
      body: jsonEncode({'studentId': studentId}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> reassignChildToParent(
      int studentId, int newParentId) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/parent/reassign-child'),
      headers: _headers(),
      body: jsonEncode({'studentId': studentId, 'newParentId': newParentId}),
    );
    return response.statusCode == 200;
  }

  // --- Permanent Hard Delete ---
  static Future<bool> hardDeleteStudent(int id) async {
    final response = await httpClient.delete(
        Uri.parse('$baseUrl/students/$id/permanent'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> hardDeleteTeacher(int id) async {
    final response = await httpClient.delete(
        Uri.parse('$baseUrl/teachers/$id/permanent'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> hardDeleteCircle(int id) async {
    final response = await httpClient.delete(
        Uri.parse('$baseUrl/circles/$id/permanent'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Announcements Actions ---
  static Future<bool> clearAllAnnouncements() async {
    final response = await httpClient.delete(
        Uri.parse('$baseUrl/announcements/clear-all'),
        headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> deleteAnnouncement(int id) async {
    final response = await httpClient
        .delete(Uri.parse('$baseUrl/announcements/$id'), headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> hardDeleteUser(int id) async {
    final response = await httpClient.delete(Uri.parse('$baseUrl/users/$id'),
        headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Profile Update Requests ---
  static Future<bool> submitProfileUpdateRequest({
    required int? studentId,
    required String requestedByRole,
    required String requestedByName,
    required Map<String, String> changes,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/profile-update-requests'),
      headers: _headers(),
      body: jsonEncode({
        'studentId': studentId,
        'requestedByRole': requestedByRole,
        'requestedByName': requestedByName,
        'changes': changes,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- SMS Dispatching ---
  static Future<Map<String, dynamic>> sendSms({
    required int targetType,
    required int? targetId,
    required String messageContent,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/sms/send'),
      headers: _headers(),
      body: jsonEncode({
        'targetType': targetType,
        'targetId': targetId,
        'messageContent': messageContent,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'error': 'فشل إرسال رسالة SMS'};
  }

  // --- Student Plan & Juz Completion ---
  static Future<bool> updateStudentPlan(
      int studentId, Map<String, dynamic> planData) async {
    final response = await httpClient.put(
      Uri.parse('$baseUrl/students/$studentId/plan'),
      headers: _headers(),
      body: jsonEncode(planData),
    );
    return response.statusCode == 200;
  }

  static Future<bool> completeJuz(
      int studentId, int juzNumber, bool isCompleted) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/students/$studentId/complete-juz'),
      headers: _headers(),
      body: jsonEncode({
        'juzNumber': juzNumber,
        'isCompleted': isCompleted,
      }),
    );
    return response.statusCode == 200;
  }

  // --- Teacher Comprehensive Report ---
  static Future<Map<String, dynamic>> getTeacherComprehensiveReport(
      int teacherId,
      {String? fromDate,
      String? toDate}) async {
    String url = '$baseUrl/teachers/$teacherId/comprehensive-report';
    final q = <String>[];
    if (fromDate != null && fromDate.isNotEmpty) {
      q.add('fromDate=${Uri.encodeComponent(fromDate)}');
    }
    if (toDate != null && toDate.isNotEmpty) {
      q.add('toDate=${Uri.encodeComponent(toDate)}');
    }
    if (q.isNotEmpty) url += '?${q.join('&')}';

    final response = await httpClient.get(
      Uri.parse(url),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  static String getTeacherReportDownloadUrl(int teacherId, String format,
      {String? fromDate, String? toDate}) {
    String url = '$baseUrl/teachers/$teacherId/report/$format';
    final q = <String>[];
    if (fromDate != null && fromDate.isNotEmpty) {
      q.add('fromDate=${Uri.encodeComponent(fromDate)}');
    }
    if (toDate != null && toDate.isNotEmpty) {
      q.add('toDate=${Uri.encodeComponent(toDate)}');
    }
    if (q.isNotEmpty) url += '?${q.join('&')}';
    return url;
  }

  static Future<Circle?> getCircle(int id) async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/circles/$id'),
          headers: _headers());
      if (response.statusCode == 200) {
        return Circle.fromJson(jsonDecode(response.body));
      }
    } catch (_) {}
    return null;
  }

  // --- Executive Dashboard Report (Unified Source of Truth for Web & Mobile) ---
  static Future<Map<String, dynamic>> getExecutiveDashboard(
      {String? fromDate, String? toDate}) async {
    String url = '$baseUrl/reports/executive-dashboard';
    final q = <String>[];
    if (fromDate != null && fromDate.isNotEmpty) {
      q.add('from=${Uri.encodeComponent(fromDate)}');
    }
    if (toDate != null && toDate.isNotEmpty) {
      q.add('to=${Uri.encodeComponent(toDate)}');
    }
    if (q.isNotEmpty) url += '?${q.join('&')}';

    try {
      final response =
          await httpClient.get(Uri.parse(url), headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  // --- Executive Dashboard Summary Report ---
  static Future<Map<String, dynamic>> getDashboardSummary(
      {String? fromDate, String? toDate}) async {
    String url = '$baseUrl/reports/summary';
    final q = <String>[];
    if (fromDate != null && fromDate.isNotEmpty) {
      q.add('from=${Uri.encodeComponent(fromDate)}');
    }
    if (toDate != null && toDate.isNotEmpty) {
      q.add('to=${Uri.encodeComponent(toDate)}');
    }
    if (q.isNotEmpty) url += '?${q.join('&')}';

    try {
      final response =
          await httpClient.get(Uri.parse(url), headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  // --- Developer Users Management ---
  static Future<bool> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/users/$id'),
        headers: _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteUser(int id) async {
    try {
      final response = await httpClient.delete(
        Uri.parse('$baseUrl/users/$id'),
        headers: _headers(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> toggleUserStatus(int id) async {
    try {
      final response = await httpClient.patch(
        Uri.parse('$baseUrl/users/$id/toggle-status'),
        headers: _headers(),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Dynamic System Settings CMS ---
  static Future<Map<String, dynamic>?> getSystemSettings() async {
    try {
      return Map<String, dynamic>.from(
          await _getCachedJson('settings', 'system_settings'));
    } catch (_) {}
    return null;
  }

  static Future<bool> updateSystemSettings(
      Map<String, dynamic> settingsData) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/settings'),
        headers: _headers(),
        body: jsonEncode(settingsData),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<List<int>?> downloadSystemDataExport() async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/settings/backup'),
        headers: _headers(),
      );
      return response.statusCode == 200 ? response.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  // --- Financial Management & Treasury Ledger ---
  static Future<Map<String, dynamic>> getFinancialSummary() async {
    try {
      final response = await httpClient
          .get(Uri.parse('$baseUrl/finance/summary'), headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'totalIncome': 0.0,
      'totalExpense': 0.0,
      'netBalance': 0.0,
      'cashBalance': 0.0,
      'appBalance': 0.0,
      'bankBalance': 0.0,
      'totalDonors': 0,
      'totalTransactions': 0,
    };
  }

  static Future<List<dynamic>> getFinancialTransactions({
    int? type,
    int? paymentMethod,
    String? category,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type.toString();
      if (paymentMethod != null) {
        queryParams['paymentMethod'] = paymentMethod.toString();
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final uri = Uri.parse('$baseUrl/finance/transactions')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await httpClient.get(uri, headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> createFinancialTransaction(
      Map<String, dynamic> data) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/finance/transactions'),
        headers: _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteFinancialTransaction(int id) async {
    try {
      final response = await httpClient.delete(
        Uri.parse('$baseUrl/finance/transactions/$id'),
        headers: _headers(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> getFinancialCategories() async {
    try {
      final response = await httpClient
          .get(Uri.parse('$baseUrl/finance/categories'), headers: _headers());
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((x) => x.toString()).toList();
      }
    } catch (_) {}
    return [
      'تبرعات عامة للمركز',
      'كفالة حلقات قرآنية',
      'مكافآت كادر المعلمين',
      'جوائز وتكريم الطلاب',
      'مطبوعات وقرطاسية وشهادات',
      'ضيافة وأنشطة مركزية',
      'صيانة وتجهيزات وتأهيل',
      'فواتير وخدمات',
      'أخرى',
    ];
  }

  // --- Talents & Preacher Youth (الفتى الواعظ والأصوات الندية) ---
  static Future<List<TalentRecord>> getTalents(
      {String? talentType, int? studentId}) async {
    try {
      String url = '$baseUrl/talents';
      List<String> queryParams = [];
      if (talentType != null && talentType.isNotEmpty) {
        queryParams.add('talentType=${Uri.encodeComponent(talentType)}');
      }
      if (studentId != null) queryParams.add('studentId=$studentId');
      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      final response =
          await httpClient.get(Uri.parse(url), headers: _headers());
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((x) => TalentRecord.fromJson(x)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> saveTalent(Map<String, dynamic> data, {int? id}) async {
    try {
      final url = id != null ? '$baseUrl/talents/$id' : '$baseUrl/talents';
      final response = id != null
          ? await httpClient.put(Uri.parse(url),
              headers: _headers(), body: jsonEncode(data))
          : await httpClient.post(Uri.parse(url),
              headers: _headers(), body: jsonEncode(data));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteTalent(int id) async {
    try {
      final response = await httpClient
          .delete(Uri.parse('$baseUrl/talents/$id'), headers: _headers());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // --- Huffaz Forum (منتدى الحفاظ وشؤون التحفيظ) ---
  static Future<Map<String, dynamic>> getHuffaz({String? filter}) async {
    try {
      String url = '$baseUrl/huffaz';
      if (filter != null && filter.isNotEmpty && filter != 'all') {
        url += '?filter=${Uri.encodeComponent(filter)}';
      }

      final response =
          await httpClient.get(Uri.parse(url), headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'members': [], 'stats': {}};
  }

  static Future<List<Teacher>> getHuffazSupervisors() async {
    try {
      final response = await httpClient
          .get(Uri.parse('$baseUrl/huffaz/supervisors'), headers: _headers());
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((x) => Teacher.fromJson(x)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> saveHuffazMember(Map<String, dynamic> data,
      {int? id}) async {
    try {
      final url = id != null ? '$baseUrl/huffaz/$id' : '$baseUrl/huffaz';
      final response = id != null
          ? await httpClient.put(Uri.parse(url),
              headers: _headers(), body: jsonEncode(data))
          : await httpClient.post(Uri.parse(url),
              headers: _headers(), body: jsonEncode(data));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteHuffazMember(int id) async {
    try {
      final response = await httpClient.delete(Uri.parse('$baseUrl/huffaz/$id'),
          headers: _headers());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> getQualityVisits({int? circleId}) async {
    try {
      final q = circleId != null ? '?circleId=$circleId' : '';
      return await _getCachedJson('quality/visits$q',
          'quality_visits_${circleId ?? 'all'}') as List<dynamic>;
    } catch (_) {}
    return [];
  }

  static Future<bool> createQualityVisit(Map<String, dynamic> data) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/quality/visits'),
        headers: _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getSpotCheckCandidates(
      int circleId) async {
    try {
      final response = await httpClient.get(
          Uri.parse('$baseUrl/quality/spot-check/$circleId'),
          headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> toggleSubstituteMode({
    required int circleId,
    required String supervisorName,
    required String reason,
    required bool activate,
  }) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl/quality/substitute-mode'),
      headers: _headers(),
      body: jsonEncode({
        'circleId': circleId,
        'supervisorName': supervisorName,
        'reason': reason,
        'activate': activate,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('فشل تحديث وضع المعلم البديل (${response.statusCode})');
  }
}
