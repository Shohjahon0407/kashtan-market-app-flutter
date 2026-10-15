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
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/meat_product_card.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_card.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/restaurant_category_landing.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_catalog.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorite_models.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorites_api.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
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
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/fake_recommendations_api.dart';
import '../../helpers/reveal_imageless.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockStoreApi extends Mock implements StoreApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockFavoritesApi extends Mock implements FavoritesApi {}

ProductSummary _product(
  String id, {
  StoreType storeType = StoreType.household,
  String? name,
  String price = '15000.00',
  bool withImage = true,
}) => ProductSummary.fromJson({
  'id': id,
  'name': name ?? 'Mahsulot $id',
  'description': '',
  'price': price,
  'main_image': withImage ? 'https://example.test/products/$id.jpg' : null,
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

const _restaurantLanding = StoreLandingData(
  header: StoreHeader(
    storeTypeWire: 'restaurant',
    label: 'Restoran',
    subtitle: 'Tayyor taomlar',
    isEnabled: true,
    showHeader: false,
  ),
  categories: [
    ProductCategory(
      id: 'first-courses',
      name: '1-TAOMLAR',
      canonicalName: '1-TAOMLAR',
      storeTypeWire: 'restaurant',
      productCount: 5,
    ),
    ProductCategory(
      id: 'plov',
      name: 'Oshlar',
      canonicalName: 'Oshlar',
      storeTypeWire: 'restaurant',
      productCount: 7,
    ),
    ProductCategory(
      id: 'empty-dessert',
      name: 'Muzqaymoq',
      canonicalName: 'Muzqaymoq',
      storeTypeWire: 'restaurant',
      productCount: 0,
    ),
  ],
  stores: [],
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
    List<ProductSummary>? catalogProducts,
    String? initialCategoryId,
    bool? searchOnly,
    FakeRecommendationsApi? recommendationsApi,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final catalogApi = _MockCatalogApi();
    final storeApi = _MockStoreApi();
    final cartApi = _MockCartApi();
    final favoritesApi = _MockFavoritesApi();
    when(() => catalogApi.fetchProducts(storeType: storeType.wire)).thenAnswer(
      (_) async => CursorPage(
        items:
            catalogProducts ??
            [
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
          items:
              catalogProducts ?? [_product('filtered', storeType: storeType)],
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
          recommendationsApiProvider.overrideWithValue(
            recommendationsApi ?? FakeRecommendationsApi(),
          ),
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
                ((storeType == StoreType.household ||
                        storeType == StoreType.restaurant) &&
                    initialCategoryId == null),
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

  testWidgets(
    'rasmsiz category mahsuloti faqat yashirin tortishdan keyin chiqadi',
    (tester) async {
      await pumpCatalog(
        tester,
        ThemeMode.light,
        initialCategoryId: 'category-1',
        catalogProducts: [_product('no-photo', withImage: false)],
      );
      expect(find.byType(ProductCard), findsNothing);
      expect(find.text('Mahsulot no-photo'), findsNothing);
      expect(
        find.byKey(const ValueKey('imageless-reveal-button')),
        findsNothing,
      );
      await revealImagelessProducts(tester);
      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.text('Mahsulot no-photo'), findsOneWidget);
    },
  );

  testWidgets(
    'aralash listda oddiy scroll rasmsizlarni ochmaydi; ochishda scroll saqlanadi',
    (tester) async {
      await pumpCatalog(
        tester,
        ThemeMode.light,
        storeType: StoreType.grocery,
        catalogProducts: [
          _product('no-photo', withImage: false, storeType: StoreType.grocery),
          for (var i = 0; i < 8; i++)
            _product('photo-$i', storeType: StoreType.grocery),
        ],
      );
      final footer = find.byKey(const ValueKey('imageless-reveal-prompt'));
      await tester.scrollUntilVisible(
        footer,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Mahsulot no-photo'), findsNothing);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      final atBottom = scroll.pixels;
      await revealImagelessProducts(tester);
      expect(scroll.pixels, atBottom);
      await tester.scrollUntilVisible(
        find.text('Mahsulot no-photo'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mahsulot no-photo'), findsOneWidget);
    },
  );

  testWidgets(
    'family rasmi bo‘lsa rasmsiz variant yo‘qolmaydi, rasmsiz family alohida ochiladi',
    (tester) async {
      await pumpCatalog(
        tester,
        ThemeMode.light,
        storeType: StoreType.shashlik,
        catalogProducts: [
          _product('beef', name: 'Mol jazz', storeType: StoreType.shashlik),
          _product(
            'beef-kg',
            name: 'Mol jazz kiloligi',
            storeType: StoreType.shashlik,
            withImage: false,
          ),
          _product(
            'lamb',
            name: 'Qo‘y jazz',
            storeType: StoreType.shashlik,
            withImage: false,
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey('shashlik-family-beef-jazz')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shashlik-family-lamb-jazz')),
        findsNothing,
      );
      final family = tester.widget<ShashlikFamilyCard>(
        find.byType(ShashlikFamilyCard),
      );
      expect(family.family.products, hasLength(2));
      await revealImagelessProducts(tester);
      expect(
        find.byKey(const ValueKey('shashlik-family-lamb-jazz')),
        findsOneWidget,
      );
    },
  );

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

  test(
    'restaurant kategoriyalari restoran assetlariga tartibli map bo‘ladi',
    () {
      const names = [
        '1-TAOMLAR',
        '2-TAOMLAR',
        'Baliq',
        'Choy non',
        'Kampot',
        'Muzqaymoq',
        'Oshlar',
        'Salatlar',
        'Shashlik',
        'Shirinliklar',
        'Somsa',
        'Xalim',
      ];
      final items = buildRestaurantCategoryItems([
        for (var index = 0; index < names.length; index++)
          ProductCategory(
            id: 'restaurant-$index',
            name: names[index],
            canonicalName: names[index],
            storeTypeWire: 'restaurant',
            productCount: 1,
          ),
      ]);

      expect(items, hasLength(12));
      expect(items.every((item) => item.assetPath != null), isTrue);
      expect(items.take(8).map((item) => item.category.name), [
        '1-TAOMLAR',
        '2-TAOMLAR',
        'Oshlar',
        'Xalim',
        'Shashlik',
        'Somsa',
        'Salatlar',
        'Choy non',
      ]);
      expect(items.first.category.name, '1-TAOMLAR');
      expect(items.first.assetPath, endsWith('first-courses.webp'));
    },
  );

  testWidgets('restaurant lenta 360px da 2 ta, 390px da 3 ta rasm ko‘rsatadi', (
    tester,
  ) async {
    final previousInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = previousInterval;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const category = ProductCategory(
      id: 'restaurant-preview',
      name: '1-TAOMLAR',
      canonicalName: '1-TAOMLAR',
      storeTypeWire: 'restaurant',
      productCount: 3,
      previewImageUrls: [
        'https://example.invalid/1.webp',
        'https://example.invalid/2.webp',
        'https://example.invalid/3.webp',
      ],
    );

    Future<void> pumpAt(double width) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                RestaurantCategoryLandingSliver(
                  categories: const [category],
                  onCategoryTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpAt(360);
    expect(
      tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .viewportFraction,
      .5,
    );

    await pumpAt(390);
    expect(
      tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .viewportFraction,
      closeTo(1 / 3, .0001),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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

  testWidgets('ochib qaytilgan mahsulot qatoridan keyin o\'xshashlar chiqadi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final products = [
      for (var i = 1; i <= 10; i++)
        _product('$i', storeType: StoreType.grocery),
    ];
    await pumpCatalog(
      tester,
      ThemeMode.light,
      storeType: StoreType.grocery,
      catalogProducts: products,
      searchOnly: false,
      recommendationsApi: FakeRecommendationsApi(
        similarItems: {
          '3': [
            _product('s1', storeType: StoreType.grocery),
            _product('s2', storeType: StoreType.grocery),
            _product(
              's-hidden',
              storeType: StoreType.grocery,
              withImage: false,
            ),
          ],
        },
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CatalogScreen)),
    );
    container
        .read(lastProductViewProvider.notifier)
        .set(
          ProductViewSignal(
            productId: '3',
            name: 'Mahsulot 3',
            storeType: StoreType.grocery,
            at: DateTime.now(),
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('catalog-similar-3')), findsOneWidget);
    expect(find.text("«Mahsulot 3»ga o'xshashlar"), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-similar-3-s1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('catalog-similar-3-s-hidden')),
      findsNothing,
    );
    // Qator mahsulot 3-4 qatoridan keyin, 5-dan oldin.
    final railTop = tester
        .getTopLeft(find.byKey(const ValueKey('catalog-similar-3')))
        .dy;
    expect(tester.getTopLeft(find.text('Mahsulot 4')).dy, lessThan(railTop));
    expect(tester.getTopLeft(find.text('Mahsulot 5')).dy, greaterThan(railTop));

    // Boshqa do'kon signali va takror — qo'shilmaydi.
    container
        .read(lastProductViewProvider.notifier)
        .set(
          ProductViewSignal(
            productId: '4',
            name: 'Mahsulot 4',
            storeType: StoreType.household,
            at: DateTime.now(),
          ),
        );
    await tester.pump();
    expect(find.byKey(const ValueKey('catalog-similar-4')), findsNothing);
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

  testWidgets(
    'restaurant root mahsulot o‘rniga rasmli categorylarni ko‘rsatadi',
    (tester) async {
      final harness = await pumpCatalog(
        tester,
        ThemeMode.light,
        storeType: StoreType.restaurant,
        landing: _restaurantLanding,
        searchOnly: false,
      );

      expect(find.text('Restoran'), findsOneWidget);
      expect(find.text('An’anaviy taomlar'), findsNothing);
      expect(find.text('Grill va tandir'), findsNothing);
      expect(find.text('1-TAOMLAR'), findsOneWidget);
      expect(find.text('Oshlar'), findsOneWidget);
      expect(find.text('Muzqaymoq'), findsNothing);
      expect(find.byType(ProductCard), findsNothing);
      expect(
        find.byKey(const ValueKey('restaurant-search-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('catalog-search-field')), findsNothing);
      verifyNever(
        () => harness.catalogApi.fetchProducts(storeType: 'restaurant'),
      );
    },
  );

  testWidgets('restaurant category route faqat shu categoryni yuklaydi', (
    tester,
  ) async {
    final harness = await pumpCatalog(
      tester,
      ThemeMode.light,
      storeType: StoreType.restaurant,
      landing: _restaurantLanding,
      initialCategoryId: 'first-courses',
    );

    expect(find.text('1-TAOMLAR'), findsOneWidget);
    expect(find.byType(ProductCard), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-search-field')), findsNothing);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'restaurant',
        categoryId: 'first-courses',
        query: '',
      ),
    ).called(1);
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
    'shashlik root family kartalari va uchta virtual bo‘limni ko‘rsatadi',
    (tester) async {
      await pumpCatalog(
        tester,
        ThemeMode.light,
        storeType: StoreType.shashlik,
        landing: _landingFor(StoreType.shashlik),
        catalogProducts: [
          _product(
            'beef-stick',
            storeType: StoreType.shashlik,
            name: 'Mol jazz',
          ),
          _product(
            'beef-kilo',
            storeType: StoreType.shashlik,
            name: 'Mol jazz kiloligi',
            price: '200000.00',
          ),
          _product(
            'lamb-stick',
            storeType: StoreType.shashlik,
            name: "Qo'y jazz",
          ),
          _product(
            'lamb-kilo',
            storeType: StoreType.shashlik,
            name: "Qo'y jazz kiloligi",
          ),
          _product('wing', storeType: StoreType.shashlik, name: 'Qanot'),
          _product(
            'wing-kilo',
            storeType: StoreType.shashlik,
            name: 'Qanot kiloligi',
          ),
          _product(
            'liver-stick',
            storeType: StoreType.shashlik,
            name: 'Jigar',
            price: '12000.00',
          ),
          _product(
            'liver-kilo',
            storeType: StoreType.shashlik,
            name: 'Jigar',
            price: '115000.00',
          ),
          _product('mince', storeType: StoreType.shashlik, name: 'Qiyma'),
          _product(
            'bread-mince',
            storeType: StoreType.shashlik,
            name: 'Non qiyma',
          ),
          _product(
            'kilo-mince',
            storeType: StoreType.shashlik,
            name: 'Kilolik qiyma',
          ),
          _product(
            'coal-fast',
            storeType: StoreType.shashlik,
            name: 'Tez yonar ko‘mir',
          ),
          _product(
            'coal-stone',
            storeType: StoreType.shashlik,
            name: 'Tosh ko‘mir',
          ),
          _product('ragu', storeType: StoreType.shashlik, name: 'Mol ragu'),
          _product('bez', storeType: StoreType.shashlik, name: 'Bez'),
        ],
      );

      expect(find.byKey(const ValueKey('catalog-search-field')), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(ProductCard), findsNothing);
      expect(find.byType(ShashlikSectionSelector), findsOneWidget);
      expect(
        tester
            .widget<ShashlikCatalogList>(find.byType(ShashlikCatalogList))
            .groups
            .families,
        hasLength(5),
      );
      expect(
        find.byKey(const ValueKey('shashlik-family-beef-jazz')),
        findsOneWidget,
      );
      expect(find.textContaining('Kilogrammi 200'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shashlik-section-charcoal')));
      await tester.pumpAndSettle();
      expect(find.byType(ShashlikProductRow), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('shashlik-section-kebabs')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shashlik-family-add-beef-jazz')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-selector-submit')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shashlik-selector-plus')));
      await tester.tap(find.byKey(const ValueKey('shashlik-selector-plus')));
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('shashlik-selector-quantity')),
            )
            .data,
        '3 dona',
      );
      await tester.tap(
        find.byKey(const ValueKey('shashlik-selector-product-beef-kilo')),
      );
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('shashlik-selector-quantity')),
            )
            .data,
        '3 kilogram',
      );
    },
  );

  testWidgets('go‘sht katalogi oltita gorizontal kartani qat’iy tartiblaydi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const meatLanding = StoreLandingData(
      header: StoreHeader(
        storeTypeWire: 'meat',
        label: 'KERAKSIZ MEAT HERO',
        subtitle: 'Mol, qo‘y va tovuq go‘shti',
        isEnabled: true,
        showHeader: true,
      ),
      categories: [
        ProductCategory(
          id: 'meat-category',
          name: 'Go‘shtlar',
          storeTypeWire: 'meat',
          productCount: 4,
        ),
      ],
      stores: [],
      banners: [],
      sections: [],
    );

    await pumpCatalog(
      tester,
      ThemeMode.light,
      storeType: StoreType.meat,
      landing: meatLanding,
      catalogProducts: [
        _product('qazi', storeType: StoreType.meat, name: 'Qazi'),
        _product('lamb-liver', storeType: StoreType.meat, name: "Qo'y jigar"),
        _product('horse', storeType: StoreType.meat, name: "Ot go'shi"),
        _product('beef', storeType: StoreType.meat, name: "Mol go'shti"),
        _product('beef-liver', storeType: StoreType.meat, name: 'Mol jigar'),
        _product('lamb', storeType: StoreType.meat, name: "Qo'y go'shti"),
      ],
    );

    expect(find.byKey(const ValueKey('catalog-search-field')), findsNothing);
    expect(find.text('KERAKSIZ MEAT HERO'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(ProductCard), findsNothing);
    expect(find.byType(MeatProductCard), findsNWidgets(6));
    expect(find.byIcon(Icons.favorite_border), findsNothing);

    const labels = [
      'Qo‘y go‘shti',
      'Mol go‘shti',
      'Ot go‘shti',
      'Qazi',
      'Mol jigar',
      'Qo‘y jigar',
    ];
    final positions = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(positions, orderedEquals([...positions]..sort()));
    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey('meat-product-card-lamb-liver')),
          )
          .dy,
      lessThanOrEqualTo(800),
    );
    expect(find.byKey(const ValueKey('meat-animal-lamb-lamb')), findsOneWidget);
    expect(find.byKey(const ValueKey('meat-animal-beef-beef')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meat-animal-horse-horse')),
      findsOneWidget,
    );

    final fallbackAssets = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('meat-product-list')),
            matching: find.byType(Image),
          ),
        )
        .map((image) => image.image)
        .map(
          (provider) =>
              provider is ResizeImage ? provider.imageProvider : provider,
        )
        .whereType<AssetImage>()
        .map((provider) => provider.assetName)
        .toSet();
    expect(fallbackAssets, contains('assets/products/meat/lamb-meat.webp'));
    expect(fallbackAssets, contains('assets/products/meat/beef-meat.webp'));
    expect(fallbackAssets, contains('assets/products/meat/horse-meat.webp'));
    expect(fallbackAssets, contains('assets/products/meat/qazi.webp'));
    expect(fallbackAssets, contains('assets/products/meat/beef-liver.webp'));
    expect(fallbackAssets, contains('assets/products/meat/lamb-liver.webp'));
  });

  testWidgets('go‘sht mini-savatchasi listni yopmaydi va scroll saqlanadi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final products = [
      _product('lamb', storeType: StoreType.meat, name: "Qo'y go'shti"),
      _product('beef', storeType: StoreType.meat, name: "Mol go'shti"),
      _product('horse', storeType: StoreType.meat, name: "Ot go'shi"),
      _product('qazi', storeType: StoreType.meat, name: 'Qazi'),
      _product('beef-liver', storeType: StoreType.meat, name: 'Mol jigar'),
      _product('lamb-liver', storeType: StoreType.meat, name: "Qo'y jigar"),
    ];
    await pumpCatalog(
      tester,
      ThemeMode.light,
      storeType: StoreType.meat,
      landing: _landingFor(StoreType.meat),
      catalogProducts: products,
      cart: CartData(
        id: 'meat-cart',
        storeTypeWire: 'meat',
        items: [
          CartItem(
            id: 'meat-line',
            product: products.first,
            quantity: 1,
            selectedAddons: const [],
            note: '',
            subtotal: '15000.00',
          ),
        ],
        totalItems: 1,
        totalQuantity: 1,
        subtotal: '15000.00',
      ),
    );

    final list = find.byKey(const ValueKey('meat-product-list'));
    final miniCart = find.byKey(const ValueKey('catalog-mini-cart'));
    expect(miniCart, findsOneWidget);
    expect(
      tester.getRect(list).bottom,
      lessThanOrEqualTo(tester.getRect(miniCart).top),
    );

    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Qo‘y jigar'), findsOneWidget);
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
