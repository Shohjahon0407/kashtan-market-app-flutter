import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_colors.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/delivery_address_selection.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:beshkashtan_customer/features/payments/domain/payment_availability.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/review_draft.dart';

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
  Future<List<UserAddress>> build() async => const [_address];

  @override
  Future<void> refresh() async {}
}

const _address = UserAddress(
  id: 'address-1',
  title: 'Uy',
  latitude: 41.311081,
  longitude: 69.240562,
  isDefault: true,
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

/// Selection uses a green border, not the retired pale-green card fill.
BorderSide _cardBorder(WidgetTester tester, String key) {
  final material = tester.widget<Material>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Material),
      matchRoot: true,
    ),
  );
  final context = tester.element(find.byKey(ValueKey(key)));
  expect(material.color, Theme.of(context).colorScheme.surface);
  return (material.shape! as RoundedRectangleBorder).side;
}

late PrefsStore _reliabilityPrefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _reliabilityPrefs = await PrefsStore.load();
  });
  for (final enabled in [false, true]) {
    testWidgets('checkout payment options: Payme enabled=$enabled', (
      tester,
    ) async {
      final cartApi = _MockCartApi();
      final checkoutApi = _MockCheckoutApi();
      when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
      when(
        () => checkoutApi.fetchBranches('store-1'),
      ).thenAnswer((_) async => const []);
      when(
        () => checkoutApi.estimate(
          storeType: 'household',
          latitude: _address.latitude!,
          longitude: _address.longitude!,
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
            prefsStoreProvider.overrideWithValue(_reliabilityPrefs),
            if (enabled) paymeEnabledProvider.overrideWithValue(true),
            paymentCapabilitiesProvider.overrideWith(
              (_) async => {'household': enabled},
            ),
            cartApiProvider.overrideWithValue(cartApi),
            orderDraftProvider.overrideWith2(
              (type) => ReviewDraft(
                type,
                OrderDraftState(
                  paymentMethod: enabled
                      ? PaymentMethod.payme
                      : PaymentMethod.cash,
                  selection: DeliveryAddressSelection(
                    address: _address,
                    estimate: const DeliveryEstimate(
                      available: true,
                      detail: '',
                      deliveryPrice: '5000',
                    ),
                    storeScope: deliveryStoreScope(_cart),
                  ),
                ),
              ),
            ),
            checkoutApiProvider.overrideWithValue(checkoutApi),
            addressLocationAccessProvider.overrideWithValue(() async {
              throw const DeviceLocationException(DeviceLocationFailure.denied);
            }),
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

      // Delivery map adds height above payment; locate the lazy ListView child.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('checkout-payment-cash')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      if (!enabled) {
        expect(
          find.byKey(const ValueKey('checkout-payment-payme')),
          findsNothing,
        );
        expect(find.text('Payme'), findsNothing);
        expect(find.text('Kuryerga naqd'), findsOneWidget);
        expect(
          _cardBorder(tester, 'checkout-payment-cash').color,
          AppColors.primary,
        );
        expect(tester.takeException(), isNull);
        return;
      }

      // Ikkala variant ham ko'rinadi.
      expect(
        find.byKey(const ValueKey('checkout-payment-payme')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout-payment-cash')),
        findsOneWidget,
      );
      expect(find.text("To'lov turi"), findsOneWidget);
      expect(find.text('Payme'), findsOneWidget);
      // Yetkazib berish tanlangani uchun naqd yorlig'i kuryerga ishora qiladi.
      expect(find.text('Kuryerga naqd'), findsOneWidget);

      // Default — Payme: both cards keep the neutral surface.
      expect(
        _cardBorder(tester, 'checkout-payment-payme').color,
        AppColors.primary,
      );
      expect(_cardBorder(tester, 'checkout-payment-payme').width, 2);
      expect(
        _cardBorder(tester, 'checkout-payment-cash').color,
        isNot(AppColors.primary),
      );

      // Naqdga o'tish (bo'lim ro'yxat ichida — avval ko'rinadigan qilamiz).
      await tester.ensureVisible(
        find.byKey(const ValueKey('checkout-payment-cash')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-payment-cash')));
      await tester.pumpAndSettle();
      expect(
        _cardBorder(tester, 'checkout-payment-payme').color,
        isNot(AppColors.primary),
      );
      expect(
        _cardBorder(tester, 'checkout-payment-cash').color,
        AppColors.primary,
      );

      // Qayta Payme'ga qaytish.
      await tester.ensureVisible(
        find.byKey(const ValueKey('checkout-payment-payme')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-payment-payme')));
      await tester.pumpAndSettle();
      expect(
        _cardBorder(tester, 'checkout-payment-payme').color,
        AppColors.primary,
      );
    });
  }
}
