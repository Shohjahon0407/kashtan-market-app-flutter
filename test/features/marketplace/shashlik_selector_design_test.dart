import 'dart:async';

import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_catalog.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

ProductSummary product(String id, String name, String price, String unit) =>
    ProductSummary.fromJson({
      'id': id,
      'name': name,
      'price': price,
      'unit': unit,
      'store_type': 'shashlik',
      'is_purchasable': true,
    });

final family = ShashlikFamily(
  key: ShashlikFamilyKey.lambJazz,
  products: [
    product('stick', "Qo'y jazz", '21000.00', 'dona'),
    product('kilo', "Qo'y jazz kiloligi", '220000.00', 'kg'),
  ],
);

class _Cart extends CartController {
  _Cart({this.initial}) : super(StoreType.shashlik);
  final CartData? initial;
  final sets = <(CartItem, int)>[];
  final calls = <(String, int)>[];
  Completer<bool>? pending;
  @override
  Future<CartState> build() async {
    ref.keepAlive();
    return CartState(cart: initial ?? CartData.empty('shashlik'));
  }

  @override
  Future<bool> setQuantity(CartItem item, int quantity) async {
    sets.add((item, quantity));
    return await (pending?.future ?? Future.value(true));
  }

  @override
  Future<bool> addProduct(
    ProductSummary product, {
    ProductVariant? variant,
    List<SelectedAddon> addons = const [],
    String note = '',
    int quantity = 1,
  }) async {
    calls.add((product.id, quantity));
    final result = await (pending?.future ?? Future.value(true));
    if (!result) {
      state = AsyncData(
        CartState(
          cart: CartData.empty('shashlik'),
          mutationFailure: const NetworkFailure(),
        ),
      );
    }
    return result;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Cart cart, {
  AppLocale locale = AppLocale.uz,
  double scale = 1,
  Size size = const Size(390, 800),
  bool reduced = true,
  bool accessible = false,
  ShashlikFamily? fixture,
  ValueNotifier<bool>? tickers,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [cartControllerProvider.overrideWith2((_) => cart)],
      child: MaterialApp(
        navigatorObservers: [appRouteObserver],
        theme: AppTheme.light(),
        locale: locale.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) {
          final page = MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
              accessibleNavigation: accessible,
            ),
            child: child!,
          );
          return tickers == null
              ? page
              : ValueListenableBuilder<bool>(
                  valueListenable: tickers,
                  child: page,
                  builder: (_, enabled, child) =>
                      TickerMode(enabled: enabled, child: child!),
                );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await showShashlikFamilySelector(context, fixture ?? family);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  if (reduced || accessible) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Finder get submit => find.byKey(const ValueKey('shashlik-selector-submit'));
Finder get plus => find.byKey(const ValueKey('shashlik-selector-plus'));
Finder get minus => find.byKey(const ValueKey('shashlik-selector-minus'));

Future<void> enterQuantity(WidgetTester tester, String value) async {
  final input = find.byKey(const ValueKey('shashlik-quantity-input'));
  await tester.ensureVisible(input);
  await tester.tap(input);
  await tester.enterText(input, value);
  await tester.pump();
}

CartData existing(int n, {String note = ''}) => CartData(
  id: 'cart',
  storeTypeWire: 'shashlik',
  items: [
    CartItem(
      id: 'line',
      product: family.products.first,
      quantity: n,
      selectedAddons: const [],
      note: note,
      subtotal: '${n * 21000}.00',
    ),
  ],
  totalItems: 1,
  totalQuantity: n,
  subtotal: '${n * 21000}.00',
);

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  Finder option(String id) =>
      find.byKey(ValueKey('shashlik-selector-product-$id'));
  Finder preset(int n) => find.byKey(ValueKey('shashlik-preset-$n'));

  testWidgets(
    'dona presets are 10/20/50/100/150/200 with initial quantity one',
    (tester) async {
      await _open(tester, _Cart());
      for (final n in [10, 20, 50, 100, 150, 200]) {
        expect(preset(n), findsOneWidget);
      }
      expect(find.byType(ListWheelScrollView), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '1',
      );
      await tester.tap(preset(150));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('150 dona · 3\u00a0150\u00a0000'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('kg presets and drafts stay separate from pieces', (
    tester,
  ) async {
    final cart = _Cart();
    await _open(tester, cart);
    await enterQuantity(tester, '37');
    await tester.tap(option('kilo'));
    await tester.pumpAndSettle();
    for (final n in [1, 2, 3, 5]) {
      expect(preset(n), findsOneWidget);
    }
    expect(preset(100), findsNothing);
    await tester.tap(preset(2));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 kilogram · 440\u00a0000'), findsOneWidget);
    await tester.tap(option('stick'));
    await tester.pumpAndSettle();
    expect(find.textContaining('37 dona · 777\u00a0000'), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(cart.calls, [('stick', 37)]);
  });

  testWidgets(
    'existing ten becomes twenty, not thirty; unchanged save sends nothing',
    (tester) async {
      final cart = _Cart(initial: existing(10));
      await _open(tester, cart);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '10',
      );
      expect(find.text('Miqdorni saqlash'), findsOneWidget);
      await tester.tap(preset(20));
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(cart.sets.single.$2, 20);
      expect(cart.calls, isEmpty);
      await _open(tester, _Cart(initial: existing(10)));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-selector-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'invalid inline entries block save and do not invent zero; preset recovers',
    (tester) async {
      final cart = _Cart();
      await _open(tester, cart);
      for (final invalid in ['', '0', '-1', '1.5', '9999999', '15 kg']) {
        await enterQuantity(tester, invalid);
        expect(
          find.byKey(const ValueKey('shashlik-quantity-error')),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        expect(find.textContaining('Miqdor · —'), findsOneWidget);
      }
      await tester.tap(preset(10));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(
        find.byKey(const ValueKey('shashlik-quantity-error')),
        findsNothing,
      );
      await enterQuantity(tester, '999999');
      expect(tester.widget<IconButton>(plus).onPressed, isNull);
      await tester.tap(minus);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '999998',
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(cart.calls, isEmpty);
    },
  );

  testWidgets(
    'keyboard leaves the inline editor and save reachable without another dialog',
    (tester) async {
      final cart = _Cart();
      await _open(tester, cart);
      tester.view.viewInsets = FakeViewPadding(
        bottom: 300 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await enterQuantity(tester, '37');
      expect(find.byType(AlertDialog), findsNothing);
      final input = find.byKey(const ValueKey('shashlik-quantity-input'));
      expect(tester.widget<TextField>(input).controller!.text, '37');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(500));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(cart.calls, [('stick', 37)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid piece draft does not contaminate kilogram and can be recovered by reselecting a preset',
    (tester) async {
      await _open(tester, _Cart());
      await tester.tap(preset(20));
      await tester.pumpAndSettle();
      await enterQuantity(tester, '');
      await tester.tap(option('kilo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '1',
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.tap(option('stick'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '20',
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'pending disables repeats, edits, presets and close; failure retains draft for retry',
    (tester) async {
      final cart = _Cart()..pending = Completer<bool>();
      await _open(tester, cart);
      await enterQuantity(tester, '250');
      await tester.tap(submit);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .enabled,
        isFalse,
      );
      expect(tester.widget<ChoiceChip>(preset(20)).onSelected, isNull);
      cart.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-selector-error')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('shashlik-quantity-input')),
            )
            .controller!
            .text,
        '250',
      );
      cart.pending = null;
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(cart.calls, [('stick', 250), ('stick', 250)]);
    },
  );

  testWidgets('custom values, third variant and unknown price remain honest', (
    tester,
  ) async {
    final cart = _Cart();
    await _open(
      tester,
      cart,
      fixture: ShashlikFamily(
        key: ShashlikFamilyKey.mince,
        products: [
          product('plain', 'Qiyma', '14000', 'dona'),
          product('bread', 'Non qiyma', '15000', 'dona'),
          product('kg', 'Kilolik qiyma', '140000', 'kg'),
        ],
      ),
    );
    await tester.tap(option('bread'));
    await tester.pumpAndSettle();
    await enterQuantity(tester, '7');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(cart.calls, [('bread', 7)]);
    await _open(
      tester,
      _Cart(),
      fixture: ShashlikFamily(
        key: ShashlikFamilyKey.mince,
        products: [product('only', 'Qiyma', 'unknown', 'dona')],
      ),
    );
    expect(find.textContaining('1 dona · —'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });

  for (final locale in AppLocale.values) {
    for (final size in const [Size(320, 640), Size(430, 800), Size(800, 360)]) {
      testWidgets(
        'inline editor and confirm reachable at 200% ${locale.code} $size',
        (tester) async {
          final cart = _Cart();
          await _open(tester, cart, locale: locale, scale: 2, size: size);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(option('kilo'));
          await tester.tap(option('kilo'));
          await tester.pumpAndSettle();
          await enterQuantity(tester, '3');
          await tester.ensureVisible(submit);
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(cart.calls, [('kilo', 3)]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
