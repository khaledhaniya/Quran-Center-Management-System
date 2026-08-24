import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Quran Center KPI & Calculation Formulas Tests', () {
    test('Attendance discipline rate formula calculates percentages accurately', () {
      final totalRecords = 50;
      final presentCount = 47;
      final excusedCount = 2;
      final absentCount = 1;

      // Positive attendance = (Present + Excused) / Total
      final positiveRate = ((presentCount + excusedCount) / totalRecords) * 100.0;
      expect(positiveRate, equals(98.0));

      final pureAttendanceRate = (presentCount / totalRecords) * 100.0;
      expect(pureAttendanceRate, equals(94.0));
    });

    test('Quranic memorization target progress computation', () {
      final dailyTarget = 2.0; // 2 pages per day
      final daysInMonth = 25; // active circle days
      final expectedPages = dailyTarget * daysInMonth; // 50 pages

      final actualPagesRecited = 52.5;
      final achievementPercentage = (actualPagesRecited / expectedPages) * 100.0;

      expect(achievementPercentage, greaterThanOrEqualTo(100.0));
      expect(achievementPercentage, closeTo(105.0, 0.01));
    });

    test('Quran Juz (30 Parts) completion rate calculation', () {
      final completedJuz = 15;
      final totalQuranJuz = 30;

      final completionRate = (completedJuz / totalQuranJuz) * 100.0;
      expect(completionRate, equals(50.0));
    });
  });
}
