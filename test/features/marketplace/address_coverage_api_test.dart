import 'dart:async';
import 'dart:convert';

import 'package:beshkashtan_customer/core/config/app_config.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/address_delivery_boundary.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object> _branch(String id, int radius) => {
  'id': id,
  'name': id,
  'latitude': '41.306913',
  'longitude': '69.562260',
  'delivery_radius_km': '$radius.00',
  'is_active': true,
};

class _Adapter implements HttpClientAdapter {
  final paths = <String>[];
  int coverageStatus = 400;
  bool failedBranch = false, paginated = false, foreignNext = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    final path = options.uri.path;
    paths.add(path);
    Object body;
    int status = 200;
    if (path.endsWith('/delivery/coverage/')) {
      status = coverageStatus;
      body = coverageStatus == 200
          ? {
              'branches': [_branch('new', 12)],
            }
          : {
              'store_type': ['This field is required.'],
            };
    } else if (path.endsWith('/stores/')) {
      final second = options.uri.queryParameters['page'] == '2';
      body = {
        'count': 2,
        'next': foreignNext
            ? 'https://untrusted.invalid/api/user/stores/?page=2'
            : paginated && !second
            ? '${AppConfig.apiBaseUrl}/stores/?page=2'
            : null,
        'results': second
            ? [
                {'id': 's2'},
              ]
            : [
                {'id': 's1'},
                if (!paginated) {'id': 's2'},
                {'id': 'hidden', 'is_visible_in_app': false},
              ],
      };
    } else if (path.endsWith('/s1/branches/')) {
      body = [_branch('small', 2)];
    } else if (path.endsWith('/s2/branches/')) {
      if (failedBranch) {
        status = 404;
        body = {'detail': 'Not found'};
      } else {
        body = [
          _branch('large', 8),
          {..._branch('inactive', 100), 'is_active': false},
          {'id': 'missing-radius', 'latitude': 41, 'longitude': 69},
        ];
      }
    } else {
      throw StateError('Unexpected path $path');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_Adapter adapter) => ApiClient.create(
  tokenStore: InMemoryTokenStore(access: 'test-access'),
  apiLang: () => 'uz',
  script: () => UzScript.none,
  refresh: (_) async => null,
  onSessionExpired: () async {},
  adapter: adapter,
);

class _PendingApi extends CheckoutApi {
  _PendingApi(super.client);
  int calls = 0;
  final pending = Completer<List<DeliveryCoverageBranch>>();
  @override
  Future<List<DeliveryCoverageBranch>> fetchAddressCoverage() {
    calls++;
    return pending.future;
  }
}

void main() {
  test('new coverage API is used without extra store requests', () async {
    final adapter = _Adapter()..coverageStatus = 200;
    final result = await CheckoutApi(_client(adapter)).fetchAddressCoverage();
    expect(result.single.radiusKm, 12);
    expect(adapter.paths, hasLength(1));
  });

  for (final status in [400, 404]) {
    test(
      'old API $status uses actual public branch radii, not an invented default',
      () async {
        final adapter = _Adapter()..coverageStatus = status;
        final result = await CheckoutApi(
          _client(adapter),
        ).fetchAddressCoverage();
        expect(largestAddressCoverage(result)!.radiusKm, 8);
        expect(result.map((b) => b.id), ['small', 'large', 'missing-radius']);
        expect(adapter.paths, hasLength(4));
      },
    );
  }

  test(
    'public fallback follows all store pages before choosing largest',
    () async {
      final adapter = _Adapter()..paginated = true;
      final result = await CheckoutApi(_client(adapter)).fetchAddressCoverage();
      expect(largestAddressCoverage(result)!.id, 'large');
      expect(adapter.paths.where((p) => p.endsWith('/stores/')), hasLength(2));
    },
  );

  test(
    'one failed store cannot silently produce a smaller partial limit',
    () async {
      final adapter = _Adapter()..failedBranch = true;
      await expectLater(
        CheckoutApi(_client(adapter)).fetchAddressCoverage(),
        throwsA(isA<NotFoundFailure>()),
      );
    },
  );

  test(
    'foreign pagination is rejected before credentials could leave backend',
    () async {
      final adapter = _Adapter()..foreignNext = true;
      await expectLater(
        CheckoutApi(_client(adapter)).fetchAddressCoverage(),
        throwsA(isA<UnknownFailure>()),
      );
      expect(adapter.paths, hasLength(2));
    },
  );

  test('403 is surfaced, not treated as an old API', () async {
    final adapter = _Adapter()..coverageStatus = 403;
    await expectLater(
      CheckoutApi(_client(adapter)).fetchAddressCoverage(),
      throwsA(isA<ForbiddenFailure>()),
    );
    expect(adapter.paths, hasLength(1));
  });

  testWidgets(
    'coverage timeout ends loading and does not start hidden automatic retries',
    (tester) async {
      final api = _PendingApi(_client(_Adapter()));
      final container = ProviderContainer(
        overrides: [
          checkoutApiProvider.overrideWithValue(api),
          accountScopeProvider.overrideWithValue('user-test'),
          apiLangProvider.overrideWithValue('uz'),
        ],
      );
      addTearDown(container.dispose);
      final listener = container.listen(addressCoverageProvider, (_, _) {});
      addTearDown(listener.close);
      final failure = expectLater(
        container.read(addressCoverageProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      await tester.pump(const Duration(seconds: 21));
      await failure;
      expect(container.read(addressCoverageProvider).hasError, isTrue);
      expect(container.read(addressCoverageProvider).isLoading, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(api.calls, 1);
    },
  );
}
