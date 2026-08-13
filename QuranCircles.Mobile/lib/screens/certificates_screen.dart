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
      if (mounted) {
        setState(() {
          _completedExams = list.where((n) => n.status == 'Completed' && n.result != null && n.result!.grade >= 60).toList();
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
                    final code = 'QURAN-10${item.id}';
                    final gradeText = item.result!.grade >= 90 ? 'ممتاز' : (item.result!.grade >= 80 ? 'جيد جداً' : 'جيد');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified, color: AppTheme.accent, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'شهادة اجتياز معتمدة',
                                  style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'تمنح إدارة المركز هذه الشهادة للطالب / الطالبة:',
                              style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            Text(
                              item.studentName,
                              style: AppTheme.cairoStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'لاجتيازه اختبـار: ${item.formattedDetails} بنجاح وتفوق، وحصل على تقدير ($gradeText) بدرجة (${item.result!.grade}%).',
                              style: AppTheme.cairoStyle(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الرمز: $code', style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                                Text('التاريخ: ${item.result!.examDate?.substring(0, 10) ?? "-"}', style: AppTheme.cairoStyle(fontSize: 11, color: AppTheme.textMuted)),
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
