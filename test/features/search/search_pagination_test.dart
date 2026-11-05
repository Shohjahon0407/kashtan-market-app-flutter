import 'dart:async';

import 'package:beshkashtan_customer/core/config/api_endpoints.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/search/domain/search_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements ApiClient {}

void main() {
  Map<String, dynamic> page(List<String> ids, [String? next]) => {
    'results': [
      for (final id in ids)
        {'id': id, 'name': id, 'store_type': 'household', 'price': '1000'},
    ],
    'next': next,
  };
  test(
    'pagination failure keeps cursor, retry deduplicates and late pages cannot replace new query',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final client = _Client();
      when(
        () => client.get(
          Api.productSearch,
          query: any(named: 'query'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (call) async => page([
          (call.namedArguments[#query] as Map)['q'] as String,
        ], '/next'),
      );
      when(
        () => client.getUrl('/next', cancelToken: any(named: 'cancelToken')),
      ).thenThrow(const NetworkFailure());
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        searchControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(searchControllerProvider.notifier);
      await controller.search('old');
      await controller.loadMore();
      expect(
        container.read(searchControllerProvider).paginationFailure,
        isA<NetworkFailure>(),
      );
      expect(container.read(searchControllerProvider).items.single.id, 'old');
      expect(container.read(searchControllerProvider).nextUrl, '/next');
      when(
        () => client.getUrl('/next', cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) async => page(['old', 'second'], '/next'));
      await controller.loadMore();
      expect(container.read(searchControllerProvider).items.map((x) => x.id), [
        'old',
        'second',
      ]);
      final delayed = Completer<Map<String, dynamic>>();
      when(
        () => client.getUrl('/next', cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) => delayed.future);
      final oldPage = controller.loadMore();
      await controller.search('new');
      delayed.complete(page(['stale']));
      await oldPage;
      expect(container.read(searchControllerProvider).items.single.id, 'new');
      expect(container.read(searchControllerProvider).isLoadingMore, isFalse);
    },
  );
}
