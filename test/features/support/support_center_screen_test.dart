import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/support/data/support_models.dart';
import 'package:beshkashtan_customer/features/support/domain/support_controller.dart';
import 'package:beshkashtan_customer/features/support/presentation/support_center_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('umumiy supportda yordam va taklif hamda history ko‘rinadi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ticket = SupportTicket(
      id: 'f2d40860-d85d-4595-9773-13ca39db16ec',
      subject: '',
      message: 'Bolalar shampuni kerak',
      kind: SupportKind.missingProduct,
      storeType: StoreType.household,
      contactName: 'Ali Valiyev',
      contactPhone: '+998901234567',
      status: SupportStatus.inProgress,
      createdAt: DateTime(2026, 8, 1, 10),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportTicketsProvider.overrideWith((ref) async => [ticket]),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: [Locale('uz')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: SupportCenterScreen(initialKind: 'support'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.text('Taklif yuborish'), findsOneWidget);
    expect(find.text("Yordam so'rash"), findsOneWidget);
    expect(find.text("Yo'q tovarlar uchun zakaz berish"), findsOneWidget);
    expect(find.text('Bolalar shampuni kerak'), findsOneWidget);
    expect(find.text("Ko'rib chiqilmoqda"), findsOneWidget);
    expect(find.text("Rasm qo'shish"), findsOneWidget);
    expect(find.text('Ovoz yozish'), findsOneWidget);
  });

  testWidgets('dedicated yo‘q tovar formasi 4 raqamlangan bo‘limdan iborat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('uz'),
          supportedLocales: [Locale('uz')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: MissingProductRequestScreen(initialStoreType: 'household'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('01 · MATN'), findsOneWidget);
    expect(find.text('02 · RASM'), findsOneWidget);
    expect(find.text('03 · OVOZ'), findsOneWidget);
    expect(find.text("04 · QAYSI DO'KONDAN?"), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(StoreType.values.length));
    final household = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('missing-product-store-household')),
    );
    expect(household.selected, isTrue);
    expect(
      find.byKey(const ValueKey('missing-product-submit')),
      findsOneWidget,
    );
    expect(find.text('Murojaatlar tarixi'), findsNothing);
  });
}
