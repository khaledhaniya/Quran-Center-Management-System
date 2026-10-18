import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_circles_mobile/models/models.dart';
import 'package:quran_circles_mobile/screens/parent_portal_screen.dart';
import 'package:quran_circles_mobile/screens/main_navigation_screen.dart';
import 'package:quran_circles_mobile/services/api_service.dart';

void main(){
  testWidgets('A teacher with no tasks can open the standalone achievement portfolio',(tester)async{
    final previous=ApiService.httpClient;final previousUser=ApiService.currentUser;final previousToken=ApiService.authToken;
    final teacher=User(id:1,username:'teacher',fullName:'المعلم',role:'Teacher',isActive:true,taskRole:'');
    ApiService.currentUser=teacher;ApiService.authToken=null;ApiService.invalidateCache();
    ApiService.httpClient=MockClient((r)async=>http.Response(jsonEncode(r.url.path.endsWith('/settings')?{'centerName':'مركز البيان','maintenanceMode':false}:[]),200,headers:{'content-type':'application/json; charset=utf-8'}));
    addTearDown((){ApiService.httpClient.close();ApiService.httpClient=previous;ApiService.currentUser=previousUser;ApiService.authToken=previousToken;ApiService.invalidateCache();});
    await tester.pumpWidget(MaterialApp(home:MainNavigationScreen(currentUser:teacher)));await tester.pumpAndSettle();
    expect(find.byType(BottomNavigationBar),findsOneWidget);
    expect(find.text('الإنجاز والشهادات'),findsWidgets);
    await tester.tap(find.text('الإنجاز والشهادات'));await tester.pumpAndSettle();
    expect(find.text('ملف الإنجاز والشهادات الرقمية'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('Course permissions never imply Quran-circle permissions',(){
    for(final task in ['معلم دورات','معلم دورة','مشرف المساقات الشرعية','معلم الدَّورات']){
      final user=User(id:1,username:'teacher',fullName:'المعلم',role:'Teacher',isActive:true,taskRole:task);
      expect(user.isCourseTeacher,isTrue);expect(user.isHalaqahTeacher,isFalse);
    }
    expect(User.permissionsFromTasks('غير مكلف'),isEmpty);
    expect(User.permissionsFromTasks('محفّظ حلقة + مشرف اختبارات'),containsAll(['circles','exams']));
  });
  test('Server assignments enable courses and exams even without task text',(){
    final courseTeacher=User.fromJson({'userId':12,'username':'course','fullName':'معلم الدورة','role':'Teacher','teacherId':5,'taskRole':'غير مكلف','permissions':['courses','exams']});
    expect(courseTeacher.isCourseTeacher,isTrue);
    expect(courseTeacher.isExamSupervisor,isTrue);
    expect(courseTeacher.isHalaqahTeacher,isFalse);
    final assistant=User.fromJson({'userId':13,'username':'assistant','fullName':'مساعد الحلقة','role':'Teacher','teacherId':6,'taskRole':'غير مكلف','permissions':['circles','exams']});
    expect(assistant.isHalaqahTeacher,isTrue);
    expect(assistant.isExamSupervisor,isTrue);
    expect(assistant.isCourseTeacher,isFalse);
  });
  testWidgets('Parent portal uses server figures and keeps the small-screen page usable',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final previous=ApiService.httpClient;final requests=<Uri>[];
    ApiService.httpClient=MockClient((r)async{requests.add(r.url);return http.Response(jsonEncode({'from':'2026-10-01','to':'2026-10-17','today':'2026-10-17','summary':{'childrenCount':1,'totalSessions':7,'absentCount':2,'excusedAbsentCount':1},'children':[{'studentId':10,'studentName':'أحمد محمد','circleName':'حلقة البيان','isActive':true,'teacherName':'الشيخ خالد','teacherPhone':'','completedAjzaaCount':2,'targetAjzaaCount':5,'attendanceRate':null,'totalSessions':7,'newPages':1.5,'reviewPages':3,'absentCount':2,'excusedAbsentCount':1,'lateCount':0,'talentsCount':0,'recentSessions':[],'recentAttendance':[],'courses':[]}]}),200,headers:{'content-type':'application/json; charset=utf-8'});});
    addTearDown((){ApiService.httpClient.close();ApiService.httpClient=previous;});
    await tester.pumpWidget(const MaterialApp(home:ParentPortalScreen()));await tester.pumpAndSettle();
    expect(requests.single.path,endsWith('/parent/portal'));
    expect(find.text('غياب بعذر'),findsWidgets);
    expect(find.text('أحمد محمد'),findsWidgets);
    await tester.drag(find.byType(SingleChildScrollView).first,const Offset(0,-550));await tester.pumpAndSettle();
    expect(find.text('لم يرصد'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
