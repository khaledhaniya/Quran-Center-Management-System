import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circles_mobile/utils/registration_rules.dart';
import 'package:quran_circles_mobile/widgets/whatsapp_number_field.dart';

void main() {
  test('Identity comparison and phone formats require complete numbers', () {
    expect(RegistrationRules.sameIdentity('123456789', '123456788'), isFalse);
    expect(RegistrationRules.sameIdentity('1', '1'), isFalse);
    expect(RegistrationRules.sameIdentity('١٢٣٤٥٦٧٨٩', '123456789'), isTrue);
    expect(RegistrationRules.identityError('12345678'), isNotNull);
    expect(RegistrationRules.phoneError('0561234567'), isNull);
    expect(RegistrationRules.phoneError('0571234567'), isNotNull);
    expect(RegistrationRules.passwordError('123456'), isNull);
    expect(RegistrationRules.passwordError('12345'), isNotNull);
  });
  test(
      'Digit formatter blocks the tenth identity digit and normalizes Arabic digits',
      () {
    const formatter = LimitedDigitsFormatter(9);
    final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
            text: '١٢٣٤٥٦٧٨٩٠',
            selection: TextSelection.collapsed(offset: 10)));
    expect(result.text, '123456789');
    expect(result.selection.baseOffset, 9);
  });
  testWidgets(
      'WhatsApp selector saves the selected country beside the number on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(12),
                child: WhatsAppNumberField(
                    controller: controller, label: 'واتساب')))));
    await tester.enterText(find.byType(TextFormField), '0591234567');
    expect(controller.text, '+970591234567');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+972').last);
    await tester.pumpAndSettle();
    expect(controller.text, '+972591234567');
    expect(tester.takeException(), isNull);
  });
}
