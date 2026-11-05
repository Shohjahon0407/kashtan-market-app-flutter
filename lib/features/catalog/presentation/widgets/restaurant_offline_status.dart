import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_controller.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/restaurant_offline_repository.dart';
import '../../domain/restaurant_offline_sync.dart';

class RestaurantOfflineStatus extends ConsumerWidget {
  const RestaurantOfflineStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(restaurantOfflineRepositoryProvider).enabled) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(restaurantOfflineSyncProvider);
    final offline = ref.watch(connectivityControllerProvider).needsRecovery;
    final l10n = AppLocalizations.of(context);
    final text = state.complete
        ? l10n.offlineMenuReady
        : state.running
        ? (state.total == 0
              ? l10n.commonLoading
              : l10n.offlineMenuSaving(state.done, state.total))
        : state.total > 0
        ? l10n.offlineMenuPartial
        : l10n.offlineMenuWaiting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                state.complete
                    ? Icons.offline_pin_outlined
                    : Icons.download_for_offline_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              if (!state.running && !state.complete && !offline)
                TextButton(
                  onPressed: () =>
                      ref.read(restaurantOfflineSyncProvider.notifier).sync(),
                  child: Text(l10n.commonRetry),
                ),
            ],
          ),
          if (state.running)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                minHeight: 2,
                value: state.total == 0
                    ? null
                    : (state.done / state.total).clamp(0, 1),
              ),
            ),
        ],
      ),
    );
  }
}
