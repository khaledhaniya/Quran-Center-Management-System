import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circles_mobile/main.dart';

void main() {
  testWidgets('App initializes', (WidgetTester tester) async {
    await tester.pumpWidget(const QuranCirclesApp());
    expect(find.byType(QuranCirclesApp), findsOneWidget);
  });
}
