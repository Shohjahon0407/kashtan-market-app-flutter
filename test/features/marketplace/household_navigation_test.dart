import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/household_categories_screen.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/household_catalog_navigation.dart';
import 'package:beshkashtan_customer/features/store/data/store_models.dart';
import 'package:beshkashtan_customer/features/store/domain/store_landing_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _categories = [
  ProductCategory(
    id: 'build',
    name: 'Qurilish mollari',
    storeTypeWire: 'household',
    productCount: 3,
  ),
  ProductCategory(
    id: 'tools',
    name: 'Ustachilik asboblari',
    storeTypeWire: 'household',
    productCount: 8,
  ),
  ProductCategory(
    id: 'tech',
    name: 'Маиший техника',
    canonicalName: 'Maishiy texnika',
    storeTypeWire: 'household',
    productCount: 2,
  ),
  ProductCategory(
    id: 'empty',
    name: 'Bo‘sh',
    storeTypeWire: 'household',
    productCount: 0,
  ),
];

StoreLandingData _landing() => StoreLandingData.fromJson({
  'categories': [
    for (final category in _categories)
      {
        'id': category.id,
        'name': category.name,
        'canonical_name': category.canonicalName,
        'product_count': category.productCount,
        'store_type': 'household',
      },
  ],
});

Widget _app({
  required Widget home,
  Locale locale = const Locale('uz'),
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

void main() {
  testWidgets('search, full index and shortcuts have separate actions', (
    tester,
  ) async {
    var searches = 0, indices = 0;
    String? selected;
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: HouseholdCatalogNavigation(
            categories: _categories,
            selectedId: null,
            onSelected: (value) => selected = value,
            onSearch: () => searches++,
            onCategories: () => indices++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('household-search-entry')));
    await tester.tap(find.byKey(const ValueKey('household-categories-button')));
    await tester.tap(find.byKey(const ValueKey('household-shortcut-build')));
    expect(searches, 1);
    expect(indices, 1);
    expect(selected, 'build');
    expect(find.text('Bo‘sh'), findsNothing);
    await tester.tap(find.text('Barchasi'));
    expect(selected, isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in [
      const Size(320, 640),
      const Size(430, 850),
      const Size(800, 360),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('pinned navigation fits $locale $size $scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _app(
              locale: locale,
              scale: scale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        title: const Text('Xozmak'),
                        bottom: PreferredSize(
                          preferredSize: Size.fromHeight(
                            HouseholdCatalogNavigation.height(context),
                          ),
                          child: HouseholdCatalogNavigation(
                            categories: _categories,
                            selectedId: 'build',
                            onSelected: (_) {},
                            onSearch: () {},
                            onCategories: () {},
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 900)),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final button = find.byKey(
            const ValueKey('household-categories-button'),
          );
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -240),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(button).top, greaterThanOrEqualTo(0));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'index searches cached labels, opens category, back retains query',
    (tester) async {
      var loads = 0;
      final router = GoRouter(
        initialLocation: Routes.householdCategories,
        routes: [
          GoRoute(
            path: Routes.storeCatalog('household'),
            builder: (_, _) => const Scaffold(body: Text('Landing')),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (_, _) => const HouseholdCategoriesScreen(),
              ),
              GoRoute(
                path: 'category/:id',
                builder: (_, state) => Scaffold(
                  appBar: AppBar(),
                  body: Text('Detail-${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            storeLandingProvider(StoreType.household).overrideWith((ref) {
              loads++;
              return Stream.value(_landing());
            }),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('uz'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('household-index-build')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('household-index-empty')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('household-category-search')),
        'maishiy',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('household-index-build')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('household-index-tech')));
      await tester.pumpAndSettle();
      expect(find.text('Detail-tech'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('household-category-search')),
            )
            .controller!
            .text,
        'maishiy',
      );
      expect(loads, 1);
      await tester.tap(
        find.byKey(const ValueKey('household-categories-close')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Landing'), findsOneWidget);
    },
  );

  testWidgets(
    'index error retries landing only; search never fetches previews',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            storeLandingProvider(StoreType.household).overrideWith((ref) {
              attempts++;
              return attempts == 1
                  ? Stream.error(const NetworkFailure())
                  : Stream.value(_landing());
            }),
          ],
          child: _app(home: const HouseholdCategoriesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      await tester.enterText(
        find.byKey(const ValueKey('household-category-search')),
        'ustachilik',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('household-index-tools')),
        findsOneWidget,
      );
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
