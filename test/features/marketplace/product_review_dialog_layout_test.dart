import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
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

/// Baho dialogi 320 dp ekranda ham (5 yulduz + tugmalar) overflow'siz.
void main() {
  testWidgets('320 dp: yulduzlar qatori va tugmalar sig\'adi', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          theme: AppTheme.light(),
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: ProductReviewsSection(
              detail: ProductDetail(
                product: _product,
                images: [],
                addonGroups: [],
                relatedProducts: [],
                canReview: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Baho va izoh yozish'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-review-star-5')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final star1 = tester.getRect(
      find.byKey(const ValueKey('product-review-star-1')),
    );
    final star5 = tester.getRect(
      find.byKey(const ValueKey('product-review-star-5')),
    );
    expect(star5.right, lessThanOrEqualTo(320));
    expect(star1.top, moreOrLessEquals(star5.top, epsilon: 1));
  });
}
