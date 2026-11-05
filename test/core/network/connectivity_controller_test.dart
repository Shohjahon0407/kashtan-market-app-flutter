import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/connectivity_controller.dart';
import 'package:beshkashtan_customer/core/network/connectivity_probe.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/ui/offline/offline_banner.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Platform extends Mock implements Connectivity {
  final changes = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> current = [ConnectivityResult.wifi];
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
  void emit(List<ConnectivityResult> value) {
    current = value;
    changes.add(value);
  }
}

class _Probe extends Mock implements ConnectivityProbe {
  int calls = 0;
  int cancellations = 0;
  Future<ProbeResult> Function() run = () async => ProbeResult.healthy;
  @override
  Future<ProbeResult> check() {
    calls++;
    return run();
  }

  @override
  void cancel() {
    cancellations++;
  }
}

Future<(ProviderContainer, _Platform, _Probe)> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final platform = _Platform();
  final probe = _Probe();
  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      connectivityProbeProvider.overrideWithValue(probe),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await platform.changes.close();
  });
  return (container, platform, probe);
}

void main() {
  for (final locale in [
    const Locale('uz'),
    const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    const Locale('ru'),
  ]) {
    testWidgets('server-unavailable banner retries and disappears ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (container, platform, probe) = await _setup();
      probe.run = () async => ProbeResult.unreachable;
      await container
          .read(connectivityControllerProvider.notifier)
          .start(connectivity: platform);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ScriptFallbackDelegate<MaterialLocalizations>(
                GlobalMaterialLocalizations.delegate,
                Locale('uz'),
              ),
              ScriptFallbackDelegate<CupertinoLocalizations>(
                GlobalCupertinoLocalizations.delegate,
                Locale('uz'),
              ),
              ScriptFallbackDelegate<WidgetsLocalizations>(
                GlobalWidgetsLocalizations.delegate,
                Locale('uz'),
              ),
            ],
            home: const OfflineBanner(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(OfflineBanner)),
      );
      expect(find.text(l10n.connectionServerUnavailable), findsOneWidget);
      expect(
        l10n.connectionServerUnavailable,
        isNot(matches(RegExp(r'server|сервер|debug', caseSensitive: false))),
      );
      expect(tester.takeException(), isNull);
      final pending = Completer<ProbeResult>();
      probe.run = () => pending.future;
      final count = probe.calls;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(probe.calls, count + 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(ProbeResult.healthy);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );
      expect(container.read(connectivityControllerProvider).isOffline, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });
  }

  test(
    'single timeout does not set offline; healthy probe keeps requests enabled',
    () async {
      final (container, platform, probe) = await _setup();
      final controller = container.read(
        connectivityControllerProvider.notifier,
      );
      await controller.start(connectivity: platform);
      final pending = Completer<ProbeResult>();
      probe.run = () => pending.future;
      controller.reportNetworkFailure();
      expect(container.read(isOfflineProvider), isFalse);
      pending.complete(ProbeResult.healthy);
      await controller.recheck();
      expect(container.read(isOfflineProvider), isFalse);
      expect(
        container.read(connectivityControllerProvider).needsRecovery,
        isFalse,
      );
    },
  );

  testWidgets('none → Wi-Fi within 1s never hard-blocks requests', (
    tester,
  ) async {
    final (container, platform, probe) = await _setup();
    final controller = container.read(connectivityControllerProvider.notifier);
    await controller.start(connectivity: platform);
    probe.run = () async => ProbeResult.unreachable;
    platform.emit([ConnectivityResult.none]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(isOfflineProvider), isFalse);
    probe.run = () async => ProbeResult.healthy;
    platform.emit([ConnectivityResult.mobile]);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(isOfflineProvider), isFalse);
    expect(
      container.read(connectivityControllerProvider).needsRecovery,
      isFalse,
    );
  });

  testWidgets('offline requires debounced none and failed independent probe', (
    tester,
  ) async {
    final (container, platform, probe) = await _setup();
    final controller = container.read(connectivityControllerProvider.notifier);
    await controller.start(connectivity: platform);
    probe.run = () async => ProbeResult.unreachable;
    platform.emit([ConnectivityResult.none]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    expect(container.read(isOfflineProvider), isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.read(isOfflineProvider), isTrue);
    probe.run = () async => ProbeResult.healthy;
    await controller.recheck(); // Works even if the plugin still reports none.
    await tester.pump();
    expect(container.read(isOfflineProvider), isFalse);
    container.dispose();
    await tester.pump();
  });

  testWidgets('Wi-Fi → mobile probes without an intermediate none event', (
    tester,
  ) async {
    final (container, platform, probe) = await _setup();
    final controller = container.read(connectivityControllerProvider.notifier);
    await controller.start(connectivity: platform);
    final before = probe.calls;
    platform.emit([ConnectivityResult.mobile]);
    await tester.pump();
    expect(probe.calls, before + 1);
  });

  testWidgets('resume during a cancelled probe schedules a fresh check', (
    tester,
  ) async {
    final (container, platform, probe) = await _setup();
    final controller = container.read(connectivityControllerProvider.notifier);
    await controller.start(connectivity: platform);
    final cancelled = Completer<ProbeResult>();
    probe.run = () => cancelled.future;
    controller.reportNetworkFailure();
    final before = probe.calls;
    controller.setForeground(false);
    probe.run = () async => ProbeResult.healthy;
    controller.setForeground(true);
    await tester.pump();
    cancelled.complete(ProbeResult.unreachable);
    await tester.pump();
    expect(probe.calls, before + 1);
    expect(
      container.read(connectivityControllerProvider).needsRecovery,
      isFalse,
    );
  });

  test('Wi-Fi + failed probe shows server-unavailable, not offline', () async {
    final (container, platform, probe) = await _setup();
    probe.run = () async => ProbeResult.unreachable;
    await container
        .read(connectivityControllerProvider.notifier)
        .start(connectivity: platform);
    final state = container.read(connectivityControllerProvider);
    expect(state.isOffline, isFalse);
    expect(state.isServerUnavailable, isTrue);
  });

  test(
    'HTTP errors do not prove Internet loss or refresh cached-data timestamp',
    () async {
      final (container, platform, _) = await _setup();
      final controller = container.read(
        connectivityControllerProvider.notifier,
      );
      await controller.start(connectivity: platform);
      for (final status in [400, 401, 403, 429, 500, 503]) {
        controller.reportHttpResponse(status);
        expect(container.read(isOfflineProvider), isFalse);
        expect(
          container.read(connectivityControllerProvider).lastSyncAt,
          isNull,
        );
      }
      controller.reportSuccess();
      expect(
        container.read(connectivityControllerProvider).needsRecovery,
        isFalse,
      );
      expect(
        container.read(connectivityControllerProvider).lastSyncAt,
        isNotNull,
      );
    },
  );

  test(
    'concurrent manual checks are single-flight; startup is idempotent',
    () async {
      final (container, platform, probe) = await _setup();
      final controller = container.read(
        connectivityControllerProvider.notifier,
      );
      await controller.start(connectivity: platform);
      final before = probe.calls;
      final pending = Completer<ProbeResult>();
      probe.run = () => pending.future;
      final checks = [
        controller.recheck(),
        controller.recheck(),
        controller.recheck(),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(probe.calls, before + 1);
      await controller.start(connectivity: platform);
      expect(probe.calls, before + 1);
      pending.complete(ProbeResult.healthy);
      await Future.wait(checks);
    },
  );

  test('late failed probe cannot replace newer API success', () async {
    final (container, platform, probe) = await _setup();
    final controller = container.read(connectivityControllerProvider.notifier);
    await controller.start(connectivity: platform);
    final pending = Completer<ProbeResult>();
    probe.run = () => pending.future;
    final check = controller.recheck();
    await Future<void>.delayed(Duration.zero);
    controller.reportSuccess();
    pending.complete(ProbeResult.unreachable);
    await check;
    expect(
      container.read(connectivityControllerProvider).needsRecovery,
      isFalse,
    );
  });

  testWidgets('5/10/20/30s retries recover without a platform event', (
    tester,
  ) async {
    final (container, platform, probe) = await _setup();
    probe.run = () async => ProbeResult.unreachable;
    final controller = container.read(connectivityControllerProvider.notifier);
    await controller.start(connectivity: platform);
    var count = probe.calls;
    for (final seconds in [5, 10, 20, 30]) {
      await tester.pump(Duration(seconds: seconds - 1));
      expect(probe.calls, count);
      await tester.pump(const Duration(seconds: 1));
      expect(probe.calls, ++count);
    }
    probe.run = () async => ProbeResult.healthy;
    await tester.pump(const Duration(seconds: 30));
    expect(
      container.read(connectivityControllerProvider).needsRecovery,
      isFalse,
    );
    count = probe.calls;
    await tester.pump(const Duration(minutes: 1));
    expect(probe.calls, count);
  });

  testWidgets('background pauses checks; resume probes even for guests', (
    tester,
  ) async {
    final (container, platform, probe) = await _setup();
    probe.run = () async => ProbeResult.unreachable;
    final controller = container.read(connectivityControllerProvider.notifier);
    await controller.start(connectivity: platform);
    controller.setForeground(false);
    final count = probe.calls;
    await tester.pump(const Duration(minutes: 1));
    expect(probe.calls, count);
    probe.run = () async => ProbeResult.healthy;
    controller.setForeground(true);
    await tester.pump();
    expect(probe.calls, count + 1);
    expect(
      container.read(connectivityControllerProvider).needsRecovery,
      isFalse,
    );
  });

  test(
    'recovery listeners fire once; health probe does not update lastSyncAt',
    () async {
      final (container, platform, probe) = await _setup();
      probe.run = () async => ProbeResult.unreachable;
      final controller = container.read(
        connectivityControllerProvider.notifier,
      );
      var reconnects = 0;
      controller.addReconnectListener(() => reconnects++);
      await controller.start(connectivity: platform);
      probe.run = () async => ProbeResult.healthy;
      await controller.recheck();
      await controller.recheck();
      expect(reconnects, 1);
      expect(container.read(connectivityControllerProvider).lastSyncAt, isNull);
    },
  );

  test('cache stale state depends on data age, not health-probe time', () {
    expect(
      ConnectivityState(
        isOffline: true,
        lastSyncAt: DateTime.now().subtract(const Duration(days: 2)),
      ).isStale,
      isTrue,
    );
    expect(
      ConnectivityState(
        isServerUnavailable: true,
        lastSyncAt: DateTime.now().subtract(const Duration(hours: 2)),
      ).isStale,
      isFalse,
    );
  });

  test(
    'disposing during a probe cancels work and tolerates its late result',
    () async {
      final (container, platform, probe) = await _setup();
      final controller = container.read(
        connectivityControllerProvider.notifier,
      );
      await controller.start(connectivity: platform);
      final pending = Completer<ProbeResult>();
      probe.run = () => pending.future;
      final check = controller.recheck();
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      pending.complete(ProbeResult.unreachable);
      await check;
      expect(probe.cancellations, greaterThan(0));
    },
  );
}
