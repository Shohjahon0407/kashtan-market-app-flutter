import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/catalog_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_card.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorite_models.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorites_api.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/features/store/data/store_api.dart';
import 'package:beshkashtan_customer/features/store/data/store_models.dart';
import 'package:beshkashtan_customer/features/store/domain/store_landing_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockStoreApi extends Mock implements StoreApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockFavoritesApi extends Mock implements FavoritesApi {}

ProductSummary _product(String id) => ProductSummary.fromJson({
  'id': id,
  'name': 'Mahsulot $id',
  'description': '',
  'price': '20000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'household',
  'store': {'id': 'store-1', 'name': 'household', 'store_type': 'household'},
  'variants': <Map<String, dynamic>>[],
});

const _landing = StoreLandingData(
  header: StoreHeader(
    storeTypeWire: 'household',
    label: 'Xozmak',
    subtitle: '',
    isEnabled: true,
    showHeader: false,
  ),
  categories: [],
  stores: [],
  banners: [],
  sections: [],
);

CartData _cartWith(ProductSummary product) => CartData(
  id: 'cart-1',
  storeTypeWire: 'household',
  items: [
    CartItem(
      id: 'item-1',
      product: product,
      quantity: 1,
      selectedAddons: const [],
      note: '',
      subtotal: '20000.00',
    ),
  ],
  totalItems: 1,
  totalQuantity: 1,
  subtotal: '20000.00',
);

/// Regressiya: "Tovar savatga qo'shildi" snackbar'i pastdagi yashil
/// "SAVAT" panelini TO'SMASLIGI kerak.
///
/// Sabab bo'lgan holat: snackbar floating rejimda va tashqi shell
/// Scaffold'iga tegishli edi — u ichki Scaffold'ning mini savat panelini
/// bekitib qo'yardi. Yechim: katalog o'z ScaffoldMessenger'iga o'ralgan.
void main() {
  testWidgets('savatga qo‘shildi snackbari mini savat panelini to‘smaydi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final catalogApi = _MockCatalogApi();
    final storeApi = _MockStoreApi();
    final cartApi = _MockCartApi();
    final favoritesApi = _MockFavoritesApi();
    final product = _product('1');

    when(
      () => catalogApi.fetchProducts(storeType: 'household'),
    ).thenAnswer((_) async => CursorPage(items: [product], nextUrl: null));
    when(
      () => storeApi.fetchLanding('household'),
    ).thenAnswer((_) async => _landing);
    // Savatda allaqachon mahsulot bor — mini savat paneli ko'rinadi.
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => _cartWith(product));
    when(() => favoritesApi.fetch()).thenAnswer((_) async => <FavoriteEntry>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          catalogApiProvider.overrideWithValue(catalogApi),
          storeApiProvider.overrideWithValue(storeApi),
          cartApiProvider.overrideWithValue(cartApi),
          favoritesApiProvider.overrideWithValue(favoritesApi),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          theme: AppTheme.light(),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          // HAQIQIY tuzilish: katalog StoreShell'ning Scaffold'i ichida
          // yashaydi (StatefulShellRoute). Aynan shu sabab root
          // ScaffoldMessenger tashqi Scaffold'ni nishonga oladi va snackbar
          // ichki mini savat panelini to'sib qo'yadi.
          home: Scaffold(
            body: const CatalogScreen(
              storeType: StoreType.household,
              searchOnly: true,
            ),
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.storefront),
                  label: 'Mahsulotlar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_cart),
                  label: 'Savat',
                ),
              ],
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cartBar = find.byKey(const ValueKey('catalog-mini-cart'));
    expect(
      cartBar,
      findsOneWidget,
      reason: 'mini savat paneli ko‘rinishi kerak',
    );

    // Snackbar'ni ProductCard bilan bir xil yo‘l orqali ko‘rsatamiz.
    final cardContext = tester.element(find.byType(ProductCard).first);
    showProductAddedSnackBar(cardContext);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsOneWidget);
    final snackRect = tester.getRect(find.byType(SnackBar));
    final cartRect = tester.getRect(cartBar);

    expect(
      snackRect.bottom,
      lessThanOrEqualTo(cartRect.top),
      reason:
          'snackbar (${snackRect.bottom}) savat panelidan (${cartRect.top}) '
          'yuqorida tugashi kerak — aks holda panelni to‘sadi',
    );
  });
}
