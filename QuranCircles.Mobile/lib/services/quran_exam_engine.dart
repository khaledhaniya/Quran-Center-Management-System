import 'dart:math';
import '../data/quran_exam_data.dart';

class QuranQuestionModel {
  final int number;
  final String difficulty;
  final String surah;
  final int juz;
  final int page;
  final int verseStart;
  final String startText;
  final String endText;
  final int verseEnd;

  const QuranQuestionModel({
    required this.number,
    required this.difficulty,
    required this.surah,
    required this.juz,
    required this.page,
    required this.verseStart,
    required this.startText,
    required this.endText,
    required this.verseEnd,
  });

  factory QuranQuestionModel.fromRow(int number, List<String> row, {String? forceDifficulty}) {
    return QuranQuestionModel(
      number: number,
      surah: row.length > 1 ? row[1] : '',
      juz: row.length > 2 ? int.tryParse(row[2]) ?? 1 : 1,
      page: row.length > 3 ? int.tryParse(row[3]) ?? 1 : 1,
      verseStart: row.length > 4 ? int.tryParse(row[4]) ?? 1 : 1,
      startText: row.length > 5 ? row[5] : '',
      endText: row.length > 6 ? row[6] : '',
      verseEnd: row.length > 7 ? int.tryParse(row[7]) ?? 1 : 1,
      difficulty: forceDifficulty ?? (row.length > 8 ? row[8] : 'متوسط'),
    );
  }
}

class GeneratedQuranExam {
  final String examKey;
  final int questionCount;
  final List<QuranQuestionModel> mainQuestions;
  final List<QuranQuestionModel> altQuestions;

  GeneratedQuranExam({
    required this.examKey,
    required this.questionCount,
    required this.mainQuestions,
    required this.altQuestions,
  });
}

class QuranExamEngine {
  static List<String> getSingleJuzList() {
    return List.generate(30, (i) => (i + 1).toString());
  }

  static List<String> getCombinedExamList() {
    return const [
      // فئة 5 أجزاء
      '05-01', '10-06', '15-11', '20-16', '25-21', '30-26',
      // فئة 10 أجزاء
      '10-01', '20-11', '30-21',
      // فئة 3 أجزاء
      '05-03', '10-08', '15-13', '20-18', '25-23', '30-28',
    ];
  }

  static String getCombinedExamTitle(String key) {
    const labels = {
      '05-01': 'الأجزاء (1 - 5) [4 أسئلة]',
      '10-06': 'الأجزاء (6 - 10) [4 أسئلة]',
      '15-11': 'الأجزاء (11 - 15) [4 أسئلة]',
      '20-16': 'الأجزاء (16 - 20) [4 أسئلة]',
      '25-21': 'الأجزاء (21 - 25) [4 أسئلة]',
      '30-26': 'الأجزاء (26 - 30) [4 أسئلة]',
      '10-01': 'الأجزاء (1 - 10) [5 أسئلة]',
      '20-11': 'الأجزاء (11 - 20) [5 أسئلة]',
      '30-21': 'الأجزاء (21 - 30) [5 أسئلة]',
      '05-03': 'الأجزاء (3 - 5) [3 أسئلة]',
      '10-08': 'الأجزاء (8 - 10) [3 أسئلة]',
      '15-13': 'الأجزاء (13 - 15) [3 أسئلة]',
      '20-18': 'الأجزاء (18 - 20) [3 أسئلة]',
      '25-23': 'الأجزاء (23 - 25) [3 أسئلة]',
      '30-28': 'الأجزاء (28 - 30) [3 أسئلة]',
    };
    if (labels.containsKey(key)) return labels[key]!;
    if (key.contains('-')) {
      final parts = key.split('-');
      final from = int.tryParse(parts.length > 1 ? parts[1] : parts[0]) ?? 1;
      final to = int.tryParse(parts[0]) ?? 1;
      return 'الأجزاء ($from - $to)';
    }
    return key;
  }

  static GeneratedQuranExam? generateExam(String examKey) {
    final key = examKey.trim();
    final qstns = examQuestionsMap[key];
    final stages = examStagesMap[key];

    if (qstns == null || stages == null) {
      return null;
    }

    final activeStages = List<int>.from(stages);
    int noOfQstn = 0;
    for (var count in activeStages) {
      noOfQstn += count;
    }

    final random = Random();
    final List<QuranQuestionModel> mainList = [];
    final List<QuranQuestionModel> altList = [];

    for (int i = 0; i < noOfQstn; i++) {
      int qstnType = 0;
      while (true) {
        qstnType = random.nextInt(3);
        if (activeStages[qstnType] != 0) break;
      }
      activeStages[qstnType]--;

      final tierRange = (i < qstns.length && qstnType < qstns[i].length)
          ? qstns[i][qstnType]
          : (qstns.isNotEmpty ? qstns[0][qstnType] : [1, 10]);

      final minIdx = tierRange[0];
      final maxIdx = tierRange[1];

      int qstnNo = minIdx + random.nextInt(max(1, maxIdx - minIdx + 1));
      int tempNo = minIdx + random.nextInt(max(1, maxIdx - minIdx + 1));

      while (qstnNo == tempNo && maxIdx > minIdx) {
        tempNo = minIdx + random.nextInt(maxIdx - minIdx + 1);
      }

      final rowMain = (qstnNo < ayaData.length) ? ayaData[qstnNo] : ayaData[1];
      final rowAlt = (tempNo < ayaData.length) ? ayaData[tempNo] : ayaData[2];

      mainList.add(QuranQuestionModel.fromRow(i + 1, rowMain));
      altList.add(QuranQuestionModel.fromRow(i + 1, rowAlt));
    }

    // لابد ان يكون هناك سؤال صعب في كل اختبار
    final bool hasHardMain = mainList.any((q) => q.difficulty == 'صعب');
    if (!hasHardMain && mainList.isNotEmpty) {
      final targetIdx = mainList.length - 1;
      final hardTierRange = (targetIdx < qstns.length && qstns[targetIdx].length > 2)
          ? qstns[targetIdx][2]
          : (qstns.isNotEmpty && qstns[0].length > 2 ? qstns[0][2] : null);
      if (hardTierRange != null) {
        final hMin = hardTierRange[0];
        final hMax = hardTierRange[1];
        final hNo = hMin + random.nextInt(max(1, hMax - hMin + 1));
        final rowMain = (hNo < ayaData.length) ? ayaData[hNo] : ayaData[1];
        mainList[targetIdx] = QuranQuestionModel.fromRow(targetIdx + 1, rowMain, forceDifficulty: 'صعب');
      }
    }

    final bool hasHardAlt = altList.any((q) => q.difficulty == 'صعب');
    if (!hasHardAlt && altList.isNotEmpty) {
      final targetIdx = altList.length - 1;
      final hardTierRange = (targetIdx < qstns.length && qstns[targetIdx].length > 2)
          ? qstns[targetIdx][2]
          : (qstns.isNotEmpty && qstns[0].length > 2 ? qstns[0][2] : null);
      if (hardTierRange != null) {
        final hMin = hardTierRange[0];
        final hMax = hardTierRange[1];
        final hNo = hMin + random.nextInt(max(1, hMax - hMin + 1));
        final rowAlt = (hNo < ayaData.length) ? ayaData[hNo] : ayaData[2];
        altList[targetIdx] = QuranQuestionModel.fromRow(targetIdx + 1, rowAlt, forceDifficulty: 'صعب');
      }
    }

    return GeneratedQuranExam(
      examKey: examKey,
      questionCount: noOfQstn,
      mainQuestions: mainList,
      altQuestions: altList,
    );
  }

  static double calculateFinalGrade(int questionCount, double totalDeductions) {
    if (questionCount <= 0) questionCount = 4;
    double degree = questionCount * 100.0;
    degree -= totalDeductions;
    degree /= questionCount;
    degree = (degree * 10.0).roundToDouble() / 10.0;
    return max(0.0, min(100.0, degree));
  }
}
