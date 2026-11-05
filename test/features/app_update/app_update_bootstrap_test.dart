import 'dart:async';

import 'package:beshkashtan_customer/core/routing/app_router.dart';
import 'package:beshkashtan_customer/features/app_update/domain/app_update_service.dart';
import 'package:beshkashtan_customer/features/app_update/presentation/app_update_bootstrap.dart';
import 'package:beshkashtan_customer/features/app_update/presentation/app_update_dialog.dart';
import 'package:beshkashtan_customer/features/app_update/presentation/update_navigation_gate.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const release = AndroidAppRelease(buildNumber: 4, version: '1.1.1');
  Future<GoRouter> mount(
    WidgetTester tester, {
    String initial = '/',
    Completer<Object?>? response,
    UpdateUrlLauncher? launcher,
  }) async {
    final key = GlobalKey<NavigatorState>();
    final gate = UpdateNavigationGate();
    final router = GoRouter(
      initialLocation: initial,
      navigatorKey: key,
      observers: [gate.observer()],
      routes: [
        for (final path in [
          '/',
          '/stores',
          '/store/restaurant/catalog',
          '/checkout',
        ])
          GoRoute(
            path: path,
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  Text(path),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          const AlertDialog(title: Text('Existing modal')),
                    ),
                    child: const Text('Open modal'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(gate.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          appRootNavigatorKeyProvider.overrideWithValue(key),
          updateNavigationGateProvider.overrideWithValue(gate),
          appUpdateServiceProvider.overrideWithValue(
            AppUpdateService(
              enabled: true,
              readBuild: () async => '3',
              fetchRelease: () =>
                  response?.future ??
                  Future.value({
                    'enabled': true,
                    'latest_build_number': 4,
                    'latest_version': '1.1.1',
                    'store_url': androidStoreUrl,
                  }),
            ),
          ),
          updateUrlLauncherProvider.overrideWithValue(
            launcher ?? (_) async => true,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('uz'),
          builder: (_, child) =>
              AppUpdateBootstrap(isAppReady: true, child: child!),
        ),
      ),
    );
    return router;
  }

  testWidgets(
    'intro finishes before one optional offer; resume does not repeat',
    (tester) async {
      await mount(tester);
      await tester.pump();
      expect(find.byType(AppUpdateDialog), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Yangilanish mavjud'), findsOneWidget);
      await tester.tap(find.text('Keyinroq'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsNothing);
    },
  );

  testWidgets('defers during checkout then preserves navigation', (
    tester,
  ) async {
    final response = Completer<Object?>();
    final router = await mount(
      tester,
      initial: '/checkout',
      response: response,
    );
    await tester.pumpAndSettle();
    response.complete({
      'enabled': true,
      'latest_build_number': 4,
      'latest_version': '1.1.1',
      'store_url': androidStoreUrl,
    });
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
    router.go('/stores');
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/stores');
  });

  testWidgets('existing modal closes fully before offering update', (
    tester,
  ) async {
    final response = Completer<Object?>();
    final router = await mount(tester, response: response);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open modal'));
    await tester.pumpAndSettle();
    response.complete({
      'enabled': true,
      'latest_build_number': 4,
      'latest_version': '1.1.1',
      'store_url': androidStoreUrl,
    });
    await tester.pumpAndSettle();
    expect(find.text('Existing modal'), findsOneWidget);
    expect(find.byType(AppUpdateDialog), findsNothing);
    router.routerDelegate.navigatorKey.currentState!.pop();
    await tester.pump();
    expect(find.byType(AppUpdateDialog), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
  });

  testWidgets(
    'launcher failure retries and successful launch does not re-offer',
    (tester) async {
      var calls = 0;
      await mount(tester, launcher: (_) async => ++calls > 2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yuklab olish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ilovalar do‘konini ochib'), findsOneWidget);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.byType(AppUpdateDialog), findsNothing);
    },
  );

  testWidgets('three locales fit a 320px screen at 2x text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in [
      const Locale('uz'),
      const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
      const Locale('ru'),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: const Scaffold(body: AppUpdateDialog(release: release)),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          locale.scriptCode == 'Cyrl'
              ? 'Янгиланиш мавжуд'
              : locale.languageCode == 'ru'
              ? 'Доступно обновление'
              : 'Yangilanish mavjud',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('single-submit protection while Play launch is in progress', (
    tester,
  ) async {
    final opening = Completer<bool>();
    var calls = 0;
    await mount(
      tester,
      launcher: (_) {
        calls++;
        return opening.future;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yuklab olish'));
    await tester.pump();
    await tester.tap(find.text('Yuklab olish'));
    expect(calls, 1);
    opening.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('closing form/auth page finishes its reverse transition first', (
    tester,
  ) async {
    final response = Completer<Object?>();
    final router = await mount(tester, response: response);
    await tester.pumpAndSettle();
    unawaited(router.push<void>('/checkout'));
    await tester.pumpAndSettle();
    response.complete({
      'enabled': true,
      'latest_build_number': 4,
      'latest_version': '1.1.1',
      'store_url': androidStoreUrl,
    });
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppUpdateDialog), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
  });

  testWidgets('background response waits until foreground', (tester) async {
    final response = Completer<Object?>();
    await mount(tester, response: response);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    response.complete({
      'enabled': true,
      'latest_build_number': 4,
      'latest_version': '1.1.1',
      'store_url': androidStoreUrl,
    });
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
  });

  testWidgets('barrier dismissal lasts for this launch', (tester) async {
    final router = await mount(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    router.go('/store/restaurant/catalog');
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
  });
}
