import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/quran_exam_engine.dart';
import '../theme/app_theme.dart';

class QuranExamSystemScreen extends StatefulWidget {
  final User currentUser;
  final ExamNomination? nomination; // Optional if launched from a nomination
  final int initialPassingScore;

  const QuranExamSystemScreen({
    super.key,
    required this.currentUser,
    this.nomination,
    this.initialPassingScore = 70,
  });

  @override
  State<QuranExamSystemScreen> createState() => _QuranExamSystemScreenState();
}

class _QuranExamSystemScreenState extends State<QuranExamSystemScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedExamKey = '1';
  GeneratedQuranExam? _generatedExam;
  
  // Alternative questions swapped state (maps question index to bool)
  final Map<int, bool> _swappedQuestions = {};

  // Mistake deductions counters
  int _deductionMajorVerseCount = 0; // -7
  int _deductionWordCount = 0;       // -3
  int _deductionLetterCount = 0;     // -2.5
  int _deductionMinorMelodyCount = 0;// -1.5

  bool _isCalculated = false;
  bool _isWithdrawn = false;
  double _finalGrade = 100.0;
  bool _isSubmitting = false;

  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // If nomination is provided, automatically select its Juz
    if (widget.nomination != null && widget.nomination!.nominationType == 'Quran') {
      final jStart = widget.nomination!.juzStart;
      final jEnd = widget.nomination!.juzEnd;
      if (jStart == jEnd) {
        _selectedExamKey = jStart.toString();
        _tabController.index = 0;
      } else {
        // Find best combined key match if available
        final combinedKey = '${jEnd.toString().padLeft(2, '0')}-${jStart.toString().padLeft(2, '0')}';
        final revCombinedKey = '${jStart.toString().padLeft(2, '0')}-${jEnd.toString().padLeft(2, '0')}';
        final combinedList = QuranExamEngine.getCombinedExamList();
        if (combinedList.contains(combinedKey)) {
          _selectedExamKey = combinedKey;
          _tabController.index = 1;
        } else if (combinedList.contains(revCombinedKey)) {
          _selectedExamKey = revCombinedKey;
          _tabController.index = 1;
        } else {
          _selectedExamKey = jStart.toString();
          _tabController.index = 0;
        }
      }
    }

    _loadExam(_selectedExamKey);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadExam(String key) {
    setState(() {
      _selectedExamKey = key;
      _generatedExam = QuranExamEngine.generateExam(key);
      _swappedQuestions.clear();
      _resetCalculator();
    });
  }

  void _resetCalculator() {
    _deductionMajorVerseCount = 0;
    _deductionWordCount = 0;
    _deductionLetterCount = 0;
    _deductionMinorMelodyCount = 0;
    _isCalculated = false;
    _isWithdrawn = false;
    _finalGrade = 100.0;
  }

  double get _totalDeductions {
    return (_deductionMajorVerseCount * 7.0) +
        (_deductionWordCount * 3.0) +
        (_deductionLetterCount * 2.5) +
        (_deductionMinorMelodyCount * 1.5);
  }

  double get _currentLiveScore {
    if (_isWithdrawn) return 0.0;
    final qCount = _generatedExam?.questionCount ?? 4;
    return QuranExamEngine.calculateFinalGrade(qCount, _totalDeductions);
  }

  void _calculateScore() {
    setState(() {
      _isCalculated = true;
      _isWithdrawn = false;
      _finalGrade = _currentLiveScore;
    });
  }

  void _withdrawStudent() {
    setState(() {
      _isCalculated = true;
      _isWithdrawn = true;
      _finalGrade = 0.0;
    });
  }

  Future<void> _submitEvaluation() async {
    if (widget.nomination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنهاء الاختبار الحر بنجاح وتوثيق النتيجة.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final totalMajor = _deductionMajorVerseCount + _deductionWordCount;
      final totalMinor = _deductionLetterCount + _deductionMinorMelodyCount;

      final success = await ApiService.evaluateExam(
        nominationId: widget.nomination!.id,
        grade: _finalGrade,
        majorMistakes: totalMajor,
        minorMistakes: totalMinor,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : (_isWithdrawn ? 'انسحاب الطالب من الاختبار' : 'تم الاختبار عبر نظام الاختبارات القرآنية المعتمد'),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم اعتماد ورصد نتيجة الاختبار بنجاح بدرجة ${_finalGrade.toStringAsFixed(1)}%!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Color _getDifficultyColor(String diff) {
    if (diff.contains('سهل')) return Colors.green;
    if (diff.contains('متوسط')) return Colors.blue;
    return Colors.deepOrange;
  }

  @override
  Widget build(BuildContext context) {
    final passingScore = widget.initialPassingScore;
    final isPassed = _finalGrade >= passingScore;

    return Scaffold(
      appBar: AppBar(
        title: Text('نظام الاختبارات القرآنية ولجنة التقييم', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: AppTheme.cairoStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.bookmark_border), text: 'الاختبارات المنفردة (1 - 30)'),
            Tab(icon: Icon(Icons.auto_stories), text: 'الاختبارات المجتمعة'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Student Context Card if nomination is active
            if (widget.nomination != null) ...[
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade900, Colors.teal.shade800]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.amber.shade400,
                      radius: 22,
                      child: const Icon(Icons.person, color: Colors.black87),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.nomination!.studentName,
                            style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'الحلقة: ${widget.nomination!.halaqahName} | المعلم: ${widget.nomination!.teacherName}',
                            style: AppTheme.cairoStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            widget.nomination!.formattedDetails,
                            style: AppTheme.cairoStyle(color: Colors.amber.shade300, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Exam Selection Grid
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Single Juz (1-30)
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: 30,
                    itemBuilder: (ctx, idx) {
                      final juzNumber = (idx + 1).toString();
                      final isSelected = _selectedExamKey == juzNumber;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('الجزء $juzNumber', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onSelected: (_) => _loadExam(juzNumber),
                        ),
                      );
                    },
                  ),
                  // Combined Exams
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: QuranExamEngine.getCombinedExamList().length,
                    itemBuilder: (ctx, idx) {
                      final key = QuranExamEngine.getCombinedExamList()[idx];
                      final isSelected = _selectedExamKey == key;
                      final labelTitle = QuranExamEngine.getCombinedExamTitle(key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(labelTitle, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade700,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onSelected: (_) => _loadExam(key),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Header Banner of current exam
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'اختبار: ${QuranExamEngine.getCombinedExamTitle(_selectedExamKey)} (${_generatedExam?.questionCount ?? 0} أسئلة)',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 15),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _loadExam(_selectedExamKey),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('توليد أسئلة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      elevation: 1,
                      textStyle: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),

            // Questions List Cards
            if (_generatedExam != null) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: _generatedExam!.mainQuestions.length,
                itemBuilder: (ctx, idx) {
                  final isSwapped = _swappedQuestions[idx] ?? false;
                  final q = isSwapped ? _generatedExam!.altQuestions[idx] : _generatedExam!.mainQuestions[idx];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: isSwapped ? Colors.amber : Colors.grey.shade300),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.primary,
                                    child: Text('${q.number}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'سورة ${q.surah} (الجزء ${q.juz})',
                                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getDifficultyColor(q.difficulty).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _getDifficultyColor(q.difficulty)),
                                    ),
                                    child: Text(
                                      q.difficulty,
                                      style: TextStyle(color: _getDifficultyColor(q.difficulty), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'صفحة ${q.page} - آية ${q.verseStart}',
                                    style: AppTheme.cairoStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Verse Question Prompt
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: 'اقرأ من قوله تعالى: ', style: AppTheme.cairoStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 13)),
                                      TextSpan(text: '﴿ ${q.startText} ﴾', style: AppTheme.cairoStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: 'إلى قوله تعالى: ', style: AppTheme.cairoStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 13)),
                                      TextSpan(text: '﴿ ${q.endText} ﴾ [آية: ${q.verseEnd}]', style: AppTheme.cairoStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _swappedQuestions[idx] = !isSwapped;
                                });
                              },
                              icon: Icon(isSwapped ? Icons.undo : Icons.swap_horiz, size: 16, color: Colors.amber.shade800),
                              label: Text(
                                isSwapped ? 'العودة للسؤال الأصلي' : 'تبديل بالسؤال البديل',
                                style: AppTheme.cairoStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            // ==========================================
            // INTERACTIVE DEDUCTION CALCULATOR CONSOLE
            // ==========================================
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text('لوحة تقييم ورصد الأخطاء التفاعلية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      IconButton(
                        tooltip: 'تصفير الحاسبة',
                        onPressed: () => setState(() => _resetCalculator()),
                        icon: const Icon(Icons.refresh, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Text('انقر على أزرار الخصم التالية عند وقوع الطالب في أي خطأ أثناء التلاوة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 14),

                  // 4 Mistake Buttons Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _buildDeductionButton(
                        label: 'رد بداية آية / مقطع',
                        points: '-7.0',
                        count: _deductionMajorVerseCount,
                        color: Colors.red.shade700,
                        onTap: () => setState(() => _deductionMajorVerseCount++),
                        onUndo: () => setState(() {
                          if (_deductionMajorVerseCount > 0) _deductionMajorVerseCount--;
                        }),
                      ),
                      _buildDeductionButton(
                        label: 'خطأ كلمة كاملة',
                        points: '-3.0',
                        count: _deductionWordCount,
                        color: Colors.deepOrange.shade700,
                        onTap: () => setState(() => _deductionWordCount++),
                        onUndo: () => setState(() {
                          if (_deductionWordCount > 0) _deductionWordCount--;
                        }),
                      ),
                      _buildDeductionButton(
                        label: 'حرف أو حركة إعرابية',
                        points: '-2.5',
                        count: _deductionLetterCount,
                        color: Colors.orange.shade800,
                        onTap: () => setState(() => _deductionLetterCount++),
                        onUndo: () => setState(() {
                          if (_deductionLetterCount > 0) _deductionLetterCount--;
                        }),
                      ),
                      _buildDeductionButton(
                        label: 'تنبيه أو لحن خفي',
                        points: '-1.5',
                        count: _deductionMinorMelodyCount,
                        color: Colors.amber.shade900,
                        onTap: () => setState(() => _deductionMinorMelodyCount++),
                        onUndo: () => setState(() {
                          if (_deductionMinorMelodyCount > 0) _deductionMinorMelodyCount--;
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Live Score Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('إجمالي الدرجات المخصومة:', style: AppTheme.cairoStyle(color: Colors.grey.shade700, fontSize: 12)),
                            Text('-${_totalDeductions.toStringAsFixed(1)} درجة', style: AppTheme.cairoStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('الدرجة اللحظية المتبقية:', style: AppTheme.cairoStyle(color: Colors.grey.shade700, fontSize: 12)),
                            Text('${_currentLiveScore.toStringAsFixed(1)}%', style: AppTheme.cairoStyle(color: _currentLiveScore >= passingScore ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _calculateScore,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('احسب النتيجة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _withdrawStudent,
                          icon: const Icon(Icons.exit_to_app, color: Colors.red),
                          label: const Text('انسحاب الطالب', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Result Card if Calculated
                  if (_isCalculated) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPassed ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isPassed ? Colors.green : Colors.red, width: 2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('الدرجة النهائية المعتمدة:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                '${_finalGrade.toStringAsFixed(1)}%',
                                style: AppTheme.cairoStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isPassed ? Colors.green.shade900 : Colors.red.shade900),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('حالة الطالب:', style: AppTheme.cairoStyle(fontWeight: FontWeight.w600)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPassed ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isPassed ? 'مكتمل واجتاز بنجاح' : (_isWithdrawn ? 'راسب (انسحاب)' : 'مكتمل ولم يجتز (راسب)'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'النهاية الصغرى للنجاح المحددة في النظام: $passingScore%',
                            style: AppTheme.cairoStyle(color: Colors.grey.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات وتوجيهات لجنة الاختبار (اختياري)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitEvaluation,
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_alt),
                        label: Text(
                          widget.nomination != null ? 'اعتماد ورصد النتيجة في طلب الترشيح وسجل الطالب' : 'إنهاء وحفظ بيانات الاختبار',
                          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDeductionButton({
    required String label,
    required String points,
    required int count,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onUndo,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0) ...[
              GestureDetector(
                onTap: onUndo,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
