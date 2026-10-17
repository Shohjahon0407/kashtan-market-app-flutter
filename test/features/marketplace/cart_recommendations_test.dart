import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_recommendations_provider.dart';
import 'package:beshkashtan_customer/features/cart/presentation/cart_screen.dart';
import 'package:beshkashtan_customer/features/cart/presentation/widgets/cart_recommendations.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/product_report_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/recommendations/data/recommendations_api.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProductSummary product(
  String id, {
  String store = 'household',
  bool image = true,
}) => ProductSummary.fromJson({
  'id': id,
  'name': 'Mahsulot $id',
  'price': '10000',
  'store_type': store,
  'is_purchasable': true,
  'variants': <Object>[],
  'main_image': image ? 'https://example.test/$id.jpg' : null,
});

class _Recommendations extends Fake implements RecommendationsApi {
  _Recommendations(this.products, {this.fail = false, this.pending});
  final List<ProductSummary> products;
  final bool fail;
  final Completer<ForYouPage>? pending;
  int calls = 0;
  String? requestedStore;
  bool? requestedImages;
  @override
  Future<ForYouPage> forYou({
    String? storeType,
    String? categoryId,
    bool imagesOnly = false,
    int limit = 20,
    int offset = 0,
    int? session,
  }) async {
    calls++;
    requestedStore = storeType;
    requestedImages = imagesOnly;
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    return ForYouPage(items: products, hasMore: false);
  }
}

class _GuestAuth extends AuthController {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _Home extends HomeController {
  @override
  Future<HomeData> build() async => const HomeData(banners: [], storeHub: []);
}

class _CartApi extends Fake implements CartApi {
  ProductSummary? added;
  @override
  Future<CartData> fetch(String storeType) async {
    final item = added;
    if (item == null || item.storeTypeWire != storeType) {
      return CartData.empty(storeType);
    }
    return CartData(
      id: 'cart',
      storeTypeWire: storeType,
      items: [
        CartItem(
          id: 'line',
          product: item,
          quantity: 1,
          selectedAddons: const [],
          note: '',
          subtotal: '10000',
        ),
      ],
      totalItems: 1,
      totalQuantity: 1,
      subtotal: '10000',
    );
  }

  @override
  Future<void> addItem({
    required String storeType,
    required CartConfiguration configuration,
    required int quantity,
  }) async {
    added = product(configuration.productId, store: storeType);
  }
}

Future<_CartApi> _mount(
  WidgetTester tester,
  _Recommendations recommendations, {
  bool global = false,
  double scale = 1,
  Locale locale = const Locale('uz'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final cartApi = _CartApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith(_GuestAuth.new),
        homeControllerProvider.overrideWith(_Home.new),
        cartApiProvider.overrideWithValue(cartApi),
        apiLangProvider.overrideWithValue(locale.languageCode),
        recommendationsApiProvider.overrideWithValue(recommendations),
        reportButtonEnabledProvider.overrideWith((ref, type) => false),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: global
            ? const MainCartScreen()
            : const CartScreen(storeType: StoreType.household),
      ),
    ),
  );
  if (recommendations.pending == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }
  return cartApi;
}

void main() {
  test(
    'suggestions are image-only, deduplicated and scoped before display',
    () async {
      final api = _Recommendations([
        product('no-image', image: false),
        product('other', store: 'grocery'),
        product('ok'),
        product('ok'),
        product('last'),
      ]);
      final container = ProviderContainer(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          accountScopeProvider.overrideWithValue('guest'),
          recommendationsApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(
        cartRecommendationsProvider(StoreType.household).future,
      );
      expect(result.map((p) => p.id), ['ok', 'last']);
      expect(api.requestedStore, 'household');
      expect(api.requestedImages, isTrue);
    },
  );

  test(
    'global recommendations retain photos from multiple supported stores',
    () async {
      final api = _Recommendations([
        product('a'),
        product('b', store: 'grocery'),
        product('c', store: 'unknown'),
        product('d', image: false),
      ]);
      final container = ProviderContainer(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          accountScopeProvider.overrideWithValue('guest'),
          recommendationsApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(
          cartRecommendationsProvider(null).future,
        )).map((p) => p.id),
        ['a', 'b'],
      );
      expect(api.requestedStore, isNull);
    },
  );

  testWidgets(
    'empty store cart has illustration, copy and working suggestion add',
    (tester) async {
      final api = _Recommendations([product('hammer')]);
      final cartApi = await _mount(tester, api);
      expect(find.text('Savat hozircha bo‘sh'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);
      expect(find.text('Kerak bo‘lib qolishi mumkin'), findsOneWidget);
      final buy = find.byKey(const ValueKey('product-card-buy-hammer'));
      await tester.drag(
        find.byKey(const PageStorageKey('cart-household')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(cartApi.added?.id, 'hammer');
      expect(find.byKey(const ValueKey('empty-cart-view')), findsNothing);
      expect(find.byType(CartRecommendations), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CartScreen)),
      );
      expect(
        container
            .read(cartControllerProvider(StoreType.household))
            .value
            ?.cart
            .totalQuantity,
        1,
      );
      expect(
        api.calls,
        1,
        reason: 'Adding to cart must not refetch optional suggestions',
      );
    },
  );

  testWidgets('failed suggestions do not hide or block the empty cart', (
    tester,
  ) async {
    await _mount(tester, _Recommendations([], fail: true));
    expect(find.text('Savat hozircha bo‘sh'), findsOneWidget);
    expect(find.text('Kerak bo‘lib qolishi mumkin'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cart-recommendations-retry')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cart-browse-products')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending suggestions do not block the cart empty state', (
    tester,
  ) async {
    final pending = Completer<ForYouPage>();
    await _mount(tester, _Recommendations([], pending: pending));
    expect(find.text('Savat hozircha bo‘sh'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.complete(const ForYouPage(items: [], hasMore: false));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'global empty cart has only one illustration and global suggestions',
    (tester) async {
      final api = _Recommendations([product('hammer')]);
      await _mount(tester, api, global: true);
      await tester.drag(
        find.byKey(const PageStorageKey('main-cart')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('empty-cart-view')), findsOneWidget);
      expect(find.text('Kerak bo‘lib qolishi mumkin'), findsOneWidget);
      expect(api.requestedStore, isNull);
    },
  );

  for (final size in [
    const Size(320, 780),
    const Size(430, 900),
    const Size(800, 360),
  ]) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('empty cart and recommendations fit $size $locale at 2x', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _mount(
          tester,
          _Recommendations([product('hammer')]),
          scale: 2,
          locale: locale,
        );
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
