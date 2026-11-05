import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/product_detail_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/meat_product_card.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_catalog.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final beef = ProductSummary.fromJson({
  'id': 'beef',
  'name': "Mol go'shti",
  'price': '120000',
  'store_type': 'meat',
  'unit': 'kg',
  'unit_display': 'kilogram',
  'is_purchasable': true,
});

class _MeatCart extends CartController {
  _MeatCart({this.quantity = 0}) : super(StoreType.meat);
  final int quantity;
  final added = <int>[];
  final updated = <int>[];
  bool fail = false;
  @override
  Future<CartState> build() async => CartState(
    cart: CartData(
      id: 'meat',
      storeTypeWire: 'meat',
      subtotal: '${quantity * 120000}',
      totalItems: quantity > 0 ? 1 : 0,
      totalQuantity: quantity,
      items: quantity == 0
          ? []
          : [
              CartItem(
                id: 'line',
                product: beef,
                quantity: quantity,
                selectedAddons: const [],
                note: '',
                subtotal: '${quantity * 120000}',
              ),
            ],
    ),
  );
  @override
  Future<bool> addProduct(
    ProductSummary product, {
    ProductVariant? variant,
    List<SelectedAddon> addons = const [],
    String note = '',
    int quantity = 1,
  }) async {
    added.add(quantity);
    if (fail) {
      state = AsyncData(
        CartState(
          cart: state.value!.cart,
          mutationFailure: const NetworkFailure(),
        ),
      );
    }
    return !fail;
  }

  @override
  Future<bool> setQuantity(CartItem item, int quantity) async {
    updated.add(quantity);
    return true;
  }
}

Future<void> _open(
  WidgetTester tester,
  _MeatCart cart, {
  Size size = const Size(390, 800),
  double scale = 1,
  Locale locale = const Locale('uz'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider(StoreType.meat).overrideWith(() => cart),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMeatQuantityEditor(context, beef),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

final input = find.byKey(const ValueKey('shashlik-quantity-input'));
final save = find.byKey(const ValueKey('shashlik-selector-submit'));

Future<void> _detail(WidgetTester tester, _MeatCart cart) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final router = GoRouter(
    initialLocation: '/product',
    routes: [
      GoRoute(
        path: '/product',
        builder: (_, _) => const ProductDetailScreen(
          storeType: StoreType.meat,
          productId: 'beef',
        ),
      ),
      GoRoute(
        path: '/store/meat/cart',
        builder: (_, _) => const Scaffold(body: Text('Meat cart destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        cartControllerProvider(StoreType.meat).overrideWith(() => cart),
        productDetailProvider('beef').overrideWith(
          (_) async => ProductDetail(
            product: beef,
            images: const [],
            addonGroups: const [],
            relatedProducts: const [],
          ),
        ),
        productReviewsProvider('beef').overrideWith((_) async => []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'meat detail opens the same quantity sheet without automatic cart navigation',
    (tester) async {
      final cart = _MeatCart();
      await _detail(tester, cart);
      expect(find.text("Mol go'shti"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meat-detail-action')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(input);
      await tester.enterText(input, '7');
      await tester.pump();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(cart.added, [7]);
      expect(find.text('Meat cart destination'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('meat detail offers absolute edit and explicit cart navigation', (
    tester,
  ) async {
    final cart = _MeatCart(quantity: 2);
    await _detail(tester, cart);
    await tester.tap(find.byKey(const ValueKey('meat-edit-quantity')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(input);
    await tester.enterText(input, '5');
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(cart.updated, [5]);
    await tester.tap(find.byKey(const ValueKey('meat-detail-action')));
    await tester.pumpAndSettle();
    expect(find.text('Meat cart destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('meat kind ordering remains stable', () {
    ProductSummary food(String id, String name) =>
        ProductSummary.fromJson({'id': id, 'name': name, 'price': '1'});
    final products = [
      food('qazi', 'Qazi'),
      beef,
      food('lamb', "Qo'y go'shti"),
      food('cut', "Mol go'shti lahm"),
    ];
    expect(sortMeatProducts(products).map((p) => p.id), [
      'lamb',
      'beef',
      'cut',
      'qazi',
    ]);
  });

  testWidgets('meat uses kg presets and starts at one, not shashlik labels', (
    tester,
  ) async {
    final cart = _MeatCart();
    await _open(tester, cart);
    expect(tester.widget<TextField>(input).controller!.text, '1');
    expect(find.text('Zixlangan'), findsNothing);
    expect(find.byKey(const ValueKey('shashlik-preset-200')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('shashlik-preset-3')));
    await tester.pump();
    expect(find.textContaining('3 kilogram'), findsOneWidget);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(cart.added, [3]);
    expect(cart.updated, isEmpty);
  });

  testWidgets('meat 2 to 5 updates absolute total, never adds five', (
    tester,
  ) async {
    final cart = _MeatCart(quantity: 2);
    await _open(tester, cart);
    await tester.enterText(input, '5');
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(cart.updated, [5]);
    expect(cart.added, isEmpty);
  });

  testWidgets('unchanged meat amount performs no mutation', (tester) async {
    final cart = _MeatCart(quantity: 2);
    await _open(tester, cart);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(cart.updated, isEmpty);
    expect(cart.added, isEmpty);
  });

  testWidgets('invalid input blocks save and failed save retains draft', (
    tester,
  ) async {
    final cart = _MeatCart()..fail = true;
    await _open(tester, cart);
    await tester.enterText(input, '0');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(input, '7');
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, '7');
    expect(
      find.byKey(const ValueKey('shashlik-selector-error')),
      findsOneWidget,
    );
    cart.fail = false;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(cart.added, [7, 7]);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(320, 640), Size(430, 850), Size(800, 360)]) {
      testWidgets('meat quantity fits $locale $size at 200%', (tester) async {
        final cart = _MeatCart();
        await _open(tester, cart, locale: locale, size: size, scale: 2);
        await tester.ensureVisible(input);
        await tester.enterText(input, '37');
        await tester.pump();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(cart.added, [37]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
