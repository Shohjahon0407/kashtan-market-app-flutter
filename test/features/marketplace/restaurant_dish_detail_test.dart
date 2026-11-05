import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/routing/back_navigation.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_review_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/product_detail_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_recommendations_api.dart';

ProductSummary dish(String id, {bool category = true, bool longName = false}) =>
    ProductSummary.fromJson({
      'id': id,
      'name': longName
          ? 'Juda uzun nomli milliy taom katta oilaviy porsiya $id'
          : 'Taom $id',
      'price': '40000.00',
      'description': '',
      'unit_display': 'porsiya',
      'store_type': 'restaurant',
      'main_image': 'https://example.invalid/$id.jpg',
      if (category)
        'category': {'id': 'osh', 'name': 'Oshlar', 'store_type': 'restaurant'},
    });

ProductDetail detail(ProductSummary product, {bool addons = false}) =>
    ProductDetail(
      product: product,
      images: [
        ProductImage(
          id: 'extra-${product.id}',
          url: 'https://example.invalid/extra-${product.id}.jpg',
          isMain: false,
        ),
      ],
      addonGroups: addons
          ? const [
              AddonGroup(
                id: 'sauce',
                name: 'Sous',
                selectionType: 'single',
                isRequired: true,
                minSelect: 1,
                maxSelect: 1,
                options: [
                  AddonOption(
                    id: 'sauce-1',
                    name: 'Achchiq sous',
                    price: '5000.00',
                    isAvailable: true,
                  ),
                ],
              ),
            ]
          : const [],
      relatedProducts: const [],
    );

class _Catalog extends Fake implements CatalogApi {
  _Catalog(this.products) {
    for (final p in products) {
      details[p.id] = detail(p);
    }
  }
  final List<ProductSummary> products;
  final Map<String, ProductDetail> details = {};
  final Map<String, Completer<ProductDetail>> pending = {};
  final List<String?> cursors = [];
  final List<String?> categories = [];
  final List<String> detailCalls = [];
  final List<String> reviewCalls = [];
  int pageSize = 20;
  bool fail = false;
  ApiFailure categoryFailure = const NetworkFailure();
  Completer<void>? categoryGate;

  @override
  Future<ProductDetail> fetchDetail(String id) async {
    detailCalls.add(id);
    return pending[id]?.future ?? Future.value(details[id]!);
  }

  @override
  Future<CursorPage<ProductSummary>> fetchProducts({
    required String storeType,
    String? categoryId,
    String query = '',
    String? nextUrl,
  }) async {
    cursors.add(nextUrl);
    categories.add(categoryId);
    if (categoryGate != null) await categoryGate!.future;
    if (fail) throw categoryFailure;
    final start = nextUrl == null ? 0 : int.parse(nextUrl);
    final end = (start + pageSize).clamp(0, products.length);
    return CursorPage(
      items: products.sublist(start, end),
      nextUrl: end < products.length ? '$end' : null,
    );
  }

  @override
  Future<OffsetPage<ProductReview>> fetchReviews(String productId) async {
    reviewCalls.add(productId);
    return const OffsetPage(items: [], nextUrl: null, count: 0);
  }
}

class _Owner extends Notifier<String> {
  @override
  String build() => 'guest';
  void change(String owner) => state = owner;
}

final _ownerProvider = NotifierProvider<_Owner, String>(_Owner.new);

class _Cart extends Fake implements CartApi {
  _Cart(this.catalog);
  final _Catalog catalog;
  final List<CartItem> items = [];
  int adds = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<CartData> fetch(String storeType) async => CartData(
    id: 'cart',
    storeTypeWire: storeType,
    items: List.of(items),
    totalItems: items.length,
    totalQuantity: items.fold(0, (sum, line) => sum + line.quantity),
    subtotal: '0',
  );
  @override
  Future<void> addItem({
    required String storeType,
    required CartConfiguration configuration,
    required int quantity,
    String? idempotencyKey,
  }) async {
    adds++;
    if (gate != null) await gate!.future;
    if (fail) throw const ValidationFailure('Cannot add', {});
    final extra = configuration.addons.isEmpty ? 0 : 5000;
    items.add(
      CartItem(
        id: configuration.productId,
        product: catalog.details[configuration.productId]!.product,
        quantity: quantity,
        selectedAddons: configuration.addons,
        note: '',
        subtotal: '${(40000 + extra) * quantity}.00',
      ),
    );
  }

  @override
  Future<void> updateQuantity(String itemId, int quantity) async {
    final index = items.indexWhere((line) => line.id == itemId);
    final line = items[index];
    items[index] = line.copyWith(
      quantity: quantity,
      subtotal:
          '${(line.selectedAddons.isEmpty ? 40000 : 45000) * quantity}.00',
    );
  }

  @override
  Future<void> deleteItem(String itemId) async =>
      items.removeWhere((line) => line.id == itemId);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<GoRouter> _pumpDish(
  WidgetTester tester,
  _Catalog catalog, {
  String id = 'a',
  _Cart? cart,
  double scale = 1,
  Locale locale = const Locale('uz'),
  Size viewportSize = const Size(390, 900),
  String? entryCategory,
  bool dynamicOwner = false,
}) async {
  await tester.binding.setSurfaceSize(viewportSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final reflect = GoRouter.optionURLReflectsImperativeAPIs;
  GoRouter.optionURLReflectsImperativeAPIs = true;
  addTearDown(() => GoRouter.optionURLReflectsImperativeAPIs = reflect);
  final router = GoRouter(
    initialLocation: '/entry',
    routes: [
      GoRoute(
        path: '/entry',
        builder: (_, _) => const Scaffold(body: Text('Category destination')),
      ),
      GoRoute(
        path: Routes.storeCart('restaurant'),
        builder: (_, _) =>
            const Scaffold(body: Text('Restaurant cart destination')),
      ),
      GoRoute(
        path: '/store/restaurant/catalog/product/:productId',
        builder: (_, state) => ProductDetailScreen(
          storeType: StoreType.restaurant,
          productId: state.pathParameters['productId']!,
          categoryId: state.uri.queryParameters['category'],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        if (dynamicOwner)
          accountScopeProvider.overrideWith((ref) => ref.watch(_ownerProvider)),
        apiLangProvider.overrideWithValue(locale.languageCode),
        catalogApiProvider.overrideWithValue(catalog),
        cartApiProvider.overrideWithValue(cart ?? _Cart(catalog)),
        recommendationsApiProvider.overrideWithValue(FakeRecommendationsApi()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  final path = Routes.productDetail('restaurant', id);
  unawaited(
    router.push<void>(
      entryCategory == null
          ? path
          : Uri.parse(
              path,
            ).replace(queryParameters: {'category': entryCategory}).toString(),
    ),
  );
  await settle(tester);
  return router;
}

Finder get pager => find.byKey(const ValueKey('restaurant-detail-pager'));
Finder dishPrice(String id) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('dish-price-$id-'),
);
Future<void> swipe(WidgetTester tester, {bool previous = false}) async {
  final list = find.byType(Scrollable).first;
  if (pager.evaluate().isEmpty) {
    await tester.scrollUntilVisible(pager, 100, scrollable: list);
  }
  await tester.ensureVisible(pager);
  await tester.pump();
  final rect = tester.getRect(pager).intersect(tester.getRect(list));
  await tester.dragFrom(
    Offset(
      previous ? rect.left + rect.width * .15 : rect.left + rect.width * .85,
      rect.center.dy,
    ),
    Offset(rect.width * (previous ? .7 : -.7), 0),
  );
  await settle(tester);
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await settle(tester);
}

void main() {
  testWidgets('large left/right arrows navigate and stop at category edges', (
    tester,
  ) async {
    final catalog = _Catalog([dish('a'), dish('b'), dish('c')]);
    await _pumpDish(tester, catalog);
    Finder arrow(String direction) => find.descendant(
      of: find.byKey(ValueKey('dish-$direction-button')),
      matching: find.byType(IconButton),
    );
    final left = arrow('previous');
    final right = arrow('next');
    expect(tester.widget<IconButton>(left).onPressed, isNull);
    expect(tester.widget<IconButton>(right).onPressed, isNotNull);
    for (final control in [left, right]) {
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(52));
      expect(size.height, greaterThanOrEqualTo(52));
      final style = tester.widget<IconButton>(control).style!;
      expect(style.iconSize!.resolve({}), 36);
      expect(tester.widget<IconButton>(control).tooltip, isNotEmpty);
    }
    expect(tester.getCenter(left).dx, lessThan(80));
    expect(tester.getCenter(right).dx, greaterThan(310));
    await tester.tap(right);
    await settle(tester);
    expect(find.byKey(const ValueKey('dish-title-b')), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(tester.widget<IconButton>(left).onPressed, isNotNull);
    await tester.tap(right);
    await settle(tester);
    expect(find.byKey(const ValueKey('dish-title-c')), findsOneWidget);
    expect(tester.widget<IconButton>(right).onPressed, isNull);
    await tester.tap(left);
    await settle(tester);
    expect(find.byKey(const ValueKey('dish-title-b')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single dish does not show navigation arrows', (tester) async {
    await _pumpDish(tester, _Catalog([dish('a')]));
    expect(find.byKey(const ValueKey('dish-previous-button')), findsNothing);
    expect(find.byKey(const ValueKey('dish-next-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'nearby photos stay decoded across swipes without retaining the whole menu',
    (tester) async {
      final products = List.generate(16, (index) => dish('photo-$index'));
      final cache = PaintingBinding.instance.imageCache;
      final image = await tester.runAsync(() => createTestImage());
      final keys = <String, Object>{};
      for (final product in products) {
        final provider = ProductImageView.decodedProvider(
          product.imageUrl!,
          persistent: true,
        );
        final key = await provider.obtainKey(ImageConfiguration.empty);
        keys[product.id] = key;
        cache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image!.clone())),
          ),
        );
      }
      image!.dispose();
      addTearDown(() {
        cache.clear();
        cache.clearLiveImages();
      });
      final router = await _pumpDish(tester, _Catalog(products), id: 'photo-7');
      for (var index = 5; index <= 9; index++) {
        expect(cache.statusForKey(keys['photo-$index']!).live, isTrue);
      }
      expect(cache.statusForKey(keys['photo-0']!).live, isFalse);
      expect(cache.statusForKey(keys['photo-15']!).live, isFalse);
      final placeholders = find.descendant(
        of: pager,
        matching: find.byIcon(Icons.image_outlined),
      );
      expect(placeholders, findsNothing);
      await swipe(tester);
      expect(find.byKey(const ValueKey('dish-title-photo-8')), findsOneWidget);
      expect(placeholders, findsNothing);
      await swipe(tester, previous: true);
      expect(find.byKey(const ValueKey('dish-title-photo-7')), findsOneWidget);
      expect(placeholders, findsNothing);
      router.pop();
      await settle(tester);
      cache.clear();
      for (final key in keys.values) {
        expect(cache.statusForKey(key).live, isFalse);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo is near the top; dish name is below carousel and before price',
    (tester) async {
      final catalog = _Catalog([dish('a'), dish('b'), dish('c')]);
      await _pumpDish(tester, catalog, id: 'b');
      final image = tester.getRect(find.byKey(const ValueKey('dish-photo-b')));
      final toolbar = tester.getRect(find.byType(AppBar));
      final title = tester.getRect(find.byKey(const ValueKey('dish-title-b')));
      final price = tester.getRect(dishPrice('b'));
      expect(image.top - toolbar.bottom, closeTo(16, 1));
      expect(title.top, greaterThan(tester.getRect(pager).bottom));
      expect(title.bottom, lessThan(price.top));
      await swipe(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('dish-title-c'))).top,
        greaterThan(
          tester.getRect(find.byKey(const ValueKey('dish-photo-c'))).bottom,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dish page is pure white and only image cards have a soft glow', (
    tester,
  ) async {
    final catalog = _Catalog([dish('a'), dish('b'), dish('c')]);
    await _pumpDish(tester, catalog, id: 'b');
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.white);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(appBar.scrolledUnderElevation, 0);
    final background = tester.widget<Material>(
      find.byKey(const ValueKey('restaurant-detail-background')),
    );
    expect(background.color, Colors.white);
    expect(background.surfaceTintColor, Colors.transparent);
    expect(background.elevation, 0);
    for (final id in ['a', 'b', 'c']) {
      final glow = find.byKey(ValueKey('dish-glow-$id'));
      final decoration =
          tester.widget<DecoratedBox>(glow).decoration as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.boxShadow, isNotEmpty);
      final shadow = decoration.boxShadow!.single;
      expect(shadow.offset, Offset.zero);
      expect(shadow.blurRadius, greaterThanOrEqualTo(16));
      expect(shadow.spreadRadius, greaterThan(0));
      expect(
        tester.getRect(glow),
        tester.getRect(find.byKey(ValueKey('dish-photo-$id'))),
      );
    }
    final center = tester.getRect(find.byKey(const ValueKey('dish-photo-b')));
    expect(center.top - tester.getRect(pager).top, greaterThanOrEqualTo(16));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category and detail timeouts show only friendly text and retry still works',
    (tester) async {
      const raw =
          '[debug] connectionTimeout RequestOptions.connectTimeout '
          'https://private.example 00:00:08.000000 SocketException';
      final catalog = _Catalog([dish('a'), dish('b')])
        ..fail = true
        ..categoryFailure = const NetworkFailure.timeout(raw);
      final pending = Completer<ProductDetail>();
      catalog.pending['b'] = pending;
      await _pumpDish(tester, catalog);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProductDetailScreen)),
      );
      expect(find.text(l10n.errorNetworkSlow), findsOneWidget);
      void expectSafe() {
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .join(' ');
        expect(
          text,
          isNot(
            matches(
              RegExp(
                r'debug|connectionTimeout|RequestOptions|https?://|SocketException|server',
                caseSensitive: false,
              ),
            ),
          ),
        );
      }

      expectSafe();
      catalog.fail = false;
      await tester.ensureVisible(find.text(l10n.commonRetry));
      await tester.tap(find.text(l10n.commonRetry));
      await settle(tester);
      pending.completeError(const NetworkFailure.timeout(raw));
      await settle(tester);
      await swipe(tester);
      expect(find.text(l10n.errorNetworkSlow), findsOneWidget);
      expectSafe();
      final add = find.byKey(const ValueKey('product-detail-add-to-cart'));
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      catalog.pending.remove('b');
      await tester.ensureVisible(find.text(l10n.commonRetry));
      await tester.tap(find.text(l10n.commonRetry));
      await settle(tester);
      expect(find.text(l10n.errorNetworkSlow), findsNothing);
      expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
      expectSafe();
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'larger center and lower neighbors with wider peeks at $width',
      (tester) async {
        final catalog = _Catalog([dish('a'), dish('b'), dish('c')]);
        await _pumpDish(
          tester,
          catalog,
          id: 'b',
          viewportSize: Size(width, 900),
        );
        final bounds = tester.getRect(pager);
        final center = tester.getRect(
          find.byKey(const ValueKey('dish-photo-b')),
        );
        final previous = tester.getRect(
          find.byKey(const ValueKey('dish-photo-a')),
        );
        final next = tester.getRect(find.byKey(const ValueKey('dish-photo-c')));
        expect(center.width, greaterThan(width * .78 - 16));
        expect(center.height, greaterThan((width * .78 - 16) * .75));
        expect(center.width / center.height, closeTo(6 / 5, .01));
        expect(previous.top - center.top, closeTo(24, .5));
        expect(next.top - center.top, closeTo(24, .5));
        expect(previous.intersect(bounds).width, greaterThan(width * .05));
        expect(next.intersect(bounds).width, greaterThan(width * .05));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'carousel transforms follow drag and arrow transition lasts 600ms',
    (tester) async {
      final catalog = _Catalog([dish('a'), dish('b'), dish('c')]);
      await _pumpDish(tester, catalog, id: 'b');
      final image = find.byKey(const ValueKey('dish-photo-b'));
      final before = tester.getRect(image);
      final bounds = tester.getRect(pager);
      final touch = await tester.startGesture(
        Offset(bounds.right - 20, bounds.center.dy),
      );
      await touch.moveBy(const Offset(-20, 0));
      await tester.pump();
      await touch.moveBy(Offset(-bounds.width * .2, 0));
      await tester.pump();
      final moving = tester.getRect(image);
      expect(moving.width, lessThan(before.width));
      expect(moving.top, greaterThan(before.top));
      expect(moving.top - before.top, lessThan(24));
      await touch.cancel();
      await settle(tester);
      final controller = tester
          .widget<PageView>(
            find.descendant(of: pager, matching: find.byType(PageView)),
          )
          .controller!;
      controller.jumpToPage(1);
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.page, greaterThan(1));
      expect(controller.page, lessThan(2));
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(controller.page, closeTo(2, .01));
      expect(find.byKey(const ValueKey('dish-detail-loading')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide add becomes left outlined stepper and right cart button; zero restores add',
    (tester) async {
      final catalog = _Catalog([dish('a')]);
      final cart = _Cart(catalog);
      await _pumpDish(tester, catalog, cart: cart);
      final go = find.byKey(const ValueKey('product-detail-go-to-cart'));
      final add = find.byKey(const ValueKey('product-detail-add-to-cart'));
      final total = dishPrice('a');
      expect(go, findsNothing);
      expect(tester.widget<FilledButton>(add).child, isA<Text>());
      expect(tester.getSize(add).width, closeTo(390 - 32, 1));
      expect(find.byIcon(Icons.add), findsNothing);
      await tester.tap(add);
      await settle(tester);
      expect(go, findsOneWidget);
      final quantity = find.byKey(const ValueKey('restaurant-dish-quantity'));
      expect(tester.getRect(quantity).right, lessThan(tester.getRect(go).left));
      expect(tester.getSize(quantity).height, greaterThanOrEqualTo(52));
      expect(
        tester.widget<FilledButton>(go).style!.backgroundColor!.resolve({}),
        const Color(0xFFCFE8DA),
      );
      expect(
        tester.widget<FilledButton>(go).style!.foregroundColor!.resolve({}),
        const Color(0xFF2E443A),
      );
      expect(tester.widget<Text>(total).data, contains('40\u00a0000'));
      await tester.tap(find.byIcon(Icons.add).last);
      await settle(tester);
      expect(cart.items.single.subtotal, '80000.00');
      expect(tester.widget<Text>(total).data, contains('40\u00a0000'));
      await tester.tap(find.byIcon(Icons.remove));
      await settle(tester);
      expect(tester.widget<Text>(total).data, contains('40\u00a0000'));
      await tester.tap(find.byIcon(Icons.remove));
      await settle(tester);
      expect(go, findsNothing);
      expect(add, findsOneWidget);
      await tester.tap(add);
      await settle(tester);
      await tester.tap(go);
      await settle(tester);
      expect(find.text('Restaurant cart destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'warm swipes reuse detail/reviews and keep the same page without loading',
    (tester) async {
      final catalog = _Catalog([dish('a'), dish('b'), dish('c')]);
      await _pumpDish(tester, catalog);
      expect(catalog.detailCalls, containsAll(['a', 'b']));
      final page = tester.element(pager);
      for (final previous in [false, false, true, true, false, true]) {
        await swipe(tester, previous: previous);
        expect(tester.element(pager), same(page));
        expect(find.byKey(const ValueKey('dish-detail-loading')), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }
      for (final id in ['a', 'b', 'c']) {
        expect(catalog.detailCalls.where((value) => value == id), hasLength(1));
        expect(
          catalog.reviewCalls.where((value) => value == id).length,
          lessThanOrEqualTo(1),
        );
      }
      expect(catalog.cursors, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slow prefetched dish preserves price/footer and shares one request',
    (tester) async {
      final catalog = _Catalog([dish('a'), dish('b')]);
      final waiting = Completer<ProductDetail>();
      catalog.pending['b'] = waiting;
      await _pumpDish(tester, catalog);
      expect(catalog.detailCalls.where((id) => id == 'b'), hasLength(1));
      final add = find.byKey(const ValueKey('product-detail-add-to-cart'));
      final before = tester.getRect(add);
      await swipe(tester);
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      expect(tester.getRect(add), before);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<Text>(dishPrice('b')).data, contains('40\u00a0000'));
      expect(catalog.detailCalls.where((id) => id == 'b'), hasLength(1));
      waiting.complete(catalog.details['b']!);
      await settle(tester);
      expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
      await swipe(tester, previous: true);
      await swipe(tester);
      expect(find.byKey(const ValueKey('dish-detail-loading')), findsNothing);
      expect(catalog.detailCalls.where((id) => id == 'b'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change clears route cache and discards old in-flight responses',
    (tester) async {
      final catalog = _Catalog([dish('a'), dish('b')]);
      final old = Completer<ProductDetail>();
      final fresh = Completer<ProductDetail>();
      catalog.pending['b'] = old;
      await _pumpDish(tester, catalog, dynamicOwner: true);
      catalog.pending['b'] = fresh;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProductDetailScreen)),
      );
      container.read(_ownerProvider.notifier).change('user_other');
      await settle(tester);
      expect(catalog.detailCalls.where((id) => id == 'a'), hasLength(2));
      old.complete(catalog.details['b']!);
      await settle(tester);
      await swipe(tester);
      final add = find.byKey(const ValueKey('product-detail-add-to-cart'));
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      fresh.complete(catalog.details['b']!);
      await settle(tester);
      expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
      expect(catalog.detailCalls.where((id) => id == 'b'), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swipe keeps route/draft, restores photo, back pops once, no autoplay',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final catalog = _Catalog([dish('a'), dish('b'), dish('c')]);
      final router = await _pumpDish(tester, catalog, id: 'b');
      expect(find.byKey(const ValueKey('dish-title-b')), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dish-thumbnail-1')));
      await settle(tester);
      expect(
        tester
            .widget<ProductImageView>(
              find.byKey(const ValueKey('dish-photo-b')),
            )
            .imageUrl,
        contains('extra-b'),
      );
      await swipe(tester);
      expect(
        find.byKey(const ValueKey('dish-title-c')),
        findsOneWidget,
        reason:
            'uri=${router.routeInformationProvider.value.uri}; calls=${catalog.detailCalls}; '
            'texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
      );
      expect(AppBackCoordinator.of(router).location, endsWith('/product/c'));
      expect(
        router.routeInformationProvider.value.uri.path,
        endsWith('/product/c'),
      );
      await tester.pump(const Duration(seconds: 8));
      expect(find.byKey(const ValueKey('dish-title-c')), findsOneWidget);
      await swipe(tester, previous: true);
      expect(find.byKey(const ValueKey('dish-title-b')), findsOneWidget);
      expect(
        tester
            .widget<ProductImageView>(
              find.byKey(const ValueKey('dish-photo-b')),
            )
            .imageUrl,
        contains('extra-b'),
      );
      router.pop();
      await settle(tester);
      expect(find.text('Category destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category load does not block detail; pagination goes beyond six',
    (tester) async {
      final catalog = _Catalog([for (var i = 0; i < 9; i++) dish('$i')])
        ..pageSize = 3;
      catalog.categoryGate = Completer<void>();
      await _pumpDish(tester, catalog, id: '5');
      expect(find.byKey(const ValueKey('dish-title-5')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-detail-add-to-cart')),
        findsOneWidget,
      );
      catalog.categoryGate!.complete();
      await settle(tester);
      expect(find.text('6 / 6'), findsOneWidget);
      await swipe(tester, previous: true);
      await swipe(tester);
      await swipe(tester);
      expect(find.byKey(const ValueKey('dish-title-6')), findsOneWidget);
      expect(catalog.cursors, contains('6'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'required addons, cart total, increment/decrement and draft isolation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final catalog = _Catalog([dish('a'), dish('b')]);
      catalog.details['a'] = detail(catalog.products.first, addons: true);
      final cart = _Cart(catalog);
      await _pumpDish(tester, catalog, cart: cart);
      final add = find.byKey(const ValueKey('product-detail-add-to-cart'));
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text('Achchiq sous'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Achchiq sous'));
      await settle(tester);
      expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
      await tester.tap(add);
      await settle(tester);
      expect(cart.adds, 1);
      expect(cart.items.single.selectedAddons.single.id, 'sauce-1');
      expect(tester.widget<Text>(dishPrice('a')).data, contains('45\u00a0000'));
      await tester.tap(find.byIcon(Icons.add).last);
      await settle(tester);
      expect(cart.items.single.quantity, 2);
      expect(tester.widget<Text>(dishPrice('a')).data, contains('45\u00a0000'));
      expect(cart.items.single.subtotal, '90000.00');
      await tester.tap(find.byIcon(Icons.remove));
      await settle(tester);
      expect(cart.items.single.quantity, 1);
      await swipe(tester);
      expect(tester.widget<Text>(dishPrice('b')).data, contains('40\u00a0000'));
      await swipe(tester, previous: true);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(tester.widget<Text>(dishPrice('a')).data, contains('45\u00a0000'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late detail cannot overwrite selection; failed category retry works',
    (tester) async {
      final catalog = _Catalog([dish('a'), dish('b'), dish('c')])..fail = true;
      catalog.pending['b'] = Completer<ProductDetail>();
      await _pumpDish(tester, catalog);
      expect(find.byKey(const ValueKey('dish-title-a')), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      catalog.fail = false;
      await tester.ensureVisible(find.text('Qayta urinish'));
      await tester.tap(find.text('Qayta urinish'));
      await settle(tester);
      await swipe(tester);
      expect(find.byKey(const ValueKey('dish-title-b')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('product-detail-add-to-cart')),
            )
            .onPressed,
        isNull,
      );
      await swipe(tester);
      expect(find.byKey(const ValueKey('dish-title-c')), findsOneWidget);
      catalog.pending['b']!.complete(catalog.details['b']!);
      await settle(tester);
      expect(find.byKey(const ValueKey('dish-title-c')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown category is static; failed cart mutation rolls back', (
    tester,
  ) async {
    final catalog = _Catalog([dish('a', category: false)]);
    final cart = _Cart(catalog)..fail = true;
    await _pumpDish(tester, catalog, cart: cart);
    expect(catalog.cursors, isEmpty);
    expect(find.text('1 / 1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('product-detail-add-to-cart')));
    await settle(tester);
    expect(cart.items, isEmpty);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(
      find.byKey(const ValueKey('product-detail-add-to-cart')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explicit parent category survives swipe and includes child dishes',
    (tester) async {
      final catalog = _Catalog([dish('a'), dish('b')]);
      final router = await _pumpDish(
        tester,
        catalog,
        entryCategory: 'parent-menu',
      );
      expect(catalog.categories, ['parent-menu']);
      await swipe(tester);
      expect(find.byKey(const ValueKey('dish-title-b')), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['category'],
        'parent-menu',
      );
      expect(catalog.categories, ['parent-menu']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending cart write disables controls and cannot duplicate add', (
    tester,
  ) async {
    final catalog = _Catalog([dish('a')]);
    final cart = _Cart(catalog)..gate = Completer<void>();
    await _pumpDish(tester, catalog, cart: cart);
    await tester.tap(find.byKey(const ValueKey('product-detail-add-to-cart')));
    await settle(tester);
    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      if (button.icon is Icon &&
          ((button.icon as Icon).icon == Icons.add ||
              (button.icon as Icon).icon == Icons.remove)) {
        expect(button.onPressed, isNull);
      }
    }
    expect(cart.adds, 1);
    cart.gate!.complete();
    await settle(tester);
    expect(cart.items.single.quantity, 1);
    expect(cart.adds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty category retains the requested dish without fake neighbors',
    (tester) async {
      final catalog = _Catalog([]);
      catalog.details['a'] = detail(dish('a'));
      await _pumpDish(tester, catalog);
      expect(find.byKey(const ValueKey('dish-title-a')), findsOneWidget);
      expect(find.text('1 / 1'), findsNothing);
      expect(
        find.byKey(const ValueKey('product-detail-add-to-cart')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('foreign store detail cannot expose a restaurant cart action', (
    tester,
  ) async {
    final catalog = _Catalog([]);
    catalog.details['a'] = detail(
      ProductSummary.fromJson({
        'id': 'a',
        'name': 'Wrong store',
        'store_type': 'household',
        'price': '40000',
      }),
    );
    await _pumpDish(tester, catalog);
    expect(
      find.byKey(const ValueKey('product-detail-add-to-cart')),
      findsNothing,
    );
    expect(catalog.cursors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [
    const Locale('uz'),
    const Locale('ru'),
    const Locale('uz', 'Cyrl'),
  ]) {
    for (final size in [
      const Size(320, 800),
      const Size(430, 900),
      const Size(800, 430),
    ]) {
      testWidgets('layout $locale $size at 200%', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final catalog = _Catalog([dish('a', longName: true), dish('b')]);
        await _pumpDish(
          tester,
          catalog,
          scale: 2,
          locale: locale,
          viewportSize: size,
        );
        expect(tester.takeException(), isNull);
        final button = find.byKey(const ValueKey('product-detail-add-to-cart'));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        await swipe(tester);
        final title = find.byKey(const ValueKey('dish-title-b'));
        if (title.evaluate().isEmpty) {
          // In landscape the photo is taller than the viewport; the name
          // deliberately lives below it and is reached by vertical scrolling.
          await tester.scrollUntilVisible(
            title,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await settle(tester);
        }
        expect(find.byKey(const ValueKey('dish-title-b')), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('product-detail-add-to-cart')),
        );
        await settle(tester);
        final go = find.byKey(const ValueKey('product-detail-go-to-cart'));
        expect(go, findsOneWidget);
        expect(tester.getSize(go).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
