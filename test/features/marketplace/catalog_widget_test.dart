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
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/household_category_landing.dart';
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
    bool? searchOnly,
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
            searchOnly:
                searchOnly ??
                (storeType == StoreType.household && initialCategoryId == null),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _CatalogHarness(catalogApi);
  }

  test('household 19 categoryni 5 bo‘limga ajratib YesPOSni yashiradi', () {
    const names = [
      'Arra zapchastlari',
      'Kiyim-kechak',
      'Ko‘k yashil to‘r',
      'Konstovar',
      'Maishiy texnika',
      'Mashina aksessuarlari',
      'MP3 va elektronika',
      'Oshxona anjomlari',
      'O‘yinchoqlar',
      'Oyoq kiyim',
      'Parfyumeriya',
      'Plastmassa',
      'Qurilish mollari',
      'Salafan va dasturxon',
      'Telefon zapchastlari',
      'Turli xil mahsulotlar',
      'Ustachilik asboblari',
      'Velosiped zapchastlari',
      'YesPOS Imported',
    ];
    final sections = buildHouseholdCategorySections([
      for (var index = 0; index < names.length; index++)
        ProductCategory(
          id: 'category-$index',
          name: names[index],
          canonicalName: names[index],
          storeTypeWire: 'household',
          productCount: 1,
        ),
    ]);

    expect(sections, hasLength(5));
    final items = sections.expand((section) => section.items).toList();
    expect(items, hasLength(18));
    expect(
      items.any((item) => item.category.name == 'YesPOS Imported'),
      isFalse,
    );
    expect(items.every((item) => item.assetPath != null), isTrue);
    expect(items.first.category.name, 'Qurilish mollari');
  });

  test('household asset mapping o‘zbek kirill yozuvida ham ishlaydi', () {
    final sections = buildHouseholdCategorySections(const [
      ProductCategory(
        id: 'construction',
        name: 'Қурилиш моллари',
        canonicalName: 'Қурилиш моллари',
        storeTypeWire: 'household',
        productCount: 1,
      ),
    ]);

    expect(
      sections.single.items.single.assetPath,
      endsWith('construction.webp'),
    );
  });

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

  testWidgets('household root rasmli category landingni ko‘rsatadi', (
    tester,
  ) async {
    final harness = await pumpCatalog(
      tester,
      ThemeMode.light,
      searchOnly: false,
    );

    expect(find.text('Xozmak'), findsOneWidget);
    expect(find.text('Asboblar'), findsOneWidget);
    expect(find.text('Bo‘sh kategoriya'), findsNothing);
    expect(find.byType(ProductCard), findsNothing);
    expect(
      find.byKey(const ValueKey('household-search-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-search-field')), findsNothing);
    verifyNever(() => harness.catalogApi.fetchProducts(storeType: 'household'));
  });

  testWidgets('category card bosilishi tanlangan kategoriyani qaytaradi', (
    tester,
  ) async {
    ProductCategory? selected;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: const [Locale('uz')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              HouseholdCategoryLandingSliver(
                categories: _landing.categories,
                onCategoryTap: (value) => selected = value,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('household-category-card-category-1')),
    );
    expect(selected?.id, 'category-1');
  });

  testWidgets('direct-link household category mahsulotlarini ochadi', (
    tester,
  ) async {
    final harness = await pumpCatalog(
      tester,
      ThemeMode.light,
      initialCategoryId: 'category-1',
    );

    expect(find.text('Asboblar'), findsOneWidget);
    expect(find.byType(ProductCard), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-search-field')), findsNothing);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).called(1);
  });

  testWidgets('qidiruv paneli pinned appbar ichida qoladi', (tester) async {
    await pumpCatalog(tester, ThemeMode.light, searchOnly: true);

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
