import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/back_navigation.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/store/presentation/widgets/store_switch_button.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _data = HomeData(
  banners: const [],
  storeHub: [
    for (final type in StoreType.values)
      StoreHubItem(
        storeType: type,
        storeTypeWire: type.wire,
        label: type.wire,
        subtitle: '',
        imageUrl: null,
        accentColor: null,
        sortOrder: type.index,
        isEnabled: type != StoreType.grocery,
      ),
    const StoreHubItem(
      storeType: null,
      storeTypeWire: 'unknown',
      label: 'Unknown',
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 99,
    ),
  ],
);

class _Home extends HomeController {
  _Home({this.failFirst = false});
  final bool failFirst;
  int requests = 0;
  @override
  Future<HomeData> build() async {
    requests++;
    if (failFirst) throw const NetworkFailure();
    return _data;
  }

  @override
  Future<void> refresh() async {
    requests++;
    state = AsyncData(_data);
  }
}

class _Draft extends OrderDraftController {
  _Draft(super.storeType);
  @override
  OrderDraftState build() => const OrderDraftState();
}

class _Page extends ConsumerStatefulWidget {
  const _Page(this.type);
  final StoreType type;
  @override
  ConsumerState<_Page> createState() => _PageState();
}

class _PageState extends ConsumerState<_Page> {
  final input = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      title: Text(widget.type.wire),
      actions: [StoreSwitchButton(storeType: widget.type)],
    ),
    body: ListView(
      controller: scroll,
      children: [
        TextField(controller: input, key: const ValueKey('page-draft')),
        Text(ref.watch(orderDraftProvider(widget.type)).note),
        for (var i = 0; i < 40; i++)
          SizedBox(height: 48, child: Text('item-$i')),
      ],
    ),
  );
}

Future<(GoRouter, ProviderContainer)> _mount(
  WidgetTester tester,
  _Home home, {
  Locale locale = const Locale('uz'),
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      homeControllerProvider.overrideWith(() => home),
      orderDraftProvider.overrideWith2(_Draft.new),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: Routes.storeCatalog('household'),
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const Scaffold(body: Text('Home destination')),
      ),
      GoRoute(
        path: Routes.stores,
        builder: (_, _) => const Scaffold(body: Text('Stores destination')),
      ),
      for (final type in StoreType.values)
        GoRoute(
          path: Routes.storeCatalog(type.wire),
          builder: (_, _) => _Page(type),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router, container);
}

Future<void> _switch(WidgetTester tester, String wire) async {
  await tester.tap(find.byKey(const ValueKey('store-switch-button')));
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('switch-store-$wire'));
  await tester.scrollUntilVisible(
    tile,
    180,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('store-switch-picker')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'store switch preserves source scroll, page state and isolated drafts',
    (tester) async {
      final home = _Home();
      final (router, container) = await _mount(tester, home);
      expect(home.requests, 0);
      final source = tester.state<_PageState>(find.byType(_Page));
      await tester.enterText(
        find.byKey(const ValueKey('page-draft')),
        'Local draft',
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      source.scroll.jumpTo(200);
      await tester.pumpAndSettle();
      container
          .read(orderDraftProvider(StoreType.household).notifier)
          .setNote('without salt');
      await _switch(tester, 'meat');
      expect(
        AppBackCoordinator.of(router).location,
        Routes.storeCatalog('meat'),
      );
      expect(
        container.read(orderDraftProvider(StoreType.household)).note,
        'without salt',
      );
      expect(container.read(orderDraftProvider(StoreType.meat)).note, '');
      await tester.tap(find.byKey(const ValueKey('app-back-button')));
      await tester.pumpAndSettle();
      expect(tester.state<_PageState>(find.byType(_Page)), same(source));
      expect(source.input.text, 'Local draft');
      expect(source.scroll.offset, 200);
      expect(home.requests, 1);
    },
  );

  testWidgets('revisiting store restores it without creating a back loop', (
    tester,
  ) async {
    final (router, _) = await _mount(tester, _Home());
    final source = tester.state<_PageState>(find.byType(_Page));
    await _switch(tester, 'meat');
      await _switch(tester, 'restaurant');
    await _switch(tester, 'household');
    expect(tester.state<_PageState>(find.byType(_Page)), same(source));
    await tester.tap(find.byKey(const ValueKey('app-back-button')));
    await tester.pumpAndSettle();
    expect(AppBackCoordinator.of(router).location, Routes.home);
  });

  testWidgets(
    'picker filters disabled and unsupported stores; current selection just closes',
    (tester) async {
      final (router, _) = await _mount(tester, _Home());
      await tester.tap(find.byKey(const ValueKey('store-switch-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('switch-store-grocery')), findsNothing);
      expect(find.byKey(const ValueKey('switch-store-unknown')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('switch-store-household')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('store-switch-picker')), findsNothing);
      expect(
        AppBackCoordinator.of(router).location,
        Routes.storeCatalog('household'),
      );
    },
  );

  testWidgets('offline picker retries without leaving current store', (
    tester,
  ) async {
    final home = _Home(failFirst: true);
    final (router, _) = await _mount(tester, home);
    await tester.tap(find.byKey(const ValueKey('store-switch-button')));
    await tester.pumpAndSettle();
    final beforeRetry = home.requests;
    await tester.tap(find.text('Qayta urinish'));
    await tester.pumpAndSettle();
    expect(home.requests, beforeRetry + 1);
    expect(find.byKey(const ValueKey('switch-store-meat')), findsOneWidget);
    expect(
      AppBackCoordinator.of(router).location,
      Routes.storeCatalog('household'),
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(320, 640), Size(430, 850), Size(800, 360)]) {
      testWidgets('picker fits $locale $size at 200%', (tester) async {
        final (router, _) = await _mount(
          tester,
          _Home(),
          locale: locale,
          size: size,
          scale: 2,
        );
        await _switch(tester, 'meat');
        expect(
          AppBackCoordinator.of(router).location,
          Routes.storeCatalog('meat'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
