import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/catalog_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_card.dart';
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

ProductSummary _product(
  String id, {
  StoreType storeType = StoreType.household,
  String? name,
}) => ProductSummary.fromJson({
  'id': id,
  'name': name ?? 'Mahsulot $id',
  'description': '',
  'price': '15000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': storeType.wire,
  'store': {
    'id': 'store-1',
    'name': storeType.wire,
    'store_type': storeType.wire,
  },
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
  categories: [
    ProductCategory(
      id: 'category-1',
      name: 'Asboblar',
      storeTypeWire: 'household',
      productCount: 10,
    ),
    ProductCategory(
      id: 'category-empty',
      name: 'Bo‘sh kategoriya',
      storeTypeWire: 'household',
      productCount: 0,
    ),
  ],
  stores: [
    StoreInfo(
      id: 'store-1',
      name: 'Xozmak',
      storeTypeWire: 'household',
      description: '1005 xil mahsulot',
    ),
  ],
  banners: [],
  sections: [],
);

StoreLandingData _landingFor(
  StoreType type, {
  List<ProductSection> sections = const [],
}) => StoreLandingData(
  header: StoreHeader(
    storeTypeWire: type.wire,
    label: type.wire,
    subtitle: '',
    isEnabled: true,
    showHeader: false,
  ),
  categories: [
    ProductCategory(
      id: 'category-${type.wire}',
      name: 'Kategoriya ${type.wire}',
      storeTypeWire: type.wire,
      productCount: 4,
    ),
  ],
  stores: const [],
  banners: const [],
  sections: sections,
);

class _CatalogHarness {
  const _CatalogHarness(this.catalogApi);

  final _MockCatalogApi catalogApi;
}

void main() {
  Future<_CatalogHarness> pumpCatalog(
    WidgetTester tester,
    ThemeMode themeMode, {
    StoreType storeType = StoreType.household,
    StoreLandingData landing = _landing,
    CartData? cart,
    String? initialCategoryId,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final catalogApi = _MockCatalogApi();
    final storeApi = _MockStoreApi();
    final cartApi = _MockCartApi();
    final favoritesApi = _MockFavoritesApi();
    when(() => catalogApi.fetchProducts(storeType: storeType.wire)).thenAnswer(
      (_) async => CursorPage(
        items: [
          _product('1', storeType: storeType),
          _product('2', storeType: storeType),
        ],
        nextUrl: null,
      ),
    );
    if (initialCategoryId != null) {
      when(
        () => catalogApi.fetchProducts(
          storeType: storeType.wire,
          categoryId: initialCategoryId,
          query: '',
        ),
      ).thenAnswer(
        (_) async => CursorPage(
          items: [_product('filtered', storeType: storeType)],
          nextUrl: null,
        ),
      );
    }
    when(
      () => storeApi.fetchLanding(storeType.wire),
    ).thenAnswer((_) async => landing);
    when(
      () => cartApi.fetch(storeType.wire),
    ).thenAnswer((_) async => cart ?? CartData.empty(storeType.wire));
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
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeMode,
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: CatalogScreen(
            storeType: storeType,
            initialCategoryId: initialCategoryId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _CatalogHarness(catalogApi);
  }

  testWidgets('katalog aynan 2 ustun va ikki ProductCard chizadi', (
    tester,
  ) async {
    await pumpCatalog(tester, ThemeMode.light);

    final grids = find.byType(SliverGrid);
    expect(grids, findsOneWidget);
    final grid = tester.widget<SliverGrid>(grids);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(find.byType(ProductCard), findsNWidgets(2));
    for (final card in tester.widgetList<ProductCard>(
      find.byType(ProductCard),
    )) {
      expect(card.catalogStyle, isTrue);
    }
  });

  testWidgets('katalog dark theme’da ham xatosiz chiziladi', (tester) async {
    await pumpCatalog(tester, ThemeMode.dark);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(CatalogScreen))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('household category rail va filter sheetni chiqaradi', (
    tester,
  ) async {
    await pumpCatalog(tester, ThemeMode.light);

    expect(find.text('1005 xil mahsulot'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-category-rail')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.text('Asboblar'), findsOneWidget);
    expect(find.text('Bo‘sh kategoriya'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(
      find.byKey(const ValueKey('household-category-filter')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('household-category-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Kategoriyalar'), findsOneWidget);
    expect(find.text('Barchasi'), findsNWidgets(2));
    expect(find.text('Asboblar'), findsNWidgets(2));
    expect(find.text('Bo‘sh kategoriya'), findsNWidgets(2));
  });

  testWidgets('household rail category bosilganda mahsulotlarni filtrlaydi', (
    tester,
  ) async {
    final harness = await pumpCatalog(tester, ThemeMode.light);
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).thenAnswer(
      (_) async => CursorPage(
        items: [_product('rail-result', name: 'Rail natija')],
        nextUrl: null,
      ),
    );

    await tester.tap(find.text('Asboblar'));
    await tester.pumpAndSettle();

    expect(find.text('Rail natija'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Asboblar'),
    );
    expect(chip.selected, isTrue);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).called(1);
  });

  testWidgets('household category tanlaydi va filter active ko‘rinadi', (
    tester,
  ) async {
    final harness = await pumpCatalog(tester, ThemeMode.light);
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).thenAnswer(
      (_) async => CursorPage(
        items: [_product('category-result', name: 'Category natija')],
        nextUrl: null,
      ),
    );
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: '',
      ),
    ).thenAnswer(
      (_) async => CursorPage(
        items: [_product('all-result', name: 'Barcha natija')],
        nextUrl: null,
      ),
    );

    final filter = find.byKey(const ValueKey('household-category-filter'));
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('household-category-category-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Category natija'), findsOneWidget);
    final badge = tester.widget<Badge>(
      find.descendant(of: filter, matching: find.byType(Badge)),
    );
    expect(badge.isLabelVisible, isTrue);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).called(1);

    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('household-category-all')));
    await tester.pumpAndSettle();
    expect(find.text('Barcha natija'), findsOneWidget);
    final clearedBadge = tester.widget<Badge>(
      find.descendant(of: filter, matching: find.byType(Badge)),
    );
    expect(clearedBadge.isLabelVisible, isFalse);
  });

  testWidgets('direct-link household category filterini active qiladi', (
    tester,
  ) async {
    final harness = await pumpCatalog(
      tester,
      ThemeMode.light,
      initialCategoryId: 'category-1',
    );

    final filter = find.byKey(const ValueKey('household-category-filter'));
    final badge = tester.widget<Badge>(
      find.descendant(of: filter, matching: find.byType(Badge)),
    );
    expect(badge.isLabelVisible, isTrue);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).called(1);
  });

  testWidgets('qidiruv paneli pinned appbar ichida qoladi', (tester) async {
    await pumpCatalog(tester, ThemeMode.light);

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.pinned, isTrue);
    expect(appBar.bottom, isNotNull);
    expect(find.byKey(const ValueKey('catalog-search-field')), findsOneWidget);
  });

  testWidgets('boshqa store kategoriya chiplarini saqlaydi', (tester) async {
    await pumpCatalog(
      tester,
      ThemeMode.light,
      storeType: StoreType.grocery,
      landing: _landingFor(StoreType.grocery),
    );

    expect(find.text('Kategoriya grocery'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
  });

  testWidgets(
    'live qidiruv curated seksiyani yashirib natijani darhol ko‘rsatadi',
    (tester) async {
      final landing = _landingFor(
        StoreType.household,
        sections: [
          ProductSection(
            id: 'popular',
            title: '',
            products: [_product('popular')],
          ),
        ],
      );
      final harness = await pumpCatalog(
        tester,
        ThemeMode.light,
        landing: landing,
      );
      when(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          categoryId: null,
          query: 'temir',
        ),
      ).thenAnswer(
        (_) async => CursorPage(
          items: [_product('result', name: 'Temir natija')],
          nextUrl: null,
        ),
      );
      expect(find.text('Ommabop'), findsNothing);

      await tester.enterText(find.byType(TextField), 'temir');
      await tester.pump(const Duration(milliseconds: 349));
      verifyNever(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          categoryId: null,
          query: 'temir',
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Ommabop'), findsNothing);
      expect(find.text('Temir natija'), findsOneWidget);
      verify(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          categoryId: null,
          query: 'temir',
        ),
      ).called(1);
    },
  );

  testWidgets('qidiruv boshlanganda household category bekor qilinadi', (
    tester,
  ) async {
    final harness = await pumpCatalog(tester, ThemeMode.light);
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).thenAnswer(
      (_) async =>
          CursorPage(items: [_product('category-result')], nextUrl: null),
    );
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: 'bolg‘a',
      ),
    ).thenAnswer(
      (_) async => CursorPage(
        items: [_product('search-result', name: 'Bolg‘a natija')],
        nextUrl: null,
      ),
    );

    final filter = find.byKey(const ValueKey('household-category-filter'));
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('household-category-category-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('catalog-search-field')),
      'bolg‘a',
    );
    await tester.pump();
    final badge = tester.widget<Badge>(
      find.descendant(of: filter, matching: find.byType(Badge)),
    );
    expect(badge.isLabelVisible, isFalse);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Bolg‘a natija'), findsOneWidget);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: 'bolg‘a',
      ),
    ).called(1);
  });

  testWidgets('qidiruv paytida category tanlansa matn tozalanadi', (
    tester,
  ) async {
    final harness = await pumpCatalog(tester, ThemeMode.light);
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: 'sovun',
      ),
    ).thenAnswer(
      (_) async =>
          CursorPage(items: [_product('search-result')], nextUrl: null),
    );
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).thenAnswer(
      (_) async => CursorPage(
        items: [_product('category-result', name: 'Category natija')],
        nextUrl: null,
      ),
    );

    final search = find.byKey(const ValueKey('catalog-search-field'));
    await tester.enterText(search, 'sovun');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('household-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('household-category-category-1')),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(search).controller?.text, isEmpty);
    expect(find.text('Category natija'), findsOneWidget);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).called(1);
  });

  testWidgets('lupa, Enter va clear darhol ishlaydi', (tester) async {
    final landing = _landingFor(
      StoreType.household,
      sections: [
        ProductSection(
          id: 'popular',
          title: '',
          products: [_product('popular')],
        ),
      ],
    );
    final harness = await pumpCatalog(
      tester,
      ThemeMode.light,
      landing: landing,
    );
    for (final query in ['sovun', 'temir']) {
      when(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          categoryId: null,
          query: query,
        ),
      ).thenAnswer(
        (_) async => CursorPage(
          items: [_product(query, name: 'Natija $query')],
          nextUrl: null,
        ),
      );
    }
    when(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: '',
      ),
    ).thenAnswer(
      (_) async => CursorPage(items: [_product('reset')], nextUrl: null),
    );
    clearInteractions(harness.catalogApi);

    await tester.enterText(find.byType(TextField), 'sovun');
    await tester.tap(find.byTooltip('Qidirish'));
    await tester.pumpAndSettle();
    expect(find.text('Natija sovun'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'temir');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Natija temir'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Ommabop'), findsNothing);
    expect(find.text('Mahsulot reset'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: '',
      ),
    ).called(1);
  });

  testWidgets('savat to‘lsa sticky mini-savat chiqadi', (tester) async {
    final product = _product('cart', storeType: StoreType.restaurant);
    await pumpCatalog(
      tester,
      ThemeMode.light,
      storeType: StoreType.restaurant,
      landing: _landingFor(StoreType.restaurant),
      cart: CartData(
        id: 'cart-restaurant',
        storeTypeWire: 'restaurant',
        items: [
          CartItem(
            id: 'line-1',
            product: product,
            quantity: 2,
            selectedAddons: const [],
            note: '',
            subtotal: '30000.00',
          ),
        ],
        totalItems: 1,
        totalQuantity: 2,
        subtotal: '30000.00',
      ),
    );

    expect(find.byKey(const ValueKey('catalog-mini-cart')), findsOneWidget);
    expect(find.text('SAVAT · 2 ta'), findsOneWidget);
    expect(find.text("30\u00a0000 so'm"), findsOneWidget);
  });
}
