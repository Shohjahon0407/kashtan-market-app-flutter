import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/address_form_screen.dart'
    show
        addressLocationResolverProvider,
        AddressLocationResolver,
        addressLocationAccessProvider;
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

const _coverageBranch = DeliveryCoverageBranch(
  id: 'branch',
  name: 'Filial',
  latitude: 41.31,
  longitude: 69.24,
  radiusKm: 8,
);

Future<void> _pumpCoverageCheckout(
  WidgetTester tester,
  _MockCheckoutApi api,
  AddressLocationResolver resolver, {
  LocationAccessResolver? access,
  LocationAccessResolver? passiveAccess,
  LocationSettingsOpener? settingsOpener,
  AddressesController Function()? addressesFactory,
  bool settle = true,
}) async {
  final cartApi = _MockCartApi();
  when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
  when(() => api.fetchBranches('store-1')).thenAnswer((_) async => []);
  when(
    () => api.fetchCoverage('household'),
  ).thenAnswer((_) async => [_coverageBranch]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountScopeProvider.overrideWithValue('user_test'),
        apiLangProvider.overrideWithValue('uz'),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(api),
        cartControllerProvider.overrideWith2(_TestCartController.new),
        addressesControllerProvider.overrideWith(
          addressesFactory ?? _SingleAddressController.new,
        ),
        addressLocationResolverProvider.overrideWithValue(resolver),
        addressLocationAccessProvider.overrideWithValue(access ?? () async {}),
        addressLocationStatusProvider.overrideWithValue(
          passiveAccess ?? access ?? () async {},
        ),
        if (settingsOpener != null)
          locationSettingsOpenerProvider.overrideWithValue(settingsOpener),
      ],
      child: const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: CheckoutScreen(storeType: StoreType.household),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

class _WaitingAddresses extends AddressesController {
  _WaitingAddresses(this.result);
  final Completer<List<UserAddress>> result;
  @override
  Future<List<UserAddress>> build() => result.future;
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
  testWidgets('GPS starts on checkout entry even while addresses are loading', (
    tester,
  ) async {
    final addresses = Completer<List<UserAddress>>();
    var requests = 0;
    await _pumpCoverageCheckout(
      tester,
      _MockCheckoutApi(),
      () async {
        requests++;
        return _position();
      },
      addressesFactory: () => _WaitingAddresses(addresses),
      settle: false,
    );
    expect(requests, 1);
    expect(find.byKey(const ValueKey('checkout-map-gps-pin')), findsOneWidget);
    expect(find.text('Yetkazish joylashuvini tanlang'), findsNothing);
    addresses.complete([_defaultAddress]);
    await tester.pumpAndSettle();
    expect(find.text('Yetkazish joylashuvini tanlang'), findsOneWidget);
    expect(requests, 1);
  });

  testWidgets('Quick Settings enabling GPS refreshes automatically on resume', (
    tester,
  ) async {
    var enabled = false;
    var requests = 0;
    Future<void> access() async {
      if (!enabled) {
        throw const DeviceLocationException(
          DeviceLocationFailure.serviceDisabled,
        );
      }
    }

    await _pumpCoverageCheckout(tester, _MockCheckoutApi(), () async {
      requests++;
      return _position();
    }, access: access);
    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.textContaining('GPS o‘chiq'), findsOneWidget);
    enabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byKey(const ValueKey('checkout-map-gps-pin')), findsOneWidget);
    expect(find.textContaining('GPS o‘chiq'), findsNothing);
    expect(find.text('Manzilni tanlang'), findsOneWidget);
  });

  testWidgets('resume with denied access never prompts again', (tester) async {
    var prompts = 0;
    var reads = 0;
    await _pumpCoverageCheckout(
      tester,
      _MockCheckoutApi(),
      () async => _position(),
      access: () async {
        prompts++;
        throw const DeviceLocationException(DeviceLocationFailure.denied);
      },
      passiveAccess: () async {
        reads++;
        throw const DeviceLocationException(DeviceLocationFailure.denied);
      },
    );
    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }
    expect(prompts, 1);
    expect(reads, greaterThanOrEqualTo(2));
    expect(find.text('Manzilni tanlang'), findsOneWidget);
  });
  testWidgets(
    'returning from settings retries once without selecting an address',
    (tester) async {
      var allowed = false;
      var requests = 0;
      var settings = 0;
      final api = _MockCheckoutApi();
      await _pumpCoverageCheckout(
        tester,
        api,
        () async {
          requests++;
          return _position();
        },
        access: () async {
          if (!allowed) {
            throw const DeviceLocationException(
              DeviceLocationFailure.deniedForever,
            );
          }
        },
        settingsOpener: ({required bool gps}) async {
          expect(gps, isFalse);
          settings++;
          allowed = true;
          return true;
        },
      );
      await tester.tap(find.byTooltip('Yopish'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('checkout-location-retry'))),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-location-retry')));
      await tester.pumpAndSettle();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(settings, 1);
      expect(requests, 1);
      expect(
        find.byKey(const ValueKey('checkout-map-gps-pin')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout-location-retry')),
        findsNothing,
      );
      expect(find.text('Manzilni tanlang'), findsOneWidget);
      verifyNever(
        () => api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );
    },
  );

  testWidgets(
    'a GPS point expires without background tracking or automatic refetch',
    (tester) async {
      var requests = 0;
      await _pumpCoverageCheckout(tester, _MockCheckoutApi(), () async {
        requests++;
        return _position();
      });
      await tester.tap(find.byTooltip('Yopish'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('checkout-map-gps-pin')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.byKey(const ValueKey('checkout-map-gps-pin')), findsNothing);
      expect(find.textContaining('GPS nuqtasi eskirgan'), findsOneWidget);
    },
  );
  testWidgets('permission finishes before chooser; GPS does not block it', (
    tester,
  ) async {
    final permission = Completer<void>();
    final fix = Completer<Position>();
    var requests = 0;
    final api = _MockCheckoutApi();
    await _pumpCoverageCheckout(tester, api, () {
      requests++;
      return fix.future;
    }, access: () => permission.future);
    expect(find.text('Yetkazish joylashuvini tanlang'), findsNothing);
    expect(requests, 0);
    permission.complete();
    await tester.pumpAndSettle();
    expect(find.text('Yetkazish joylashuvini tanlang'), findsOneWidget);
    expect(requests, 1);
    fix.complete(_position());
    await tester.pumpAndSettle();
    verifyNever(
      () => api.estimate(
        storeType: any(named: 'storeType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    );
    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();
    expect(find.text('Manzilni tanlang'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checkout-selected-address-address-default')),
      findsNothing,
    );
  });

  for (final reason in [
    DeviceLocationFailure.denied,
    DeviceLocationFailure.deniedForever,
    DeviceLocationFailure.serviceDisabled,
  ]) {
    testWidgets(
      '$reason still opens the manual chooser without requesting GPS',
      (tester) async {
        var requests = 0;
        await _pumpCoverageCheckout(
          tester,
          _MockCheckoutApi(),
          () async {
            requests++;
            return _position();
          },
          access: () async => throw DeviceLocationException(reason),
        );
        expect(requests, 0);
        expect(find.text('Yetkazish joylashuvini tanlang'), findsOneWidget);
        await tester.tap(find.byTooltip('Yopish'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('checkout-location-retry')),
          findsOneWidget,
        );
      },
    );
  }

  for (final reason in [
    DeviceLocationFailure.timeout,
    DeviceLocationFailure.stale,
  ]) {
    testWidgets('$reason keeps manual address available', (tester) async {
      await _pumpCoverageCheckout(
        tester,
        _MockCheckoutApi(),
        () async => throw DeviceLocationException(reason),
      );
      await tester.tap(find.byTooltip('Yopish'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('checkout-location-retry')),
        findsOneWidget,
      );
      expect(find.text('Manzilni tanlang'), findsOneWidget);
    });
  }

  testWidgets(
    'low accuracy is labelled approximate without selecting delivery',
    (tester) async {
      await _pumpCoverageCheckout(
        tester,
        _MockCheckoutApi(),
        () async => _position(accuracy: 1000),
      );
      await tester.tap(find.byTooltip('Yopish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Joylashuv taxminiy'), findsOneWidget);
      expect(find.text('Manzilni tanlang'), findsOneWidget);
    },
  );
  testWidgets(
    'GPS starts before chooser; permission failure keeps manual checkout',
    (tester) async {
      final api = _MockCheckoutApi();
      var requests = 0;
      await _pumpCoverageCheckout(
        tester,
        api,
        () async {
          requests++;
          throw StateError('location_permission_denied');
        },
        passiveAccess: () async {
          throw const DeviceLocationException(DeviceLocationFailure.denied);
        },
      );
      expect(requests, 1);
      await tester.tap(find.byTooltip('Yopish'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.textContaining('Lokatsiya ruxsati berilmadi'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout-choose-address')),
        findsOneWidget,
      );
      verifyNever(
        () => api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );
    },
  );

  testWidgets(
    'GPS does not choose address; authoritative radius blocks outside order',
    (tester) async {
      final api = _MockCheckoutApi();
      when(
        () => api.estimate(
          storeType: 'household',
          latitude: _defaultAddress.latitude!,
          longitude: _defaultAddress.longitude!,
        ),
      ).thenAnswer(
        (_) async => const DeliveryEstimate(
          available: false,
          detail: '',
          reasonCode: 'outside_delivery_radius',
          coverageRadiusKm: 9.55,
          branch: DeliveryCoverageBranch(
            id: 'server',
            name: 'Server filial',
            latitude: 41.1,
            longitude: 69.1,
            radiusKm: 9.55,
          ),
        ),
      );
      await _pumpCoverageCheckout(
        tester,
        api,
        () async => Position(
          latitude: 42,
          longitude: 70,
          timestamp: DateTime.now(),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('checkout-address-option-address-default')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yetkazish radiusi: 9.55 km'), findsOneWidget);
      expect(
        find.textContaining('9.55 km yetkazish radiusidan tashqarida'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout-selected-address-address-default')),
        findsOneWidget,
      );
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Buyurtmani tasdiqlash'),
      );
      expect(submit.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed checkout preparation shows retry, never empty-cart or submit',
    (tester) async {
      final cartApi = _MockCartApi();
      var fail = true;
      when(() => cartApi.mergeGuestCart()).thenAnswer((_) async {
        if (fail) throw const NetworkFailure('offline');
        return false;
      });
      final checkoutApi = _MockCheckoutApi();
      when(
        () => checkoutApi.fetchBranches('store-1'),
      ).thenAnswer((_) async => []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartApiProvider.overrideWithValue(cartApi),
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
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CheckoutScreen)),
      );
      expect(find.text(l10n.checkoutEmptyCart), findsNothing);
      expect(find.text(l10n.checkoutSubmit), findsNothing);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      fail = false;
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();
      expect(find.text('Yetkazish joylashuvini tanlang'), findsOneWidget);
    },
  );

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
          addressLocationAccessProvider.overrideWithValue(() async {
            throw const DeviceLocationException(DeviceLocationFailure.denied);
          }),
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

Position _position({double accuracy = 5}) => Position(
  latitude: 41.311,
  longitude: 69.24,
  timestamp: DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
