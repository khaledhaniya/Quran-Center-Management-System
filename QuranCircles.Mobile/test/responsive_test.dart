import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_circles_mobile/screens/login_screen.dart';
import 'package:quran_circles_mobile/screens/financial_management_screen.dart';
import 'package:quran_circles_mobile/services/api_service.dart';

void main() {
  for (final width in [320.0, 360.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('Login and finance fit width $width with text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ApiService.httpClient = MockClient((request) async => http.Response(
            request.url.path.endsWith('/transactions')
                ? '[]'
                : jsonEncode({
                    'centerName':
                        'مركز البيان لتعليم القرآن الكريم والعلوم الشرعية',
                    'totalIncome': 1234567.5,
                    'totalExpense': 500,
                    'netBalance': 1234067.5,
                  }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'}));
        addTearDown(() => ApiService.httpClient.close());
        Widget app(Widget screen) => MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                    textDirection: TextDirection.rtl, child: child!)),
            home: screen);
        await tester.pumpWidget(app(const LoginScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(const FinancialManagementScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
