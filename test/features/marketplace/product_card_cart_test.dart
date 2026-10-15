import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_card.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorite_models.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorites_api.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCartApi extends Mock implements CartApi {}

class _MockFavoritesApi extends Mock implements FavoritesApi {}

final _product = ProductSummary.fromJson({
  'id': 'product-1',
  'name': 'Temir choynak',
  'description': '',
  'price': '15000.00',
  'old_price': '22000.00',
  'main_image': null,
  'image_count': 2,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'household',
  'variants': <Map<String, dynamic>>[],
});

final _restaurantProduct = ProductSummary.fromJson({
  'id': 'dish-1',
  'name': "Lag'mon uyg'ur",
  'description': '',
  'price': '35000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'restaurant',
  'variants': <Map<String, dynamic>>[],
});

CartData _cart(int quantity) => CartData(
  id: 'cart-1',
  storeTypeWire: 'household',
  items: quantity == 0
      ? const []
      : [
          CartItem(
            id: 'line-1',
            product: _product,
            quantity: quantity,
            selectedAddons: const [],
            note: '',
            subtotal: '${15000 * quantity}.00',
          ),
        ],
  totalItems: quantity == 0 ? 0 : 1,
  totalQuantity: quantity,
  subtotal: '${15000 * quantity}.00',
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CartConfiguration(productId: 'fallback-product'),
    );
  });

  Future<void> pumpCard(WidgetTester tester, {required CartApi cartApi}) async {
    final favoritesApi = _MockFavoritesApi();
    when(() => favoritesApi.fetch()).thenAnswer((_) async => <FavoriteEntry>[]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          cartApiProvider.overrideWithValue(cartApi),
          favoritesApiProvider.overrideWithValue(favoritesApi),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 310,
                child: ProductCard(
                  product: _product,
                  storeType: StoreType.household,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('oddiy restoran taomida plus bevosita savatga qo‘shadi', (
    tester,
  ) async {
    final cartApi = _MockCartApi();
    var quantity = 0;
    CartData restaurantCart() => CartData(
      id: 'restaurant-cart',
      storeTypeWire: 'restaurant',
      items: quantity == 0
          ? const []
          : [
              CartItem(
                id: 'dish-line-1',
                product: _restaurantProduct,
                quantity: quantity,
                selectedAddons: const [],
                note: '',
                subtotal: '${35000 * quantity}.00',
              ),
            ],
      totalItems: quantity == 0 ? 0 : 1,
      totalQuantity: quantity,
      subtotal: '${35000 * quantity}.00',
    );

    when(
      () => cartApi.fetch('restaurant'),
    ).thenAnswer((_) async => restaurantCart());
    when(
      () => cartApi.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async => quantity = 1);

    final favoritesApi = _MockFavoritesApi();
    when(() => favoritesApi.fetch()).thenAnswer((_) async => <FavoriteEntry>[]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          cartApiProvider.overrideWithValue(cartApi),
          favoritesApiProvider.overrideWithValue(favoritesApi),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 310,
                child: ProductCard(
                  product: _restaurantProduct,
                  storeType: StoreType.restaurant,
                  catalogStyle: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_restaurantProduct.requiresConfiguration, isFalse);
    await tester.tap(find.byKey(const ValueKey('product-card-buy-dish-1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    verify(
      () => cartApi.addItem(
        storeType: 'restaurant',
        configuration: any(named: 'configuration'),
        quantity: 1,
      ),
    ).called(1);
    expect(
      find.byKey(const ValueKey('product-card-stepper-dish-1')),
      findsOneWidget,
    );
  });

  testWidgets('Xarid qilish add, snackbar, stepper va delete oqimi ishlaydi', (
    tester,
  ) async {
    final cartApi = _MockCartApi();
    var quantity = 0;
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => _cart(quantity));
    when(
      () => cartApi.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((_) async => quantity = 1);
    when(() => cartApi.updateQuantity('line-1', any())).thenAnswer((
      call,
    ) async {
      quantity = call.positionalArguments[1] as int;
    });
    when(() => cartApi.deleteItem('line-1')).thenAnswer((_) async {
      quantity = 0;
    });

    await pumpCard(tester, cartApi: cartApi);

    expect(find.text('Xarid qilish'), findsOneWidget);
    expect(find.text('dona'), findsNothing);
    expect(
      find.byKey(const ValueKey('product-card-image-count-product-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('product-card-buy-product-1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text("Tovar savatga qo'shildi"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-card-stepper-product-1')),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);
    verify(
      () => cartApi.addItem(
        storeType: 'household',
        configuration: any(named: 'configuration'),
        quantity: 1,
      ),
    ).called(1);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('product-card-stepper-product-1')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('Xarid qilish'), findsOneWidget);
    verify(() => cartApi.deleteItem('line-1')).called(1);
  });

  testWidgets('add xatosida success snackbar va stepper chiqmaydi', (
    tester,
  ) async {
    final cartApi = _MockCartApi();
    when(() => cartApi.fetch('household')).thenAnswer((_) async => _cart(0));
    when(
      () => cartApi.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
      ),
    ).thenThrow(const ServerFailure('server yiqildi', 500));

    await pumpCard(tester, cartApi: cartApi);
    await tester.tap(find.byKey(const ValueKey('product-card-buy-product-1')));
    await tester.pumpAndSettle();

    expect(find.text("Tovar savatga qo'shildi"), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Xarid qilish'), findsOneWidget);
  });
}
