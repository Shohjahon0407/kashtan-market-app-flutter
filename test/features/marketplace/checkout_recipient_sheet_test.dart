import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Oluvchi: profildan boshlanadi, noto'g'ri raqam saqlanmaydi, "O'zimga"
/// profilga qaytaradi.
void main() {
  Future<({String name, String phone})?> open(
    WidgetTester tester,
    Future<void> Function() act,
  ) async {
    ({String name, String phone})? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const RecipientSheet(
                      initialName: 'Shohjahon',
                      initialPhone: '+998886187407',
                      profileName: 'Shohjahon',
                      profilePhone: '+998886187407',
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('boshqa oluvchi saqlanadi, raqam normallashadi', (tester) async {
    final result = await open(tester, () async {
      expect(find.text('Shohjahon'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('recipient-name')),
        'Ona',
      );
      final phone = find.descendant(
        of: find.byKey(const ValueKey('recipient-phone')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(phone, '901234567');
      await tester.tap(find.byKey(const ValueKey('recipient-save')));
    });
    expect(result, (name: 'Ona', phone: '+998901234567'));
  });

  testWidgets('noto\'g\'ri raqam — xato, sheet yopilmaydi', (tester) async {
    final result = await open(tester, () async {
      final phone = find.descendant(
        of: find.byKey(const ValueKey('recipient-phone')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(phone, '12');
      await tester.tap(find.byKey(const ValueKey('recipient-save')));
      await tester.pumpAndSettle();
      expect(find.text("Telefon raqamini to'g'ri kiriting"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recipient-reset')));
    });
    expect(result, (name: 'Shohjahon', phone: '+998886187407'));
  });
}
