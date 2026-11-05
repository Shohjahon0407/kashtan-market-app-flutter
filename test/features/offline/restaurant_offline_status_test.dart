import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/network/connectivity_controller.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/catalog/data/restaurant_offline_repository.dart';
import 'package:beshkashtan_customer/features/catalog/domain/restaurant_offline_sync.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/restaurant_offline_status.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends JsonDiskCache {
  @override
  bool get isPersistentAvailable => true;
}

class _Download extends RestaurantOfflineSync {
  _Download(this.value);
  final RestaurantDownloadState value;
  @override
  RestaurantDownloadState build() => value;
}

class _Offline extends ConnectivityController {
  @override
  ConnectivityState build() => const ConnectivityState(isOffline: true);
}

void main() {
  for (final locale in AppLocale.values) {
    for (final state in const [
      RestaurantDownloadState(),
      RestaurantDownloadState(running: true, done: 12, total: 20),
      RestaurantDownloadState(done: 12, total: 20),
      RestaurantDownloadState(done: 20, total: 20, complete: true),
    ]) {
      testWidgets(
        '${locale.code}: offline status at 320px and 2x font ($state)',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                restaurantOfflineRepositoryProvider.overrideWithValue(
                  RestaurantOfflineRepository(_Storage(), 'test'),
                ),
                restaurantOfflineSyncProvider.overrideWith(
                  () => _Download(state),
                ),
                connectivityControllerProvider.overrideWith(_Offline.new),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                locale: locale.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const Scaffold(body: RestaurantOfflineStatus()),
              ),
            ),
          );
          await tester.pump();
          final context = tester.element(find.byType(RestaurantOfflineStatus));
          final l10n = AppLocalizations.of(context);
          final expected = state.complete
              ? l10n.offlineMenuReady
              : state.running
              ? l10n.offlineMenuSaving(12, 20)
              : state.total > 0
              ? l10n.offlineMenuPartial
              : l10n.offlineMenuWaiting;
          expect(find.text(expected), findsOneWidget);
          expect(find.text(l10n.commonRetry), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
