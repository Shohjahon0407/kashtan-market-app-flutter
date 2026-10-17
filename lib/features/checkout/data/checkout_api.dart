import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'checkout_models.dart';

class CheckoutApi {
  const CheckoutApi(this._client, {this.cache, this.cacheKeySuffix});

  final ApiClient _client;

  /// Manzillar ro'yxati oflaynda ham kerak (bosh ekran sarlavhasi shuni o'qiydi).
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  Future<List<UserAddress>> fetchAddresses() async {
    final data = await _client.get(Api.addresses);
    try {
      final suffix = cacheKeySuffix?.call();
      if (cache != null && suffix != null && data != null) {
        unawaited(cache!.writeJson(addressesCacheKey(suffix), data as Object));
      }
    } on Object {
      // Kesh majburiy emas.
    }
    return PageDecoder.bare(data, UserAddress.fromJson).items;
  }

  /// Oflaynda ko'rsatiladigan oxirgi manzillar.
  Future<List<UserAddress>?> cachedAddresses() async {
    try {
      final suffix = cacheKeySuffix?.call();
      if (cache == null || suffix == null) return null;
      final raw = await cache!.readEntry(addressesCacheKey(suffix));
      if (raw == null) return null;
      return PageDecoder.bare(raw.payload, UserAddress.fromJson).items;
    } on Object {
      return null;
    }
  }

  Future<UserAddress> createAddress(UserAddress address) async {
    final data = await _client.post(
      Api.addresses,
      body: address.toRequestJson(),
    );
    return _address(data);
  }

  Future<UserAddress> updateAddress(UserAddress address) async {
    final data = await _client.patch(
      Api.address(address.id),
      body: address.toRequestJson(),
    );
    return _address(data);
  }

  Future<void> deleteAddress(String id) async {
    await _client.delete(Api.address(id));
  }

  Future<void> setDefaultAddress(String id) async {
    await _client.post(Api.addressSetDefault(id));
  }

  Future<DeliveryEstimate> estimate({
    required String storeType,
    required double latitude,
    required double longitude,
    String? branchId,
  }) async {
    final data = await _client.post(
      Api.deliveryEstimate,
      body: {
        'store_type': storeType,
        'latitude': latitude,
        'longitude': longitude,
        'branch_id': ?branchId,
      },
    );
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure.malformed(
        'delivery estimate javobi obyekt emas',
      );
    }
    return DeliveryEstimate.fromJson(map);
  }

  Future<List<StoreBranch>> fetchBranches(String storeId) async {
    final data = await _client.get(Api.storeBranches(storeId));
    return PageDecoder.bare(data, StoreBranch.fromJson).items;
  }

  Future<List<DeliveryCoverageBranch>> fetchCoverage(String storeType) async {
    return _fetchCoverage({'store_type': storeType});
  }

  Future<List<DeliveryCoverageBranch>> fetchAddressCoverage() async {
    try {
      return await _fetchCoverage({'scope': 'address'});
    } on ValidationFailure {
      // Older deployments require store_type and do not know scope=address.
      return _publicAddressCoverage();
    } on NotFoundFailure {
      return _publicAddressCoverage();
    }
  }

  /// Compatibility path using existing public, visible-store APIs. Never
  /// invent an 8 km default or silently use a partial set of store radii.
  Future<List<DeliveryCoverageBranch>> _publicAddressCoverage() async {
    final ids = <String>{};
    var page = PageDecoder.offset(await _client.get(Api.stores), (map) => map);
    final visited = <String>{};
    while (true) {
      for (final store in page.items) {
        final id = JsonRead.string(store['id']);
        if (id.isNotEmpty &&
            store['is_active'] != false &&
            store['is_visible_in_app'] != false) {
          ids.add(id);
        }
      }
      final next = page.nextUrl;
      if (next == null || next.isEmpty) break;
      final base = Uri.parse(AppConfig.apiBaseUrl);
      final uri = base.resolve(next);
      if (uri.origin != base.origin ||
          uri.path != '${base.path}${Api.stores}' ||
          !visited.add(uri.toString())) {
        throw const UnknownFailure.malformed('Invalid store pagination URL');
      }
      page = PageDecoder.offset(
        await _client.getUrl(uri.toString()),
        (map) => map,
      );
    }
    final lists = await Future.wait(
      ids.map((id) async {
        final data = await _client.get(
          Api.storeBranches(Uri.encodeComponent(id)),
        );
        return PageDecoder.bare(data, (json) => json).items
            .where((json) => json['is_active'] != false)
            .map(DeliveryCoverageBranch.fromJson)
            .where((branch) => branch.hasCoverage);
      }),
    );
    final unique = <String, DeliveryCoverageBranch>{};
    for (final branches in lists) {
      for (final branch in branches) {
        unique[branch.id] = branch;
      }
    }
    return unique.values.toList(growable: false);
  }

  Future<List<DeliveryCoverageBranch>> _fetchCoverage(
    Map<String, dynamic> query,
  ) async {
    final data = JsonRead.map(
      await _client.get(Api.deliveryCoverage, query: query),
    );
    if (data == null) {
      throw const UnknownFailure.malformed(
        'delivery coverage javobi obyekt emas',
      );
    }
    return (data['branches'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DeliveryCoverageBranch.fromJson)
        .where((branch) => branch.hasCoverage)
        .toList(growable: false);
  }

  UserAddress _address(Object? data) {
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure.malformed('address javobi obyekt emas');
    }
    return UserAddress.fromJson(map);
  }
}
