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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockCartApi extends Mock implements CartApi {}

final _product = ProductSummary.fromJson({
  'id': 'product-1',
  'name': 'Temir choynak',
  'description': '',
  'price': '120000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'household',
  'variants': <Map<String, dynamic>>[],
});

final _detail = ProductDetail(
  product: _product,
  images: const [
    ProductImage(
      id: 'image-1',
      url: 'https://example.test/product-1.jpg',
      isMain: true,
    ),
    ProductImage(
      id: 'image-2',
      url: 'https://example.test/product-2.jpg',
      isMain: false,
    ),
  ],
  addonGroups: const [],
  relatedProducts: const [],
);

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
            subtotal: '${120000 * quantity}.00',
          ),
        ],
  totalItems: quantity == 0 ? 0 : 1,
  totalQuantity: quantity,
  subtotal: '${120000 * quantity}.00',
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CartConfiguration(productId: 'fallback-product'),
    );
  });

  testWidgets('Savatga → stepper → cart branch va delete oqimi ishlaydi', (
    tester,
  ) async {
    Future<void> pumpUi() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    final catalogApi = _MockCatalogApi();
    final cartApi = _MockCartApi();
    var serverQuantity = 0;

    when(
      () => catalogApi.fetchDetail('product-1'),
    ).thenAnswer((_) async => _detail);
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => _cart(serverQuantity));
    when(
      () => cartApi.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
      ),
    ).thenAnswer((invocation) async {
      serverQuantity += invocation.namedArguments[#quantity] as int;
    });
    when(() => cartApi.updateQuantity('line-1', any())).thenAnswer((
      invocation,
    ) async {
      serverQuantity = invocation.positionalArguments[1] as int;
    });
    when(() => cartApi.deleteItem('line-1')).thenAnswer((_) async {
      serverQuantity = 0;
    });

    final router = GoRouter(
      initialLocation: '/product',
      routes: [
        GoRoute(
          path: '/product',
          builder: (_, _) => const ProductDetailScreen(
            storeType: StoreType.household,
            productId: 'product-1',
          ),
        ),
        GoRoute(
          path: '/store/household/cart',
          builder: (_, _) => const Scaffold(body: Text('Cart destination')),
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
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
        ),
      ),
    );
    await pumpUi();

    expect(find.text('Izoh'), findsNothing);
    expect(find.text('Masalan, piyozsiz'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-gallery-previous')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('product-gallery-next')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('product-gallery-next')));
    await pumpUi();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-gallery-previous')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('product-gallery-next')), findsNothing);

    expect(
      find.byKey(const ValueKey('product-detail-add-to-cart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-detail-go-to-cart')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('product-detail-add-to-cart')));
    await pumpUi();
    expect(find.text('1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-detail-go-to-cart')),
      findsOneWidget,
    );
    verify(
      () => cartApi.addItem(
        storeType: 'household',
        configuration: any(named: 'configuration'),
        quantity: 1,
      ),
    ).called(1);

    await tester.tap(find.byIcon(Icons.add));
    await pumpUi();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await pumpUi();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await pumpUi();
    expect(
      find.byKey(const ValueKey('product-detail-add-to-cart')),
      findsOneWidget,
    );
    verify(() => cartApi.deleteItem('line-1')).called(1);

    await tester.tap(find.byKey(const ValueKey('product-detail-add-to-cart')));
    await pumpUi();
    await tester.tap(find.byKey(const ValueKey('product-detail-go-to-cart')));
    await pumpUi();
    expect(find.text('Cart destination'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/store/household/cart',
    );
  });
}
