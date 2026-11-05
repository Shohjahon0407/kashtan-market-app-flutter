import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/shashlik_family_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_cart_bar.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _product = ProductSummary.fromJson({
  'id': 'lamb',
  'name': "Qo'y jazz",
  'price': '21000',
  'store_type': 'shashlik',
  'is_purchasable': true,
});
CartData _cart() => CartData(
  id: 'shashlik-cart',
  storeTypeWire: 'shashlik',
  items: [
    CartItem(
      id: 'line',
      product: _product,
      quantity: 3,
      selectedAddons: const [],
      note: '',
      subtotal: '63000',
    ),
  ],
  totalItems: 1,
  totalQuantity: 3,
  subtotal: '63000',
);

class _Catalog extends CatalogController {
  _Catalog(super.storeType);
  @override
  Future<CatalogState> build() async => CatalogState(items: [_product]);
}

class _Cart extends CartController {
  _Cart(super.storeType);
  @override
  Future<CartState> build() async => CartState(cart: _cart());
}

void main() {
  final action = find.byKey(const ValueKey('shashlik-go-to-cart'));
  for (final locale in AppLocale.values) {
    for (final size in const [Size(320, 640), Size(430, 800), Size(800, 360)]) {
      testWidgets('panel fits above navbar, 200% ${locale.code} $size', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: locale.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              bottomNavigationBar: const SizedBox(
                key: ValueKey('navbar'),
                height: 64,
              ),
              body: Scaffold(
                body: const Center(child: Text('Products')),
                bottomNavigationBar: ShashlikCartBar(
                  quantity: 3,
                  subtotal: '63000',
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(Uzs.format('63000')), findsOneWidget);
        final l10n = AppLocalizations.of(tester.element(action));
        expect(find.text(l10n.productGoToCart), findsOneWidget);
        expect(find.text(l10n.cartItemsCount(3)), findsOneWidget);
        expect(
          tester.getRect(action).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(const ValueKey('navbar'))).top,
          ),
        );
        expect(tester.getSize(action).height, greaterThanOrEqualTo(56));
        await tester.tap(action);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('empty/show/update/hide reserve space and animate for 200ms', (
    tester,
  ) async {
    final value = ValueNotifier<int>(0);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('uz'),
        home: ValueListenableBuilder<int>(
          valueListenable: value,
          builder: (_, quantity, _) => Scaffold(
            body: const SizedBox.expand(key: ValueKey('body')),
            bottomNavigationBar: ShashlikCartBar(
              quantity: quantity,
              subtotal: '${quantity * 21000}',
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(action, findsNothing);
    final emptyHeight = tester
        .getSize(find.byKey(const ValueKey('body')))
        .height;
    value.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final halfway = tester.getSize(find.byKey(const ValueKey('body'))).height;
    await tester.pump(const Duration(milliseconds: 100));
    expect(halfway, lessThan(emptyHeight));
    expect(
      halfway,
      greaterThan(tester.getSize(find.byKey(const ValueKey('body'))).height),
    );
    value.value = 3;
    await tester.pumpAndSettle();
    expect(find.text(Uzs.format('63000')), findsOneWidget);
    value.value = 0;
    await tester.pump();
    expect(
      tester
          .widget<AnimatedSwitcher>(
            find.descendant(
              of: find.byType(ShashlikCartBar),
              matching: find.byType(AnimatedSwitcher),
            ),
          )
          .duration,
      const Duration(milliseconds: 200),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(action, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump();
    expect(action, findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('body'))).height,
      emptyHeight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('family panel opens the shashlik cart without replacing navbar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final router = GoRouter(
      initialLocation: Routes.shashlikFamily('lamb-jazz'),
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(
            body: child,
            bottomNavigationBar: const SizedBox(
              height: 64,
              child: Text('Store navbar'),
            ),
          ),
          routes: [
            GoRoute(
              path: Routes.shashlikFamily('lamb-jazz'),
              builder: (_, _) =>
                  const ShashlikFamilyScreen(familyKey: 'lamb-jazz'),
            ),
            GoRoute(
              path: Routes.storeCart('shashlik'),
              builder: (_, _) => const Scaffold(body: Text('Shashlik cart')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          catalogControllerProvider.overrideWith2(_Catalog.new),
          cartControllerProvider.overrideWith2(_Cart.new),
          productDetailProvider('lamb').overrideWith(
            (ref) async => ProductDetail(
              product: _product,
              images: const [],
              addonGroups: const [],
              relatedProducts: const [],
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      Routes.storeCart('shashlik'),
    );
    expect(find.text('Shashlik cart'), findsOneWidget);
    expect(find.text('Store navbar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
