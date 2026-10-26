import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_circles_mobile/models/models.dart';
import 'package:quran_circles_mobile/screens/teacher_operations_screen.dart';
import 'package:quran_circles_mobile/services/api_service.dart';

void main() {
  testWidgets('Teacher attendance shows the full date range, absence and substitutes on a phone', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final previousClient=ApiService.httpClient;
    final previousUser=ApiService.currentUser;
    final requests=<Uri>[];
    ApiService.currentUser=User(id:7,username:'dev',fullName:'المطور',role:'Developer',isActive:true);
    ApiService.invalidateCache();
    ApiService.httpClient=MockClient((request)async{
      requests.add(request.url);
      Object result=[];
      if(request.url.path.endsWith('/operations/today'))result={'date':'2026-10-17'};
      if(request.url.path.endsWith('/circles'))result=[{'id':1,'name':'حلقة البيان','isActive':true}];
      if(request.url.path.endsWith('/teacher-attendance'))result=[
        {'circleId':1,'circleName':'حلقة البيان','teacherName':'محمد أحمد','date':'2026-10-17','status':'Absent','statusText':'غائب','isAutomatic':false,'substituteName':'عبد الرحمن البديل','reason':'إجازة','scheduledStart':'08:00','openedAt':null,'closedAt':null,'lateMinutes':0},
        {'circleId':1,'circleName':'حلقة البيان','teacherName':'محمد أحمد','date':'2026-10-16','status':'NotAbsent','statusText':'لم يسجل غياب','isAutomatic':false,'substituteName':'','reason':'','scheduledStart':'08:00','openedAt':null,'closedAt':null,'lateMinutes':0}
      ];
      return http.Response(jsonEncode(result),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    addTearDown((){ApiService.httpClient.close();ApiService.httpClient=previousClient;ApiService.currentUser=previousUser;ApiService.invalidateCache();});
    await tester.pumpWidget(const MaterialApp(home:TeacherOperationsScreen()));await tester.pumpAndSettle();
    expect(find.byType(PaginatedDataTable),findsOneWidget);expect(find.byType(AlertDialog),findsNothing);
    expect(find.text('الغياب'),findsOneWidget);
    expect(find.text('العذر'),findsOneWidget);
    expect(find.text('إجازة'),findsOneWidget);
    expect(find.text('عبد الرحمن البديل'),findsOneWidget);
    expect(find.text('الجمعة\n2026-10-16'),findsOneWidget);
    expect(tester.takeException(),isNull);
    final query=requests.lastWhere((u)=>u.path.endsWith('/teacher-attendance')).queryParameters;
    expect(query['from'],'2026-09-17');
    expect(query['to'],'2026-10-17');
    expect(tester.takeException(),isNull);
  });
}
