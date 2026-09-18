import 'package:beshkashtan_customer/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double width = 360}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('6 ta box chiziladi', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(OtpCodeField(controller: controller)));

    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('otp-box-$i')), findsOneWidget);
    }
  });

  testWidgets('harflar filtrlanadi, 6 tada kesiladi', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(OtpCodeField(controller: controller)));

    await tester.enterText(find.byType(TextField), '12a34b5678');
    expect(controller.text, '123456');
  });

  testWidgets('paste to‘liq kod bilan ishlaydi', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    await tester.pumpWidget(
      _wrap(OtpCodeField(controller: controller, onChanged: changes.add)),
    );

    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump(); // ValueListenableBuilder boxlarni qayta chizsin
    expect(controller.text, '654321');
    expect(changes.last, '654321');
    // Boxlarda raqamlar ko'rinadi
    expect(find.text('6'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('180px enda overflow bo‘lmaydi', (tester) async {
    final controller = TextEditingController(text: '123456');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(OtpCodeField(controller: controller), width: 180),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('otp-box-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('otp-box-5')), findsOneWidget);
  });

  testWidgets('raqam klaviaturasi va oneTimeCode autofill', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(OtpCodeField(controller: controller)));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
  });

  testWidgets('Android back bilan yopilgach tap keyboardni qayta ochadi', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(OtpCodeField(controller: controller)));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    tester.testTextInput.hide();
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byKey(const ValueKey('otp-code-tap-target')));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });
  testWidgets('dasturiy controller yozuvi boxlarni chizadi, lekin onChanged ni '
      'CHAQIRMAYDI', (tester) async {
    // Bu — SMS autofill'dagi `_applyAutofilledCode` nima uchun qo'shimcha
    // ravishda `_onCodeChanged` ni o'zi chaqirishining sababi. Agar
    // Flutter bu xatti-harakatni o'zgartirsa, test yiqiladi va u yerdagi
    // qo'lda chaqiruvni qayta ko'rib chiqish kerak bo'ladi.
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpCodeField(controller: controller, onChanged: changes.add),
        ),
      ),
    );

    controller.value = const TextEditingValue(
      text: '654321',
      selection: TextSelection.collapsed(offset: 6),
    );
    await tester.pump();

    expect(find.text('6'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(changes, isEmpty);
  });
}
