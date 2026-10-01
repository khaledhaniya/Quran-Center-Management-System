import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'teacher_sessions_screen.dart';

class TeacherLotteryScreen extends StatefulWidget {
  final User currentUser;
  const TeacherLotteryScreen({super.key, required this.currentUser});

  @override
  State<TeacherLotteryScreen> createState() => _TeacherLotteryScreenState();
}

class _TeacherLotteryScreenState extends State<TeacherLotteryScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isDrawing = false;
  List<Circle> _circles = [];
  Circle? _selectedCircle;
  DateTime _lotteryDate = DateTime.now();

  Map<String, dynamic>? _lotteryResult;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _loadCircles();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCircles() async {
    setState(() => _isLoading = true);
    try {
      final circles = await ApiService.getCircles();
      final activeCircles = circles.where((c) => c.isActive).toList();

      List<Circle> myCircles = activeCircles;
      if (widget.currentUser.role == 'Teacher') {
        myCircles = activeCircles.where((c) {
          final tName = c.teacherName.trim();
          final uName = widget.currentUser.fullName.trim();
          return tName.isNotEmpty && (tName == uName || tName.contains(uName) || uName.contains(tName));
        }).toList();
        if (myCircles.isEmpty) myCircles = activeCircles;
      }

      if (mounted) {
        setState(() {
          _circles = myCircles;
          if (myCircles.isNotEmpty) _selectedCircle = myCircles.first;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _drawLottery() async {
    if (_selectedCircle == null) return;
    setState(() {
      _isDrawing = true;
      _lotteryResult = null;
    });

    _animController.repeat();

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_lotteryDate);
      final res = await ApiService.drawLottery(_selectedCircle!.id, dateStr);

      await Future.delayed(const Duration(milliseconds: 700));
      _animController.stop();

      if (mounted) {
        setState(() {
          _lotteryResult = res;
          _isDrawing = false;
        });
      }
    } catch (e) {
      _animController.stop();
      if (mounted) {
        setState(() => _isDrawing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل سحب القرعة: $e', style: AppTheme.cairoStyle())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_lotteryDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text('القرعة العشوائية للتسميع', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Setup Card (Matches Web #lottery-circle-select)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.casino, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text('إعدادات سحب القرعة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const Divider(height: 20),

                          DropdownButtonFormField<Circle>(
                            value: _selectedCircle,
                            decoration: InputDecoration(
                              labelText: 'الحلقة المستهدفة:',
                              labelStyle: AppTheme.cairoStyle(fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _circles.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: AppTheme.cairoStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCircle = val);
                            },
                          ),
                          const SizedBox(height: 12),

                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _lotteryDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) setState(() => _lotteryDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: AppTheme.primary, size: 18),
                                      const SizedBox(width: 8),
                                      Text('استبعاد الغائبين لتاريخ: $dateStr', style: AppTheme.cairoStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            '* تضمن القرعة استبعاد أي طالب تم تسجيله كـ "غائب" في جدول الحضور لهذا اليوم لضمان اختيار طالب متواجد في المسجد فعلياً.',
                            style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),

                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: _isDrawing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                              label: Text(_isDrawing ? 'جاري السحب...' : 'سحب القرعة الآن', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              onPressed: _isDrawing ? null : _drawLottery,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Result Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _lotteryResult != null ? [const Color(0xFFE8F5E9), Colors.white] : [Colors.grey.shade50, Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotationTransition(
                            turns: _animController,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _lotteryResult != null ? Colors.green.shade100 : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.casino,
                                size: 54,
                                color: _lotteryResult != null ? Colors.green.shade800 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_lotteryResult == null) ...[
                            Text('اضغط على "سحب القرعة الآن" للاختيار', style: AppTheme.cairoStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                          ] else ...[
                            Text('الطالب المختار بالقرعة:', style: AppTheme.cairoStyle(color: Colors.grey.shade700, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(
                              _lotteryResult!['studentName'] ?? _lotteryResult!['fullName'] ?? '',
                              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green.shade900),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الحلقة: ${_selectedCircle?.name ?? ""}',
                              style: AppTheme.cairoStyle(fontSize: 12, color: Colors.green.shade800),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade800,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.book, size: 18),
                              label: Text('تسجيل تسميع لهذا الطالب الآن', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (ctx) => TeacherSessionsScreen(currentUser: widget.currentUser)),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
