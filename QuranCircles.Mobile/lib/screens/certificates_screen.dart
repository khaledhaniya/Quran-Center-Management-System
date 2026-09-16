import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  List<ExamNomination> _completedExams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  void _loadCertificates() async {
    try {
      final list = await ApiService.getNominations();
      final rawList = list.where((n) => n.status == 'Completed' && n.result != null && n.result!.grade >= 60).toList();
      final Map<String, ExamNomination> dedupMap = {};
      for (var item in rawList) {
        final isQuran = item.nominationType == 'Quran';
        final key = isQuran
            ? 'quran_${item.studentId}_${item.juzStart}_${item.juzEnd}'
            : 'course_${item.studentId}_${item.courseId ?? item.courseName ?? ''}';
        if (!dedupMap.containsKey(key) || (dedupMap[key]!.result?.grade ?? 0) < (item.result?.grade ?? 0)) {
          dedupMap[key] = item;
        }
      }
      if (mounted) {
        setState(() {
          _completedExams = dedupMap.values.toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السجل العام للشهادات الرقمية المعتمدة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _completedExams.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.workspace_premium, size: 64, color: AppTheme.accent),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد شهادات رقمية صادرة حالياً',
                          style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'اجتز دورة أو اختبار قرآن كريم بنجاح لتظهر الشهادة هنا.',
                          style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _completedExams.length,
                  itemBuilder: (ctx, index) {
                    final item = _completedExams[index];
                    final isQuran = item.nominationType == 'Quran';
                    final code = isQuran ? 'QURAN-10${item.id}' : 'CERT-CRS-${2000 + item.id}';
                    final gradeText = item.result!.grade >= 95 ? 'ممتاز مرتفع' : (item.result!.grade >= 90 ? 'ممتاز' : (item.result!.grade >= 80 ? 'جيد جداً' : 'جيد'));
                    final teacherRole = isQuran ? 'محفظ الحلقة' : 'معلم الدورة';
                    final teacherName = item.teacherName.isNotEmpty ? item.teacherName : (isQuran ? 'شيخ ومعلم الحلقة' : 'معلم ومحاضر الدورة');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              const Color(0xFFFBFBF9),
                            ],
                          ),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6), width: 2),
                        ),
                        child: Column(
                          children: [
                            // Header & Logo Emblem
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'دولة فلسطين',
                                      style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                    ),
                                    Text(
                                      'مركز البيان لتعليم القرآن',
                                      style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.accent, width: 1.5),
                                    color: Colors.white,
                                  ),
                                  child: const Icon(Icons.workspace_premium, color: AppTheme.accent, size: 28),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'اعتماد رسمي',
                                      style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted),
                                    ),
                                    Text(
                                      code,
                                      style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Title Ribbon
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.primaryDark, AppTheme.primary],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.accent, width: 1),
                              ),
                              child: Text(
                                isQuran ? 'شَهَادَةُ اجْتِيَازِ اخْتِبَارِ القُرْآنِ الكَرِيمِ' : 'شَهَادَةُ إِتْمَامِ دَوْرَةٍ عِلْمِيَّةٍ مُعْتَمَدَةٍ',
                                style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'تَشْهَدُ إِدَارَةُ المَرْكَزِ بِأَنَّ الطَّالِبَ المُبَارَكَ:',
                              style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.studentName,
                              style: AppTheme.cairoStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.primaryDark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isQuran
                                  ? 'قَدِ اجْتَازَ بِتَوْفِيقِ اللَّهِ تَعَالَى وَبِنَجَاحٍ اخْتِبَارَ حِفْظِ وَتَسْمِيعِ كِتَابِ اللَّهِ الكَرِيمِ (${item.formattedDetails})، وَنَالَ تَقْدِيرَ ($gradeText) بِدَرَجَةِ (${item.result!.grade}%).'
                                  : 'قَدْ أَكْمَلَ بِتَوْفِيقِ اللَّهِ تَعَالَى وَبِنَجَاحٍ كَافَّةَ مُتَطَلَّبَاتِ حُضُورِ وَاجْتِيَازِ مَقَرَّرِ (${item.courseName ?? item.formattedDetails})، بِتَقْدِيرِ ($gradeText) وَدَرَجَةِ (${item.result!.grade}%).',
                              style: AppTheme.cairoStyle(fontSize: 12, color: const Color(0xFF334155)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            // Signatures & Emir Box
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Teacher Column
                                Column(
                                  children: [
                                    Text(teacherRole, style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(teacherName, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                                    const SizedBox(height: 4),
                                    Container(width: 80, height: 1, color: AppTheme.accent),
                                  ],
                                ),
                                // Stamp
                                Column(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(colors: [Colors.amber.shade200, AppTheme.accent]),
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'مُجَاز',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.result!.examDate?.substring(0, 10) ?? '-',
                                      style: AppTheme.cairoStyle(fontSize: 9, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                // Emir Column
                                Column(
                                  children: [
                                    Text('أمير المركز / المشرف', style: AppTheme.cairoStyle(fontSize: 10, color: AppTheme.textMuted)),
                                    const SizedBox(height: 2),
                                    Text('الشيخ علي حسن النبيه', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                                    const SizedBox(height: 4),
                                    Container(width: 80, height: 1, color: AppTheme.accent),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
