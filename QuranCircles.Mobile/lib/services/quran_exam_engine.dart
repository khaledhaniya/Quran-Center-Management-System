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

  factory QuranQuestionModel.fromRow(int number, List<String> row) {
    return QuranQuestionModel(
      number: number,
      surah: row.length > 1 ? row[1] : '',
      juz: row.length > 2 ? int.tryParse(row[2]) ?? 1 : 1,
      page: row.length > 3 ? int.tryParse(row[3]) ?? 1 : 1,
      verseStart: row.length > 4 ? int.tryParse(row[4]) ?? 1 : 1,
      startText: row.length > 5 ? row[5] : '',
      endText: row.length > 6 ? row[6] : '',
      verseEnd: row.length > 7 ? int.tryParse(row[7]) ?? 1 : 1,
      difficulty: row.length > 8 ? row[8] : 'متوسط',
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
      '10-08', '10-06', '05-03', '05-01', '10-01',
      '20-18', '20-16', '15-13', '15-11', '20-11',
      '30-28', '30-26', '25-23', '25-21', '30-21',
    ];
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
