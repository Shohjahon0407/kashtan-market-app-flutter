import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/address_display.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/addresses_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _unnamed = UserAddress(
  id: 'address-1',
  title: '',
  latitude: 41.311081,
  longitude: 69.240563,
  isDefault: true,
);

const _named = UserAddress(
  id: 'address-2',
  title: 'Uy',
  latitude: 41.315,
  longitude: 69.25,
  isDefault: false,
);

class _AddressesController extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => const [_unnamed, _named];

  @override
  Future<void> refresh() async {}
}

/// Manzil nomi ixtiyoriy: nomsiz manzil ekranda bo'sh qator emas, umumiy
/// yozuv bilan ko'rinadi, aniq joyi esa koordinata bilan.
void main() {
  test('displayTitle bo\'sh nom o\'rniga umumiy yozuv qaytaradi', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('uz'));
    expect(_unnamed.displayTitle(l10n), 'Xaritadagi manzil');
    expect(_named.displayTitle(l10n), 'Uy');
    // Faqat probeldan iborat nom ham bo'sh hisoblanadi.
    const spaces = UserAddress(id: 'x', title: '   ', isDefault: false);
    expect(spaces.displayTitle(l10n), 'Xaritadagi manzil');
  });

  test('ruscha va kirill tillarida ham tarjima bor', () async {
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(_unnamed.displayTitle(ru), 'Точка на карте');
    final cyrl = await AppLocalizations.delegate.load(
      const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    );
    expect(_unnamed.displayTitle(cyrl), 'Харитадаги манзил');
  });

  testWidgets('manzillar ro\'yxatida nomsiz manzil umumiy yozuv bilan', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesControllerProvider.overrideWith(_AddressesController.new),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddressesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xaritadagi manzil'), findsOneWidget);
    expect(find.text('Uy'), findsOneWidget);
    // Koordinata pastki qatorda qoladi — qaysi joy ekani ko'rinadi.
    expect(find.text('41.311081, 69.240563'), findsOneWidget);
  });
}
