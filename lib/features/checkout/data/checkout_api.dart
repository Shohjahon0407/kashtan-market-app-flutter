import 'dart:async';

import '../../../core/config/api_endpoints.dart';
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

  UserAddress _address(Object? data) {
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure.malformed('address javobi obyekt emas');
    }
    return UserAddress.fromJson(map);
  }
}
