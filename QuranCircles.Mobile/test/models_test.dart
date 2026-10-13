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

    test('Student parses family, housing and memorization data', () {
      final student = Student.fromJson({
        'id': 42,
        'fullName': 'أحمد محمد علي',
        'studentIdentityNumber': '402123456',
        'circleId': 3,
        'circleName': 'حلقة الإمام الشاطبي',
        'fatherStatus': 'Orphan',
        'currentAddress': 'غزة',
        'previousQuranMemorization': '29,30',
        'isActive': false,
      });
      expect(student.id, 42);
      expect(student.circleName, 'حلقة الإمام الشاطبي');
      expect(student.fatherStatus, 'Orphan');
      expect(student.currentAddress, 'غزة');
      expect(student.completedAjzaa, '29,30');
      expect(student.isActive, isFalse);
    });

    test('Exam result preserves grade, mistakes and notes', () {
      final result = ExamResultData.fromJson({
        'id': 101,
        'majorMistakes': 1,
        'minorMistakes': 2,
        'grade': 98,
        'notes': 'مراجعة التجويد',
        'examDate': '2026-08-24',
      });
      expect(result.grade, 98.0);
      expect(result.majorMistakes, 1);
      expect(result.minorMistakes, 2);
      expect(result.notes, 'مراجعة التجويد');
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
