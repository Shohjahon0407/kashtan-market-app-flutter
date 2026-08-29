import 'package:beshkashtan_customer/features/auth/presentation/widgets/phone_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('yozish paytida guruhlab ko‘rsatadi', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(PhoneField(controller: controller)));

    await tester.enterText(find.byType(TextField), '901234567');
    expect(controller.text, '90 123 45 67');
    expect(PhoneField.localDigitsOf(controller), '901234567');
  });

  testWidgets('yopishtirilgan +998 prefiksi tashlanadi', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(PhoneField(controller: controller)));

    await tester.enterText(find.byType(TextField), '+998901234567');
    expect(PhoneField.localDigitsOf(controller), '901234567');
  });

  testWidgets('9 raqamdan ortiq kiritilmaydi', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(PhoneField(controller: controller)));

    await tester.enterText(find.byType(TextField), '9012345678888');
    expect(PhoneField.localDigitsOf(controller), '901234567');
  });

  test('formatter: o‘rtadan o‘chirishda karetka joyida qoladi', () {
    const formatter = UzbekPhoneFormatter();
    // "90 123 45 67" holatida foydalanuvchi 4-pozitsiyadagi "1" ni o'chirdi:
    // yangi xom matn "90 23 45 67", karetka 3-pozitsiyada.
    final result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '90 123 45 67',
        selection: TextSelection.collapsed(offset: 4),
      ),
      const TextEditingValue(
        text: '90 23 45 67',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    expect(result.text, '90 234 56 7');
    // Karetka oxiriga SAKRAMAGAN (eski app xatosi) — 2-raqamdan keyin,
    // guruh bo'shlig'idan oldin turadi.
    expect(result.selection.baseOffset, 2);
  });

  test('formatter: yozish oxirida karetka oxirida', () {
    const formatter = UzbekPhoneFormatter();
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '90 12'),
      const TextEditingValue(
        text: '90 123',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    expect(result.text, '90 123');
    expect(result.selection.baseOffset, 6);
  });

  testWidgets('+998 prefiks chip ko‘rinadi', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(PhoneField(controller: controller)));
    expect(find.text('+998'), findsOneWidget);
  });
}
