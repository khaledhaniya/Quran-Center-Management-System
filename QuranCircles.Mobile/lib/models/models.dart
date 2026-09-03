class User {
  final int id;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;
  final int? studentId;
  final int? teacherId;
  final int? parentId;
  final String? plainPassword;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.studentId,
    this.teacherId,
    this.parentId,
    this.plainPassword,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['userId'];
    final parsedId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;
    
    dynamic rawRole = json['role'];
    String roleStr = 'Student';
    if (rawRole is int) {
      switch (rawRole) {
        case 1: roleStr = 'Admin'; break;
        case 2: roleStr = 'Teacher'; break;
        case 3: roleStr = 'Student'; break;
        case 4: roleStr = 'Parent'; break;
        case 5: roleStr = 'Developer'; break;
        case 6: roleStr = 'ExamSupervisor'; break;
        default: roleStr = 'Student';
      }
    } else if (rawRole != null) {
      final s = rawRole.toString();
      if (s == '6' || s.contains('Supervisor') || s.contains('Exam')) {
        roleStr = 'ExamSupervisor';
      } else if (s == '1' || s == 'Admin') {
        roleStr = 'Admin';
      } else if (s == '2' || s == 'Teacher') {
        roleStr = 'Teacher';
      } else if (s == '4' || s == 'Parent') {
        roleStr = 'Parent';
      } else if (s == '5' || s == 'Developer') {
        roleStr = 'Developer';
      } else {
        roleStr = s;
      }
    }
    
    int? tId = json['teacherId'] is int ? json['teacherId'] : int.tryParse(json['teacherId']?.toString() ?? '');
    if (tId == null && roleStr == 'Teacher') {
      tId = parsedId;
    }
    
    int? sId = json['studentId'] is int ? json['studentId'] : int.tryParse(json['studentId']?.toString() ?? '');
    if (sId == null && roleStr == 'Student') {
      sId = parsedId;
    }

    int? pId = json['parentId'] is int ? json['parentId'] : int.tryParse(json['parentId']?.toString() ?? '');
    if (pId == null && roleStr == 'Parent') {
      pId = parsedId;
    }

    final p = json['plainPassword'] ?? json['PlainPassword'];
    final defaultPw = (p != null && p.toString().trim().isNotEmpty)
        ? p.toString().trim()
        : (json['username'] == 'dev' ? 'dev123' : (json['username'] == 'admin' ? 'admin123' : (json['username'] == 'wael' ? 'wael123' : '123456')));

    return User(
      id: parsedId,
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      role: roleStr,
      isActive: json['isActive'] ?? true,
      studentId: sId,
      teacherId: tId,
      parentId: pId,
      plainPassword: defaultPw,
    );
  }
}

class Student {
  final int id;
  final String fullName;
  final String? address;
  final String? dateOfBirth;
  final String? familyContact;
  final String? registrationDate;
  final int? circleId;
  final String? circleName;
  final bool isActive;
  final String? studentIdentityNumber;
  final String? previousQuranMemorization;
  final String? healthStatus;
  final String? fatherStatus;
  final String? motherStatus;
  final String? kinship;
  final String? parentIdentityNumber;
  final String? whatsappNumber;
  final String? walletNumber;
  final String? bankAccountNumber;
  final String? bankName;
  final String? studentMobile;
  final String? studentWhatsapp;
  final String? originalAddress;
  final String? currentAddress;
  final String? notes;

  Student({
    required this.id,
    required this.fullName,
    this.address,
    this.dateOfBirth,
    this.familyContact,
    this.registrationDate,
    this.circleId,
    this.circleName,
    required this.isActive,
    this.studentIdentityNumber,
    this.previousQuranMemorization,
    this.healthStatus,
    this.fatherStatus,
    this.motherStatus,
    this.kinship,
    this.parentIdentityNumber,
    this.whatsappNumber,
    this.studentMobile,
    this.studentWhatsapp,
    this.walletNumber,
    this.bankAccountNumber,
    this.bankName,
    this.originalAddress,
    this.currentAddress,
    this.notes,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      address: json['address'],
      dateOfBirth: json['dateOfBirth'],
      familyContact: json['familyContact'],
      registrationDate: json['registrationDate'],
      circleId: json['circleId'],
      circleName: json['circleName'],
      isActive: json['isActive'] ?? true,
      studentIdentityNumber: json['studentIdentityNumber'],
      previousQuranMemorization: json['previousQuranMemorization'],
      healthStatus: json['healthStatus'],
      fatherStatus: json['fatherStatus'],
      motherStatus: json['motherStatus'],
      kinship: json['kinship'],
      parentIdentityNumber: json['parentIdentityNumber'],
      whatsappNumber: json['whatsappNumber'] ?? json['studentWhatsapp'],
      studentMobile: json['studentMobile'],
      studentWhatsapp: json['studentWhatsapp'] ?? json['whatsappNumber'],
      walletNumber: json['walletNumber'],
      bankAccountNumber: json['bankAccountNumber'],
      bankName: json['bankName'],
      originalAddress: json['originalAddress'],
      currentAddress: json['currentAddress'],
      notes: json['notes'],
    );
  }
}

class Teacher {
  final int id;
  final String fullName;
  final String? contact;
  final String? address;
  final String? dateOfBirth;
  final String? registrationDate;
  final bool isActive;

  Teacher({
    required this.id,
    required this.fullName,
    this.contact,
    this.address,
    this.dateOfBirth,
    this.registrationDate,
    required this.isActive,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      contact: json['contact'],
      address: json['address'],
      dateOfBirth: json['dateOfBirth'],
      registrationDate: json['registrationDate'],
      isActive: json['isActive'] ?? true,
    );
  }
}

class Circle {
  final int id;
  final String name;
  final String? timing;
  final int? teacherId;
  final String? teacherName;
  final int? assistantTeacherId;
  final String? assistantTeacherName;
  final int studentCount;
  final bool isActive;

  Circle({
    required this.id,
    required this.name,
    this.timing,
    this.teacherId,
    this.teacherName,
    this.assistantTeacherId,
    this.assistantTeacherName,
    this.studentCount = 0,
    required this.isActive,
  });

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      timing: json['timing']?.toString(),
      teacherId: json['teacherId'],
      teacherName: json['teacherName'],
      assistantTeacherId: json['assistantTeacherId'],
      assistantTeacherName: json['assistantTeacherName'],
      studentCount: json['studentCount'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }
}

class Course {
  final int id;
  final String name;
  final String? description;
  final int? teacherId;
  final String? teacherName;
  final int? examSupervisorId;
  final String? examSupervisorName;
  final int enrollmentCount;
  final bool isActive;

  Course({
    required this.id,
    required this.name,
    this.description,
    this.teacherId,
    this.teacherName,
    this.examSupervisorId,
    this.examSupervisorName,
    this.enrollmentCount = 0,
    required this.isActive,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      teacherId: json['teacherId'],
      teacherName: json['teacherName'],
      examSupervisorId: json['examSupervisorId'],
      examSupervisorName: json['examSupervisorName'],
      enrollmentCount: json['enrollmentCount'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }
}

class CourseAttendanceRecord {
  final int id;
  final int studentId;
  final String studentName;
  final int courseId;
  final String courseName;
  final String sessionDate;
  final int status;
  final String statusText;

  CourseAttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.sessionDate,
    required this.status,
    required this.statusText,
  });

  factory CourseAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return CourseAttendanceRecord(
      id: json['id'] ?? 0,
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      courseId: json['courseId'] ?? 0,
      courseName: json['courseName'] ?? '',
      sessionDate: json['sessionDate'] ?? '',
      status: json['status'] ?? 1,
      statusText: json['statusText'] ?? 'حاضر',
    );
  }
}

class ExamResultData {
  final int id;
  final int majorMistakes;
  final int minorMistakes;
  final double grade;
  final String? notes;
  final String? examDate;

  ExamResultData({
    required this.id,
    required this.majorMistakes,
    required this.minorMistakes,
    required this.grade,
    this.notes,
    this.examDate,
  });

  factory ExamResultData.fromJson(Map<String, dynamic> json) {
    return ExamResultData(
      id: json['id'] ?? 0,
      majorMistakes: json['majorMistakes'] ?? 0,
      minorMistakes: json['minorMistakes'] ?? 0,
      grade: (json['grade'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
      examDate: json['examDate'],
    );
  }
}

class ExamNomination {
  final int id;
  final int studentId;
  final String studentName;
  final String halaqahName;
  final String teacherName;
  final String nominationType;
  final int? courseId;
  final String? courseName;
  final int juzStart;
  final int juzEnd;
  final String status;
  final String nominationDate;
  final String? examDate;
  final ExamResultData? result;

  ExamNomination({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.halaqahName,
    required this.teacherName,
    required this.nominationType,
    this.courseId,
    this.courseName,
    required this.juzStart,
    required this.juzEnd,
    required this.status,
    required this.nominationDate,
    this.examDate,
    this.result,
  });

  factory ExamNomination.fromJson(Map<String, dynamic> json) {
    return ExamNomination(
      id: json['id'] ?? 0,
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      halaqahName: json['halaqahName'] ?? '',
      teacherName: json['teacherName'] ?? '',
      nominationType: json['nominationType'] ?? 'Quran',
      courseId: json['courseId'],
      courseName: json['courseName'],
      juzStart: json['juzStart'] ?? 1,
      juzEnd: json['juzEnd'] ?? 1,
      status: json['status'] ?? 'Pending',
      nominationDate: json['nominationDate'] ?? '',
      examDate: json['examDate'],
      result: json['result'] != null ? ExamResultData.fromJson(json['result']) : null,
    );
  }

  String get formattedDetails {
    if (nominationType == 'Quran') {
      if (juzStart == juzEnd) {
        return 'الجزء ($juzStart)';
      } else {
        return 'الأجزاء ($juzStart) إلى ($juzEnd)';
      }
    } else {
      return 'دورة: ${courseName ?? ""}';
    }
  }
}

class Announcement {
  final int id;
  final String title;
  final String content;
  final String targetAudience;
  final String datePosted;
  final String publisherName;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.targetAudience,
    required this.datePosted,
    required this.publisherName,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final rawDate = json['dateTimeSent'] ?? json['datePosted'];
    String dateStr = '';
    if (rawDate != null) {
      dateStr = rawDate.toString().split('T')[0];
    }
    return Announcement(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      targetAudience: json['targetName'] ?? json['targetAudience'] ?? 'الجميع',
      datePosted: dateStr,
      publisherName: json['senderName'] ?? json['publisherName'] ?? 'إدارة المركز',
    );
  }
}

class AuditLog {
  final int id;
  final String username;
  final String action;
  final String details;
  final String timestamp;
  final String ipAddress;

  AuditLog({
    required this.id,
    required this.username,
    required this.action,
    required this.details,
    required this.timestamp,
    required this.ipAddress,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      action: json['action'] ?? '',
      details: json['details'] ?? '',
      timestamp: json['timestamp'] ?? '',
      ipAddress: json['ipAddress'] ?? '::1',
    );
  }
}

class SystemSettings {
  final int id;
  final String centerName;
  final String mosqueName;
  final String centerAddress;
  final String supportPhone;
  final String supportEmail;
  final String welcomeMessage;
  final int passingScoreThreshold;
  final int minAttendancePercentForExam;
  final int maxStudentsPerCircle;
  final int maxAbsenceDaysWarning;
  final bool allowTeacherEditStudentPlan;
  final bool allowTeacherSelfEnrollment;
  final bool hideParentPhoneFromTeacher;
  final bool allowStudentProfileEditRequests;
  final bool enforceDailyAttendanceRecording;
  final bool showStudentCountToTeacher;
  final bool showCumulativeAttendance;
  final bool enableCertificates;
  final String signatoryName;
  final String signatoryTitle;
  final bool showHonorsBoard;
  final bool allowPublicAnnouncements;
  final bool enableAbsenceAutoAlert;
  final String absenceAlertTemplate;
  final String themeStyle;
  final bool maintenanceMode;

  SystemSettings({
    required this.id,
    required this.centerName,
    required this.mosqueName,
    required this.centerAddress,
    required this.supportPhone,
    required this.supportEmail,
    required this.welcomeMessage,
    required this.passingScoreThreshold,
    required this.minAttendancePercentForExam,
    required this.maxStudentsPerCircle,
    required this.maxAbsenceDaysWarning,
    required this.allowTeacherEditStudentPlan,
    required this.allowTeacherSelfEnrollment,
    required this.hideParentPhoneFromTeacher,
    required this.allowStudentProfileEditRequests,
    required this.enforceDailyAttendanceRecording,
    required this.showStudentCountToTeacher,
    required this.showCumulativeAttendance,
    required this.enableCertificates,
    required this.signatoryName,
    required this.signatoryTitle,
    required this.showHonorsBoard,
    required this.allowPublicAnnouncements,
    required this.enableAbsenceAutoAlert,
    required this.absenceAlertTemplate,
    required this.themeStyle,
    required this.maintenanceMode,
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      id: json['id'] ?? 1,
      centerName: json['centerName'] ?? 'مركز البيان لتعليم القرآن الكريم',
      mosqueName: json['mosqueName'] ?? 'مسجد علي بن أبي طالب',
      centerAddress: json['centerAddress'] ?? 'فلسطين - غزة - المقر الرئيسي',
      supportPhone: json['supportPhone'] ?? '+970599000000',
      supportEmail: json['supportEmail'] ?? 'info@albayan.quran',
      welcomeMessage: json['welcomeMessage'] ?? 'أهلاً وسهلاً بكم في منصة تحفيظ القرآن الكريم والعلوم الشرعية',
      passingScoreThreshold: json['passingScoreThreshold'] ?? 70,
      minAttendancePercentForExam: json['minAttendancePercentForExam'] ?? 75,
      maxStudentsPerCircle: json['maxStudentsPerCircle'] ?? 20,
      maxAbsenceDaysWarning: json['maxAbsenceDaysWarning'] ?? 3,
      allowTeacherEditStudentPlan: json['allowTeacherEditStudentPlan'] ?? true,
      allowTeacherSelfEnrollment: json['allowTeacherSelfEnrollment'] ?? true,
      hideParentPhoneFromTeacher: json['hideParentPhoneFromTeacher'] ?? false,
      allowStudentProfileEditRequests: json['allowStudentProfileEditRequests'] ?? true,
      enforceDailyAttendanceRecording: json['enforceDailyAttendanceRecording'] ?? true,
      showStudentCountToTeacher: json['showStudentCountToTeacher'] ?? true,
      showCumulativeAttendance: json['showCumulativeAttendance'] ?? true,
      enableCertificates: json['enableCertificates'] ?? true,
      signatoryName: json['signatoryName'] ?? 'فضيلة الشيخ / رئيس المركز',
      signatoryTitle: json['signatoryTitle'] ?? 'المشرف العام على حلقات تحفيظ القرآن الكريم',
      showHonorsBoard: json['showHonorsBoard'] ?? true,
      allowPublicAnnouncements: json['allowPublicAnnouncements'] ?? true,
      enableAbsenceAutoAlert: json['enableAbsenceAutoAlert'] ?? true,
      absenceAlertTemplate: json['absenceAlertTemplate'] ?? '',
      themeStyle: json['themeStyle'] ?? 'Classic',
      maintenanceMode: json['maintenanceMode'] ?? false,
    );
  }
}
