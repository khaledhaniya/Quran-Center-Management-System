import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'offline_cache.dart';
import 'notification_service.dart';
import 'offline_sync_manager.dart';

class ApiService {
  static String baseUrl = 'https://albayan-quran.onrender.com/api';
  static User? currentUser;
  static String? authToken;

  // Fast In-Memory Cache for Instant UI
  static List<Student>? _cachedStudents;
  static List<Teacher>? _cachedTeachers;
  static List<Circle>? _cachedCircles;
  static DateTime? _cacheTime;

  static void invalidateCache() {
    _cachedStudents = null;
    _cachedTeachers = null;
    _cachedCircles = null;
    _cacheTime = null;
  }

  static void setBaseUrl(String url) {
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api')) {
      baseUrl = '$url/api';
    } else {
      baseUrl = url;
    }
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
      headers['X-2FA-Code'] = code2FA;
    }
    return headers;
  }

  // --- Auth ---
  static Future<User?> tryAutoLogin() async {
    try {
      final cached = await OfflineCache.load('user_login');
      if (cached != null && cached.isNotEmpty) {
        final json = jsonDecode(cached);
        final user = User.fromJson(json['user'] ?? json);
        currentUser = user;
        authToken = json['token']?.toString() ?? '';
        NotificationService.start(user);
        OfflineSyncManager.initialize();
        return user;
      }
    } catch (_) {}
    return null;
  }

  static Future<User> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final user = User.fromJson(json['user'] ?? json);
      currentUser = user;
      authToken = json['token']?.toString() ?? '';
      await OfflineCache.save('user_login', response.body);
      NotificationService.start(user);
      OfflineSyncManager.initialize();
      return user;
    } else {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? err['error'] ?? 'فشل تسجيل الدخول. تحقق من كلمة المرور.');
      } catch (e) {
        final cached = await OfflineCache.load('user_login');
        if (cached != null) {
          final json = jsonDecode(cached);
          final user = User.fromJson(json['user'] ?? json);
          currentUser = user;
          authToken = json['token']?.toString() ?? '';
          NotificationService.start(user);
          OfflineSyncManager.initialize();
          return user;
        }
        if (e.toString().contains('Exception:')) rethrow;
        throw Exception('فشل الاتصال بالسيرفر. يرجى التحقق من الاتصال بالإنترنت.');
      }
    }
  }

  static Future<void> logout() async {
    currentUser = null;
    authToken = null;
    NotificationService.stop();
    await OfflineCache.remove('user_login');
    invalidateCache();
  }

  // --- Students CRUD ---
  static Future<List<Student>> getStudents({String? search, bool forceRefresh = false}) async {
    if (!forceRefresh && (search == null || search.isEmpty) && _cachedStudents != null) {
      return _cachedStudents!;
    }

    String url = '$baseUrl/students';
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeComponent(search)}';
    }
    try {
      final response = await http.get(Uri.parse(url), headers: _headers());
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final list = data.map((item) => Student.fromJson(item)).toList();
        if (search == null || search.isEmpty) {
          _cachedStudents = list;
          _cacheTime = DateTime.now();
        }
        await OfflineCache.save('students_list', response.body);
        return list;
      }
    } catch (_) {
      final cached = await OfflineCache.load('students_list');
      if (cached != null) {
        final List data = jsonDecode(cached);
        return data.map((item) => Student.fromJson(item)).toList();
      }
    }
    return _cachedStudents ?? [];
  }

  static Future<bool> createStudent(Map<String, dynamic> data) async {
    invalidateCache();
    final response = await http.post(
      Uri.parse('$baseUrl/students'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<bool> updateStudent(int id, Map<String, dynamic> data) async {
    invalidateCache();
    final response = await http.put(
      Uri.parse('$baseUrl/students/$id'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteStudent(int id) async {
    invalidateCache();
    final response = await http.delete(Uri.parse('$baseUrl/students/$id'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Teachers CRUD ---
  static Future<List<Teacher>> getTeachers({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTeachers != null) {
      return _cachedTeachers!;
    }
    try {
      final response = await http.get(Uri.parse('$baseUrl/teachers'), headers: _headers());
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final list = data.map((item) => Teacher.fromJson(item)).toList();
        _cachedTeachers = list;
        await OfflineCache.save('teachers_list', response.body);
        return list;
      }
    } catch (_) {
      final cached = await OfflineCache.load('teachers_list');
      if (cached != null) {
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
  }) async {
    invalidateCache();
    final response = await http.post(
      Uri.parse('$baseUrl/teachers'),
      headers: _headers(),
      body: jsonEncode({
        'fullName': fullName,
        'contact': contact,
        'address': address,
        'dateOfBirth': dateOfBirth,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<bool> updateTeacher(int id, {
    required String fullName,
    String? contact,
    String? address,
  }) async {
    invalidateCache();
    final response = await http.put(
      Uri.parse('$baseUrl/teachers/$id'),
      headers: _headers(),
      body: jsonEncode({
        'fullName': fullName,
        'contact': contact,
        'address': address,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteTeacher(int id) async {
    invalidateCache();
    final response = await http.delete(Uri.parse('$baseUrl/teachers/$id'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Circles CRUD ---
  static Future<List<Circle>> getCircles({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCircles != null) {
      return _cachedCircles!;
    }
    try {
      final response = await http.get(Uri.parse('$baseUrl/circles'), headers: _headers());
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final list = data.map((item) => Circle.fromJson(item)).toList();
        _cachedCircles = list;
        await OfflineCache.save('circles_list', response.body);
        return list;
      }
    } catch (_) {
      final cached = await OfflineCache.load('circles_list');
      if (cached != null) {
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
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/circles'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'timing': timing ?? 'Fajr',
        'teacherId': teacherId,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<bool> updateCircle(int id, {
    required String name,
    String? timing,
    int? teacherId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/circles/$id'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'timing': timing,
        'teacherId': teacherId,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> deleteCircle(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/circles/$id'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Courses CRUD ---
  static Future<List<Course>> getCourses() async {
    final response = await http.get(Uri.parse('$baseUrl/courses'), headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => Course.fromJson(item)).toList();
    }
    throw Exception('فشل جلب قائمة الدورات والمساقات (${response.statusCode})');
  }

  static Future<bool> createCourse({
    required String name,
    String? description,
    int? teacherId,
    int? examSupervisorId,
  }) async {
    final response = await http.post(
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

  static Future<bool> updateCourse(int id, {
    required String name,
    String? description,
    int? teacherId,
    int? examSupervisorId,
  }) async {
    final response = await http.put(
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
    final response = await http.delete(Uri.parse('$baseUrl/courses/$id'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> enrollInCourse({
    required int courseId,
    int? studentId,
    int? circleId,
  }) async {
    final response = await http.post(
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
      throw Exception(err['message'] ?? err['error'] ?? 'فشل تسجيل الطالب بالدورة');
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception('فشل الاتصال بالإنترنت لتسجيل الطالب بالدورة');
    }
  }

  // --- Attendance & Sessions ---
  static Future<List<CourseAttendanceRecord>> getCourseAttendance(int courseId, String date) async {
    final enrollmentsResp = await http.get(
      Uri.parse('$baseUrl/courses/$courseId/enrollments'),
      headers: _headers(),
    );
    final attendanceResp = await http.get(
      Uri.parse('$baseUrl/courses/$courseId/attendance?date=$date'),
      headers: _headers(),
    );

    final Map<int, int> statusMap = {};
    if (attendanceResp.statusCode == 200) {
      final List attData = jsonDecode(attendanceResp.body);
      for (var item in attData) {
        statusMap[item['studentId'] ?? 0] = item['status'] ?? 1;
      }
    }

    if (enrollmentsResp.statusCode == 200) {
      final List enrollData = jsonDecode(enrollmentsResp.body);
      return enrollData.map((item) {
        final sId = item['studentId'] ?? 0;
        final statusVal = statusMap[sId] ?? 1;
        String statusTxt = 'حاضر';
        if (statusVal == 2) statusTxt = 'غائب';
        if (statusVal == 3) statusTxt = 'متأخر';

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
    return [];
  }

  static Future<bool> saveCourseAttendance(int courseId, String sessionDate, List<Map<String, dynamic>> items) async {
    final response = await http.post(
      Uri.parse('$baseUrl/courses/attendance'),
      headers: _headers(),
      body: jsonEncode({
        'courseId': courseId,
        'sessionDate': sessionDate,
        'items': items,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> saveCircleAttendance(int circleId, String sessionDate, List<Map<String, dynamic>> records) async {
    bool ok = true;
    for (var r in records) {
      final resp = await http.post(
        Uri.parse('$baseUrl/attendance'),
        headers: _headers(),
        body: jsonEncode({
          'studentId': r['studentId'],
          'circleId': circleId,
          'sessionDate': sessionDate,
          'status': r['status'],
        }),
      );
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
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: _headers(),
      body: jsonEncode({
        'studentId': studentId,
        'sessionDate': sessionDate,
        'surahName': surahName,
        'fromVerse': fromVerse,
        'toVerse': toVerse,
        'assessment': assessment,
        'notes': notes,
        'viaLottery': viaLottery,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- Exams & Nominations ---
  static Future<List<ExamNomination>> getNominations() async {
    final response = await http.get(Uri.parse('$baseUrl/exams/nominations'), headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => ExamNomination.fromJson(item)).toList();
    }
    throw Exception('فشل جلب قائمة طلبات الترشيح والامتحانات (${response.statusCode})');
  }

  static Future<bool> nominateExam({
    required int studentId,
    required String nominationType,
    int? courseId,
    required int juzStart,
    required int juzEnd,
  }) async {
    final response = await http.post(
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
    final response = await http.put(
      Uri.parse('$baseUrl/exams/schedule'),
      headers: _headers(),
      body: jsonEncode({
        'nominationId': nominationId,
        'examDate': examDate,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> evaluateExam({
    required int nominationId,
    required int majorMistakes,
    required int minorMistakes,
    required double grade,
    String? notes,
    required String code2FA,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/exams/evaluate'),
      headers: _headers(code2FA: code2FA),
      body: jsonEncode({
        'nominationId': nominationId,
        'majorMistakes': majorMistakes,
        'minorMistakes': minorMistakes,
        'grade': grade,
        'notes': notes,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'فشل حفظ نتيجة التقييم');
    }
  }

  static Future<List<Map<String, dynamic>>> getCourseEnrollments(int courseId) async {
    final response = await http.get(Uri.parse('$baseUrl/courses/$courseId/enrollments'), headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // --- Active Toggles ---
  static Future<bool> toggleStudentActive(int id) async {
    final response = await http.post(Uri.parse('$baseUrl/students/$id/toggle-active'), headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> toggleTeacherActive(int id) async {
    final response = await http.post(Uri.parse('$baseUrl/teachers/$id/toggle-active'), headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> toggleCircleActive(int id) async {
    final response = await http.post(Uri.parse('$baseUrl/circles/$id/toggle-active'), headers: _headers());
    return response.statusCode == 200;
  }

  // --- Student 360 View ---
  static Future<Map<String, dynamic>> getStudent360(int studentId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/students/$studentId/progress'), headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    final responseFallback = await http.get(Uri.parse('$baseUrl/students/$studentId/360'), headers: _headers());
    if (responseFallback.statusCode == 200) {
      return jsonDecode(responseFallback.body);
    }
    throw Exception('فشل جلب الملف الموحد للطالب (${responseFallback.statusCode})');
  }

  // --- Users & Announcements ---
  static Future<List<User>> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'), headers: _headers());
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
    final response = await http.post(
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
    final response = await http.get(Uri.parse('$baseUrl/announcements/my'), headers: _headers());
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
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/announcements'),
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'content': content,
        'targetType': targetType,
        'targetId': targetId,
      }),
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  static Future<List<AuditLog>> getAuditLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/audit-logs'), headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((item) => AuditLog.fromJson(item)).toList();
    }
    return [];
  }

  // --- Profile Requests ---
  static Future<List<dynamic>> getProfileUpdateRequests() async {
    final response = await http.get(Uri.parse('$baseUrl/profile-update-requests'), headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
  }

  static Future<bool> approveProfileRequest(int id) async {
    final response = await http.post(Uri.parse('$baseUrl/profile-update-requests/$id/approve'), headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> rejectProfileRequest(int id) async {
    final response = await http.post(Uri.parse('$baseUrl/profile-update-requests/$id/reject'), headers: _headers());
    return response.statusCode == 200;
  }

  // --- Parent Audit Data ---
  static Future<List<dynamic>> getParentAuditData() async {
    final response = await http.get(Uri.parse('$baseUrl/parent/audit'), headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
  }

  // --- Permanent Hard Delete ---
  static Future<bool> hardDeleteStudent(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/students/$id/permanent'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> hardDeleteTeacher(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/teachers/$id/permanent'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<bool> hardDeleteCircle(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/circles/$id/permanent'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Announcements Actions ---
  static Future<bool> clearAllAnnouncements() async {
    final response = await http.delete(Uri.parse('$baseUrl/announcements/clear-all'), headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> deleteAnnouncement(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/announcements/$id'), headers: _headers());
    return response.statusCode == 200;
  }

  static Future<bool> hardDeleteUser(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/users/$id'), headers: _headers());
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Profile Update Requests ---
  static Future<bool> submitProfileUpdateRequest({
    required int? studentId,
    required String requestedByRole,
    required String requestedByName,
    required Map<String, String> changes,
  }) async {
    final response = await http.post(
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
    final response = await http.post(
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
  static Future<bool> updateStudentPlan(int studentId, Map<String, dynamic> planData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/students/$studentId/plan'),
      headers: _headers(),
      body: jsonEncode(planData),
    );
    return response.statusCode == 200;
  }

  static Future<bool> completeJuz(int studentId, int juzNumber, bool isCompleted) async {
    final response = await http.post(
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
  static Future<Map<String, dynamic>> getTeacherComprehensiveReport(int teacherId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/teachers/$teacherId/comprehensive-report'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  // --- Developer Users Management ---
  static Future<List<User>> getUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users'), headers: _headers());
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((x) => User.fromJson(x)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
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
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$id'),
        headers: _headers(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  static Future<List<AuditLog>> getAuditLogs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/audit'), headers: _headers());
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((x) => AuditLog.fromJson(x)).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- Dynamic System Settings CMS ---
  static Future<Map<String, dynamic>?> getSystemSettings() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/settings'), headers: _headers());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> updateSystemSettings(Map<String, dynamic> settingsData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/settings'),
        headers: _headers(),
        body: jsonEncode(settingsData),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}

