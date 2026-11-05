import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/restaurant_category_landing.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _products = [
  CategoryProductPreview(
    id: 'osh',
    name: 'To‘y oshi katta porsiya',
    imageUrl: 'https://example.invalid/osh.webp',
    price: '45000.00',
  ),
  CategoryProductPreview(
    id: 'manti',
    name: 'Manti',
    imageUrl: 'https://example.invalid/manti.webp',
    price: '32000.00',
  ),
];

ProductCategory _category({
  List<CategoryProductPreview> products = _products,
  List<String> legacy = const [],
}) => ProductCategory(
  id: 'test',
  name: '1-TAOMLAR',
  canonicalName: 'unknown category',
  storeTypeWire: 'restaurant',
  productCount: 2,
  previewProducts: products,
  previewImageUrls: legacy,
);

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  tearDown(
    () => VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    ProductCategory? category,
    double scale = 1,
    Locale locale = const Locale('uz'),
    bool accessible = false,
    bool reduced = false,
    void Function(ProductCategory)? onTap,
    void Function(ProductCategory, String)? onProductTap,
    ScrollController? scrollController,
    double trailingSpace = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            accessibleNavigation: accessible,
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const OfiyatBrandTitle(),
            toolbarHeight: 64 * scale,
            leading: const BackButton(),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
            ],
          ),
          body: CustomScrollView(
            controller: scrollController,
            slivers: [
              RestaurantCategoryLandingSliver(
                categories: [category ?? _category()],
                onCategoryTap: onTap ?? (_) {},
                onProductTap: onProductTap,
              ),
              if (trailingSpace > 0)
                SliverToBoxAdapter(child: SizedBox(height: trailingSpace)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
  }

  test('new preview is typed and independent of legacy photo order', () {
    final category = ProductCategory.fromJson({
      'id': '1',
      'name': 'Oshlar',
      'preview_images': ['/wrong.webp'],
      'preview_products': [
        {'id': 'p1', 'name': 'Osh', 'image': '/osh.webp', 'price': '45000.00'},
      ],
    });
    expect(category.previewProducts.single.name, 'Osh');
    expect(category.previewProducts.single.price, '45000.00');
    expect(category.previewProducts.single.imageUrl, endsWith('/osh.webp'));
    expect(ProductCategory.fromJson({}).previewProducts, isEmpty);
  });

  for (final locale in [
    const Locale('uz'),
    const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    const Locale('ru'),
  ]) {
    for (final size in [
      const Size(320, 800),
      const Size(430, 850),
      const Size(800, 360),
    ]) {
      testWidgets('brand/category/dish/price layout $locale $size 2x', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await pump(tester, scale: 2, locale: locale, reduced: true);
        expect(find.text('Ofiyat'), findsOneWidget);
        final title = tester.widget<Text>(find.text('Ofiyat'));
        expect(title.style!.color, ofiyatGreen);
        final heading = find.byKey(
          const ValueKey('restaurant-category-heading-test'),
        );
        final headingStyle = tester.widget<Text>(heading).style!;
        expect(headingStyle.fontFamily, 'RobotoCondensed');
        expect(headingStyle.fontSize, 24);
        expect(headingStyle.fontWeight, FontWeight.w900);
        final card = find.byKey(const ValueKey('photo-category-card-test'));
        expect(
          tester.getBottomLeft(heading).dy,
          lessThan(tester.getTopLeft(card).dy),
        );
        final name = find.text(_products[0].name);
        final price = find.text(Uzs.format(_products[0].price));
        final nameStyle = tester.widget<Text>(name).style!;
        final priceStyle = tester.widget<Text>(price).style!;
        expect(priceStyle.color, ofiyatGreen);
        expect(priceStyle.fontSize, nameStyle.fontSize);
        expect(priceStyle.fontWeight, nameStyle.fontWeight);
        final all = tester.widget<TextButton>(
          find.byKey(const ValueKey('restaurant-category-all-test')),
        );
        expect(
          all.style!.foregroundColor!.resolve({}),
          const Color(0xFF171717),
        );
        expect(
          all.style!.backgroundColor!.resolve({}),
          const Color(0xFFF5F5F4),
        );
        final controller = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        final image = find.byKey(
          ValueKey('restaurant-dish-image-test-${controller.page!.round()}'),
        );
        expect(
          tester.getTopLeft(name).dy,
          greaterThan(tester.getBottomLeft(image).dy),
        );
        expect(
          tester.getBottomRight(price).dy,
          lessThan(tester.getBottomRight(card).dy),
        );
        expect(
          tester.getBottomRight(name).dy,
          lessThan(tester.getTopLeft(price).dy),
        );
        expect(
          tester
              .widget<PageView>(find.byType(PageView))
              .controller!
              .viewportFraction,
          lessThan(1),
        );
        final imageRect = tester.getRect(image);
        expect(imageRect.width, lessThanOrEqualTo(380));
        expect(imageRect.height, closeTo(imageRect.width / 2, .01));
        final nextImage = tester.getRect(
          find.byKey(
            ValueKey(
              'restaurant-dish-image-test-${controller.page!.round() + 1}',
            ),
          ),
        );
        expect(nextImage.left, lessThan(tester.getRect(card).right));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('normal font cards are compact and retain dish name and price', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await pump(tester, reduced: true);
    final rect = tester.getRect(
      find.byKey(const ValueKey('photo-category-card-test')),
    );
    expect(rect.height, lessThan(230));
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    final imageRect = tester.getRect(
      find.byKey(
        ValueKey('restaurant-dish-image-test-${controller.page!.round()}'),
      ),
    );
    expect(imageRect.height, lessThan(145));
    expect(find.text(_products[0].name), findsOneWidget);
    expect(find.text(Uzs.format(_products[0].price)), findsOneWidget);
    expect(
      tester.getBottomRight(find.text(_products[0].name)).dy,
      lessThan(tester.getTopLeft(find.text(Uzs.format(_products[0].price))).dy),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'auto advance is 3s/600ms; manual swipe, background and covering route pause',
    (tester) async {
      await pump(tester);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      final initial = controller.page!;
      await tester.pump(const Duration(milliseconds: 2000));
      expect(controller.page, initial);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.page, greaterThan(initial));
      expect(controller.page, lessThan(initial + 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.page, initial + 1);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      final manuallySelected = controller.page!;
      await tester.pump(const Duration(milliseconds: 1500));
      expect(controller.page, manuallySelected);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      expect(controller.page, manuallySelected);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final context = tester.element(find.byType(PageView));
      final route = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered')),
      );
      unawaited(Navigator.of(context).push(route));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(controller.page, manuallySelected);
      Navigator.of(tester.element(find.text('Covered'))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offscreen carousel pauses and resumes with a fresh interval', (
    tester,
  ) async {
    await pump(tester);
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    final detector = tester.widget<VisibilityDetector>(
      find.byKey(const ValueKey('restaurant-category-visibility-test')),
    );
    final initial = controller.page!;
    detector.onVisibilityChanged!(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(400, 225),
        visibleBounds: Rect.zero,
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(controller.page, initial);
    detector.onVisibilityChanged!(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(400, 225),
        visibleBounds: const Rect.fromLTWH(0, 0, 400, 225),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2900));
    expect(controller.page, initial);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.page, initial + 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final a11y in [true, false]) {
    testWidgets('accessibility/reduced motion stops auto advance a11y=$a11y', (
      tester,
    ) async {
      await pump(tester, accessible: a11y, reduced: !a11y);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      final page = controller.page;
      await tester.pump(const Duration(seconds: 6));
      expect(controller.page, page);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('heading, all and dish open the category list', (tester) async {
    final taps = <String>[];
    await pump(tester, onTap: (category) => taps.add(category.id));
    await tester.tap(find.text('1-TAOMLAR'));
    await tester.tap(
      find.byKey(const ValueKey('restaurant-category-all-test')),
    );
    await tester.tap(find.text(_products[0].name));
    expect(taps, ['test', 'test', 'test']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'dish opens its own product; headings and legacy photos open category',
    (tester) async {
      final categories = <String>[];
      final products = <String>[];
      await pump(
        tester,
        onTap: (category) => categories.add(category.id),
        onProductTap: (category, id) => products.add('${category.id}/$id'),
      );
      await tester.tap(find.text(_products.first.name));
      expect(products, ['test/osh']);
      expect(categories, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('restaurant-category-all-test')),
      );
      expect(categories, ['test']);
      await pump(
        tester,
        category: _category(
          products: [],
          legacy: ['https://example.invalid/old.jpg'],
        ),
        onTap: (category) => categories.add(category.id),
        onProductTap: (category, id) => products.add('${category.id}/$id'),
      );
      await tester.tap(find.byKey(const ValueKey('restaurant-dish-test-0')));
      expect(categories, ['test', 'test']);
      expect(products, ['test/osh']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('category return and offscreen rebuild preserve both scrolls', (
    tester,
  ) async {
    final vertical = ScrollController();
    addTearDown(vertical.dispose);
    await pump(
      tester,
      reduced: true,
      scrollController: vertical,
      trailingSpace: 1500,
      onTap: (category) {
        unawaited(
          Navigator.of(tester.element(find.byType(PageView))).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Text('Category ${category.id}')),
            ),
          ),
        );
      },
    );
    vertical.jumpTo(100);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    final page = tester
        .widget<PageView>(find.byType(PageView))
        .controller!
        .page!;
    final selected = _products[page.round() % _products.length];
    await tester.tap(find.text(selected.name).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Category test'), findsOneWidget);
    Navigator.of(tester.element(find.text('Category test'))).pop();
    await tester.pumpAndSettle();
    expect(vertical.offset, 100);
    expect(
      tester.widget<PageView>(find.byType(PageView)).controller!.page,
      page,
    );
    vertical.jumpTo(1100);
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    vertical.jumpTo(100);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byType(PageView)).controller!.page,
      page,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('desktop mouse drag can move the restaurant carousel', (
    tester,
  ) async {
    await pump(tester, reduced: true);
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    final initial = controller.page!;
    await tester.drag(
      find.byType(PageView),
      const Offset(-600, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(controller.page, greaterThan(initial));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing price and empty category do not invent labels', (
    tester,
  ) async {
    await pump(
      tester,
      category: _category(
        products: const [
          CategoryProductPreview(
            id: 'unknown',
            name: 'Juda uzun taom nomi bir necha qatorga sig‘ishi kerak',
            imageUrl: 'https://example.invalid/missing.webp',
          ),
        ],
      ),
      scale: 2,
    );
    expect(find.text(Uzs.format('45000')), findsNothing);
    expect(tester.takeException(), isNull);
    await pump(
      tester,
      category: const ProductCategory(
        id: 'empty',
        name: 'Empty category',
        storeTypeWire: 'restaurant',
      ),
    );
    expect(find.text('Empty category'), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('single, empty and legacy previews do not invent metadata', (
    tester,
  ) async {
    var legacyCategoryTaps = 0;
    await pump(tester, category: _category(products: [_products[0]]));
    expect(find.byType(PageView), findsNothing);
    expect(find.text(Uzs.format('45000')), findsOneWidget);
    await pump(
      tester,
      category: _category(
        products: [],
        legacy: [
          'https://example.invalid/legacy.webp',
          'https://example.invalid/legacy-second.webp',
        ],
      ),
      onTap: (_) => legacyCategoryTaps++,
    );
    expect(find.byType(PageView), findsNothing);
    expect(find.text(_products[0].name), findsNothing);
    expect(find.text(Uzs.format('45000')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('restaurant-dish-image-test-0')),
    );
    expect(legacyCategoryTaps, 1);
    await pump(tester, category: _category(products: []));
    expect(find.byType(PageView), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
