import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circles_mobile/models/models.dart';

void main() {
  group('Enterprise Data Models Serialization Tests', () {
    test('User model parses JSON correctly across role representations', () {
      final jsonAdmin = {
        'id': 1,
        'username': 'admin_manager',
        'fullName': 'مدير المركز القرآني',
        'role': 'Admin',
        'isActive': true
      };

      final user = User.fromJson(jsonAdmin);
      expect(user.id, equals(1));
      expect(user.username, equals('admin_manager'));
      expect(user.role, equals('Admin'));
      expect(user.isActive, isTrue);
    });

    test('Student model serializes with 360 degree profile fields', () {
      final jsonStudent = {
        'id': 42,
        'fullName': 'أحمد محمد علي',
        'studentIdentityNumber': '402123456',
        'circleId': 3,
        'circleName': 'حلقة الإمام الشاطبي',
        'fatherStatus': 'Orphan',
        'motherStatus': 'Alive',
        'housingStatus': 'DisplacedTent',
        'memorizationPlan': 'Intensive',
        'currentJuz': 15,
        'monthlyRewardPoints': 120,
        'dailyPageTarget': 2.5
      };

      final student = Student.fromJson(jsonStudent);
      expect(student.id, equals(42));
      expect(student.fullName, equals('أحمد محمد علي'));
      expect(student.studentIdentityNumber, equals('402123456'));
      expect(student.circleName, equals('حلقة الإمام الشاطبي'));
      expect(student.fatherStatus, equals('Orphan'));
      expect(student.housingStatus, equals('DisplacedTent'));
      expect(student.memorizationPlan, equals('Intensive'));
      expect(student.currentJuz, equals(15));
      expect(student.dailyPageTarget, equals(2.5));
    });

    test('RecitationSession model handles scores and notes', () {
      final jsonSession = {
        'id': 101,
        'studentId': 42,
        'studentName': 'أحمد محمد',
        'sessionDate': '2026-08-24',
        'type': 'NewMemorization',
        'fromSurah': 'البقرة',
        'fromAyah': 1,
        'toSurah': 'البقرة',
        'toAyah': 25,
        'pagesCount': 2.0,
        'grade': 'Excellent',
        'score': 98.5
      };

      final session = RecitationSession.fromJson(jsonSession);
      expect(session.id, equals(101));
      expect(session.studentId, equals(42));
      expect(session.grade, equals('Excellent'));
      expect(session.score, equals(98.5));
      expect(session.pagesCount, equals(2.0));
    });

    test('SystemSettings model parses dynamic CMS configurations', () {
      final jsonSettings = {
        'centerName': 'مركز البيان القرآني',
        'mosqueName': 'مسجد التقوى',
        'supportPhone': '+970599123456',
        'themeStyle': 'Heritage Classic',
        'showStudentCountToTeacher': true,
        'allowTeacherSelfEnrollment': false,
        'enableCertificates': true
      };

      final settings = SystemSettings.fromJson(jsonSettings);
      expect(settings.centerName, equals('مركز البيان القرآني'));
      expect(settings.mosqueName, equals('مسجد التقوى'));
      expect(settings.showStudentCountToTeacher, isTrue);
      expect(settings.allowTeacherSelfEnrollment, isFalse);
      expect(settings.enableCertificates, isTrue);
    });
  });
}
