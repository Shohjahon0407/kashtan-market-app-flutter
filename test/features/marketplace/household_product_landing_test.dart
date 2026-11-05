import 'dart:async';

import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/household_category_previews.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/household_product_landing.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

ProductSummary _product(
  String id, {
  bool configured = false,
  bool available = true,
}) => ProductSummary.fromJson({
  'id': id,
  'name': 'Mahsulot $id',
  'price': '50000',
  'unit': 'dona',
  'store_type': 'household',
  'main_image': 'https://example.test/$id.jpg',
  'is_purchasable': available,
  'requires_configuration': configured,
});
const _categories = [
  ProductCategory(
    id: 'tools',
    name: 'Ustachilik asboblari',
    storeTypeWire: 'household',
    productCount: 8,
  ),
  ProductCategory(
    id: 'parts',
    name: 'Arra zapchastlari',
    storeTypeWire: 'household',
    productCount: 4,
  ),
];
final _items = {
  'tools': [
    _product('hammer'),
    _product('driver'),
    _product('pliers'),
    _product('wrench'),
    _product('saw'),
    _product('drill'),
  ],
  'parts': [_product('carburetor')],
};

class _Cart extends CartController {
  _Cart() : super(StoreType.household);
  final added = <String>[];
  @override
  Future<CartState> build() async =>
      CartState(cart: CartData.empty('household'));
  @override
  Future<bool> addProduct(
    ProductSummary product, {
    ProductVariant? variant,
    List<SelectedAddon> addons = const [],
    String note = '',
    int quantity = 1,
  }) async {
    added.add(product.id);
    state = AsyncData(
      CartState(
        cart: CartData(
          id: 'cart',
          storeTypeWire: 'household',
          items: [
            CartItem(
              id: 'line',
              product: product,
              quantity: quantity,
              selectedAddons: const [],
              note: '',
              subtotal: product.price,
            ),
          ],
          totalItems: 1,
          totalQuantity: quantity,
          subtotal: product.price,
        ),
      ),
    );
    return true;
  }
}

Future<({GoRouter router, _Cart cart, ScrollController scroll})> _open(
  WidgetTester tester, {
  List<ProductCategory> categories = _categories,
  Map<String, List<ProductSummary>>? items,
  Stream<List<ProductSummary>> Function(String)? load,
  bool reduced = true,
  bool accessible = false,
  Locale locale = const Locale('uz'),
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final cart = _Cart();
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  final router = GoRouter(
    initialLocation: '/landing',
    observers: [appRouteObserver],
    routes: [
      GoRoute(
        path: '/landing',
        builder: (context, _) => Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              HouseholdProductLandingSliver(
                categories: categories,
                onCategoryTap: (category) => context.push<void>(
                  Routes.storeCategoryProducts('household', category.id),
                ),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/store/household/catalog/category/:id',
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Category-${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/store/household/catalog/product/:id',
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Detail-${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider(StoreType.household).overrideWith(() => cart),
        householdCategoryPreviewsProvider.overrideWith(
          (ref, id) =>
              load?.call(id) ?? Stream.value((items ?? _items)[id] ?? []),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
            accessibleNavigation: accessible,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, cart: cart, scroll: scroll);
}

PageController _pages(WidgetTester tester) => tester
    .widget<PageView>(
      find.byKey(const PageStorageKey('household-category-tools')),
    )
    .controller!;

void main() {
  setUp(() {
    final previous = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(
      () => VisibilityDetectorController.instance.updateInterval = previous,
    );
  });

  testWidgets(
    'real products appear in horizontal rows with metadata below photos; no AI category tiles',
    (tester) async {
      await _open(tester);
      expect(find.byType(GridView), findsNothing);
      expect(find.text('Ustachilik asboblari'), findsOneWidget);
      expect(find.text('Arra zapchastlari'), findsOneWidget);
      final card = find.byKey(const ValueKey('household-preview-hammer'));
      final photo = find.descendant(
        of: card,
        matching: find.byType(AspectRatio),
      );
      expect(
        tester.widget<AspectRatio>(photo).aspectRatio,
        inInclusiveRange(1, 1.2),
      );
      expect(
        tester.getTopLeft(find.text('Mahsulot hammer')).dy,
        greaterThan(tester.getBottomRight(photo).dy),
      );
      expect(_pages(tester).viewportFraction, inExclusiveRange(.4, .46));
      final ribbonRect = tester.getRect(
        find.byKey(const PageStorageKey('household-category-tools')),
      );
      for (final id in ['hammer', 'driver']) {
        final rect = tester.getRect(
          find.byKey(ValueKey('household-preview-$id')),
        );
        expect(rect.left, greaterThanOrEqualTo(ribbonRect.left));
        expect(rect.right, lessThanOrEqualTo(ribbonRect.right));
      }
      final fourth = tester.getRect(
        find.byKey(const ValueKey('household-preview-pliers')),
      );
      expect(fourth.left, lessThan(ribbonRect.right));
      expect(fourth.right, greaterThan(ribbonRect.right));
      expect(find.byTooltip('Yonga suring'), findsNothing);
      final all = find.byKey(const ValueKey('household-category-all-tools'));
      expect(tester.getSize(all).width, lessThan(ribbonRect.width / 2));
      expect(tester.getBottomRight(all).dy, lessThanOrEqualTo(ribbonRect.top));
      final images = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        images.map((image) => image.imageUrl),
        contains('https://example.test/hammer.jpg'),
      );
      // Tall organizers and wide tools must both fit inside the photo area.
      for (final image in tester.widgetList<ProductImageView>(
        find.byType(ProductImageView),
      )) {
        expect(image.fit, BoxFit.contain);
      }
      for (final image in images) {
        expect(image.fit, BoxFit.contain);
      }
      expect(
        tester
            .widget<ProductImageView>(
              find.descendant(
                of: card,
                matching: find.byType(ProductImageView),
              ),
            )
            .disableFade,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all/title open unchanged category URLs; product opens existing detail and back preserves ribbon',
    (tester) async {
      final h = await _open(tester);
      await tester.tap(
        find.byKey(const ValueKey('household-category-all-tools')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Category-tools'), findsOneWidget);
      h.router.pop();
      await tester.pumpAndSettle();
      final pages = _pages(tester);
      await tester.drag(
        find.byKey(const PageStorageKey('household-category-tools')),
        const Offset(-115, 0),
      );
      await tester.pumpAndSettle();
      final index = pages.page!.round();
      expect(index, greaterThan(0));
      final id = _items['tools']![index].id;
      await tester.tap(find.byKey(ValueKey('household-preview-$id')));
      await tester.pumpAndSettle();
      expect(find.text('Detail-$id'), findsOneWidget);
      h.router.pop();
      await tester.pumpAndSettle();
      expect(_pages(tester), same(pages));
      expect(pages.page, closeTo(index.toDouble(), .01));
      await tester.tap(
        find.byKey(const ValueKey('household-category-title-tools')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Category-tools'), findsOneWidget);
    },
  );

  for (final width in [320.0, 430.0]) {
    testWidgets('two readable tiles and a next-card peek fit $width px', (
      tester,
    ) async {
      await _open(tester, size: Size(width, 900));
      final row = tester.getRect(
        find.byKey(const PageStorageKey('household-category-tools')),
      );
      for (final id in ['hammer', 'driver']) {
        final card = tester.getRect(
          find.byKey(ValueKey('household-preview-$id')),
        );
        expect(card.left, greaterThanOrEqualTo(row.left));
        expect(card.right, lessThanOrEqualTo(row.right));
      }
      final fourth = tester.getRect(
        find.byKey(const ValueKey('household-preview-pliers')),
      );
      expect(fourth.left, lessThan(row.right));
      expect(fourth.right, greaterThan(row.right));
      final add = find.byKey(const ValueKey('product-card-buy-hammer'));
      final first = tester.getRect(
        find.byKey(const ValueKey('household-preview-hammer')),
      );
      expect(tester.getSize(add), const Size(48, 48));
      final photo = find.descendant(
        of: find.byKey(const ValueKey('household-preview-hammer')),
        matching: find.byType(AspectRatio),
      );
      expect(tester.getRect(add).right, closeTo(first.right, 1));
      expect(
        tester.getRect(add).bottom,
        greaterThan(tester.getRect(photo).bottom),
      );
      final visual = find.byKey(
        const ValueKey('product-card-add-visual-hammer'),
      );
      expect(tester.getSize(visual), const Size(30, 30));
      expect(first.height, lessThan(260));
      final favorite = tester.getRect(
        find.byKey(const ValueKey('household-favorite-hammer')),
      );
      expect(favorite.overlaps(tester.getRect(add)), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'hardware ribbon never moves automatically even with motion enabled',
    (tester) async {
      await _open(tester, reduced: false);
      final initial = _pages(tester).page;
      await tester.pump(const Duration(seconds: 30));
      expect(_pages(tester).page, initial);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plus reuses simple cart add while configured product opens detail',
    (tester) async {
      final h = await _open(
        tester,
        items: {
          'tools': [_product('simple')],
          'parts': [_product('configured', configured: true)],
        },
      );
      await tester.tap(find.byKey(const ValueKey('product-card-buy-simple')));
      await tester.pumpAndSettle();
      expect(h.cart.added, ['simple']);
      expect(
        find.byKey(const ValueKey('product-card-stepper-simple')),
        findsOneWidget,
      );
      final configured = find.byKey(
        const ValueKey('product-card-buy-configured'),
      );
      await tester.ensureVisible(configured);
      await tester.pumpAndSettle();
      await tester.tap(configured);
      await tester.pumpAndSettle();
      expect(find.text('Detail-configured'), findsOneWidget);
      expect(h.cart.added, ['simple']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty preview has all-products action, errors retry only that category',
    (tester) async {
      final calls = <String, int>{};
      await _open(
        tester,
        load: (id) {
          calls[id] = (calls[id] ?? 0) + 1;
          if (id == 'tools' && calls[id] == 1) {
            return Stream.error(const NetworkFailure());
          }
          return Stream.value(id == 'tools' ? _items[id]! : []);
        },
      );
      expect(
        find.byKey(const ValueKey('household-category-all-parts')),
        findsOneWidget,
      );
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(calls['tools'], 2);
      expect(calls['parts'], 1);
      expect(find.text('Mahsulot hammer'), findsOneWidget);
    },
  );

  testWidgets(
    'rows load lazily instead of requesting the whole category tree',
    (tester) async {
      final loaded = <String>{};
      await _open(
        tester,
        categories: [
          for (var i = 0; i < 20; i++)
            ProductCategory(
              id: '$i',
              name: 'Category $i',
              storeTypeWire: 'household',
              productCount: 1,
            ),
        ],
        load: (id) {
          loaded.add(id);
          return Stream.value([_product('product-$id')]);
        },
      );
      expect(loaded.length, lessThan(20));
    },
  );

  testWidgets(
    'manual scroll survives covered and background states without restarting motion',
    (tester) async {
      final h = await _open(tester, reduced: false);
      final pages = _pages(tester);
      await tester.drag(
        find.byKey(const PageStorageKey('household-category-tools')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(pages.page, greaterThan(.5));
      unawaited(
        h.router.push<void>(Routes.storeCategoryProducts('household', 'tools')),
      );
      await tester.pumpAndSettle();
      final before = pages.page;
      await tester.pump(const Duration(seconds: 9));
      expect(pages.page, before);
      h.router.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 9));
      expect(pages.page, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(320, 640), Size(430, 850), Size(800, 360)]) {
      testWidgets(
        'household ribbons fit $locale $size at 200%, including populated cart',
        (tester) async {
          final h = await _open(tester, locale: locale, size: size, scale: 2);
          final add = find.byKey(const ValueKey('product-card-buy-hammer'));
          // Reveal vertically only. Scrollable.ensureVisible would also
          // align the button's x offset inside its horizontal PageView.
          final viewport = tester.getRect(find.byType(CustomScrollView));
          final offset =
              h.scroll.offset + tester.getCenter(add).dy - viewport.center.dy;
          h.scroll.jumpTo(offset.clamp(0.0, h.scroll.position.maxScrollExtent));
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('product-card-stepper-hammer')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
