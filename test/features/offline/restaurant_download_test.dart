import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/product_image_cache.dart';
import 'package:beshkashtan_customer/core/storage/product_image_files.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/restaurant_offline_repository.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/domain/restaurant_offline_sync.dart';
import 'package:dio/dio.dart';
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _product(String id, String price) => {
  'id': id,
  'name': 'Taom $id',
  'price': price,
  'store_type': 'restaurant',
  'unit_display': 'porsiya',
  'main_image': 'https://media.test/$id.jpg',
  'category': {
    'id': 'child',
    'name': 'Taomlar',
    'parent': 'parent',
    'store_type': 'restaurant',
  },
  'images': [
    {'id': 'extra-$id', 'image': 'https://media.test/$id-extra.jpg'},
  ],
  'can_review': true,
};

class _Server implements HttpClientAdapter {
  bool offline = false, failSecondPage = false, paginatedReviews = false;
  String price = '40000.00';
  int calls = 0, active = 0, peak = 0;
  final Map<String, int> paths = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    active++;
    if (active > peak) peak = active;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    try {
      final path = options.uri.path;
      paths[path] = (paths[path] ?? 0) + 1;
      Object payload;
      var status = 200;
      if (path.endsWith('/products/')) {
        final second = options.uri.queryParameters['cursor'] == 'second';
        if (second && failSecondPage) {
          payload = {'detail': 'not available'};
          status = 400;
        } else {
          payload = {
            'results': [
              if (!second) _product('a', price),
              if (second) _product('b', price),
            ],
            'next': second
                ? null
                : 'https://api.beshkashtan.uz/api/user/catalog/products/?cursor=second',
          };
        }
      } else if (path.endsWith('/reviews/')) {
        final second = options.uri.queryParameters['cursor'] == 'second';
        payload = {
          'count': paginatedReviews ? 2 : 1,
          'next': paginatedReviews && !second
              ? 'https://api.beshkashtan.uz$path?cursor=second'
              : null,
          'results': [
            {
              'id': second ? 'r2' : 'r1',
              'user_id': 'user-review',
              'user_name': 'Mijoz',
              'rating': 5,
              'comment': 'Mazali',
              'created_at': '2026-10-29T10:00:00Z',
            },
          ],
        };
      } else {
        final id = path.split('/').where((part) => part.isNotEmpty).last;
        payload = _product(id, price);
      }
      return ResponseBody.fromString(
        jsonEncode(payload),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    } finally {
      active--;
    }
  }

  @override
  void close({bool force = false}) {}
}

class _Images extends Fake implements ProductImageCache {
  final Set<String> saved = {}, failures = {};
  @override
  Future<bool> save(String url) async {
    if (failures.contains(url)) return false;
    saved.add(url);
    return true;
  }
}

ApiClient _client(_Server server) => ApiClient.create(
  tokenStore: InMemoryTokenStore(),
  apiLang: () => 'uz',
  script: () => UzScript.none,
  refresh: (_) async => null,
  onSessionExpired: () async {},
  adapter: server,
  isOffline: () => server.offline,
);

void main() {
  late Directory root;
  late PrefsStore prefs;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('restaurant-download-test-');
    SharedPreferences.setMockInitialValues({});
    prefs = await PrefsStore.load();
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  RestaurantOfflineRepository repository([String scope = 'guest_uz_latin']) =>
      RestaurantOfflineRepository(
        JsonDiskCache(
          directoryOverride: Directory('${root.path}/app-support/data'),
          retention: null,
        ),
        scope,
      );

  Future<void> seedLanding(RestaurantOfflineRepository repo) =>
      repo.saveLanding({
        'categories': [
          {'id': 'parent', 'name': 'Menyu'},
          {
            'id': 'child',
            'name': 'Taomlar',
            'parent': 'parent',
            'preview_images': ['https://media.test/a-thumb.jpg'],
            'preview_products': [
              {'id': 'b', 'image': 'https://media.test/b-thumb.jpg'},
            ],
          },
        ],
      });

  ProviderContainer container(
    RestaurantOfflineRepository repo,
    CatalogApi api,
    _Images images,
  ) => ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      restaurantOfflineRepositoryProvider.overrideWithValue(repo),
      catalogApiProvider.overrideWithValue(api),
      productImageCacheProvider.overrideWithValue(images),
    ],
  );

  test(
    'whole menu, details, ratings, comments and images survive restart offline without requests',
    () async {
      final repo = repository();
      await seedLanding(repo);
      final server = _Server();
      final api = CatalogApi(_client(server), offline: repo);
      final images = _Images();
      final first = container(repo, api, images);
      await first.read(restaurantOfflineSyncProvider.notifier).sync();
      final state = first.read(restaurantOfflineSyncProvider);
      expect(state.complete, isTrue);
      expect(state.done, 2);
      expect(state.total, 2);
      expect(images.saved, hasLength(6));
      expect(images.saved, contains('https://media.test/a-thumb.jpg'));
      expect(images.saved, contains('https://media.test/b-thumb.jpg'));
      expect(server.peak, lessThanOrEqualTo(2));
      final originalCalls = server.calls;
      await first.read(restaurantOfflineSyncProvider.notifier).sync();
      expect(
        server.calls,
        originalCalls,
      ); // no duplicate download within 15 min
      first.dispose();

      // New objects mimic a process restart: no route/provider memory remains.
      server.offline = true;
      final restored = repository();
      final secondApi = CatalogApi(_client(server), offline: restored);
      final second = container(restored, secondApi, images);
      addTearDown(second.dispose);
      final menu = await secondApi.fetchProducts(
        storeType: 'restaurant',
        categoryId: 'parent',
      );
      expect(menu.items.map((p) => p.id), ['a', 'b']);
      expect(menu.nextUrl, isNull);
      for (final id in ['a', 'b']) {
        final detailSubscription = second.listen(
          restaurantProductDetailProvider(id),
          (_, _) {},
        );
        final reviewsSubscription = second.listen(
          restaurantProductReviewsProvider(id),
          (_, _) {},
        );
        final dish = await second.read(
          restaurantProductDetailProvider(id).future,
        );
        final reviews = await second.read(
          restaurantProductReviewsProvider(id).future,
        );
        expect(dish.product.price, '40000.00');
        expect(dish.images.single.url, contains('$id-extra.jpg'));
        expect(reviews.single.rating, 5);
        expect(reviews.single.comment, 'Mazali');
        detailSubscription.close();
        reviewsSubscription.close();
      }
      expect(server.calls, originalCalls);
      final manifest = await restored.storage.read(
        restaurantSyncKey(restored.scope),
      );
      expect(manifest?['complete'], isTrue);
    },
  );

  test(
    'failed images keep download partial; resume does not reload good details',
    () async {
      final repo = repository();
      await seedLanding(repo);
      final server = _Server();
      final api = CatalogApi(_client(server), offline: repo);
      final images = _Images()..failures.add('https://media.test/b-extra.jpg');
      final app = container(repo, api, images);
      addTearDown(app.dispose);
      await app.read(restaurantOfflineSyncProvider.notifier).sync();
      expect(app.read(restaurantOfflineSyncProvider).complete, isFalse);
      expect(app.read(restaurantOfflineSyncProvider).done, 1);
      final detailsBefore = server.paths['/api/user/catalog/products/a/'];
      images.failures.clear();
      await app.read(restaurantOfflineSyncProvider.notifier).sync();
      expect(app.read(restaurantOfflineSyncProvider).complete, isTrue);
      expect(server.paths['/api/user/catalog/products/a/'], detailsBefore);
    },
  );

  test(
    'successful sync refreshes price; failed cursor never replaces complete menu with a partial page',
    () async {
      final repo = repository();
      await seedLanding(repo);
      final server = _Server();
      final api = CatalogApi(_client(server), offline: repo);
      final app = container(repo, api, _Images());
      addTearDown(app.dispose);
      await app.read(restaurantOfflineSyncProvider.notifier).sync();
      server.price = '45000.00';
      await app.read(restaurantOfflineSyncProvider.notifier).sync(force: true);
      expect((await repo.detail('a'))?.product.price, '45000.00');
      server.price = '99999.00';
      server.failSecondPage = true;
      await app.read(restaurantOfflineSyncProvider.notifier).sync(force: true);
      final saved = await repo.products();
      expect(saved?.items, hasLength(2));
      expect(saved!.items.first.price, '45000.00');
      expect(app.read(restaurantOfflineSyncProvider).complete, isTrue);
    },
  );

  test(
    'account and language snapshots never share personal review eligibility',
    () async {
      final owner = repository('user_a_uz_latin');
      await owner.saveDetail('a', _product('a', '40000'));
      expect((await owner.detail('a'))?.canReview, isTrue);
      expect(await repository('user_b_uz_latin').detail('a'), isNull);
      expect(await repository('user_a_ru_latin').detail('a'), isNull);
    },
  );

  test('concurrent detail requests are single-flight', () async {
    final server = _Server();
    final api = CatalogApi(_client(server), offline: repository());
    await Future.wait([api.fetchDetail('a'), api.fetchDetail('a')]);
    expect(server.paths['/api/user/catalog/products/a/'], 1);
  });

  test(
    'every review page is saved, including comments beyond page one',
    () async {
      final repo = repository();
      final server = _Server()..paginatedReviews = true;
      final api = CatalogApi(_client(server), offline: repo);
      final reviews = await api.downloadRestaurantReviews('a');
      expect(reviews.items.map((review) => review.id), ['r1', 'r2']);
      expect(reviews.nextUrl, isNull);
      final restored = await repository().reviews('a');
      expect(restored?.items.map((review) => review.id), ['r1', 'r2']);
      await api.fetchReviews('a');
      expect((await repository().reviews('a'))?.items, hasLength(2));
    },
  );

  test(
    'a fresh first review page is not a complete offline download',
    () async {
      final repo = repository();
      await seedLanding(repo);
      final server = _Server()..paginatedReviews = true;
      final api = CatalogApi(_client(server), offline: repo);
      await api.fetchDetail('a');
      await api.fetchReviews('a');
      expect(await repo.isRecent('a'), isFalse);
      final app = container(repo, api, _Images());
      addTearDown(app.dispose);
      await app.read(restaurantOfflineSyncProvider.notifier).sync();
      expect(app.read(restaurantOfflineSyncProvider).complete, isTrue);
      expect((await repo.reviews('a'))?.items, hasLength(2));
    },
  );

  test(
    'an interrupted preview download cannot claim the menu is complete',
    () async {
      final repo = repository();
      await seedLanding(repo);
      final server = _Server();
      final api = CatalogApi(_client(server), offline: repo);
      final images = _Images()..failures.add('https://media.test/a-thumb.jpg');
      final app = container(repo, api, images);
      addTearDown(app.dispose);
      await app.read(restaurantOfflineSyncProvider.notifier).sync();
      expect(app.read(restaurantOfflineSyncProvider).done, 2);
      expect(app.read(restaurantOfflineSyncProvider).complete, isFalse);
      images.failures.clear();
      await app.read(restaurantOfflineSyncProvider.notifier).sync();
      expect(app.read(restaurantOfflineSyncProvider).complete, isTrue);
    },
  );

  test(
    'image bytes use app-support files, survive manager recreation and temporary-cache removal',
    () async {
      final directory = const LocalFileSystem().directory(
        '${root.path}/app-support/images',
      );
      await directory.create(recursive: true);
      CacheManager manager() => CacheManager(
        Config(
          'offline-image-test',
          fileSystem: ProductImageFiles(directory: Future.value(directory)),
          repo: JsonCacheInfoRepository.withFile(
            directory.childFile('index.json'),
          ),
          stalePeriod: const Duration(days: 3650),
          maxNrOfCacheObjects: 5000,
        ),
      );
      final first = manager();
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final file = await first.putFile(
        'https://media.test/a.jpg',
        bytes,
        fileExtension: 'png',
      );
      expect(file.path, contains('/app-support/images/'));
      // CacheManager.putFile schedules its metadata insert without awaiting
      // it. Let the repository settle before simulating a clean shutdown.
      await Future<void>.delayed(Duration.zero);
      await first.dispose();
      final temporary = Directory('${root.path}/temporary-cache');
      await temporary.create();
      await temporary.delete(recursive: true);
      final restored = manager();
      addTearDown(restored.dispose);
      final info = await restored.getFileFromCache('https://media.test/a.jpg');
      expect(info, isNotNull);
      expect(await info!.file.readAsBytes(), bytes);
    },
  );
}
