import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/category_banners.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/catalog_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/category_product_banners.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/household_category_landing.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/meat_product_card.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_card.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/restaurant_category_landing.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_cart_bar.dart';
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

class _MockCategoryBannersApi extends Mock implements CategoryBannersApi {}

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
  setUp(() {
    final previous = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(
      () => VisibilityDetectorController.instance.updateInterval = previous,
    );
  });
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
    List<CategoryProductBanner> categoryBanners = const [],
    List<ProductSummary> categoryRecommendations = const [],
    double textScale = 1,
    bool withNavbar = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final catalogApi = _MockCatalogApi();
    final storeApi = _MockStoreApi();
    final cartApi = _MockCartApi();
    final favoritesApi = _MockFavoritesApi();
    final bannersApi = _MockCategoryBannersApi();
    when(
      () => bannersApi.fetch(any()),
    ).thenAnswer((_) async => CategoryBannerPage(categoryBanners, null));
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
    if (storeType == StoreType.household &&
        initialCategoryId == null &&
        searchOnly == false) {
      for (final category in landing.categories.where(
        (c) => c.productCount > 0,
      )) {
        when(
          () => catalogApi.fetchProducts(
            storeType: 'household',
            categoryId: category.id,
            query: '',
          ),
        ).thenAnswer(
          (_) async => CursorPage(
            items: catalogProducts ?? [_product('preview')],
            nextUrl: null,
          ),
        );
      }
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
          categoryBannersApiProvider.overrideWithValue(bannersApi),
          if (initialCategoryId != null) ...[
            catalogControllerProvider(storeType).overrideWith(
              () => CatalogController(
                storeType,
                initialCategoryId: initialCategoryId,
              ),
            ),
            categoryRecommendationsProvider(
              initialCategoryId,
            ).overrideWith((ref) async => categoryRecommendations),
          ],
          storeApiProvider.overrideWithValue(storeApi),
          cartApiProvider.overrideWithValue(cartApi),
          favoritesApiProvider.overrideWithValue(favoritesApi),
          recommendationsApiProvider.overrideWithValue(
            recommendationsApi ?? FakeRecommendationsApi(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
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
          home: Builder(
            builder: (_) {
              final screen = CatalogScreen(
                storeType: storeType,
                initialCategoryId: initialCategoryId,
                searchOnly:
                    searchOnly ??
                    ((storeType == StoreType.household ||
                            storeType == StoreType.restaurant) &&
                        initialCategoryId == null),
              );
              return withNavbar
                  ? Scaffold(
                      body: screen,
                      bottomNavigationBar: const SizedBox(height: 80),
                    )
                  : screen;
            },
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shashlik-family-lamb-jazz')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
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

  testWidgets('restaurant lenta keyingi kartani ko‘rsatadi va resize qiladi', (
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
      previewProducts: [
        CategoryProductPreview(
          id: '1',
          name: 'Sho‘rva',
          imageUrl: 'https://example.invalid/1.webp',
        ),
        CategoryProductPreview(
          id: '2',
          name: 'Mastava',
          imageUrl: 'https://example.invalid/2.webp',
        ),
        CategoryProductPreview(
          id: '3',
          name: 'Moshxo‘rda',
          imageUrl: 'https://example.invalid/3.webp',
        ),
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
      closeTo((328 * .82 + 12) / 328, .001),
    );

    await pumpAt(390);
    expect(
      tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .viewportFraction,
      closeTo((358 * .82 + 12) / 358, .001),
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

  testWidgets(
    'household root real category product ribbons replace category collages',
    (tester) async {
      final harness = await pumpCatalog(
        tester,
        ThemeMode.light,
        searchOnly: false,
      );

      expect(find.text('Xozmak'), findsOneWidget);
      expect(find.text('Asboblar'), findsNWidgets(2));
      expect(find.text('Bo‘sh kategoriya'), findsNothing);
      expect(find.byType(ProductCard), findsNothing);
      expect(
        find.byKey(const ValueKey('household-preview-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('household-category-card-category-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('household-search-entry')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('catalog-search-field')), findsNothing);
      verifyNever(
        () => harness.catalogApi.fetchProducts(storeType: 'household'),
      );
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(430, 850),
    const Size(800, 360),
  ]) {
    testWidgets('household root, cart and navbar fit 200% $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpCatalog(
        tester,
        ThemeMode.light,
        searchOnly: false,
        textScale: 2,
        withNavbar: true,
        cart: CartData(
          id: 'household-cart',
          storeTypeWire: 'household',
          items: [
            CartItem(
              id: 'line',
              product: _product('preview'),
              quantity: 1,
              selectedAddons: const [],
              note: '',
              subtotal: '50000',
            ),
          ],
          totalItems: 1,
          totalQuantity: 1,
          subtotal: '50000',
        ),
      );
      expect(
        find.byKey(const ValueKey('household-categories-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('household-categories-button')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('household-cart-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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

      expect(find.text('Restoran'), findsNothing);
      expect(find.text('Ofiyat'), findsOneWidget);
      expect(find.text('milliy taomlari'), findsOneWidget);
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

  for (final size in [
    const Size(320, 800),
    const Size(430, 850),
    const Size(800, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'restaurant category is a single food list $size scale=$scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          const name =
              'Qaynatma sho‘rva katta porsiya sabzavotlar va go‘sht bilan';
          await pumpCatalog(
            tester,
            ThemeMode.light,
            storeType: StoreType.restaurant,
            initialCategoryId: 'first-courses',
            landing: _restaurantLanding,
            textScale: scale,
            catalogProducts: [
              _product(
                'first',
                storeType: StoreType.restaurant,
                name: name,
                price: '125000',
              ),
              _product(
                'second',
                storeType: StoreType.restaurant,
                name: 'Ikkinchi taom',
              ),
            ],
          );
          expect(find.byType(SliverGrid), findsNothing);
          final first = find.byKey(const ValueKey('restaurant-product-first'));
          final firstRect = tester.getRect(first);
          final image = find.descendant(
            of: first,
            matching: find.byType(ProductImageView),
          );
          expect(tester.widget<ProductImageView>(image).fit, BoxFit.cover);
          final imageRect = tester.getRect(image);
          expect(imageRect.height, closeTo(imageRect.width * 9 / 16, .01));
          expect(tester.widget<Text>(find.text(name)).style!.fontSize, 16);
          expect(tester.widget<Text>(find.text(name)).maxLines, 2);
          expect(firstRect.width, lessThanOrEqualTo(680));
          expect(
            tester.getTopLeft(find.text(name)).dy,
            greaterThanOrEqualTo(imageRect.bottom),
          );
          final buy = find.byKey(const ValueKey('product-card-buy-first'));
          expect(tester.getSize(buy).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(buy).height, greaterThanOrEqualTo(48));
          expect(
            find.descendant(of: first, matching: find.byIcon(Icons.add)),
            findsOneWidget,
          );
          final scrollable = find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first;
          final offset = tester
              .state<ScrollableState>(scrollable)
              .position
              .pixels;
          final worldBottom = firstRect.bottom + offset;
          final second = find.byKey(
            const ValueKey('restaurant-product-second'),
          );
          await tester.scrollUntilVisible(second, 250, scrollable: scrollable);
          await tester.pumpAndSettle();
          final secondRect = tester.getRect(second);
          final newOffset = tester
              .state<ScrollableState>(scrollable)
              .position
              .pixels;
          expect(
            secondRect.top + newOffset,
            greaterThanOrEqualTo(worldBottom + 9),
          );
          expect(secondRect.left, closeTo(firstRect.left, .01));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
    expect(find.byKey(const ValueKey('catalog-search-field')), findsOneWidget);
    verify(
      () => harness.catalogApi.fetchProducts(
        storeType: 'household',
        categoryId: 'category-1',
        query: '',
      ),
    ).called(1);
  });

  testWidgets(
    'Xozmak category orders banner, search, recommendations then grid',
    (tester) async {
      final previousVisibilityInterval =
          VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval =
            previousVisibilityInterval,
      );
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ad = CategoryProductBanner.fromJson({
        'id': 'ad',
        'title': 'Hafta reklamasi',
        'subtitle': 'Sifatli asbob',
        'badge': 'Taklif',
        'product': {
          'id': 'ad-product',
          'name': 'Drel',
          'price': '120000',
          'store_type': 'household',
        },
      });
      await pumpCatalog(
        tester,
        ThemeMode.light,
        initialCategoryId: 'category-1',
        categoryBanners: [ad],
        categoryRecommendations: [_product('recommended')],
      );
      expect(find.byType(CategoryProductBanners), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Hafta reklamasi')).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('catalog-search-field')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('catalog-search-field')))
            .dy,
        lessThan(tester.getTopLeft(find.text('Sizga tavsiya etamiz')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Sizga tavsiya etamiz')).dy,
        lessThan(tester.getTopLeft(find.text('Kategoriya mahsulotlari')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'category search hides ads/recs, fallback has category label; clear restores',
    (tester) async {
      final previousVisibilityInterval =
          VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval =
            previousVisibilityInterval,
      );
      final ad = CategoryProductBanner.fromJson({
        'id': 'ad',
        'title': 'Hafta reklamasi',
        'product': {
          'id': 'ad-product',
          'price': '120000',
          'store_type': 'household',
        },
      });
      final harness = await pumpCatalog(
        tester,
        ThemeMode.light,
        initialCategoryId: 'category-1',
        categoryBanners: [ad],
        categoryRecommendations: [_product('recommended')],
      );
      when(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          categoryId: 'category-1',
          query: 'choynak',
        ),
      ).thenAnswer((_) async => const CursorPage(items: [], nextUrl: null));
      when(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          query: 'choynak',
        ),
      ).thenAnswer(
        (_) async => CursorPage(
          items: [
            ProductSummary.fromJson({
              'id': 'other',
              'name': 'Choynak',
              'price': '5000',
              'store_type': 'household',
              'category': {'id': 'kitchen', 'name': 'Oshxona'},
              'main_image': 'https://example.test/choynak.jpg',
            }),
          ],
          nextUrl: null,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('catalog-search-field')),
        'choynak',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductBanners), findsNothing);
      expect(find.text('Sizga tavsiya etamiz'), findsNothing);
      expect(find.text('Oshxona'), findsOneWidget);
      expect(find.text('Choynak'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CatalogScreen)),
      );
      await tester.tap(find.byTooltip(l10n.commonClose));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryProductBanners), findsOneWidget);
      expect(find.text('Sizga tavsiya etamiz'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'category keyboard retains focus while first character hides banner',
    (tester) async {
      final previousInterval =
          VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval =
            previousInterval,
      );
      final ad = CategoryProductBanner.fromJson({
        'id': 'ad',
        'title': 'Taklif',
        'product': {'id': 'ad-p', 'price': '2000', 'store_type': 'household'},
      });
      final harness = await pumpCatalog(
        tester,
        ThemeMode.light,
        initialCategoryId: 'category-1',
        categoryBanners: [ad],
      );
      when(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          categoryId: 'category-1',
          query: 'ustachilik',
        ),
      ).thenAnswer(
        (_) async => CursorPage(items: [_product('match')], nextUrl: null),
      );
      final finder = find.byKey(const ValueKey('catalog-search-field'));
      await tester.showKeyboard(finder);
      final originalFocus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      for (var i = 1; i <= 'ustachilik'.length; i++) {
        tester.testTextInput.enterText('ustachilik'.substring(0, i));
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).focusNode,
          same(originalFocus),
        );
        expect(originalFocus.hasFocus, isTrue);
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(finder).controller!.text, 'ustachilik');
      verify(
        () => harness.catalogApi.fetchProducts(
          storeType: 'household',
          categoryId: 'category-1',
          query: 'ustachilik',
        ),
      ).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in const [Size(320, 900), Size(800, 360)]) {
    testWidgets('full category page large text and scrolling $size', (
      tester,
    ) async {
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval,
      );
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ad = CategoryProductBanner.fromJson({
        'id': 'ad',
        'title': 'Uy ta’miri uchun maxsus qulay taklif',
        'subtitle': 'Qurilish va ustachilik uchun ishonchli mahsulotlar',
        'product': {
          'id': 'ad-product',
          'price': '120000',
          'store_type': 'household',
        },
      });
      await pumpCatalog(
        tester,
        ThemeMode.light,
        initialCategoryId: 'category-1',
        categoryBanners: [ad],
        categoryRecommendations: [_product('recommended')],
        textScale: 2,
      );
      for (var i = 0; i < 8; i++) {
        expect(tester.takeException(), isNull);
        await tester.dragFrom(
          Offset(5, size.height - 100),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
      expect(
        find.descendant(
          of: find.byType(ShashlikFamilyCard).first,
          matching: find.textContaining('200'),
        ),
        findsWidgets,
      );

      await tester.tap(find.byKey(const ValueKey('shashlik-section-charcoal')));
      await tester.pumpAndSettle();
      expect(find.byType(ShashlikProductRow), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('shashlik-section-kebabs')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shashlik-family-add-beef-jazz')),
      );
      // Allow the bottom sheet's entrance transition to finish.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('shashlik-selector-submit')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('shashlik-selector-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shashlik-selector-plus')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '3',
      );
      await tester.tap(
        find.byKey(const ValueKey('shashlik-selector-product-beef-kilo')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '1',
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'go‘sht katalogi oq fonda rasmli bo‘limlar va miqdor amali bilan chiqadi',
    (tester) async {
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
      expect(find.byType(MeatProductCard), findsWidgets);
      expect(find.text('Qo‘y go‘shti'), findsOneWidget);
      expect(find.byKey(const ValueKey('meat-add-lamb')), findsOneWidget);
      final picture = find.descendant(
        of: find.byKey(const ValueKey('meat-preview-lamb')),
        matching: find.byType(AspectRatio),
      );
      expect(tester.widget<AspectRatio>(picture.first).aspectRatio, 2);
      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .map(
            (provider) =>
                provider is ResizeImage ? provider.imageProvider : provider,
          )
          .whereType<AssetImage>()
          .map((provider) => provider.assetName);
      expect(assets, contains('assets/products/meat/lamb-meat.webp'));
      expect(tester.takeException(), isNull);
    },
  );

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

    final list = find.byKey(const PageStorageKey('meat-product-list'));
    final miniCart = find.byKey(const ValueKey('shashlik-go-to-cart'));
    expect(miniCart, findsOneWidget);
    expect(
      tester.getRect(list).bottom,
      lessThanOrEqualTo(tester.getRect(miniCart).top),
    );

    await tester.drag(list, const Offset(0, -3000));
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
    expect(find.text("Savatga o'tish"), findsOneWidget);
    expect(find.text('2 ta'), findsOneWidget);
    expect(find.text("30\u00a0000 so'm"), findsOneWidget);
  });

  testWidgets(
    'shashlik bar stays in all sections and never covers snackbar or products',
    (tester) async {
      final product = _product(
        'lamb',
        storeType: StoreType.shashlik,
        name: "Qo'y jazz",
        price: '21000',
      );
      await pumpCatalog(
        tester,
        ThemeMode.light,
        storeType: StoreType.shashlik,
        landing: _landingFor(StoreType.shashlik),
        catalogProducts: [
          product,
          _product('coal', storeType: StoreType.shashlik, name: 'Tosh ko‘mir'),
          for (var i = 0; i < 20; i++)
            _product(
              'other-$i',
              storeType: StoreType.shashlik,
              name: 'Boshqa $i',
            ),
        ],
        cart: CartData(
          id: 'cart',
          storeTypeWire: 'shashlik',
          items: [
            CartItem(
              id: 'line',
              product: product,
              quantity: 3,
              selectedAddons: const [],
              note: '',
              subtotal: '63000',
            ),
          ],
          totalItems: 1,
          totalQuantity: 3,
          subtotal: '63000',
        ),
      );
      final action = find.byKey(const ValueKey('shashlik-go-to-cart'));
      for (final section in ['charcoal', 'kebabs', 'other']) {
        await tester.tap(find.byKey(ValueKey('shashlik-section-$section')));
        await tester.pumpAndSettle();
        expect(action, findsOneWidget);
        expect(
          tester.widget<ShashlikCartBar>(find.byType(ShashlikCartBar)).subtotal,
          '63000',
        );
      }
      final list = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(list).position;
      position.jumpTo(300);
      await tester.pumpAndSettle();
      final context = tester.element(action);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added')));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(tester.getRect(action).top),
      );
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      final container = ProviderScope.containerOf(context, listen: false);
      final api = container.read(cartApiProvider);
      when(
        () => api.fetch('shashlik'),
      ).thenAnswer((_) async => CartData.empty('shashlik'));
      await container
          .read(cartControllerProvider(StoreType.shashlik).notifier)
          .refresh();
      await tester.pumpAndSettle();
      expect(action, findsNothing);
      expect(position.pixels, closeTo(300, .1));
      expect(tester.takeException(), isNull);
    },
  );
}
