import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_dimens.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:beshkashtan_customer/features/videos/presentation/widgets/video_product_rail.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVideoApi extends Mock implements VideoApi {}

class _MockCartApi extends Mock implements CartApi {}

ProductSummary _product(int index) => ProductSummary(
  id: 'product-$index',
  name: 'Mahsulot $index',
  description: '',
  price: '10000',
  imageUrl: null,
  unit: 'dona',
  isPurchasable: true,
  storeTypeWire: 'household',
  variants: const [],
);

void main() {
  testWidgets('rail aynan 3 karta kengligida va 15 + see-all bilan ishlaydi', (
    tester,
  ) async {
    final videoApi = _MockVideoApi();
    final cartApi = _MockCartApi();
    final rail = VideoProductRail(
      products: List.generate(18, _product),
      storeType: 'household',
      category: 'Uy jihozlari',
      categoryId: 'category-1',
    );
    when(() => videoApi.fetchProducts('video-1')).thenAnswer((_) async => rail);
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => CartData.empty('household'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          videoApiProvider.overrideWithValue(videoApi),
          cartApiProvider.overrideWithValue(cartApi),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: [Locale('uz')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: VideoProductRailSection(videoId: 'video-1', cardHeight: 170),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ListView);
    final listRect = tester.getRect(list);
    expect(listRect.height, 170);
    final cards = [
      for (var index = 0; index < 3; index++)
        tester.getRect(find.byKey(ValueKey('video-product-product-$index'))),
    ];
    expect(cards[0].width, closeTo((listRect.width - 16) / 3, .01));
    expect(cards[2].right, closeTo(listRect.right, .01));

    await tester.drag(list, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('video-product-product-14')), findsOne);
    expect(
      find.byKey(const ValueKey('video-product-product-15')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('video-products-see-all-video-1')),
      findsOne,
    );
  });

  testWidgets('Web transient nol kenglikda manfiy constraint yaratmaydi', (
    tester,
  ) async {
    final videoApi = _MockVideoApi();
    final cartApi = _MockCartApi();
    final rail = VideoProductRail(
      products: [_product(0)],
      storeType: 'household',
      category: 'Uy jihozlari',
      categoryId: 'category-1',
    );
    when(() => videoApi.fetchProducts('video-1')).thenAnswer((_) async => rail);
    when(
      () => cartApi.fetch('household'),
    ).thenAnswer((_) async => CartData.empty('household'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          videoApiProvider.overrideWithValue(videoApi),
          cartApiProvider.overrideWithValue(cartApi),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: [Locale('uz')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: AppSpacing.sm * 2,
                child: VideoProductRailSection(
                  videoId: 'video-1',
                  cardHeight: 170,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsNothing);
  });
}
