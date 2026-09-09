import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/product_detail_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockCartApi extends Mock implements CartApi {}

final _product = ProductSummary.fromJson({
  'id': 'product-1',
  'name': 'Lavash',
  'description': '',
  'price': '30000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'restaurant',
  'variants': <Map<String, dynamic>>[],
});

/// Majburiy guruhning barcha optsiyalari mavjud emas — UI'da tanlash uchun
/// hech narsa yo'q. Ilgari "kamida bittasini tanlang" chiqib, mahsulotni
/// hech qachon qo'shib bo'lmasdi; endi tugma o'chiq va "mavjud emas" kartasi.
final _detail = ProductDetail(
  product: _product,
  images: const [],
  addonGroups: const [
    AddonGroup(
      id: 'sauce',
      name: 'Sous',
      selectionType: 'single',
      isRequired: true,
      minSelect: 1,
      maxSelect: 1,
      options: [
        AddonOption(id: 'o1', name: 'Ketchup', price: '0', isAvailable: false),
        AddonOption(id: 'o2', name: 'Mayonez', price: '0', isAvailable: false),
      ],
    ),
  ],
  relatedProducts: const [],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const CartConfiguration(productId: 'fallback'));
  });

  testWidgets('tanlab bo\'lmaydigan majburiy guruh: tugma o\'chiq, xabar bor', (
    tester,
  ) async {
    final catalogApi = _MockCatalogApi();
    final cartApi = _MockCartApi();
    when(
      () => catalogApi.fetchDetail('product-1'),
    ).thenAnswer((_) async => _detail);
    when(
      () => cartApi.fetch('restaurant'),
    ).thenAnswer((_) async => CartData.empty('restaurant'));

    final router = GoRouter(
      initialLocation: '/product',
      routes: [
        GoRoute(
          path: '/product',
          builder: (_, _) => const ProductDetailScreen(
            storeType: StoreType.restaurant,
            productId: 'product-1',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          catalogApiProvider.overrideWithValue(catalogApi),
          cartApiProvider.overrideWithValue(cartApi),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final add = find.byKey(const ValueKey('product-detail-add-to-cart'));
    expect(add, findsOneWidget);
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    expect(
      find.byKey(const ValueKey('product-detail-unavailable')),
      findsOneWidget,
    );
    verifyNever(
      () => cartApi.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
      ),
    );
  });
}
