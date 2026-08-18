import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DynamicReportsScreen extends StatefulWidget {
  const DynamicReportsScreen({super.key});

  @override
  State<DynamicReportsScreen> createState() => _DynamicReportsScreenState();
}

class _DynamicReportsScreenState extends State<DynamicReportsScreen> {
  bool _isLoading = true;
  List<Student> _allStudents = [];
  List<Circle> _circles = [];
  List<Student> _filteredStudents = [];

  // Filter States
  String _orphanFilter = 'all';
  String _ageFilter = 'all';
  String _quranFilter = 'all';
  String _healthFilter = 'all';
  String _circleFilter = 'all';
  String _keyword = '';
  
  double _minAgeInput = 5;
  double _maxAgeInput = 18;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await ApiService.getStudents();
      final circles = await ApiService.getCircles();
      setState(() {
        _allStudents = students;
        _circles = circles;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب البيانات: $e', style: AppTheme.cairoStyle())),
        );
      }
    }
  }

  int? _calculateAge(String? dobStr) {
    if (dobStr == null || dobStr.isEmpty) return null;
    try {
      final dob = DateTime.parse(dobStr);
      final today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  void _applyFilters() {
    List<Student> results = _allStudents.where((s) {
      final age = _calculateAge(s.dateOfBirth);

      // 1. Orphan Filter
      final f = (s.fatherStatus ?? '').trim();
      final m = (s.motherStatus ?? '').trim();
      final fOrphan = (f == 'شهيد' || f == 'متوفي' || f == 'شهيدة' || f == 'متوفاة');
      final mOrphan = (m == 'شهيد' || m == 'متوفي' || m == 'شهيدة' || m == 'متوفاة');

      if (_orphanFilter == 'orphans_all' && !(fOrphan || mOrphan)) return false;
      if (_orphanFilter == 'father_orphan' && !(fOrphan && !mOrphan)) return false;
      if (_orphanFilter == 'both_orphans' && !(fOrphan && mOrphan)) return false;
      if (_orphanFilter == 'mother_orphan' && !(mOrphan && !fOrphan)) return false;
      if (_orphanFilter == 'special_father' && (fOrphan || f.isEmpty || f == 'سليم' || f == 'حي')) return false;

      // 2. Age Filter
      if (_ageFilter == '12_under' && (age == null || age > 12)) return false;
      if (_ageFilter == '13_15' && (age == null || age < 13 || age > 15)) return false;
      if (_ageFilter == '16_above' && (age == null || age < 16)) return false;
      if (_ageFilter == 'custom' && (age == null || age < _minAgeInput || age > _maxAgeInput)) return false;

      // 3. Quran Level Filter
      final quran = (s.previousQuranMemorization ?? '').toLowerCase();
      if (_quranFilter == '1_juz' && (!quran.contains('جزء') || quran.contains('جزئين') || quran.contains('أجزاء'))) return false;
      if (_quranFilter == '2_juz' && (!quran.contains('جزئين') && !quran.contains('2'))) return false;
      if (_quranFilter == '3_5_juz' && (!quran.contains('3') && !quran.contains('4') && !quran.contains('5') && !quran.contains('ثلاث') && !quran.contains('خمس'))) return false;
      if (_quranFilter == '10_plus_juz' && (!quran.contains('10') && !quran.contains('عشر') && !quran.contains('خاتم'))) return false;
      if (_quranFilter == 'khatim' && (!quran.contains('خاتم') && !quran.contains('30') && !quran.contains('كامل'))) return false;

      // 4. Health Filter
      final health = (s.healthStatus ?? '').trim();
      if (_healthFilter == 'healthy' && health.isNotEmpty && health != 'سليم') return false;
      if (_healthFilter == 'sick_special' && (health.isEmpty || health == 'سليم')) return false;

      // 5. Circle Filter
      if (_circleFilter != 'all' && s.circleId.toString() != _circleFilter) return false;

      // 6. Keyword Filter
      if (_keyword.isNotEmpty) {
        final kw = _keyword.toLowerCase();
        final nameMatch = s.fullName.toLowerCase().contains(kw);
        final addrMatch = (s.address ?? '').toLowerCase().contains(kw);
        final contactMatch = (s.familyContact ?? '').toLowerCase().contains(kw);
        if (!nameMatch && !addrMatch && !contactMatch) return false;
      }

      return true;
    }).toList();

    setState(() {
      _filteredStudents = results;
    });
  }

  void _resetFilters() {
    setState(() {
      _orphanFilter = 'all';
      _ageFilter = 'all';
      _quranFilter = 'all';
      _healthFilter = 'all';
      _circleFilter = 'all';
      _keyword = '';
      _minAgeInput = 5;
      _maxAgeInput = 18;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _allStudents.isEmpty ? 1 : _allStudents.length;
    final matchCount = _filteredStudents.length;
    final perc = ((matchCount / totalCount) * 100).toStringAsFixed(1);
    final orphanCount = _filteredStudents.where((s) {
      final f = (s.fatherStatus ?? '').trim();
      final m = (s.motherStatus ?? '').trim();
      return (f == 'شهيد' || f == 'متوفي' || m == 'شهيد' || m == 'متوفاة');
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'مُولد التقارير والفلترة الديناميكية',
          style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة ضبط الفلاتر',
            onPressed: _resetFilters,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Center Title Ribbon
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mosque, color: AppTheme.primary, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مركز البيان لتعليم القرآن الكريم',
                                style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark, fontSize: 15),
                              ),
                              Text(
                                'مسجد علي بن أبي طالب - تقارير ذكية مركبة',
                                style: AppTheme.cairoStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Controls Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tune, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text('لوحة الفلاتر المركّبة المتقدمة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const Divider(height: 20),

                          // Keyword Search
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'بحث بالاسم أو العنوان أو الرقم',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              _keyword = val;
                              _applyFilters();
                            },
                          ),
                          const SizedBox(height: 12),

                          // Row 1: Orphan & Age Filters
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _orphanFilter,
                                  decoration: InputDecoration(
                                    labelText: 'حالة اليتم والوالدين',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('كافة الطلاب')),
                                    DropdownMenuItem(value: 'orphans_all', child: Text('كافة الأيتام')),
                                    DropdownMenuItem(value: 'father_orphan', child: Text('يتيم الأب')),
                                    DropdownMenuItem(value: 'both_orphans', child: Text('يتيم الأبوين')),
                                    DropdownMenuItem(value: 'mother_orphan', child: Text('يتيم الأم')),
                                    DropdownMenuItem(value: 'special_father', child: Text('حالات خاصة')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      _orphanFilter = val;
                                      _applyFilters();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _ageFilter,
                                  decoration: InputDecoration(
                                    labelText: 'الفئة العمرية',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('كافة الأعمار')),
                                    DropdownMenuItem(value: '12_under', child: Text('12 سنة فأقل')),
                                    DropdownMenuItem(value: '13_15', child: Text('13 إلى 15 سنة')),
                                    DropdownMenuItem(value: '16_above', child: Text('16 سنة فأكثر')),
                                    DropdownMenuItem(value: 'custom', child: Text('مدى مخصص')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      _ageFilter = val;
                                      _applyFilters();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Custom Age Range Slider if selected
                          if (_ageFilter == 'custom') ...[
                            Text(
                              'تحديد العمر الدقيق: ${_minAgeInput.round()} - ${_maxAgeInput.round()} سنة',
                              style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            RangeSlider(
                              values: RangeValues(_minAgeInput, _maxAgeInput),
                              min: 4,
                              max: 25,
                              divisions: 21,
                              labels: RangeLabels('${_minAgeInput.round()}', '${_maxAgeInput.round()}'),
                              onChanged: (values) {
                                setState(() {
                                  _minAgeInput = values.start;
                                  _maxAgeInput = values.end;
                                });
                                _applyFilters();
                              },
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Row 2: Quran & Circle Filters
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _quranFilter,
                                  decoration: InputDecoration(
                                    labelText: 'مستوى الحفظ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('كافة المستويات')),
                                    DropdownMenuItem(value: '1_juz', child: Text('جزء واحد')),
                                    DropdownMenuItem(value: '2_juz', child: Text('جزئين (2)')),
                                    DropdownMenuItem(value: '3_5_juz', child: Text('3-5 أجزاء')),
                                    DropdownMenuItem(value: '10_plus_juz', child: Text('10 أجزاء فأكثر')),
                                    DropdownMenuItem(value: 'khatim', child: Text('خاتم القرآن')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      _quranFilter = val;
                                      _applyFilters();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _circleFilter,
                                  decoration: InputDecoration(
                                    labelText: 'الحلقة القرآنية',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(value: 'all', child: Text('كافة الحلقات', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                    ..._circles.map((c) => DropdownMenuItem(value: c.id.toString(), child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      _circleFilter = val;
                                      _applyFilters();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // KPI Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard('عدد النتيجة', '$matchCount طالب', const Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('نسبة المركز', '$perc%', Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('عدد الأيتام', '$orphanCount يتيم', Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Header for List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'قائمة نتائج الطلاب (أعمدة مفصلة)',
                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryDark),
                      ),
                      Chip(
                        label: Text('العدد: $matchCount', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                        backgroundColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Student Result Cards
                  if (_filteredStudents.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'لا يوجد طلاب يطابقون هذه الفلاتر حالياً.',
                          style: AppTheme.cairoStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final age = _calculateAge(student.dateOfBirth);
                        final ageText = age != null ? '$age سنة' : (student.dateOfBirth ?? '-');
                        
                        final f = (student.fatherStatus ?? 'سليم').trim();
                        final m = (student.motherStatus ?? 'سليم').trim();
                        final fOrphan = (f == 'شهيد' || f == 'متوفي' || f == 'شهيدة' || f == 'متوفاة');
                        final mOrphan = (m == 'شهيد' || m == 'متوفي' || m == 'شهيدة' || m == 'متوفاة');

                        String orphanText = 'غير يتيم';
                        Color orphanColor = Colors.grey;
                        if (fOrphan && mOrphan) {
                          orphanText = 'يتيم الأبوين';
                          orphanColor = Colors.red;
                        } else if (fOrphan) {
                          orphanText = 'يتيم الأب ($f)';
                          orphanColor = Colors.red;
                        } else if (mOrphan) {
                          orphanText = 'يتيم الأم ($m)';
                          orphanColor = Colors.orange;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.primaryLight,
                                      child: Text(
                                        '${index + 1}',
                                        style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.fullName,
                                            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            'هوية: ${student.studentIdentityNumber ?? "غير مسجل"} | العمر: $ageText',
                                            style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Text(orphanText, style: AppTheme.cairoStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                      backgroundColor: orphanColor,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _buildDetailBadge('حالة الأب', f, Colors.blueGrey),
                                    _buildDetailBadge('حالة الأم', m, Colors.blueGrey),
                                    _buildDetailBadge('الحفظ السابق', student.previousQuranMemorization ?? 'غير محدد', Colors.green),
                                    _buildDetailBadge('الحلقة', student.circleName ?? 'غير مسند', Colors.teal),
                                    _buildDetailBadge('الصحة', student.healthStatus ?? 'سليم', Colors.purple),
                                    _buildDetailBadge('التواصل', student.familyContact ?? '-', Colors.amber[800]!),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTheme.cairoStyle(fontSize: 11, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: AppTheme.cairoStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
