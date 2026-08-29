import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCartApi extends Mock implements CartApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

class _TestCartController extends CartController {
  _TestCartController(super.storeType);

  @override
  Future<CartState> build() async => const CartState(cart: _cart);

  @override
  Future<void> refresh() async {}
}

class _TestAddressesController extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => const [
    _defaultAddress,
    _officeAddress,
  ];

  @override
  Future<void> refresh() async {}
}

class _SingleAddressController extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => const [_defaultAddress];

  @override
  Future<void> refresh() async {}
}

const _defaultAddress = UserAddress(
  id: 'address-default',
  title: 'Uy',
  latitude: 41.311081,
  longitude: 69.240562,
  isDefault: true,
);

const _officeAddress = UserAddress(
  id: 'address-office',
  title: 'Ofis',
  latitude: 41.320000,
  longitude: 69.250000,
  isDefault: false,
);

const _product = ProductSummary(
  id: 'product-1',
  name: 'Sovun',
  description: '',
  price: '12000',
  imageUrl: null,
  unit: 'dona',
  isPurchasable: true,
  storeTypeWire: 'household',
  store: ProductStore(
    id: 'store-1',
    name: 'Xozmak',
    storeTypeWire: 'household',
  ),
  variants: [],
);

const _cart = CartData(
  id: 'cart-1',
  storeTypeWire: 'household',
  items: [
    CartItem(
      id: 'item-1',
      product: _product,
      quantity: 1,
      selectedAddons: [],
      note: '',
      subtotal: '12000',
    ),
  ],
  totalItems: 1,
  totalQuantity: 1,
  subtotal: '12000',
);

void main() {
  testWidgets(
    'checkout eski defaultni avtomatik tanlamaydi va user tanlovini kutadi',
    (tester) async {
      final cartApi = _MockCartApi();
      final checkoutApi = _MockCheckoutApi();
      when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
      when(
        () => checkoutApi.fetchBranches('store-1'),
      ).thenAnswer((_) async => const []);
      when(
        () => checkoutApi.estimate(
          storeType: 'household',
          latitude: _officeAddress.latitude!,
          longitude: _officeAddress.longitude!,
        ),
      ).thenAnswer(
        (_) async => const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '5000',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartApiProvider.overrideWithValue(cartApi),
            checkoutApiProvider.overrideWithValue(checkoutApi),
            cartControllerProvider.overrideWith2(_TestCartController.new),
            addressesControllerProvider.overrideWith(
              _TestAddressesController.new,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('uz'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: CheckoutScreen(storeType: StoreType.household),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yetkazish joylashuvini tanlang'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('checkout-add-new-location')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout-address-option-address-default')),
        findsOneWidget,
      );
      verifyNever(
        () => checkoutApi.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('checkout-address-option-address-office')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('checkout-selected-address-address-office')),
        findsOneWidget,
      );
      verify(
        () => checkoutApi.estimate(
          storeType: 'household',
          latitude: _officeAddress.latitude!,
          longitude: _officeAddress.longitude!,
        ),
      ).called(1);

      await tester.tap(find.text('Olib ketish'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('checkout-selected-address-address-office')),
        findsNothing,
      );

      await tester.tap(find.text('Yetkazib berish'));
      await tester.pumpAndSettle();
      expect(find.text('Yetkazish joylashuvini tanlang'), findsOneWidget);
    },
  );

  testWidgets('tanlov oynasi yopilsa checkout manzilsiz qoladi', (
    tester,
  ) async {
    final cartApi = _MockCartApi();
    final checkoutApi = _MockCheckoutApi();
    when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
    when(
      () => checkoutApi.fetchBranches('store-1'),
    ).thenAnswer((_) async => const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartApiProvider.overrideWithValue(cartApi),
          checkoutApiProvider.overrideWithValue(checkoutApi),
          cartControllerProvider.overrideWith2(_TestCartController.new),
          addressesControllerProvider.overrideWith(
            _SingleAddressController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: CheckoutScreen(storeType: StoreType.household),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();

    expect(find.text('Manzilni tanlang'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checkout-choose-address')),
      findsOneWidget,
    );
    verifyNever(
      () => checkoutApi.estimate(
        storeType: any(named: 'storeType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    );
  });
}
