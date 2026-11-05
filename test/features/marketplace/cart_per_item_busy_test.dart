import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/catalog_screen.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorite_models.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorites_api.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/features/store/data/store_api.dart';
import 'package:beshkashtan_customer/features/store/data/store_models.dart';
import 'package:beshkashtan_customer/features/store/domain/store_landing_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockStoreApi extends Mock implements StoreApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockFavoritesApi extends Mock implements FavoritesApi {}

ProductSummary _product(String id) => ProductSummary.fromJson({
  'id': id,
  'name': 'Mahsulot $id',
  'description': '',
  'price': '20000.00',
  'main_image': 'https://example.test/products/$id.jpg',
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'household',
  'store': {'id': 'store-1', 'name': 'household', 'store_type': 'household'},
  'variants': <Map<String, dynamic>>[],
});

const _landing = StoreLandingData(
  header: StoreHeader(
    storeTypeWire: 'household',
    label: 'Xozmak',
    subtitle: '',
    isEnabled: true,
    showHeader: false,
  ),
  categories: [],
  stores: [],
  banners: [],
  sections: [],
);

/// Cart mutationlar optimistic: bosilgan karta darhol stepperga aylanadi,
/// ammo hech bir karta tarmoq spinnerini ko'rsatmaydi.
void main() {
  setUpAll(() {
    registerFallbackValue(const CartConfiguration(productId: 'fallback'));
  });

  Future<void> pumpCatalog(
    WidgetTester tester, {
    required _MockCartApi cartApi,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final catalogApi = _MockCatalogApi();
    final storeApi = _MockStoreApi();
    final favoritesApi = _MockFavoritesApi();

    when(() => catalogApi.fetchProducts(storeType: 'household')).thenAnswer(
      (_) async =>
          CursorPage(items: [_product('1'), _product('2')], nextUrl: null),
    );
    when(
      () => storeApi.fetchLanding('household'),
    ).thenAnswer((_) async => _landing);
    when(() => favoritesApi.fetch()).thenAnswer((_) async => <FavoriteEntry>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          catalogApiProvider.overrideWithValue(catalogApi),
          storeApiProvider.overrideWithValue(storeApi),
          cartApiProvider.overrideWithValue(cartApi),
          favoritesApiProvider.overrideWithValue(favoritesApi),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          theme: AppTheme.light(),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const CatalogScreen(
            storeType: StoreType.household,
            searchOnly: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder buyButton(String productId) =>
      find.byKey(ValueKey('product-card-buy-$productId'));

  bool hasSpinner(WidgetTester tester, String productId) => tester
      .widgetList(
        find.descendant(
          of: buyButton(productId),
          matching: find.byType(CircularProgressIndicator),
        ),
      )
      .isNotEmpty;

  testWidgets('qo‘shish paytida quantity darhol chiqadi va spinner yo‘q', (
    tester,
  ) async {
    final cartApi = _MockCartApi();
    final adding = Completer<void>();
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => CartData.empty('household'));
    when(
      () => cartApi.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) => adding.future);

    await pumpCatalog(tester, cartApi: cartApi);
    expect(buyButton('1'), findsOneWidget);
    expect(buyButton('2'), findsOneWidget);

    await tester.tap(buyButton('1'));
    await tester.pump();

    expect(
      hasSpinner(tester, '1'),
      isFalse,
      reason: 'cart mutation spinner bilan almashtirilmasligi kerak',
    );
    expect(
      hasSpinner(tester, '2'),
      isFalse,
      reason: 'boshqa kartalar bandligini KO\'RSATMASLIGI kerak',
    );
    expect(
      find.byKey(const ValueKey('product-card-stepper-1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('product-card-stepper-1')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 200));
    adding.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('birinchi so\'rov ketayotganda bosilgan ikkinchi karta '
      'TASHLAB YUBORILMAYDI', (tester) async {
    final cartApi = _MockCartApi();
    final firstAdd = Completer<void>();
    final addedProductIds = <String>[];
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => CartData.empty('household'));
    when(
      () => cartApi.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) {
      final configuration =
          invocation.namedArguments[#configuration] as CartConfiguration;
      addedProductIds.add(configuration.productId);
      return configuration.productId == '1'
          ? firstAdd.future
          : Future<void>.value();
    });

    await pumpCatalog(tester, cartApi: cartApi);

    await tester.tap(buyButton('1'));
    await tester.pump(const Duration(milliseconds: 200));
    // Birinchi so'rov hali tugamagan — ikkinchi kartani bosamiz.
    await tester.tap(buyButton('2'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      hasSpinner(tester, '2'),
      isFalse,
      reason: 'navbatdagi kartada ham spinner chiqmasligi kerak',
    );
    expect(
      find.byKey(const ValueKey('product-card-stepper-2')),
      findsOneWidget,
    );
    expect(addedProductIds, ['1'], reason: 'so\'rovlar ketma-ket ketadi');

    firstAdd.complete();
    await tester.pumpAndSettle();

    expect(
      addedProductIds,
      ['1', '2'],
      reason: 'ikkinchi bosish jimgina tashlab yuborilmasligi kerak',
    );
  });
}
