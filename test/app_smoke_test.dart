import 'package:beshkashtan_customer/app.dart';
import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHomeApi extends Mock implements HomeApi {}

class _MockVideoApi extends Mock implements VideoApi {}

class _MockCartApi extends Mock implements CartApi {}

/// Ilova daraxti uchma-uch quriladimi: mavzu, 3 ta locale, l10n delegatlari,
/// playground ekrani. Emulyatorsiz ham eng muhim regressiyalarni ushlaydi.
///
/// DIQQAT: har bir locale ALOHIDA testda tekshiriladi. Bitta test ichida
/// qayta `pumpWidget` qilinsa Flutter element daraxtini qayta ishlatadi va
/// `LocaleController` qaytadan qurilmaydi — ya'ni til o'zgarmaydi.
Future<void> _pumpApp(WidgetTester tester, {String? localeCode}) async {
  SharedPreferences.setMockInitialValues(
    localeCode == null
        ? <String, Object>{}
        : <String, Object>{'app.locale_code': localeCode},
  );
  final prefs = await PrefsStore.load();
  final homeApi = _MockHomeApi();
  final videoApi = _MockVideoApi();
  final cartApi = _MockCartApi();
  when(
    () => homeApi.fetch(),
  ).thenAnswer((_) async => const HomeData(banners: [], storeHub: []));
  when(() => videoApi.fetchFeed()).thenAnswer(
    (_) async => const CursorPage<StoreVideo>(items: [], nextUrl: null),
  );
  when(() => cartApi.fetch(any())).thenAnswer(
    (invocation) async =>
        CartData.empty(invocation.positionalArguments.first as String),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        homeApiProvider.overrideWithValue(homeApi),
        videoApiProvider.overrideWithValue(videoApi),
        cartApiProvider.overrideWithValue(cartApi),
      ],
      child: const BeshKashtanApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('guest ilova ishga tushganda Home ekrani ochiladi', (
    tester,
  ) async {
    await _pumpApp(tester);
    // Router guestni majburiy auth ekraniga yubormaydi.
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Besh Kashtan'), findsOneWidget);
    expect(find.text('Telefon raqamingiz'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system dark bo‘lsa ham ilova faqat light theme ishlatadi', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
  });

  testWidgets('uz_Cyrl locale Material delegatlarini buzmaydi', (tester) async {
    // Regressiya: `const [...]` ro'yxatida `ScriptFallbackDelegate` ning tur
    // argumenti `dynamic` ga chiqarilsa, MaterialLocalizations ro'yxatdan
    // o'tmay qoladi va "No MaterialLocalizations found" bilan yiqiladi.
    await _pumpApp(tester, localeCode: 'uz_Cyrl');

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, AppLocale.uzCyrl.locale);
    expect(tester.takeException(), isNull);

    final context = tester.element(find.byType(Scaffold).first);
    expect(MaterialLocalizations.of(context), isNotNull);
  });

  testWidgets('uz — lotin matn', (tester) async {
    await _pumpApp(tester, localeCode: 'uz');
    final context = tester.element(find.byType(Scaffold).first);
    expect(AppLocalizations.of(context).commonRetry, 'Qayta urinish');
    expect(AppLocalizations.of(context).appName, 'Besh Kashtan');
  });

  testWidgets('uz_Cyrl — kirill matn (generatsiya qilingan ARB)', (
    tester,
  ) async {
    await _pumpApp(tester, localeCode: 'uz_Cyrl');
    final context = tester.element(find.byType(Scaffold).first);
    expect(AppLocalizations.of(context).commonRetry, 'Қайта уриниш');
    // cyrl_overrides.json dagi qo'lda yozilgan qiymat
    expect(AppLocalizations.of(context).appName, 'Besh Kashtan');
  });

  testWidgets('ru — rus matn', (tester) async {
    await _pumpApp(tester, localeCode: 'ru');
    final context = tester.element(find.byType(Scaffold).first);
    expect(AppLocalizations.of(context).commonRetry, 'Повторить');
  });

  testWidgets('apiLang uz_Cyrl uchun ham "uz" qaytaradi', (tester) async {
    await _pumpApp(tester, localeCode: 'uz_Cyrl');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(container.read(apiLangProvider), 'uz');
  });
}
