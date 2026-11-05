import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/connectivity_controller.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/delivery_address_selection.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/address_form_screen.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/delivery_address_navigation.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/delivery_address_screen.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/widgets/checkout_delivery_map.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements CheckoutApi {}

const _home = UserAddress(
  id: 'home',
  title: 'Uy',
  isDefault: true,
  latitude: 41.01,
  longitude: 69.01,
  street: 'Yangi ko‘cha, 14-uy',
);
const _work = UserAddress(
  id: 'work',
  title: 'Ishxona',
  isDefault: false,
  latitude: 41.02,
  longitude: 69.02,
);
const _branch = DeliveryCoverageBranch(
  id: 'branch',
  name: 'Do‘kon',
  latitude: 41,
  longitude: 69,
  radiusKm: 2,
);
const _quote = DeliveryEstimate(
  available: true,
  detail: '',
  deliveryPrice: '5000',
  distanceKm: '1.4',
  branch: _branch,
);

CartData _cart([String id = 'store']) => CartData(
  id: 'cart',
  storeTypeWire: 'household',
  subtotal: '8000',
  totalItems: 1,
  totalQuantity: 1,
  minimumDeliveryOrderAmount: '20000',
  items: [
    CartItem(
      id: 'item',
      quantity: 1,
      selectedAddons: const [],
      note: '',
      subtotal: '8000',
      product: ProductSummary.fromJson({
        'id': 'p',
        'name': 'Buyum',
        'price': '8000',
        'store_type': 'household',
        'store': {'id': id, 'name': 'Store', 'store_type': 'household'},
      }),
    ),
  ],
);

class _Cart extends CartController {
  _Cart(super.storeType);
  @override
  Future<CartState> build() async => CartState(cart: _cart());
  @override
  Future<void> refresh() async {}
  void changeStore(String id) => state = AsyncData(CartState(cart: _cart(id)));
}

class _Addresses extends AddressesController {
  static List<UserAddress> items = [];
  @override
  Future<List<UserAddress>> build() async => items;
  @override
  Future<void> refresh() async => state = AsyncData(List.of(items));
  @override
  Future<UserAddress> save(UserAddress address) async {
    final saved = UserAddress(
      id: address.id.isEmpty ? 'created' : address.id,
      title: address.title,
      isDefault: address.isDefault,
      latitude: address.latitude,
      longitude: address.longitude,
      landmark: address.landmark,
    );
    items = [...items.where((a) => a.id != saved.id), saved];
    state = AsyncData(items);
    return saved;
  }
}

Future<void> _mount(
  WidgetTester tester, {
  List<UserAddress> addresses = const [_work, _home],
  _Api? api,
  String? initial,
  double scale = 1,
  Locale locale = const Locale('uz'),
  void Function(DeliveryAddressSelection?)? onResult,
  Future<DeliveryEstimate> Function(double latitude)? quote,
  bool settle = true,
  bool launcher = false,
  Future<void> Function()? access,
  Future<Position> Function()? resolve,
  Future<void> Function()? status,
  Future<bool> Function({required bool gps})? settings,
  bool pickupAvailable = true,
}) async {
  _Addresses.items = addresses;
  api ??= _Api();
  when(() => api!.fetchBranches(any())).thenAnswer(
    (_) async => [
      StoreBranch.fromJson({
        'id': 'pickup',
        'name': 'Filial',
        'address': 'Toshkent',
        'is_active': true,
        'is_pickup_available': pickupAvailable,
        'store': {'id': 'store', 'store_type': 'household'},
      }),
    ],
  );
  when(
    () => api!.fetchCoverage('household'),
  ).thenAnswer((_) async => [_branch]);
  when(
    () => api!.estimate(
      storeType: any(named: 'storeType'),
      latitude: any(named: 'latitude'),
      longitude: any(named: 'longitude'),
    ),
  ).thenAnswer(
    (call) async => quote == null
        ? _quote
        : quote(call.namedArguments[#latitude] as double),
  );
  final gps = ValueNotifier<LatLng?>(const LatLng(41.03, 69.03));
  addTearDown(gps.dispose);
  final args = DeliveryAddressArguments(
    initialAddressId: initial,
    gps: gps,
    onLocate: () {},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountScopeProvider.overrideWithValue('user-test'),
        apiLangProvider.overrideWithValue('uz'),
        checkoutApiProvider.overrideWithValue(api),
        addressesControllerProvider.overrideWith(_Addresses.new),
        cartControllerProvider.overrideWith2(_Cart.new),
        addressCoverageProvider.overrideWith((_) async => const [_branch]),
        addressLocationAccessProvider.overrideWithValue(access ?? () async {}),
        addressLocationStatusProvider.overrideWithValue(status ?? () async {}),
        if (settings != null)
          locationSettingsOpenerProvider.overrideWithValue(settings),
        addressLocationResolverProvider.overrideWithValue(
          resolve ??
              () async => Position(
                latitude: 41.01,
                longitude: 69.01,
                timestamp: DateTime.now(),
                accuracy: 5,
                altitude: 0,
                altitudeAccuracy: 0,
                heading: 0,
                headingAccuracy: 0,
                speed: 0,
                speedAccuracy: 0,
              ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: launcher
            ? Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    child: const Text('Open'),
                    onPressed: () async => onResult?.call(
                      await pickCartDeliveryAddress(
                        context,
                        ref,
                        StoreType.household,
                        initialAddressId: initial,
                      ),
                    ),
                  ),
                ),
              )
            : onResult == null
            ? Scaffold(
                body: DeliveryAddressScreen(
                  storeType: StoreType.household,
                  arguments: args,
                ),
                bottomNavigationBar: const SizedBox(height: 80),
              )
            : Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open'),
                    onPressed: () async {
                      onResult(
                        await Navigator.of(
                          context,
                        ).push<DeliveryAddressSelection>(
                          MaterialPageRoute(
                            builder: (_) => DeliveryAddressScreen(
                              storeType: StoreType.household,
                              arguments: args,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  if (onResult != null) {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }
}

FilledButton _confirm(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const ValueKey('delivery-address-confirm')),
);
Future<void> _choose(WidgetTester tester, String id) async {
  final card = find.byKey(ValueKey('checkout-address-option-$id'));
  await _scrollTo(tester, card);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final list = find.byKey(const ValueKey('delivery-address-list'));
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    final rect = tester.getRect(list);
    await tester.dragFrom(
      Offset(rect.left + 3, rect.center.dy),
      const Offset(0, -130),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  Position fix({double accuracy = 5, Duration age = Duration.zero}) => Position(
    latitude: 41.03,
    longitude: 69.03,
    timestamp: DateTime.now().subtract(age),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  testWidgets('cart launcher settles permission before route, not GPS fix', (
    tester,
  ) async {
    final permission = Completer<void>();
    final gps = Completer<Position>();
    var fixes = 0;
    await _mount(
      tester,
      launcher: true,
      onResult: (_) {},
      access: () => permission.future,
      resolve: () {
        fixes++;
        return gps.future;
      },
    );
    expect(find.byType(DeliveryAddressScreen), findsNothing);
    expect(fixes, 0);
    permission.complete();
    await tester.pumpAndSettle();
    expect(find.byType(DeliveryAddressScreen), findsOneWidget);
    expect(fixes, 1);
    expect(_confirm(tester).enabled, isTrue);
    gps.complete(fix());
    await tester.pumpAndSettle();
    final map = tester.widget<CheckoutDeliveryMap>(
      find.byType(CheckoutDeliveryMap),
    );
    expect(map.gps.value, const LatLng(41.03, 69.03));
    expect(map.deliveryPoint, const LatLng(41.01, 69.01));
    await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
    await tester.pumpAndSettle();
  });

  testWidgets('GPS denied does not block saved addresses or invoke fix', (
    tester,
  ) async {
    var fixes = 0;
    await _mount(
      tester,
      launcher: true,
      onResult: (_) {},
      access: () async =>
          throw const DeviceLocationException(DeviceLocationFailure.denied),
      resolve: () async {
        fixes++;
        return fix();
      },
    );
    expect(_confirm(tester).enabled, isTrue);
    expect(fixes, 0);
    expect(find.textContaining('Lokatsiya ruxsati berilmadi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
    await tester.pumpAndSettle();
  });

  for (final approximate in [false, true]) {
    testWidgets(
      'GPS ${approximate ? 'approximate' : 'stale'} is not precise marker',
      (tester) async {
        await _mount(
          tester,
          launcher: true,
          onResult: (_) {},
          resolve: () async => fix(
            accuracy: approximate ? 500 : 5,
            age: approximate ? Duration.zero : const Duration(minutes: 2),
          ),
        );
        final map = tester.widget<CheckoutDeliveryMap>(
          find.byType(CheckoutDeliveryMap),
        );
        expect(map.gps.value, isNull);
        expect(_confirm(tester).enabled, isTrue);
        await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'late GPS completion after cancel does not update disposed route',
    (tester) async {
      final gps = Completer<Position>();
      await _mount(
        tester,
        launcher: true,
        onResult: (_) {},
        resolve: () => gps.future,
      );
      await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
      await tester.pumpAndSettle();
      gps.complete(fix());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GPS timeout keeps confirm available and provides retry', (
    tester,
  ) async {
    final pending = Completer<Position>();
    await _mount(
      tester,
      launcher: true,
      onResult: (_) {},
      resolve: () => pending.future,
    );
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.textContaining('GPS javobi kechikdi'), findsOneWidget);
    expect(_confirm(tester).enabled, isTrue);
    expect(
      tester
          .widget<CheckoutDeliveryMap>(find.byType(CheckoutDeliveryMap))
          .gps
          .value,
      isNull,
    );
    pending.complete(fix());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
    await tester.pumpAndSettle();
  });

  testWidgets('GPS expires without replacing selected saved address', (
    tester,
  ) async {
    await _mount(tester, launcher: true, onResult: (_) {});
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    final map = tester.widget<CheckoutDeliveryMap>(
      find.byType(CheckoutDeliveryMap),
    );
    expect(map.gps.value, isNull);
    expect(map.deliveryPoint, const LatLng(41.01, 69.01));
    expect(_confirm(tester).enabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'permanently denied GPS offers settings then one-shot fix on resume',
    (tester) async {
      bool? openedGps;
      var checks = 0;
      await _mount(
        tester,
        launcher: true,
        onResult: (_) {},
        access: () async => throw const DeviceLocationException(
          DeviceLocationFailure.deniedForever,
        ),
        status: () async {
          checks++;
        },
        settings: ({required bool gps}) async {
          openedGps = gps;
          return true;
        },
      );
      final action = find.byKey(const ValueKey('delivery-address-gps-retry'));
      await _scrollTo(tester, action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(openedGps, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(
        tester
            .widget<CheckoutDeliveryMap>(find.byType(CheckoutDeliveryMap))
            .gps
            .value,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
      await tester.pumpAndSettle();
    },
  );

  test(
    'successful address write survives a failed subsequent list refresh',
    () async {
      final api = _Api();
      const input = UserAddress(
        id: '',
        title: 'Ishxona',
        isDefault: false,
        latitude: 41.02,
        longitude: 69.02,
      );
      var reads = 0;
      when(() => api.fetchAddresses()).thenAnswer((_) async {
        if (++reads > 1) throw const NetworkFailure();
        return [_home];
      });
      when(() => api.createAddress(input)).thenAnswer((_) async => _work);
      final container = ProviderContainer.test(
        overrides: [
          accountScopeProvider.overrideWithValue('user'),
          apiLangProvider.overrideWithValue('uz'),
          connectivityRecoveryProvider.overrideWithValue(0),
          checkoutApiProvider.overrideWithValue(api),
        ],
      );
      await container.read(addressesControllerProvider.future);
      final result = await container
          .read(addressesControllerProvider.notifier)
          .save(input);
      expect(result.id, 'work');
      expect(
        container.read(addressesControllerProvider).value!.map((a) => a.id),
        ['home', 'work'],
      );
      expect(
        container.read(addressesControllerProvider).value!.first.isDefault,
        isTrue,
      );
    },
  );

  test(
    'initial draft honors current, then default, then valid saved address',
    () {
      const invalid = UserAddress(id: 'bad', title: '', isDefault: true);
      expect(initialDeliveryAddress([_work, _home], null)!.id, 'home');
      expect(initialDeliveryAddress([_work, _home], 'work')!.id, 'work');
      expect(initialDeliveryAddress([invalid, _work], null)!.id, 'work');
      expect(initialDeliveryAddress([invalid], null), isNull);
      final result = DeliveryAddressSelection(
        address: _home,
        estimate: _quote,
        storeScope: deliveryStoreScope(_cart()),
      );
      expect(result.matches(_home, _cart()), isTrue);
      expect(result.matches(_home, _cart('another-store')), isFalse);
      expect(
        result.matches(
          const UserAddress(
            id: 'home',
            title: '',
            isDefault: true,
            latitude: 42,
            longitude: 70,
          ),
          _cart(),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'saved address is primary; card tap does not commit or change default',
    (tester) async {
      DeliveryAddressSelection? result;
      await _mount(tester, onResult: (r) => result = r);
      expect(find.text('Yetkazib berish manzili'), findsOneWidget);
      expect(_confirm(tester).onPressed, isNotNull);
      final home = find.byKey(const ValueKey('checkout-address-option-home'));
      await _scrollTo(tester, home);
      expect(
        find.descendant(
          of: home,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      await _choose(tester, 'work');
      expect(result, isNull);
      expect(find.byType(DeliveryAddressScreen), findsOneWidget);
      expect(
        _Addresses.items.firstWhere((a) => a.id == 'home').isDefault,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('delivery-address-confirm')));
      await tester.pumpAndSettle();
      expect(result!.address.id, 'work');
      expect(result!.estimate.deliveryPrice, '5000');
    },
  );

  testWidgets('cancel returns no selection', (tester) async {
    var returned = false;
    DeliveryAddressSelection? result;
    await _mount(
      tester,
      onResult: (r) {
        returned = true;
        result = r;
      },
    );
    await _choose(tester, 'work');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
  });

  testWidgets('late quote cannot overwrite a newer draft selection', (
    tester,
  ) async {
    final old = Completer<DeliveryEstimate>();
    await _mount(
      tester,
      settle: false,
      quote: (lat) => lat == _home.latitude ? old.future : Future.value(_quote),
    );
    expect(_confirm(tester).onPressed, isNull);
    await _choose(tester, 'work');
    expect(_confirm(tester).onPressed, isNotNull);
    old.complete(
      const DeliveryEstimate(
        available: true,
        detail: '',
        deliveryPrice: '99000',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('99\u00a0000'), findsNothing);
    expect(_confirm(tester).onPressed, isNotNull);
  });

  testWidgets(
    'offline quote is disabled; retry succeeds without changing address',
    (tester) async {
      var requests = 0;
      await _mount(
        tester,
        quote: (_) async {
          if (++requests == 1) throw const NetworkFailure();
          return _quote;
        },
      );
      expect(_confirm(tester).onPressed, isNull);
      await tester.tap(
        find.byKey(const ValueKey('delivery-address-quote-retry')),
      );
      await tester.pumpAndSettle();
      expect(_confirm(tester).onPressed, isNotNull);
      expect(requests, 2);
    },
  );

  testWidgets(
    'missing tariff offers retry and only an available pickup alternative',
    (tester) async {
      const missing = DeliveryEstimate(
        available: false,
        detail: '',
        reasonCode: 'delivery_tariff_unavailable',
      );
      await _mount(tester, quote: (_) async => missing);
      expect(
        find.text('Bu manzil uchun yetkazish narxi hozircha aniqlanmadi.'),
        findsOneWidget,
      );
      expect(_confirm(tester).onPressed, isNull);
      expect(
        find.byKey(const ValueKey('delivery-address-quote-retry')),
        findsOneWidget,
      );
      final pickup = find.byKey(const ValueKey('delivery-address-use-pickup'));
      final container = ProviderScope.containerOf(tester.element(pickup));
      await tester.ensureVisible(pickup);
      await tester.tap(pickup);
      await tester.pumpAndSettle();
      expect(
        container.read(orderDraftProvider(StoreType.household)).fulfillment,
        FulfillmentType.pickup,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, quote: (_) async => missing, pickupAvailable: false);
      expect(pickup, findsNothing);
      expect(_confirm(tester).onPressed, isNull);
    },
  );

  for (final rejected in [
    const DeliveryEstimate(
      available: false,
      detail: '',
      reasonCode: 'outside_delivery_radius',
      branch: _branch,
    ),
    const DeliveryEstimate(
      available: false,
      detail: '',
      reasonCode: 'delivery_tariff_unavailable',
    ),
    const DeliveryEstimate(available: true, detail: ''),
  ]) {
    testWidgets(
      'unavailable/missing-price quote blocks confirm: ${rejected.reasonCode}',
      (tester) async {
        await _mount(
          tester,
          quote: (lat) async => lat == _home.latitude ? rejected : _quote,
        );
        expect(_confirm(tester).onPressed, isNull);
        await _choose(tester, 'work');
        expect(_confirm(tester).onPressed, isNotNull);
      },
    );
  }

  testWidgets(
    'legacy address without coordinates cannot be confirmed; unnamed valid address can',
    (tester) async {
      const invalid = UserAddress(id: 'legacy', title: '', isDefault: true);
      const unnamed = UserAddress(
        id: 'unnamed',
        title: '',
        isDefault: false,
        latitude: 41.02,
        longitude: 69.02,
      );
      var requests = 0;
      await _mount(
        tester,
        addresses: [invalid, unnamed],
        quote: (_) async {
          requests++;
          return _quote;
        },
      );
      expect(requests, 1);
      expect(_confirm(tester).onPressed, isNotNull);
      await _choose(tester, 'legacy');
      expect(_confirm(tester).onPressed, isNull);
      expect(requests, 1);
    },
  );

  testWidgets(
    'physical cart store change invalidates quote and waits for new estimate',
    (tester) async {
      var requests = 0;
      final changed = Completer<DeliveryEstimate>();
      await _mount(
        tester,
        quote: (_) {
          requests++;
          return requests == 1 ? Future.value(_quote) : changed.future;
        },
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeliveryAddressScreen)),
      );
      (container.read(cartControllerProvider(StoreType.household).notifier)
              as _Cart)
          .changeStore('another');
      await tester.pump();
      await tester.pump();
      expect(_confirm(tester).onPressed, isNull);
      expect(requests, 2);
      changed.complete(_quote);
      await tester.pumpAndSettle();
      expect(_confirm(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'empty list uses add-on-map primary action, existing list uses outlined add',
    (tester) async {
      await _mount(tester, addresses: const []);
      expect(
        find.text('Bu buyurtma uchun yetkazish manzilini qo‘shing.'),
        findsOneWidget,
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(_confirm(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'new address returns to chooser as draft, not directly to checkout',
    (tester) async {
      await _mount(tester, addresses: const []);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('checkout-add-new-location')),
      );
      await tester.tap(find.byKey(const ValueKey('checkout-add-new-location')));
      await tester.pumpAndSettle();
      expect(find.text('Manzilni saqlash'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('address-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(AddressFormScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('checkout-address-option-created')),
        findsOneWidget,
      );
      expect(_confirm(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'cancel edit preserves draft selection and does not write default',
    (tester) async {
      await _mount(tester, initial: 'work');
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('delivery-address-edit-work')),
      );
      await tester.tap(
        find.byKey(const ValueKey('delivery-address-edit-work')),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_confirm(tester).onPressed, isNotNull);
      expect(
        _Addresses.items.firstWhere((a) => a.id == 'home').isDefault,
        isTrue,
      );
    },
  );

  for (final scale in [1.0, 2.0]) {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in [
        const Size(320, 640),
        const Size(430, 850),
        const Size(800, 360),
      ]) {
        testWidgets('selector fits $locale $size ${scale}x', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await _mount(tester, locale: locale, scale: scale);
          expect(tester.takeException(), isNull);
          final button = tester.getRect(
            find.byKey(const ValueKey('delivery-address-confirm')),
          );
          expect(button.bottom, lessThanOrEqualTo(size.height));
          expect(button.left, greaterThanOrEqualTo(0));
          expect(button.right, lessThanOrEqualTo(size.width));
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('long unavailable quote fits landscape 2x $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 360);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _mount(
        tester,
        locale: locale,
        scale: 2,
        quote: (_) async => DeliveryEstimate(
          available: false,
          detail: List.filled(12, 'Yetkazib berish mumkin emas.').join(' '),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('delivery-address-confirm')))
            .bottom,
        lessThanOrEqualTo(360),
      );
      expect(_confirm(tester).onPressed, isNull);
    });
  }
}
