import 'dart:async';

import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/features/catalog/data/category_banners.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/category_product_banners.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

CategoryProductBanner banner(
  int id, {
  bool long = false,
}) => CategoryProductBanner.fromJson({
  'id': '$id',
  'title': long
      ? 'Professional asboblar uchun maxsus qulay taklif $id'
      : 'Taklif $id',
  'subtitle': long
      ? 'Kuchli, ishonchli va qulay mahsulot. Uy va ustaxona uchun sifatli tanlov.'
      : 'Uy va ustaxona uchun',
  'badge': 'Hafta taklifi',
  'cta': 'Xarid qilish',
  'background_color': '#087F65',
  'text_color': '#FFFFFF',
  'product': {
    'id': 'p$id',
    'price': '639000',
    'name': 'Drel',
    'store_type': 'household',
  },
});

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  Future<void> mount(
    WidgetTester tester, {
    int count = 2,
    double scale = 1,
    Locale locale = const Locale('uz'),
    bool reduced = false,
    VoidCallback? onLoad,
    ValueChanged<CategoryProductBanner>? onTap,
    bool hasMore = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [appRouteObserver],
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                CategoryProductBanners(
                  banners: List.generate(
                    count,
                    (i) => banner(i, long: scale > 1),
                  ),
                  onTap: onTap ?? (_) {},
                  onLoadMore: onLoad ?? () {},
                  hasMore: hasMore,
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
  }

  int current(WidgetTester tester) => tester
      .widget<PageView>(find.byType(PageView, skipOffstage: false))
      .controller!
      .page!
      .round();
  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets(
    'no banners leave no carousel; one banner stays static and opens product',
    (tester) async {
      await mount(tester, count: 0);
      expect(find.byType(PageView), findsNothing);
      var taps = 0;
      await mount(tester, count: 1, onTap: (_) => taps++);
      await tester.pump(const Duration(seconds: 6));
      expect(current(tester), 0);
      await tester.tap(find.text('Taklif 0'));
      expect(taps, 1);
      await clean(tester);
    },
  );
  testWidgets(
    'auto-slide after 2.5 seconds and manual swipe load later pages',
    (tester) async {
      var loads = 0;
      await mount(tester, count: 4, hasMore: true, onLoad: () => loads++);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(current(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(current(tester), 1);
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(current(tester), 2);
      expect(loads, greaterThan(0));
      await clean(tester);
    },
  );
  testWidgets('background and reduced-motion stop automatic sliding', (
    tester,
  ) async {
    await mount(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(current(tester), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(current(tester), 1);
    await clean(tester);
    await mount(tester, reduced: true);
    await tester.pump(const Duration(seconds: 8));
    expect(current(tester), 0);
    await clean(tester);
  });
  testWidgets('minimal dots replace numbers and active dot becomes a pill', (
    tester,
  ) async {
    await mount(tester, count: 3);
    expect(find.text('1 / 3'), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    double width(int index) => tester
        .widget<AnimatedContainer>(
          find.byKey(ValueKey('category-banner-indicator-$index')),
        )
        .constraints!
        .maxWidth;
    expect(width(0), 20);
    expect(width(1), 6);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(width(0), 6);
    expect(width(1), 20);
    await clean(tester);
    await mount(tester, count: 30);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.key.toString().contains('category-banner-indicator-'),
      ),
      findsNWidgets(7),
    );
    expect(tester.takeException(), isNull);
    await clean(tester);
  });
  testWidgets('offscreen banner and covering route pause autoplay', (
    tester,
  ) async {
    await mount(tester);
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    state.position.jumpTo(900);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(current(tester), 0);
    state.position.jumpTo(0);
    await tester.pump();
    final context = tester.element(find.byType(CategoryProductBanners));
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Detail')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 6));
    expect(current(tester), 0);
    Navigator.of(context).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await clean(tester);
  });
  for (final width in [320.0, 360.0, 430.0, 800.0]) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('banner text fits $width $locale at 2x', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(tester, count: 1, scale: 2, locale: locale);
        expect(tester.takeException(), isNull);
        await clean(tester);
      });
    }
  }
}
