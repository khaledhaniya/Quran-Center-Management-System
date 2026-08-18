import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AnnouncementsScreen extends StatefulWidget {
  final User currentUser;

  const AnnouncementsScreen({super.key, required this.currentUser});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getAnnouncements();
      if (mounted) {
        setState(() {
          _announcements = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddAnnouncementModal() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    int targetType = 1;
    int? selectedTargetId;
    int? selectedCircleFilter;

    final isTeacher = widget.currentUser.role == 'Teacher';
    final isParent = widget.currentUser.role == 'Parent';
    final isStudent = widget.currentUser.role == 'Student';

    if (isTeacher) {
      targetType = 2; // Default to Circle for Teacher
    } else if (isParent || isStudent) {
      targetType = 3; // Default to Teacher for Parent and Student
    }

    final searchController = TextEditingController();
    List<Circle> circles = [];
    List<Teacher> teachers = [];
    List<Student> students = [];
    List<Map<String, dynamic>> parentsList = [];

    try {
      circles = await ApiService.getCircles();
      if (isTeacher && widget.currentUser.teacherId != null) {
        circles = circles.where((c) => c.teacherId == widget.currentUser.teacherId).toList();
      }
      teachers = await ApiService.getTeachers();
      students = await ApiService.getStudents();
      if (isTeacher && circles.isNotEmpty) {
        final circleIds = circles.map((c) => c.id).toSet();
        students = students.where((s) => s.circleId != null && circleIds.contains(s.circleId)).toList();
      }
      final rawAudit = await ApiService.getParentAuditData();
      parentsList = List<Map<String, dynamic>>.from(rawAudit);
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = searchController.text.trim().toLowerCase();

          return AlertDialog(
            title: Text('نشر إعلان جديد للمركز', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'عنوان الإعلان *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'محتوى الإعلان والتفاصيل *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: targetType,
                      decoration: const InputDecoration(labelText: 'الفئة المستهدفة'),
                      items: [
                        if (widget.currentUser.role == 'Student') ...const [
                          DropdownMenuItem(value: 3, child: Text('معلم الحلقة (محفظي)')),
                          DropdownMenuItem(value: 2, child: Text('طلاب حلقتي')),
                        ] else if (widget.currentUser.role == 'Parent') ...const [
                          DropdownMenuItem(value: 3, child: Text('معلم حلقة ابنك (المحفظ)')),
                        ] else if (isTeacher) ...const [
                          DropdownMenuItem(value: 2, child: Text('كل طلاب حلقتي')),
                          DropdownMenuItem(value: 4, child: Text('طالب معين في حلقتي')),
                          DropdownMenuItem(value: 7, child: Text('ولي أمر معين في حلقتي')),
                          DropdownMenuItem(value: 3, child: Text('معلم آخر')),
                        ] else ...const [
                          DropdownMenuItem(value: 1, child: Text('الجميع (عام)')),
                          DropdownMenuItem(value: 5, child: Text('جميع المعلمين')),
                          DropdownMenuItem(value: 2, child: Text('حلقة معينة')),
                          DropdownMenuItem(value: 3, child: Text('معلم معين')),
                          DropdownMenuItem(value: 4, child: Text('طالب معين')),
                          DropdownMenuItem(value: 7, child: Text('أولياء الأمور')),
                        ],
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            targetType = val;
                            selectedTargetId = null;
                            searchController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    if (targetType == 2 || targetType == 3 || targetType == 4 || targetType == 7) ...[
                      if (targetType == 4) ...[
                        DropdownButtonFormField<int?>(
                          value: selectedCircleFilter,
                          decoration: const InputDecoration(labelText: 'فلترة بالحلقة القرآنية (اختياري)'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('-- جميع الحلقات والطلاب --')),
                            const DropdownMenuItem<int?>(value: -1, child: Text('⚠️ طلاب غير مسندين لحلقة')),
                            ...circles.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text('🕌 ${c.name}'))),
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              selectedCircleFilter = val;
                              selectedTargetId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ] else if (targetType == 7) ...[
                        DropdownButtonFormField<int?>(
                          value: selectedCircleFilter,
                          decoration: const InputDecoration(labelText: 'فلترة بحلقة الأبناء (اختياري)'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('-- جميع أولياء الأمور --')),
                            ...circles.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text('🕌 ${c.name}'))),
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              selectedCircleFilter = val;
                              selectedTargetId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      TextField(
                        controller: searchController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: targetType == 4 
                              ? '🔍 اكتب اسم الطالب أو رقم الهوية...' 
                              : targetType == 7 
                                  ? '🔍 اكتب اسم ولي الأمر أو هوية ولي الأمر...' 
                                  : targetType == 3 
                                      ? '🔍 اكتب اسم المعلم...' 
                                      : '🔍 اكتب اسم الحلقة...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (targetType == 2) ...[
                      Builder(builder: (c) {
                        final filtered = circles.where((item) => item.name.toLowerCase().contains(query)).toList();
                        return DropdownButtonFormField<int>(
                          value: selectedTargetId,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: 'اختر الحلقة (${filtered.length}) *'),
                          items: filtered
                              .map((item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) => setModalState(() => selectedTargetId = val),
                        );
                      }),
                    ] else if (targetType == 3) ...[
                      Builder(builder: (c) {
                        final filtered = teachers.where((item) => item.fullName.toLowerCase().contains(query)).toList();
                        return DropdownButtonFormField<int>(
                          value: selectedTargetId,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: 'اختر المعلم (${filtered.length}) *'),
                          items: filtered
                              .map((item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.fullName, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) => setModalState(() => selectedTargetId = val),
                        );
                      }),
                    ] else if (targetType == 4) ...[
                      Builder(builder: (c) {
                        List<Student> filtered = students;
                        if (selectedCircleFilter == -1) {
                          filtered = filtered.where((s) => s.circleId == null).toList();
                        } else if (selectedCircleFilter != null) {
                          filtered = filtered.where((s) => s.circleId == selectedCircleFilter).toList();
                        }
                        if (query.isNotEmpty) {
                          filtered = filtered.where((item) => 
                              item.fullName.toLowerCase().contains(query) ||
                              (item.studentIdentityNumber != null && item.studentIdentityNumber!.contains(query)) ||
                              (item.circleName != null && item.circleName!.toLowerCase().contains(query))
                          ).toList();
                        }
                        return DropdownButtonFormField<int>(
                          value: filtered.any((s) => s.id == selectedTargetId) ? selectedTargetId : null,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: 'اختر الطالب (${filtered.length}) *'),
                          items: filtered
                              .map((item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(
                                      '${item.fullName} - ${item.circleName ?? "غير مسند"}',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.cairoStyle(fontSize: 12),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) => setModalState(() => selectedTargetId = val),
                        );
                      }),
                    ] else if (targetType == 7) ...[
                      Builder(builder: (c) {
                        List<Map<String, dynamic>> filtered = parentsList;
                        if (selectedCircleFilter != null) {
                          filtered = filtered.where((p) {
                            final children = (p['children'] as List? ?? []);
                            return children.any((ch) => ch['circleId'] == selectedCircleFilter);
                          }).toList();
                        }
                        if (query.isNotEmpty) {
                          filtered = filtered.where((p) {
                            final parentName = (p['parentName'] ?? '').toString().toLowerCase();
                            final parentId = (p['parentIdentityNumber'] ?? p['parentId'] ?? '').toString();
                            final children = (p['children'] as List? ?? []);
                            final childMatch = children.any((ch) => (ch['fullName'] ?? '').toString().toLowerCase().contains(query));
                            return parentName.contains(query) || parentId.contains(query) || childMatch;
                          }).toList();
                        }

                        return DropdownButtonFormField<int>(
                          value: filtered.any((p) => p['parentId'] == selectedTargetId) ? selectedTargetId : null,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: 'اختر ولي الأمر (${filtered.length}) *'),
                          items: filtered
                              .map((p) {
                                final id = p['parentId'] as int? ?? 0;
                                final name = p['parentName'] ?? 'ولي أمر';
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(name, overflow: TextOverflow.ellipsis, style: AppTheme.cairoStyle(fontSize: 12)),
                                );
                              })
                              .toList(),
                          onChanged: (val) => setModalState(() => selectedTargetId = val),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) return;

                if ((targetType == 2 || targetType == 3 || targetType == 4) && selectedTargetId == null) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار الجهة المستهدفة من القائمة'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                final ok = await ApiService.createAnnouncement(
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                  targetType: targetType,
                  targetId: selectedTargetId,
                );

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                if (ok) {
                  _loadAnnouncements();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نشر الإعلان بنجاح'), backgroundColor: Colors.green),
                  );
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل نشر الإعلان'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('نشر الإعلان'),
            ),
          ],
        );
      },
    ),
  );
  }

  void _showSendSmsModal() async {
    final messageController = TextEditingController();
    final searchController = TextEditingController();

    int targetType = 1;
    int? selectedTargetId;
    List<Student> selectedStudents = [];

    final role = widget.currentUser.role;
    if (role == 'Teacher') targetType = 2;
    if (role == 'ExamSupervisor') targetType = 7;

    List<Circle> circles = [];
    List<Teacher> teachers = [];
    List<Student> students = [];

    try {
      circles = await ApiService.getCircles();
      teachers = await ApiService.getTeachers();
      students = await ApiService.getStudents();

      if (role == 'Teacher' && widget.currentUser.teacherId != null) {
        final teacherCircleIds = circles.where((c) => c.teacherId == widget.currentUser.teacherId).map((c) => c.id).toSet();
        circles = circles.where((c) => c.teacherId == widget.currentUser.teacherId).toList();
        students = students.where((s) => s.circleId != null && teacherCircleIds.contains(s.circleId)).toList();
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = searchController.text.trim().toLowerCase();

          List<Student> filteredStudents = students.where((s) => !selectedStudents.any((sel) => sel.id == s.id)).toList();
          if (query.isNotEmpty) {
            filteredStudents = filteredStudents.where((s) =>
              s.fullName.toLowerCase().contains(query) ||
              (s.studentIdentityNumber != null && s.studentIdentityNumber!.contains(query)) ||
              (s.familyContact != null && s.familyContact!.contains(query))
            ).toList();
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.sms, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'إرسال رسالة SMS (تطبيقات الجوال)',
                    style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      value: targetType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'فئة مستلم الرسالة النصية'),
                      items: [
                        if (role == 'Admin' || role == 'Developer') ...const [
                          DropdownMenuItem(value: 1, child: Text('كافة منتسبي المركز (عام - أولياء الأمور والطلاب)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 5, child: Text('جميع معلمين المركز', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 2, child: Text('طلاب حلقة معينة', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 3, child: Text('معلم معين', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 4, child: Text('طالب معين أو مجموعة طلاب (بحث سريع)', overflow: TextOverflow.ellipsis)),
                        ] else if (role == 'Teacher') ...const [
                          DropdownMenuItem(value: 2, child: Text('كل طلاب حلقتي (أولياء أمورهم)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 4, child: Text('طالب معين أو مجموعة طلاب بالبحث في حلقتي', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 6, child: Text('إدارة المركز (أمير المركز)', overflow: TextOverflow.ellipsis)),
                        ] else if (role == 'ExamSupervisor') ...const [
                          DropdownMenuItem(value: 7, child: Text('الطلاب المرشحون للاختبارات (من المعلمين)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 6, child: Text('إدارة المركز والمطورين', overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            targetType = val;
                            selectedTargetId = null;
                            selectedStudents.clear();
                            searchController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    if (targetType == 2) ...[
                      DropdownButtonFormField<int>(
                        value: selectedTargetId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'اختر الحلقة المستهدفة'),
                        items: circles.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setModalState(() => selectedTargetId = val),
                      ),
                      const SizedBox(height: 10),
                    ] else if (targetType == 3) ...[
                      DropdownButtonFormField<int>(
                        value: selectedTargetId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'اختر المعلم المستهدف'),
                        items: teachers.map((t) => DropdownMenuItem<int>(value: t.id, child: Text(t.fullName, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setModalState(() => selectedTargetId = val),
                      ),
                      const SizedBox(height: 10),
                    ] else if (targetType == 4) ...[
                      Text('البحث وإضافة الطلاب المستهدفين:', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),

                      // Selected Students Chips
                      if (selectedStudents.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الطلاب المحددون (${selectedStudents.length}):', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selectedStudents.map((st) => Chip(
                                  backgroundColor: Colors.white,
                                  avatar: const Icon(Icons.person, size: 16, color: Colors.green),
                                  label: Text(
                                    '${st.fullName} (${st.familyContact ?? st.studentMobile ?? "بدون هاتف"})',
                                    style: AppTheme.cairoStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.red),
                                  onDeleted: () => setModalState(() => selectedStudents.remove(st)),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      TextField(
                        controller: searchController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: 'اكتب اسم الطالب لإضافته للقائمة... (مثال: محمد)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setModalState(() => searchController.clear())) : null,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Instant Results Box
                      if (query.isNotEmpty) ...[
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: filteredStudents.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text('لم يتم العثور على طلاب بهذا الاسم', style: AppTheme.cairoStyle(fontSize: 12, color: Colors.grey.shade600)),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, idx) {
                                  final st = filteredStudents[idx];
                                  final phone = st.familyContact ?? st.studentMobile ?? "بدون هاتف";
                                  return ListTile(
                                    dense: true,
                                    title: Text(st.fullName, style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('جوال ولي الأمر: $phone | الحلقة: ${st.circleName ?? "غير مسند"}', style: AppTheme.cairoStyle(fontSize: 11)),
                                    trailing: const Icon(Icons.add_circle, color: Colors.green, size: 22),
                                    onTap: () {
                                      setModalState(() {
                                        if (!selectedStudents.any((sel) => sel.id == st.id)) {
                                          selectedStudents.add(st);
                                        }
                                        searchController.clear();
                                      });
                                    },
                                  );
                                },
                              ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],

                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'محتوى نص رسالة الـ SMS *',
                        hintText: 'اكتب نص الرسالة هنا وسيتم فتح تطبيق الرسائل الرسمي بالجوال لإرسالها...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                onPressed: () async {
                  final text = messageController.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى كتابة نص الرسالة النصية أولاً'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  // 1. Gather all target phone numbers based on selected target scope
                  List<String> targetNumbers = [];

                  if (targetType == 1) { // All Center
                    for (var s in students) {
                      if (s.familyContact != null && s.familyContact!.isNotEmpty) targetNumbers.add(s.familyContact!);
                      else if (s.studentMobile != null && s.studentMobile!.isNotEmpty) targetNumbers.add(s.studentMobile!);
                    }
                    for (var t in teachers) {
                      if (t.contact != null && t.contact!.isNotEmpty) targetNumbers.add(t.contact!);
                    }
                  } else if (targetType == 5) { // All Teachers
                    for (var t in teachers) {
                      if (t.contact != null && t.contact!.isNotEmpty) targetNumbers.add(t.contact!);
                    }
                  } else if (targetType == 2 && selectedTargetId != null) { // Specific Circle
                    final circleStudents = students.where((s) => s.circleId == selectedTargetId).toList();
                    for (var s in circleStudents) {
                      if (s.familyContact != null && s.familyContact!.isNotEmpty) targetNumbers.add(s.familyContact!);
                      else if (s.studentMobile != null && s.studentMobile!.isNotEmpty) targetNumbers.add(s.studentMobile!);
                    }
                  } else if (targetType == 3 && selectedTargetId != null) { // Specific Teacher
                    final t = teachers.firstWhere((item) => item.id == selectedTargetId, orElse: () => Teacher(id: 0, fullName: '', contact: '', address: '', isActive: true));
                    if (t.contact != null && t.contact!.isNotEmpty) targetNumbers.add(t.contact!);
                  } else if (targetType == 4) { // Specific Students
                    if (selectedStudents.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى البحث واختيار طالب واحد على الأقل'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    for (var st in selectedStudents) {
                      if (st.familyContact != null && st.familyContact!.isNotEmpty) {
                        targetNumbers.add(st.familyContact!);
                      } else if (st.studentMobile != null && st.studentMobile!.isNotEmpty) {
                        targetNumbers.add(st.studentMobile!);
                      }
                    }
                  } else if (targetType == 7) { // Exam Nominated Students
                    for (var s in students) {
                      if (s.familyContact != null && s.familyContact!.isNotEmpty) targetNumbers.add(s.familyContact!);
                    }
                  } else if (targetType == 6) { // Admin
                    targetNumbers.add("0599000000"); // Center Admin fallback
                  }

                  // Clean and deduplicate phone numbers
                  final cleanNumbers = targetNumbers
                      .where((p) => p.trim().isNotEmpty)
                      .map((p) => p.replaceAll(RegExp(r'[^\d+]'), ''))
                      .toSet()
                      .toList();

                  // Log to Audit Logger via Backend API asynchronously
                  ApiService.sendSms(
                    targetType: targetType,
                    targetId: selectedTargetId,
                    messageContent: text,
                  );

                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);

                  if (!mounted) return;

                  if (cleanNumbers.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لم يتم العثور على أرقام جوالات مسجلة لهذه الفئة المختارة'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  _showSmartDispatchSheet(cleanNumbers, text);
                },
                icon: const Icon(Icons.send, color: Colors.white, size: 16),
                label: const Text('فتح تطبيق الرسائل وإرسال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPost = widget.currentUser.role != 'ExamSupervisor';
    final canSendSms = widget.currentUser.role == 'Admin' || widget.currentUser.role == 'Developer' || widget.currentUser.role == 'Teacher' || widget.currentUser.role == 'ExamSupervisor';
    final canClear = widget.currentUser.role == 'Admin' || widget.currentUser.role == 'Developer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشرات وإعلانات المركز'),
        actions: [
          if (canSendSms)
            IconButton(
              icon: const Icon(Icons.sms, color: Colors.lightBlueAccent),
              tooltip: 'إرسال رسالة SMS نصية',
              onPressed: _showSendSmsModal,
            ),
          if (canClear)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'مسح كافة الإعلانات',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('مسح كافة الإعلانات والتعاميم', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    content: Text('هل أنت مؤكد من رغبتك في مسح وتنظيف كافة الإعلانات والتعاميم الحالية؟', style: AppTheme.cairoStyle()),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('مسح الكل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final ok = await ApiService.clearAllAnnouncements();
                  if (ok) {
                    _loadAnnouncements();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم مسح جميع الإعلانات والتعاميم بنجاح'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
            ),
        ],
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              onPressed: _showAddAnnouncementModal,
              icon: const Icon(Icons.campaign, color: Colors.white),
              label: Text('نشر إعلان جديد', style: AppTheme.cairoStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? Center(child: Text('لا يوجد إعلانات منشورة حالياً', style: AppTheme.cairoStyle()))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  itemBuilder: (ctx, index) {
                    final item = _announcements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: AppTheme.cairoStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    item.datePosted,
                                    style: AppTheme.cairoStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.content,
                              style: AppTheme.cairoStyle(fontSize: 14, color: AppTheme.textDark),
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'المرسل: ${item.publisherName}',
                                  style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'الفئة: ${item.targetAudience}',
                                  style: AppTheme.cairoStyle(fontSize: 12, color: AppTheme.textMuted),
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

  void _showSmartDispatchSheet(List<String> cleanNumbers, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.send_rounded, color: AppTheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'خيارات إرسال الرسالة (${cleanNumbers.length} مستلم)',
                  style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                text,
                style: AppTheme.cairoStyle(fontSize: 13, color: Colors.grey.shade800),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),

            // Option 1: Direct WhatsApp / Apps Share
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade200)),
              tileColor: Colors.green.shade50,
              leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.share, color: Colors.white)),
              title: Text('مشاركة وإرسال عبر واتساب والتطبيقات', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
              subtitle: Text('مشاركة فورية للمجموعة أو الأفراد بدون قيود الـ MMS', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.green.shade700)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final encoded = Uri.encodeComponent(text);
                final waUrl = 'https://wa.me/?text=$encoded';
                try {
                  await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Direct SMS App
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
              tileColor: Colors.blue.shade50,
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.sms, color: Colors.white)),
              title: Text('فتح تطبيق رسائل الجوال SMS (لكافة الأرقام)', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              subtitle: Text('محاولة إرسال SMS قياسي لكافة أرقام المستلمين', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.blue.shade700)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final numbersJoined = cleanNumbers.join(';');
                final Uri smsUri = Uri(
                  scheme: 'sms',
                  path: numbersJoined,
                  queryParameters: <String, String>{
                    'body': text,
                  },
                );
                try {
                  bool ok = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
                  if (!ok) {
                    final fallback = 'sms:${cleanNumbers.join(',')}?body=${Uri.encodeComponent(text)}';
                    await launchUrl(Uri.parse(fallback), mode: LaunchMode.externalApplication);
                  }
                } catch (_) {
                  final fallback = 'sms:${cleanNumbers.join(',')}?body=${Uri.encodeComponent(text)}';
                  try {
                    await launchUrl(Uri.parse(fallback), mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
            ),
            const SizedBox(height: 10),

            // Option 3: Copy Numbers & Message
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              tileColor: Colors.grey.shade50,
              leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.copy, color: Colors.white)),
              title: Text('نسخ الأرقام ونص الرسالة إلى الحافظة', style: AppTheme.cairoStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('نسخ فوري للالتصاق في أي برنامج مراسلة تفضله', style: AppTheme.cairoStyle(fontSize: 11, color: Colors.grey.shade600)),
              onTap: () {
                Navigator.pop(sheetCtx);
                final clipboardContent = 'أرقام المستلمين:\n${cleanNumbers.join('\n')}\n\nنص الرسالة:\n$text';
                Clipboard.setData(ClipboardData(text: clipboardContent));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ الأرقام ونص الرسالة بنجاح 📋'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
