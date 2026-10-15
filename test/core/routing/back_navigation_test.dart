import 'dart:async';

import 'package:beshkashtan_customer/core/routing/back_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<GoRouter> mount(WidgetTester tester, {String initial = '/'}) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        for (final path in [
          '/',
          '/stores',
          '/videos',
          '/profile',
          '/first',
          '/second',
          '/store/shashlik/cart/checkout',
        ])
          GoRoute(
            path: path,
            routes: [
              if (path == '/first')
                GoRoute(
                  path: 'detail',
                  builder: (_, _) => const Scaffold(body: Text('detail')),
                ),
            ],
            builder: (context, state) => BackNavigationGuard(
              child: Scaffold(
                appBar: AppBar(title: Text(path)),
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('dialog')),
                  ),
                  child: const Text('open dialog'),
                ),
              ),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationProvider: router.routeInformationProvider,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        backButtonDispatcher: AppBackButtonDispatcher(
          AppBackCoordinator.of(router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('system back restores tabs in order; Home allows exit', (
    tester,
  ) async {
    final router = await mount(tester);
    final back = AppBackCoordinator.of(router);
    back.go('/stores');
    await tester.pumpAndSettle();
    back.go('/videos');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/stores');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/');
    expect(await back.back(), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('direct link falls back to Home; dialog closes first', (
    tester,
  ) async {
    final router = await mount(tester, initial: '/profile');
    final back = AppBackCoordinator.of(router);
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
    expect(back.location, '/profile');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/');
  });

  testWidgets('restores nested pushed caller and deduplicates same tab', (
    tester,
  ) async {
    final router = await mount(tester);
    final back = AppBackCoordinator.of(router);
    unawaited(router.push<void>('/first'));
    await tester.pumpAndSettle();
    back.go('/second');
    await tester.pumpAndSettle();
    back.go('/second');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/first');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/');
  });

  testWidgets(
    'rapid back does not skip a page; clear removes account history',
    (tester) async {
      final router = await mount(tester);
      final back = AppBackCoordinator.of(router);
      back.go('/first');
      await tester.pumpAndSettle();
      back.go('/second');
      await tester.pumpAndSettle();
      await Future.wait([back.back(), back.back()]);
      await tester.pumpAndSettle();
      expect(back.location, '/first');
      back.clear();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(back.location, '/');
    },
  );

  testWidgets('completed checkout is discarded from return history', (
    tester,
  ) async {
    final router = await mount(tester);
    final back = AppBackCoordinator.of(router);
    back.go('/store/shashlik/cart/checkout');
    await tester.pumpAndSettle();
    back.go('/second');
    await tester.pumpAndSettle();
    back.discardCheckout();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/');
  });

  testWidgets(
    'an intentionally non-dismissible modal never triggers fallback',
    (tester) async {
      final router = await mount(tester, initial: '/profile');
      final context = tester.element(find.text('open dialog'));
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: AlertDialog(content: Text('blocked modal')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('blocked modal'), findsOneWidget);
      expect(AppBackCoordinator.of(router).location, '/profile');
      Navigator.of(tester.element(find.text('blocked modal'))).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('revisiting a tab unwinds its excursion and retains caller', (
    tester,
  ) async {
    final router = await mount(tester, initial: '/stores');
    final back = AppBackCoordinator.of(router);
    unawaited(router.push<void>('/first?category=tools'));
    await tester.pumpAndSettle();
    for (var repeat = 0; repeat < 3; repeat++) {
      back.go('/second');
      await tester.pumpAndSettle();
      back.go('/first?category=tools');
      await tester.pumpAndSettle();
      expect(back.location, '/first?category=tools');
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/stores');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/');
  });

  testWidgets('returning from another tab resets detail to root, not cart', (
    tester,
  ) async {
    final router = await mount(tester, initial: '/stores');
    final back = AppBackCoordinator.of(router);
    unawaited(router.push<void>('/first'));
    await tester.pumpAndSettle();
    unawaited(router.push<void>('/first/detail'));
    await tester.pumpAndSettle();
    back.go('/second');
    await tester.pumpAndSettle();
    back.go('/first');
    await tester.pumpAndSettle();
    expect(back.location, '/first');
    expect(find.text('detail'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(back.location, '/stores');
  });
}
