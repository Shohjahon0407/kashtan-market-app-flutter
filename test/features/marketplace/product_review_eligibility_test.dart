import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_review_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_reviews_section.dart';
import 'package:beshkashtan_customer/features/ugc/data/ugc_api.dart';
import 'package:beshkashtan_customer/features/ugc/data/ugc_models.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

const _product = ProductSummary(
  id: 'product-1',
  name: 'Sovun',
  description: '',
  price: '12000',
  imageUrl: null,
  unit: 'dona',
  isPurchasable: true,
  storeTypeWire: 'household',
  variants: [],
);

ProductDetail _detail({required bool canReview, bool hasReviewed = false}) =>
    ProductDetail(
      product: _product,
      images: const [],
      addonGroups: const [],
      relatedProducts: const [],
      canReview: canReview,
      hasReviewed: hasReviewed,
    );

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required bool canReview,
    bool hasReviewed = false,
  }) async {
    final api = _MockCatalogApi();
    when(() => api.fetchReviews('product-1')).thenAnswer(
      (_) async =>
          const OffsetPage<ProductReview>(items: [], nextUrl: null, count: 0),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogApiProvider.overrideWithValue(api),
          ugcPolicyProvider.overrideWith(
            (ref) async => const UgcPolicy(
              version: 'test-v1',
              accepted: true,
              title: '',
              summary: '',
              termsUrl: '',
              communityGuidelinesUrl: '',
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ProductReviewsSection(
              detail: _detail(canReview: canReview, hasReviewed: hasReviewed),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('yetkazilmagan mahsulotda review inputi va action chiqmaydi', (
    tester,
  ) async {
    await pumpSection(tester, canReview: false);

    expect(
      find.text('Bu mahsulot yetkazilgandan keyin izoh yozishingiz mumkin'),
      findsOneWidget,
    );
    expect(find.text('Baho va izoh yozish'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('yetkazilgan mahsulotda input faqat action bosilgach ochiladi', (
    tester,
  ) async {
    await pumpSection(tester, canReview: true);

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Baho va izoh yozish'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
