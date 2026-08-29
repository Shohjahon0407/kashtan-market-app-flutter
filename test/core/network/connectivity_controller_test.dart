import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/connectivity_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> initialPrefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await PrefsStore.load();
  final container = ProviderContainer(
    overrides: [prefsStoreProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'tarmoq xatosi offline holatga o‘tkazadi, muvaffaqiyat qaytaradi',
    () async {
      final container = await _container();
      final notifier = container.read(connectivityControllerProvider.notifier);
      expect(container.read(isOfflineProvider), isFalse);

      notifier.reportNetworkFailure();
      expect(container.read(isOfflineProvider), isTrue);

      notifier.reportSuccess();
      expect(container.read(isOfflineProvider), isFalse);
      expect(
        container.read(connectivityControllerProvider).lastSyncAt,
        isNotNull,
      );
    },
  );

  test('online qaytganda reconnect tinglovchisi chaqiriladi', () async {
    final container = await _container();
    final notifier = container.read(connectivityControllerProvider.notifier);
    var reconnects = 0;
    notifier.addReconnectListener(() => reconnects++);

    notifier.reportNetworkFailure();
    expect(reconnects, 0);
    notifier.reportSuccess();
    expect(reconnects, 1);

    // Online holatida takroriy muvaffaqiyat qayta ishga tushirmaydi.
    notifier.reportSuccess();
    expect(reconnects, 1);
  });

  test(
    'offline + 1 kundan eski sinxronizatsiya → eski ma‘lumot belgisi',
    () async {
      final old = DateTime.now().subtract(const Duration(days: 2));
      final container = await _container({
        'net.last_sync_at': old.toIso8601String(),
      });
      final notifier = container.read(connectivityControllerProvider.notifier);

      // Online bo'lsa "eski" belgisi chiqmaydi.
      expect(container.read(connectivityControllerProvider).isStale, isFalse);

      notifier.reportNetworkFailure();
      expect(container.read(connectivityControllerProvider).isStale, isTrue);
    },
  );

  test('offline, lekin kesh yangi → eski ma‘lumot belgisi yo‘q', () async {
    final recent = DateTime.now().subtract(const Duration(hours: 2));
    final container = await _container({
      'net.last_sync_at': recent.toIso8601String(),
    });
    container
        .read(connectivityControllerProvider.notifier)
        .reportNetworkFailure();

    final state = container.read(connectivityControllerProvider);
    expect(state.isOffline, isTrue);
    expect(state.isStale, isFalse);
  });
}
