import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/search/domain/search_controller.dart';
import 'package:beshkashtan_customer/features/search/presentation/search_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCartApi extends Mock implements CartApi {}

class _FakeSearchController extends ProductSearchController {
  _FakeSearchController(this.initial);

  final SearchState initial;
  String? latestQuery;

  @override
  SearchState build() => initial;

  @override
  Future<void> search(String query) async {
    latestQuery = query;
    if (query.trim().isEmpty) state = const SearchState();
  }

  @override
  Future<void> loadMore() async {}
}

const _product = ProductSummary(
  id: 'product-1',
  name: 'Mol go‘shti marinovka, 1 kg',
  description: '',
  price: '89000',
  imageUrl: null,
  unit: 'dona',
  isPurchasable: true,
  storeTypeWire: 'shashlik',
  variants: [],
);

void main() {
  Future<_FakeSearchController> pumpSearch(
    WidgetTester tester,
    SearchState state,
  ) async {
    final cartApi = _MockCartApi();
    when(() => cartApi.fetch(any())).thenAnswer(
      (invocation) async =>
          CartData.empty(invocation.positionalArguments.first as String),
    );
    late _FakeSearchController fake;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartApiProvider.overrideWithValue(cartApi),
          searchControllerProvider.overrideWith(() {
            fake = _FakeSearchController(state);
            return fake;
          }),
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
          home: SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets(
    'natija compact qator, narx, store va yashil plus bilan chiqadi',
    (tester) async {
      await pumpSearch(
        tester,
        const SearchState(items: [_product], searched: true, query: 'mol'),
      );

      expect(find.text('NATIJALAR 1'), findsOneWidget);
      expect(find.text('Mol go‘shti marinovka, 1 kg'), findsOneWidget);
      expect(find.text('SHASHLIK'), findsOneWidget);
      expect(find.text("89\u00a0000 so'm"), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-card-buy-product-1')),
        findsOneWidget,
      );
      expect(find.byType(GridView), findsNothing);
      expect(
        find.byKey(const ValueKey('search-missing-product-cta')),
        findsOneWidget,
      );
    },
  );

  testWidgets('350 ms debounce va clear qidiruvni tozalaydi', (tester) async {
    final fake = await pumpSearch(tester, const SearchState());
    final field = find.byKey(const ValueKey('global-search-field'));

    await tester.enterText(field, 'marinovka');
    await tester.pump(const Duration(milliseconds: 349));
    expect(fake.latestQuery, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(fake.latestQuery, 'marinovka');

    await tester.tap(find.byKey(const ValueKey('global-search-clear')));
    await tester.pump();
    expect(fake.latestQuery, '');
    expect(find.byKey(const ValueKey('global-search-clear')), findsNothing);
  });
}
