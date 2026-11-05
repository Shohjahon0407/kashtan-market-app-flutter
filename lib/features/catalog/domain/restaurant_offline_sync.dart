import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../../core/storage/product_image_cache.dart';
import '../data/product_models.dart';
import '../data/restaurant_offline_repository.dart';
import 'catalog_controller.dart';

class RestaurantDownloadState {
  const RestaurantDownloadState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.complete = false,
  });
  final bool running, complete;
  final int done, total;
}

final restaurantOfflineSyncProvider =
    NotifierProvider<RestaurantOfflineSync, RestaurantDownloadState>(
      RestaurantOfflineSync.new,
    );

class RestaurantOfflineSync extends Notifier<RestaurantDownloadState> {
  int _generation = 0;
  bool _busy = false;
  bool _syncAgain = false, _forceAgain = false;

  @override
  RestaurantDownloadState build() {
    final repo = ref.watch(restaurantOfflineRepositoryProvider);
    final generation = ++_generation;
    _busy = false;
    _syncAgain = _forceAgain = false;
    ref.onDispose(() => _generation++);
    if (!repo.enabled) return const RestaurantDownloadState();
    listenForConnectionRecovery(ref, () => sync(force: true));
    ref.listen(
      connectivityControllerProvider.select((value) => value.isForeground),
      (previous, next) {
        if (next) unawaited(sync());
      },
    );
    if (repo.enabled) {
      scheduleMicrotask(() async {
        final saved = await repo.storage.read(restaurantSyncKey(repo.scope));
        if (!ref.mounted ||
            generation != _generation ||
            _busy ||
            saved == null) {
          return;
        }
        state = RestaurantDownloadState(
          done: saved['done'] as int? ?? 0,
          total: saved['total'] as int? ?? 0,
          complete: saved['complete'] == true,
        );
      });
    }
    return const RestaurantDownloadState();
  }

  Future<void> sync({bool force = false}) async {
    final repo = ref.read(restaurantOfflineRepositoryProvider);
    final connection = ref.read(connectivityControllerProvider);
    if (!repo.enabled || connection.needsRecovery || !connection.isForeground) {
      return;
    }
    if (_busy) {
      // A reconnect/landing update while the previous run is settling must
      // not get lost. Coalesce all such requests into one following run.
      _syncAgain = true;
      _forceAgain |= force;
      return;
    }
    _busy = true;
    final generation = _generation;
    bool current() => ref.mounted && generation == _generation;
    var done = 0, total = 0;
    var published = false;
    var menuFetched = false;
    var previous = state;
    try {
      final manifest = await repo.storage.readEntry(
        restaurantSyncKey(repo.scope),
      );
      final payload = manifest?.payload;
      if (payload is Map) {
        previous = RestaurantDownloadState(
          done: payload['done'] as int? ?? 0,
          total: payload['total'] as int? ?? 0,
          complete: payload['complete'] == true,
        );
      }
      if (!force &&
          manifest != null &&
          manifest.age < const Duration(minutes: 15) &&
          payload is Map &&
          payload['complete'] == true) {
        if (current()) {
          state = RestaurantDownloadState(
            done: payload['done'] as int? ?? 0,
            total: payload['total'] as int? ?? 0,
            complete: true,
          );
        }
        return;
      }
      if (!current()) return;
      state = const RestaurantDownloadState(running: true);
      final api = ref.read(catalogApiProvider);
      final images = ref.read(productImageCacheProvider);
      final page = await api.downloadRestaurantMenu();
      if (!current()) return;
      menuFetched = true;
      final products = page.items
          .where((p) => p.storeTypeWire == 'restaurant')
          .toList();
      total = products.length;
      var position = 0;
      state = RestaurantDownloadState(running: true, total: total);
      Future<void> worker() async {
        while (current() &&
            position < products.length &&
            ref.read(connectivityControllerProvider).isForeground &&
            !ref.read(connectivityControllerProvider).needsRecovery) {
          final product = products[position++];
          try {
            ProductDetail? detail = await repo.detail(product.id);
            final recent = !force && await repo.isRecent(product.id);
            if (detail == null || !recent) {
              detail = await api.fetchDetail(product.id);
              if (!current()) return;
              await api.downloadRestaurantReviews(product.id);
            }
            if (!current()) return;
            final urls = <String>{
              if (product.imageUrl?.isNotEmpty == true) product.imageUrl!,
              if (detail.product.imageUrl?.isNotEmpty == true)
                detail.product.imageUrl!,
              ...detail.images
                  .map((p) => p.url)
                  .whereType<String>()
                  .where((p) => p.isNotEmpty),
            };
            var savedImages = true;
            for (final url in urls) {
              if (!current()) return;
              savedImages = await images.save(url) && savedImages;
            }
            if (!current()) return;
            if (savedImages &&
                await repo.detail(product.id) != null &&
                await repo.reviews(product.id) != null) {
              done++;
            }
          } on Object {
            /* Previous good snapshots remain usable. */
          }
          if (current()) {
            state = RestaurantDownloadState(
              running: true,
              done: done,
              total: total,
            );
          }
        }
      }

      await Future.wait([worker(), worker()]);
      if (!current()) return;
      final landing = await repo.landing();
      final previewUrls = <String>{};
      void collect(Object? value) {
        if (value is Map) {
          for (final entry in value.entries) {
            if (const {
                  'image',
                  'image_url',
                  'main_image',
                }.contains(entry.key) &&
                entry.value is String) {
              final url = AppConfig.resolveMediaUrl(entry.value as String);
              if (url != null && url.isNotEmpty) previewUrls.add(url);
            } else if (entry.key == 'preview_images' && entry.value is List) {
              for (final raw in (entry.value as List).whereType<String>()) {
                final url = AppConfig.resolveMediaUrl(raw);
                if (url != null && url.isNotEmpty) previewUrls.add(url);
              }
            } else {
              collect(entry.value);
            }
          }
        } else if (value is List) {
          for (final child in value) {
            collect(child);
          }
        }
      }

      collect(landing);
      var previewReady = true;
      final urls = previewUrls.toList();
      var nextImage = 0;
      Future<void> savePreviews() async {
        while (current() && nextImage < urls.length) {
          final connection = ref.read(connectivityControllerProvider);
          if (!connection.isForeground || connection.needsRecovery) {
            previewReady = false;
            return;
          }
          final saved = await images.save(urls[nextImage++]);
          if (!saved) previewReady = false;
        }
      }

      await Future.wait([savePreviews(), savePreviews()]);
      if (!current()) return;
      // A disk-full write must not report a successful complete download.
      final menu = await repo.products();
      final complete =
          done == total &&
          menu != null &&
          menu.items.length == total &&
          landing != null &&
          previewReady;
      await repo.storage.write(restaurantSyncKey(repo.scope), {
        'done': done,
        'total': total,
        'complete': complete,
      });
      if (!current()) return;
      state = RestaurantDownloadState(
        done: done,
        total: total,
        complete: complete,
      );
      published = true;
      ref.read(restaurantOfflineRevisionProvider.notifier).refresh();
    } on Object {
      if (current()) {
        state = menuFetched
            ? RestaurantDownloadState(done: done, total: total)
            : previous;
      }
    } finally {
      if (current()) {
        _busy = false;
        if (!published && state.running) {
          state = RestaurantDownloadState(done: done, total: total);
        }
        if (_syncAgain) {
          final forced = _forceAgain;
          _syncAgain = _forceAgain = false;
          unawaited(sync(force: forced));
        }
      }
    }
  }
}
