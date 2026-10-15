import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/address_form_screen.dart'
    show addressLocationResolverProvider, addressLocationAccessProvider;
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/widgets/checkout_receipt_paper.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _CartApi extends Mock implements CartApi {}

class _CheckoutApi extends Mock implements CheckoutApi {}

class _Cart extends CartController {
  _Cart(super.storeType, [this.fixture]);
  final CartData? fixture;
  @override
  Future<CartState> build() async => CartState(
    cart:
        fixture ??
        CartData(
          id: 'cart',
          storeTypeWire: storeType.wire,
          subtotal: '180000',
          totalItems: 1,
          totalQuantity: 2,
          items: [
            CartItem(
              id: 'item',
              product: ProductSummary.fromJson({
                'id': 'food',
                'name': 'Osh',
                'price': '90000',
                'unit': 'dona',
                'store_type': storeType.wire,
                'store': {
                  'id': 'store',
                  'name': 'Store',
                  'store_type': storeType.wire,
                },
              }),
              quantity: 2,
              selectedAddons: const [],
              note: '',
              subtotal: '180000',
            ),
          ],
        ),
  );
  @override
  Future<void> refresh() async {}
}

class _Addresses extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => const [
    UserAddress(
      id: 'address',
      title: 'Uy',
      latitude: 41.311,
      longitude: 69.24,
      street: 'Toshkent sh., Yangi ko‘cha',
      isDefault: true,
    ),
  ];
  @override
  Future<void> refresh() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('uz'),
  double scale = 1,
  StoreType store = StoreType.restaurant,
  bool covered = true,
  CartData? cart,
  bool selectAddress = true,
}) async {
  final cartApi = _CartApi();
  final api = _CheckoutApi();
  when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
  when(() => api.fetchBranches('store')).thenAnswer(
    (_) async => [
      StoreBranch.fromJson({
        'id': 'pickup',
        'store': {'id': 'store', 'name': 'Store', 'store_type': store.wire},
        'name': 'Filial',
        'address': 'Toshkent',
        'is_active': true,
        'is_pickup_available': true,
      }),
    ],
  );
  when(() => api.fetchCoverage(store.wire)).thenAnswer(
    (_) async => const [
      DeliveryCoverageBranch(
        id: 'branch',
        name: 'Filial',
        latitude: 41.31,
        longitude: 69.24,
        radiusKm: 8,
      ),
    ],
  );
  when(
    () =>
        api.estimate(storeType: store.wire, latitude: 41.311, longitude: 69.24),
  ).thenAnswer(
    (_) async => DeliveryEstimate(
      available: covered,
      detail: '',
      reasonCode: covered ? '' : 'outside_delivery_radius',
      distanceKm: '0.4',
      deliveryPrice: '5000',
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiLangProvider.overrideWithValue(locale.languageCode),
        accountScopeProvider.overrideWithValue('user_test'),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(api),
        cartControllerProvider.overrideWith2((store) => _Cart(store, cart)),
        addressesControllerProvider.overrideWith(_Addresses.new),
        addressLocationAccessProvider.overrideWithValue(() async {}),
        addressLocationResolverProvider.overrideWithValue(
          () async => throw StateError('permission_denied'),
        ),
      ],
      child: MaterialApp(
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
        home: Scaffold(
          body: CheckoutScreen(storeType: store),
          bottomNavigationBar: const SizedBox(height: 64),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (selectAddress) {
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkout-address-option-address')),
    );
    await tester.tap(
      find.byKey(const ValueKey('checkout-address-option-address')),
    );
  } else {
    await tester.tap(
      find.byTooltip(
        AppLocalizations.of(
          tester.element(find.byType(CheckoutScreen)),
        ).commonClose,
      ),
    );
  }
  await tester.pumpAndSettle();
}

// The mini-map intentionally owns drags inside its bounds. A page gesture
// starts in the outer gutter, as a customer can do around the map card.
Future<void> _scrollTo(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  for (var attempt = 0; attempt < 60; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    final body = tester.getRect(find.byKey(const ValueKey('checkout-content')));
    await tester.dragFrom(
      Offset(body.left + 8, body.center.dy),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget, reason: key);
}

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'address call-to-action stands out and whole selected card edits $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, locale: locale, scale: 2, selectAddress: false);
        await _scrollTo(tester, 'checkout-choose-address');
        final action = find.byKey(const ValueKey('checkout-choose-address'));
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CheckoutScreen)),
        );
        final choose = tester.widget<FilledButton>(action);
        expect(choose.onPressed, isNotNull);
        expect(
          choose.style!.backgroundColor!.resolve({}),
          const Color(0xFF0B7C5C),
        );
        expect(find.text(l10n.checkoutAddressActionHint), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('checkout-submit')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('checkout-address-option-address')),
        );
        await tester.tap(
          find.byKey(const ValueKey('checkout-address-option-address')),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, 'checkout-selected-address-address');
        expect(find.text(l10n.commonEdit), findsOneWidget);
        expect(find.text(l10n.checkoutAddressActionHint), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('checkout-selected-address-address')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('checkout-address-option-address')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mini-map pans without changing address; wheel and outer drags scroll checkout',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester);
      final map = find.byType(FlutterMap);
      final controller = tester.widget<FlutterMap>(map).mapController!;
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('checkout-content')),
            matching: find.byType(Scrollable),
          )
          .first;
      final scroll = tester.state<ScrollableState>(scrollable).position;
      final initialOffset = scroll.pixels;
      final before = controller.camera.center;
      final mapRect = tester.getRect(map);
      await tester.dragFrom(
        mapRect.topLeft + Offset(mapRect.width / 3, 80),
        const Offset(65, 0),
      );
      await tester.pumpAndSettle();
      expect(
        controller.camera.center.longitude,
        isNot(closeTo(before.longitude, 1e-8)),
      );
      expect(scroll.pixels, initialOffset);
      expect(
        find.byKey(const ValueKey('checkout-selected-address-address')),
        findsOneWidget,
      );
      final panned = controller.camera.center;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: mapRect.center,
          scrollDelta: const Offset(0, 40),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(initialOffset));
      expect(controller.camera.center, panned);
      final offsetAfterWheel = scroll.pixels;
      final body = tester.getRect(
        find.byKey(const ValueKey('checkout-content')),
      );
      await tester.dragFrom(
        Offset(body.left + 8, body.center.dy),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(offsetAfterWheel));
      final api = ProviderScope.containerOf(
        tester.element(find.byType(CheckoutScreen)),
      ).read(checkoutApiProvider);
      verify(
        () => api.estimate(
          storeType: 'restaurant',
          latitude: 41.311,
          longitude: 69.24,
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'outside delivery has no fabricated total; pickup uses subtotal',
    (tester) async {
      await _pump(tester, covered: false);
      expect(find.byKey(const ValueKey('checkout-submit-total')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
            .onPressed,
        isNull,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CheckoutScreen)),
      );
      await tester.tap(find.text(l10n.checkoutPickup));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('checkout-delivery-map')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('checkout-submit-total')))
            .data,
        Uzs.format('180000'),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(430, 932),
    const Size(800, 360),
  ]) {
    for (final locale in [
      const Locale('uz'),
      const Locale('uz', 'Cyrl'),
      const Locale('ru'),
    ]) {
      testWidgets('checkout panels and fixed total fit $size $locale 2x', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
        final footer = find.byKey(const ValueKey('checkout-submit-total'));
        expect(tester.widget<Text>(footer).data, Uzs.format('185000'));
        final footerRect = tester.getRect(
          find.byKey(const ValueKey('checkout-submit')),
        );
        expect(footerRect.bottom, lessThanOrEqualTo(size.height - 64));
        for (final key in [
          'checkout-payment-panel',
          'checkout-note',
          'checkout-summary',
          'checkout-receipt',
        ]) {
          await _scrollTo(tester, key);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: key);
        }
        expect(find.text('Osh'), findsOneWidget);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CheckoutScreen)),
        );
        expect(find.text(l10n.shashlikPieceQuantity(2)), findsOneWidget);
      });
    }
  }

  testWidgets(
    'receipt shows configurations, units and server line prices last',
    (tester) async {
      final fixture = CartData(
        id: 'cart',
        storeTypeWire: 'restaurant',
        subtotal: '35000',
        totalItems: 2,
        totalQuantity: 5,
        items: [
          CartItem(
            id: 'kg-item',
            product: ProductSummary.fromJson({
              'id': 'beef',
              'name': 'Mol jazz kiloligi',
              'image': 'https://example.com/beef.jpg',
              'price': '10000',
              'unit': 'kg',
              'store': {'id': 'store', 'store_type': 'restaurant'},
            }),
            quantity: 2,
            selectedAddons: const [],
            note: '',
            subtotal: '20000',
          ),
          CartItem(
            id: 'variant-item',
            product: ProductSummary.fromJson({
              'id': 'food',
              'name': 'Taom',
              'price': '999999',
              'unit': 'kg',
              'store': {'id': 'store', 'store_type': 'restaurant'},
            }),
            quantity: 3,
            variant: ProductVariant.fromJson({
              'id': 'variant',
              'name': 'Kichik porsiya',
              'unit': 'dona',
              'price': '4000',
            }),
            selectedAddons: const [
              SelectedAddon(id: 'sauce', name: 'Sous', price: '1000'),
            ],
            note: 'Piyozsiz',
            subtotal: '15000',
          ),
        ],
      );
      await _pump(tester, cart: fixture);
      await _scrollTo(tester, 'checkout-receipt');
      await tester.pumpAndSettle();
      final receipt = find.byKey(const ValueKey('checkout-receipt'));
      expect(tester.widget<CheckoutReceiptPaper>(receipt), isNotNull);
      final paper = tester.widget<PhysicalShape>(
        find.descendant(of: receipt, matching: find.byType(PhysicalShape)),
      );
      expect(paper.clipper, isA<ReceiptPaperClipper>());
      expect(paper.color, const Color(0xFFEEF0F3));
      final photo = tester.widget<ProductImageView>(
        find.byKey(const ValueKey('checkout-receipt-image-kg-item')),
      );
      expect(photo.imageUrl, 'https://example.com/beef.jpg');
      expect(photo.memCacheWidth, 160);
      expect(
        find.descendant(of: receipt, matching: find.byType(ProductImageView)),
        findsNWidgets(2),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CheckoutScreen)),
      );
      expect(
        find.descendant(
          of: receipt,
          matching: find.text(l10n.checkoutReceiptTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: receipt, matching: find.text('Mol jazz kiloligi')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: receipt,
          matching: find.text(l10n.shashlikKilogramQuantity(2)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: receipt,
          matching: find.text(l10n.shashlikPieceQuantity(3)),
        ),
        findsOneWidget,
      );
      for (final text in [
        'Kichik porsiya',
        '+ Sous',
        'Piyozsiz',
        Uzs.format('20000'),
        Uzs.format('15000'),
        Uzs.format('35000'),
      ]) {
        expect(
          find.descendant(of: receipt, matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: receipt, matching: find.text(Uzs.format('999999'))),
        findsNothing,
      );
      final receiptRight = tester.getRect(receipt).right - 14;
      for (final price in ['20000', '15000', '35000']) {
        expect(
          tester
              .getRect(
                find.descendant(
                  of: receipt,
                  matching: find.text(Uzs.format(price)),
                ),
              )
              .right,
          closeTo(receiptRight, .5),
        );
      }
      final children =
          tester
                  .widget<ListView>(
                    find.byKey(const ValueKey('checkout-content')),
                  )
                  .childrenDelegate
              as SliverChildListDelegate;
      expect(
        find.descendant(
          of: find.byWidget(children.children.last),
          matching: receipt,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('help and quick notes keep manual text and toggle suggestions', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CheckoutScreen)),
    );
    await tester.tap(find.byKey(const ValueKey('checkout-help')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.checkoutHelpBody), findsOneWidget);
    await tester.tap(find.text(l10n.commonClose));
    await tester.pumpAndSettle();
    await _scrollTo(tester, 'checkout-note');
    final field = find.byKey(const ValueKey('checkout-note'));
    await tester.enterText(field, 'Eshik kodi 124');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(FilterChip, l10n.checkoutNoteNoOnion);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field).controller!.text,
      'Eshik kodi 124; ${l10n.checkoutNoteNoOnion}',
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Eshik kodi 124');
    await tester.enterText(field, List.filled(500, 'a').join());
    await tester.pump();
    expect(tester.widget<FilterChip>(chip).onSelected, isNull);
    expect(tester.takeException(), isNull);
  });
}
