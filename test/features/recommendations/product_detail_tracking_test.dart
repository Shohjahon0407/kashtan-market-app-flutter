import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/product_detail_screen.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_recommendations_api.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockCartApi extends Mock implements CartApi {}

ProductSummary _product(String id, String name) => ProductSummary.fromJson({
  'id': id,
  'name': name,
  'description': 'Izoh',
  'price': '120000.00',
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'household',
  'variants': <Map<String, dynamic>>[],
});

/// Mahsulot sahifasi: o'xshashlar gorizontal qatorda, chiqilganda "ko'rish"
/// hodisasi (qarash vaqti bilan) navbatga tushadi va katalog signali keladi.
void main() {
  testWidgets('o\'xshashlar gorizontal, chiqishda ko\'rish hodisasi yoziladi', (
    tester,
  ) async {
    final catalogApi = _MockCatalogApi();
    final cartApi = _MockCartApi();
    when(() => catalogApi.fetchDetail('teapot')).thenAnswer(
      (_) async => ProductDetail(
        product: _product('teapot', 'Elektr choynak'),
        images: const [],
        addonGroups: const [],
        relatedProducts: [
          for (var i = 0; i < 6; i++) _product('similar-$i', 'Choynak $i'),
        ],
      ),
    );
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => CartData.empty('household'));
    final container = ProviderContainer(
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        catalogApiProvider.overrideWithValue(catalogApi),
        cartApiProvider.overrideWithValue(cartApi),
        recommendationsApiProvider.overrideWithValue(FakeRecommendationsApi()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ProductDetailScreen(
            storeType: StoreType.household,
            productId: 'teapot',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final rail = find.byKey(const ValueKey('product-related-rail'));
    await tester.scrollUntilVisible(
      rail,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(rail, findsOneWidget);
    final horizontal = tester.widget<ListView>(
      find.descendant(of: rail, matching: find.byType(ListView)),
    );
    expect(horizontal.scrollDirection, Axis.horizontal);
    expect(
      find.byKey(const ValueKey('related-product-similar-0')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final pending = container.read(interactionTrackerProvider).pending;
    expect(pending, hasLength(1));
    expect(pending.single['type'], 'view');
    expect(pending.single['product_id'], 'teapot');
    expect(pending.single['scroll_depth'] as double, greaterThan(0));
    final signal = container.read(lastProductViewProvider);
    expect(signal?.productId, 'teapot');
    expect(signal?.name, 'Elektr choynak');
    expect(signal?.storeType, StoreType.household);
    expect(container.read(recoActivityProvider), 1);
  });
}
