import 'package:beshkashtan_customer/core/ui/theme/app_buttons.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Theme'dagi `FilledButton.minimumSize = Size.fromHeight(52)` (cheksiz
/// kenglik) dialog `actions` (OverflowBar) ichida to'liq kenglikka
/// klamplanadi va tugmalar vertikal stack bo'lib qolardi. Dialog tugmalari
/// `AppButtons.dialogAction` bilan bir qatorda turishi shart.
void main() {
  // Test shrifti har glifni fontSize kengligida chizadi (real shriftdan ~2x
  // keng), shuning uchun yorliqlar qisqa — real nisbat saqlanadi.
  Future<void> pumpDialog(WidgetTester tester, {required ButtonStyle? style}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Savatni tozalash'),
                    content: const Text('Barcha mahsulotlar olib tashlanadi.'),
                    actions: [
                      TextButton(
                        key: const ValueKey('cancel'),
                        onPressed: () {},
                        child: const Text('Yo\'q'),
                      ),
                      FilledButton(
                        key: const ValueKey('confirm'),
                        style: style,
                        onPressed: () {},
                        child: const Text('Ha'),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('dialog tugmalari AppButtons.dialogAction bilan bir qatorda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpDialog(tester, style: AppButtons.dialogAction);
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    final cancel = tester.getRect(find.byKey(const ValueKey('cancel')));
    final confirm = tester.getRect(find.byKey(const ValueKey('confirm')));
    expect(
      confirm.top,
      moreOrLessEquals(cancel.top, epsilon: 1),
      reason: 'tasdiq tugmasi "Bekor" bilan bir qatorda bo\'lishi kerak',
    );
    expect(
      confirm.width,
      lessThan(200),
      reason: 'tasdiq tugmasi to\'liq kenglikka cho\'zilmasligi kerak',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('style\'siz theme tugmalarni stack qiladi (regressiya hujjati)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpDialog(tester, style: null);
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    final cancel = tester.getRect(find.byKey(const ValueKey('cancel')));
    final confirm = tester.getRect(find.byKey(const ValueKey('confirm')));
    // Agar bu test yiqilsa — theme o'zgargan, `AppButtons.dialogAction`
    // endi shart emas bo'lishi mumkin; ikkala testni birga qayta ko'rib chiqing.
    expect(confirm.top, greaterThan(cancel.bottom - 1));
  });
}
