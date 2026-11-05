import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
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
  id: 'address-default',
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

/// Checkout StoreShell ichida (tashqi Scaffold + NavigationBar) ochiladi.
/// Xato snackbar'i "Buyurtma berish" tugmasini yopmasligi kerak — snackbar
/// checkout'ning o'z ScaffoldMessenger'ida, tugma USTIDA chiqadi.
late PrefsStore _reliabilityPrefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _reliabilityPrefs = await PrefsStore.load();
  });
  testWidgets('snackbar submit tugmasi ustida, uni yopmaydi', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          cartApiProvider.overrideWithValue(cartApi),
          orderDraftProvider.overrideWith2(
            (type) => ReviewDraft(
              type,
              OrderDraftState(
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
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // StoreShell'ning o'zi: tashqi Scaffold + pastki navbar.
          home: Scaffold(
            body: const CheckoutScreen(storeType: StoreType.household),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                NavigationDestination(icon: Icon(Icons.list), label: 'B'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CheckoutScreen)),
    );
    final submit = find.ancestor(
      of: find.text(l10n.checkoutSubmit),
      matching: find.byType(FilledButton),
    );
    expect(submit, findsOneWidget);

    // Ekran ichidagi (body) kontekstdan snackbar — xuddi _submit/_prepare kabi.
    final bodyContext = tester.element(
      find.byKey(const ValueKey('checkout-content')),
    );
    ScaffoldMessenger.of(bodyContext).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Xato'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    final snackRect = tester.getRect(find.byType(SnackBar));
    final submitRect = tester.getRect(submit);
    expect(
      snackRect.bottom,
      lessThanOrEqualTo(submitRect.top + 0.5),
      reason:
          'snackbar (${snackRect.bottom}) tugma ($submitRect) ustida bo\'lishi kerak',
    );
  });
}
