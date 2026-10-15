import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/recommendations_controller.dart';
import 'package:beshkashtan_customer/features/recommendations/presentation/for_you_section.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_recommendations_api.dart';

class _MockCartApi extends Mock implements CartApi {}

ProductSummary _product(String id, String storeType) =>
    ProductSummary.fromJson({
      'id': id,
      'name': 'Mahsulot $id',
      'price': '15000.00',
      'store_type': storeType,
      'is_purchasable': true,
      'variants': <Object>[],
    });

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    FakeRecommendationsApi api,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final cartApi = _MockCartApi();
    when(() => cartApi.fetch(any())).thenAnswer(
      (invocation) async =>
          CartData.empty(invocation.positionalArguments.first as String),
    );
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        recommendationsApiProvider.overrideWithValue(api),
        cartApiProvider.overrideWithValue(cartApi),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: ForYouSection())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets('aralash do\'konlardan kartalar, noma\'lum turi tashlanadi', (
    tester,
  ) async {
    await pump(
      tester,
      FakeRecommendationsApi(
        forYouItems: [
          _product('a', 'household'),
          _product('b', 'grocery'),
          _product('c', 'future-store'),
        ],
      ),
    );
    expect(find.text('SIZ UCHUN'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-for-you-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-for-you-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-for-you-c')), findsNothing);
  });

  testWidgets('bo\'sh bo\'lsa bo\'lim chizilmaydi', (tester) async {
    await pump(tester, FakeRecommendationsApi());
    expect(find.byKey(const ValueKey('home-for-you')), findsNothing);
  });

  testWidgets('3 ta yangi ko\'rishdan keyin jim yangilanadi', (tester) async {
    final api = FakeRecommendationsApi(
      forYouItems: [_product('a', 'household')],
    );
    final container = await pump(tester, api);
    expect(api.forYouCalls, 1);
    final tracker = container.read(interactionTrackerProvider);
    for (var i = 0; i < 3; i++) {
      tracker.recordView(
        productId: 'v$i',
        dwell: const Duration(seconds: 12),
        scrollDepth: 1,
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.forYouCalls, 2);
    // Yangilashdan oldin navbat serverga ketgan.
    expect(api.postedBatches.expand((batch) => batch), hasLength(3));
    container.read(forYouControllerProvider);
  });

  testWidgets('yon tomonga scroll qilinganda keyingi bo\'lak qo\'shiladi', (
    tester,
  ) async {
    final api = FakeRecommendationsApi()
      ..pagedItems = [
        for (var i = 0; i < 45; i++)
          _product('p$i', i.isEven ? 'household' : 'grocery'),
      ];
    final container = await pump(tester, api);
    expect(
      container.read(forYouControllerProvider).value?.items,
      hasLength(20),
    );
    expect(api.forYouRequests.single.offset, 0);
    final session = api.forYouRequests.single.session;

    for (var round = 0; round < 14; round++) {
      await tester.drag(
        find.byKey(const PageStorageKey('home-for-you-rail')),
        const Offset(-400, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    final feed = container.read(forYouControllerProvider).value!;
    expect(feed.items, hasLength(45));
    expect(feed.items.map((p) => p.id).toSet(), hasLength(45));
    expect(feed.hasMore, isFalse);
    expect(api.forYouRequests.map((r) => r.offset), [0, 20, 40]);
    // Bitta scroll sessiyasi — server bir xil tartibdan kesadi.
    expect(api.forYouRequests.every((r) => r.session == session), isTrue);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('home-for-you-p44')),
      find.byKey(const PageStorageKey('home-for-you-rail')),
      const Offset(-300, 0),
    );
    expect(find.byKey(const ValueKey('home-for-you-p44')), findsOneWidget);
  });
}
