import 'dart:async';

import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/back_navigation.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/shashlik_family_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_catalog.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_quantity_picker.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_variant_ribbon.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

ProductSummary food(
  String id,
  String name,
  String price, {
  bool configured = false,
}) => ProductSummary.fromJson({
  'id': id,
  'name': name,
  'price': price,
  'unit': id == 'kg' ? 'kg' : 'dona',
  'store_type': 'shashlik',
  'is_purchasable': true,
  'requires_configuration': configured,
});
final stick = food('stick', 'Mol jazz', '18000');
final kg = food('kg', 'Mol jazz kiloligi', '200000');

class _Catalog extends CatalogController {
  _Catalog(this.products) : super(StoreType.shashlik);
  final List<ProductSummary> products;
  @override
  Future<CatalogState> build() async => CatalogState(items: products);
}

class _Favorites extends FavoritesController {
  @override
  Future<FavoritesState> build() async => const FavoritesState(items: []);
}

class _Cart extends CartController {
  _Cart() : super(StoreType.shashlik);
  final calls = <(String, int)>[];
  Completer<bool>? pending;
  @override
  Future<CartState> build() async =>
      CartState(cart: CartData.empty('shashlik'));
  @override
  Future<bool> addProduct(
    ProductSummary product, {
    ProductVariant? variant,
    List<SelectedAddon> addons = const [],
    String note = '',
    int quantity = 1,
  }) async {
    calls.add((product.id, quantity));
    final success = await (pending?.future ?? Future.value(true));
    if (!success) {
      state = AsyncData(
        CartState(
          cart: CartData.empty('shashlik'),
          mutationFailure: const NetworkFailure(),
        ),
      );
    }
    return success;
  }
}

Future<GoRouter> _open(
  WidgetTester tester,
  _Cart cart, {
  String? initial,
  List<ProductSummary>? products,
  Size size = const Size(390, 844),
  Locale locale = const Locale('uz'),
  double scale = 1,
}) async {
  final items = products ?? [stick, kg];
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: Routes.shashlikFamily('beef-jazz', productId: initial),
    routes: [
      GoRoute(
        path: '/source',
        builder: (_, _) => const Scaffold(body: Text('Source page')),
      ),
      GoRoute(
        path: Routes.shashlikFamily('beef-jazz'),
        builder: (_, state) => ShashlikFamilyScreen(
          familyKey: 'beef-jazz',
          initialProductId: state.uri.queryParameters['product'],
        ),
      ),
      GoRoute(
        path: Routes.productDetail('shashlik', 'stick'),
        builder: (_, _) => const Scaffold(body: Text('Configuration')),
      ),
      GoRoute(
        path: Routes.storeCart('shashlik'),
        builder: (_, _) => const Scaffold(body: Text('Cart')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogControllerProvider.overrideWith2((_) => _Catalog(items)),
        cartControllerProvider.overrideWith2((_) => cart),
        favoritesControllerProvider.overrideWith(_Favorites.new),
        for (final item in items)
          productDetailProvider(item.id).overrideWith(
            (_) async => ProductDetail(
              product: item,
              images: const [],
              addonGroups: const [],
              relatedProducts: const [],
            ),
          ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder get total => find.byKey(const ValueKey('shashlik-family-total'));
Finder get submit => find.byKey(const ValueKey('shashlik-family-submit'));

void main() {
  testWidgets(
    'carousel replaces product URL, preserves page and returns to caller in one back',
    (tester) async {
      final router = await _open(tester, _Cart(), initial: 'stick');
      router.go('/source');
      await tester.pumpAndSettle();
      unawaited(
        router.push<void>(
          Routes.shashlikFamily('beef-jazz', productId: 'stick'),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller;
      await tester.tap(find.byKey(const ValueKey('shashlik-family-next')));
      await tester.pumpAndSettle();
      expect(
        Uri.parse(
          AppBackCoordinator.of(router).location,
        ).queryParameters['product'],
        'kg',
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller,
        same(controller),
      );
      unawaited(
        router.replace<void>(
          Routes.shashlikFamily('beef-jazz', productId: 'stick'),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller!.page, closeTo(0, .01));
      expect(tester.widget<Text>(total).data, contains('18'));
      await tester.tap(find.byKey(const ValueKey('shashlik-family-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('Source page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'family ribbon auto scroll respects motion and lifecycle: $reduced',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final interval = VisibilityDetectorController.instance.updateInterval;
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        addTearDown(
          () => VisibilityDetectorController.instance.updateInterval = interval,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('uz'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduced,
                accessibleNavigation: false,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: ShashlikVariantRibbon(
                family: ShashlikFamily(
                  key: ShashlikFamilyKey.beefJazz,
                  products: [stick, kg],
                ),
                onOpen: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        final controller = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 650));
        expect(controller.page, reduced ? closeTo(0, .01) : greaterThan(.5));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 9));
        expect(controller.page, reduced ? closeTo(0, .01) : greaterThan(.5));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'clicked kilogram opens that variant; carousel and per-product quantities stay in sync',
    (tester) async {
      final cart = _Cart();
      await _open(tester, cart, initial: 'kg');
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('shashlik-family-unit-price')),
            )
            .data,
        contains('200'),
      );
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(ShashlikQuantityPicker), findsNothing);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-selector-product-kg')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('shashlik-preset-3')),
      );
      await tester.tap(find.byKey(const ValueKey('shashlik-preset-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shashlik-selector-submit')));
      await tester.pumpAndSettle();
      expect(cart.calls, [('kg', 3)]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single product hides arrows and unknown link product safely selects first',
    (tester) async {
      await _open(tester, _Cart(), initial: 'missing', products: [stick]);
      expect(find.byKey(const ValueKey('shashlik-family-next')), findsNothing);
      expect(tester.widget<Text>(total).data, contains('18'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'required configuration uses existing product flow without unconfigured cart mutation',
    (tester) async {
      final cart = _Cart();
      await _open(
        tester,
        cart,
        products: [food('stick', 'Mol jazz', '18000', configured: true)],
      );
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Configuration'), findsOneWidget);
      expect(cart.calls, isEmpty);
    },
  );
  testWidgets(
    'detail delegates all quantities to the common sheet, preserving retry',
    (tester) async {
      final cart = _Cart()..pending = Completer<bool>();
      await _open(tester, cart);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('shashlik-selector-submit'));
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      cart.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-selector-error')),
        findsOneWidget,
      );
      cart.pending = null;
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(cart.calls, [('stick', 1), ('stick', 1)]);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in const [
    Locale('uz'),
    Locale('uz', 'Cyrl'),
    Locale('ru'),
  ]) {
    for (final size in const [Size(320, 700), Size(430, 850), Size(800, 360)]) {
      testWidgets('family page fits ${locale.toLanguageTag()} $size at 200%', (
        tester,
      ) async {
        final cart = _Cart();
        await _open(tester, cart, size: size, locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('shashlik-family-next')),
        );
        await tester.tap(find.byKey(const ValueKey('shashlik-family-next')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('shashlik-selector-submit'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(cart.calls, [('kg', 1)]);
      });
    }
  }
}
