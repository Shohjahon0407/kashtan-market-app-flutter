import 'dart:io';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/domain/household_category_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _raw(
  String id, {
  String type = 'household',
  bool image = true,
}) => {
  'id': id,
  'name': id,
  'store_type': type,
  'price': '50000',
  if (image) 'main_image': 'https://example.test/$id.jpg',
};
ProductSummary _product(
  String id, {
  String type = 'household',
  bool image = true,
}) => ProductSummary.fromJson(_raw(id, type: type, image: image));

class _Api extends Fake implements CatalogApi {
  final calls = <(String, String?)>[];
  bool failRequests = false;
  @override
  Future<CursorPage<ProductSummary>> fetchProducts({
    required String storeType,
    String? categoryId,
    String query = '',
    String? nextUrl,
  }) async {
    calls.add((storeType, categoryId));
    if (failRequests) throw const NetworkFailure();
    return CursorPage(
      items: [
        for (var i = 0; i < 10; i++) _product('$categoryId-${calls.length}-$i'),
      ],
      nextUrl: 'not-followed',
    );
  }
}

class _Owner extends Notifier<String> {
  @override
  String build() => 'guest';
  void change() => state = 'another-account';
}

final _owner = NotifierProvider<_Owner, String>(_Owner.new);

Future<ProviderContainer> _container(_Api api, {JsonDiskCache? cache}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      apiLangProvider.overrideWithValue('uz'),
      cacheKeySuffixProvider.overrideWithValue(() => 'uz_latin'),
      accountScopeProvider.overrideWith((ref) => ref.watch(_owner)),
      jsonDiskCacheProvider.overrideWithValue(cache ?? JsonDiskCache()),
      catalogApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'failed previews do not retry merely because a row is revisited',
    () async {
      final api = _Api()..failRequests = true;
      final container = await _container(api);
      final provider = householdCategoryPreviewsProvider('tools');
      final subscription = container.listen(provider, (_, _) {});
      await expectLater(
        container.read(provider.future),
        throwsA(isA<NetworkFailure>()),
      );
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      final again = container.listen(provider, (_, _) {});
      addTearDown(again.close);
      expect(container.read(provider).hasError, isTrue);
      expect(api.calls.length, 1);
      api.failRequests = false;
      container.invalidate(provider);
      expect((await container.read(provider.future)).length, 6);
      expect(api.calls.length, 2);
    },
  );
  test('previews deduplicate and cap six actual household image products', () {
    final result = householdPreviewProducts([
      _product('no-photo', image: false),
      _product('restaurant', type: 'restaurant'),
      _product('0'),
      _product('0'),
      for (var i = 1; i < 20; i++) _product('$i'),
    ]);
    expect(result.map((p) => p.id), ['0', '1', '2', '3', '4', '5']);
  });

  test(
    'one category-scoped request is reused after scroll; refresh reloads only requested category',
    () async {
      final api = _Api();
      final container = await _container(api);
      final tools = householdCategoryPreviewsProvider('tools');
      final subscription = container.listen(tools, (_, _) {});
      final first = await container.read(tools.future);
      expect(first.length, 6);
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      final again = container.listen(tools, (_, _) {});
      addTearDown(again.close);
      expect(await container.read(tools.future), same(first));
      expect(api.calls, [('household', 'tools')]);
      container.invalidate(tools);
      await container.read(tools.future);
      expect(api.calls, [('household', 'tools'), ('household', 'tools')]);
    },
  );

  test(
    'cached category summaries remain usable offline without new API or invented products',
    () async {
      final dir = await Directory.systemTemp.createTemp('xozmak-preview-test-');
      addTearDown(() => dir.delete(recursive: true));
      final cache = JsonDiskCache(directoryOverride: dir);
      await cache.write(
        catalogCategoryCacheKey('household', 'tools', 'uz_latin'),
        {
          'results': [_raw('saved')],
          'next': null,
        },
      );
      final api = _Api()..failRequests = true;
      final container = await _container(api, cache: cache);
      final provider = householdCategoryPreviewsProvider('tools');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      expect((await container.read(provider.future)).single.id, 'saved');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).value!.single.id, 'saved');
      expect(container.read(provider).hasError, isFalse);
      expect(api.calls, [('household', 'tools')]);
    },
  );

  test('account change invalidates retained previews', () async {
    final api = _Api();
    final container = await _container(api);
    final provider = householdCategoryPreviewsProvider('tools');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final first = await container.read(provider.future);
    container.read(_owner.notifier).change();
    final second = await container.read(provider.future);
    expect(api.calls.length, 2);
    expect(second.first.id, isNot(first.first.id));
  });
}
