import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
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

class _MockCartApi extends Mock implements CartApi {}

class _MockFavoritesApi extends Mock implements FavoritesApi {}

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockStoreApi extends Mock implements StoreApi {}

class _AuthenticatedAuthController extends AuthController {
  @override
  AuthState build() => const AuthState.authenticated(
    AuthUser(
      id: 'user-1',
      phoneNumber: '+998901234567',
      firstName: 'Ali',
      lastName: '',
      role: UserRole.customer,
      isPhoneVerified: true,
      requiresOnboarding: false,
      missingFields: [],
    ),
  );
}

ProductSummary _product({bool inReview = false}) => ProductSummary.fromJson({
  'id': 'product-1',
  'name': 'Temir choynak',
  'description': '',
  'price': '15000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': !inReview,
  'in_review': inReview,
  'store_type': 'household',
  'variants': <Map<String, dynamic>>[],
});

StoreLandingData _landing({required bool reportEnabled}) => StoreLandingData(
  header: const StoreHeader(
    storeTypeWire: 'household',
    label: 'Xozmak',
    subtitle: '',
    isEnabled: true,
    showHeader: false,
  ),
  categories: const [],
  stores: const [],
  banners: const [],
  sections: const [],
  reportButtonEnabled: reportEnabled,
);

const _emptyCart = CartData(
  id: 'cart-1',
  storeTypeWire: 'household',
  items: [],
  totalItems: 0,
  totalQuantity: 0,
  subtotal: '0.00',
);

void main() {
  Future<_Harness> pumpCard(
    WidgetTester tester, {
    required bool reportEnabled,
    bool inReview = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final cartApi = _MockCartApi();
    final favoritesApi = _MockFavoritesApi();
    final catalogApi = _MockCatalogApi();
    final storeApi = _MockStoreApi();
    when(() => cartApi.fetch('household')).thenAnswer((_) async => _emptyCart);
    when(() => favoritesApi.fetch()).thenAnswer((_) async => <FavoriteEntry>[]);
    when(
      () => storeApi.fetchLanding('household'),
    ).thenAnswer((_) async => _landing(reportEnabled: reportEnabled));
    when(() => catalogApi.reportProduct('product-1')).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          apiLangProvider.overrideWithValue('uz'),
          cartApiProvider.overrideWithValue(cartApi),
          favoritesApiProvider.overrideWithValue(favoritesApi),
          catalogApiProvider.overrideWithValue(catalogApi),
          storeApiProvider.overrideWithValue(storeApi),
          authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 310,
                child: ProductCard(
                  product: _product(inReview: inReview),
                  storeType: StoreType.household,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(catalogApi);
  }

  testWidgets('flag yoqiq: tugma bor; tap → tasdiqlash → badge, buy disabled', (
    tester,
  ) async {
    final harness = await pumpCard(tester, reportEnabled: true);

    final reportButton = find.byKey(
      const ValueKey('product-card-report-product-1'),
    );
    expect(reportButton, findsOneWidget);

    await tester.tap(reportButton);
    await tester.pumpAndSettle();
    expect(find.text('Adminga yuborilsinmi?'), findsOneWidget);

    await tester.tap(find.text('Yuborish'));
    await tester.pumpAndSettle();

    verify(() => harness.catalogApi.reportProduct('product-1')).called(1);
    // Tugma yo'qoladi, "Tekshiruvda" belgisi chiqadi.
    expect(reportButton, findsNothing);
    expect(
      find.byKey(const ValueKey('product-card-in-review-product-1')),
      findsOneWidget,
    );
    // Sotib olish bloklangan, lekin karta scrim BILAN yopilmaydi.
    final buyButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('product-card-buy-product-1')),
    );
    expect(buyButton.onPressed, isNull);
    expect(find.text("Hozir xarid qilib bo'lmaydi"), findsNothing);
  });

  testWidgets('payload in_review=true: tugma yo‘q, badge bor, scrim yo‘q', (
    tester,
  ) async {
    await pumpCard(tester, reportEnabled: true, inReview: true);

    expect(
      find.byKey(const ValueKey('product-card-report-product-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('product-card-in-review-product-1')),
      findsOneWidget,
    );
    expect(find.text("Hozir xarid qilib bo'lmaydi"), findsNothing);
    final buyButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('product-card-buy-product-1')),
    );
    expect(buyButton.onPressed, isNull);
  });

  testWidgets('flag o‘chiq: tugma umuman ko‘rinmaydi', (tester) async {
    await pumpCard(tester, reportEnabled: false);

    expect(
      find.byKey(const ValueKey('product-card-report-product-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('product-card-in-review-product-1')),
      findsNothing,
    );
  });
}

class _Harness {
  const _Harness(this.catalogApi);

  final CatalogApi catalogApi;
}
