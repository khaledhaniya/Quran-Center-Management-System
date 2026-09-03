import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class QualityManagementScreen extends StatefulWidget {
  const QualityManagementScreen({Key? key}) : super(key: key);

  @override
  State<QualityManagementScreen> createState() => _QualityManagementScreenState();
}

class _QualityManagementScreenState extends State<QualityManagementScreen> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _dummyVisits = [
    {
      'id': 1,
      'circleName': 'حلقة النور والهدى',
      'supervisorName': 'الشيخ وائل (مشرف عام)',
      'date': '2026-09-01',
      'rating': 96,
      'status': 'ممتاز',
      'notes': 'انضباط ممتاز من الطلاب وإتقان في أحكام التجويد والترتيل.',
    },
    {
      'id': 2,
      'circleName': 'حلقة الصحابة الكرام',
      'supervisorName': 'الشيخ خالد',
      'date': '2026-08-28',
      'rating': 91,
      'status': 'جيد جداً',
      'notes': 'الحلقة نشطة، يرجى التركيز أكثر على خطة مراجعة المحفوظ السابق.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('ملف الجودة والرقابة والتوجيه', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          backgroundColor: const Color(0xFF0D5C3A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quality KPIs
            _buildQualityKpiGrid(),

            const SizedBox(height: 16),

            // Action Button
            ElevatedButton.icon(
              onPressed: _showAddVisitModal,
              icon: const Icon(Icons.add_task),
              label: Text('تسجيل زيارة توجيهية / رقابية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C3A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'سجل تقارير الزيارات والتوجيه (${_dummyVisits.length})',
              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF1E293B)),
            ),

            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dummyVisits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _buildVisitCard(_dummyVisits[i]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityKpiGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'تقييم الامتياز',
            value: '95%',
            icon: Icons.verified_rounded,
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFDCFCE7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'الانضباط والالتزام',
            value: '98%',
            icon: Icons.speed_rounded,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFDBEAFE),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                Text(value, style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                visit['circleName'],
                style: AppTheme.cairoStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${visit['status']} (${visit['rating']}%)',
                  style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('👤 ${visit['supervisorName']}', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF64748B))),
              const SizedBox(width: 14),
              Text('📅 ${visit['date']}', style: AppTheme.cairoStyle(fontSize: 11, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            visit['notes'],
            style: AppTheme.cairoStyle(fontSize: 12, color: const Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  void _showAddVisitModal() {
    final circleController = TextEditingController();
    final notesController = TextEditingController();
    int rating = 95;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تسجيل زيارة توجيهية ورقابية', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: circleController,
                decoration: InputDecoration(
                  labelText: 'اسم الحلقة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'ملاحظات التوجيه والتوصيات',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (circleController.text.trim().isNotEmpty) {
                      setState(() {
                        _dummyVisits.insert(0, {
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'circleName': circleController.text.trim(),
                          'supervisorName': ApiService.currentUser?.fullName ?? 'مشرف المركز',
                          'date': DateTime.now().toIso8601String().split('T').first,
                          'rating': rating,
                          'status': 'ممتاز',
                          'notes': notesController.text.trim().isEmpty ? 'تمت الزيارة بنجاح وتم تسجيل الملاحظات.' : notesController.text.trim(),
                        });
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تسجيل تقرير الزيارة بنجاح ✅')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C3A), foregroundColor: Colors.white),
                  child: Text('حفظ التقرير', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
