import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Valyuta qo'shimchasi tilga mos: rus/kirill foydalanuvchi lotin "so'm"
/// ko'rmasligi kerak.
void main() {
  tearDown(() => Uzs.suffix = Uzs.suffixFor(AppLocale.uz));

  test('har til uchun o\'z qo\'shimchasi', () {
    expect(Uzs.suffixFor(AppLocale.uz), "so'm");
    expect(Uzs.suffixFor(AppLocale.uzCyrl), 'сўм');
    expect(Uzs.suffixFor(AppLocale.ru), 'сум');
  });

  test('format joriy qo\'shimchani ishlatadi', () {
    Uzs.suffix = Uzs.suffixFor(AppLocale.ru);
    expect(Uzs.format('15000.00'), '15 000 сум');
    Uzs.suffix = Uzs.suffixFor(AppLocale.uz);
    expect(Uzs.format('15000.00'), "15 000 so'm");
  });

  test(
    'locale controller tilni o\'rnatganda qo\'shimcha ham o\'zgaradi',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final container = ProviderContainer(
        overrides: [prefsStoreProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      container.read(localeControllerProvider);
      expect(Uzs.suffix, "so'm");

      await container.read(localeControllerProvider.notifier).set(AppLocale.ru);
      expect(Uzs.suffix, 'сум');

      await container
          .read(localeControllerProvider.notifier)
          .set(AppLocale.uzCyrl);
      expect(Uzs.suffix, 'сўм');
    },
  );
}
