import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../checkout/data/checkout_models.dart';
import 'order_models.dart';

class OrdersApi {
  const OrdersApi(this._client, {this.cache, this.cacheKeySuffix});

  final ApiClient _client;

  /// Buyurtmalar ro'yxatining oxirgi muvaffaqiyatli sahifasi — oflayn uchun.
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  Future<OffsetPage<OrderData>> fetch({
    required String storeType,
    String? period,
    String? nextUrl,
  }) async {
    final data = nextUrl == null
        ? await _client.get(
            Api.orders,
            query: {
              'store_type': storeType,
              'page_size': 20,
              if (period != null && period.isNotEmpty) 'period': period,
            },
          )
        : await _client.getUrl(nextUrl);
    if (nextUrl == null && data is Map<String, dynamic>) {
      _cacheOrders(storeType, period, data);
    }
    return PageDecoder.offset(data, OrderData.fromJson);
  }

  void _cacheOrders(String storeType, String? period, Object data) {
    try {
      final suffix = cacheKeySuffix?.call();
      if (cache == null || suffix == null) return;
      unawaited(
        cache!.writeJson(
          ordersCacheKey(storeType, period ?? 'all', suffix),
          data,
        ),
      );
    } on Object {
      // Kesh majburiy emas.
    }
  }

  /// Oflaynda ko'rsatiladigan oxirgi ro'yxat.
  Future<OffsetPage<OrderData>?> cachedOrders({
    required String storeType,
    String? period,
  }) async {
    try {
      final suffix = cacheKeySuffix?.call();
      if (cache == null || suffix == null) return null;
      final raw = await cache!.read(
        ordersCacheKey(storeType, period ?? 'all', suffix),
      );
      if (raw == null) return null;
      return PageDecoder.offset(raw, OrderData.fromJson);
    } on Object {
      return null;
    }
  }

  Future<OrderData> detail(String id) async {
    final data = await _client.get(Api.order(id));
    return _order(data);
  }

  Future<OrderData> create({
    required String storeType,
    required FulfillmentType fulfillmentType,
    String? addressId,
    String? pickupBranchId,
    required String paymentMethod,
    String note = '',
    String? idempotencyKey,
  }) async {
    final data = await _client.post(
      Api.orders,
      body: {
        'store_type': storeType,
        'fulfillment_type': fulfillmentType.wire,
        if (fulfillmentType == FulfillmentType.delivery)
          'address_id': addressId,
        if (fulfillmentType == FulfillmentType.pickup)
          'pickup_branch_id': pickupBranchId,
        // Backend hozir bu maydonni e'tiborsiz qoldiradi (fulfillment'dan
        // o'zi hosil qiladi). Qabul qila boshlaganda app yangilanmasdan ishlaydi.
        'payment_method': paymentMethod,
        if (note.trim().isNotEmpty) 'customer_note': note.trim(),
      },
      headers: idempotencyKey == null || idempotencyKey.isEmpty
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
    return _order(data);
  }

  Future<OrderData> cancel(String id) async {
    final data = await _client.post(Api.orderCancel(id));
    return _order(data);
  }

  Future<OrderTrackingData> tracking(String id) async {
    final data = await _client.get(Api.orderTracking(id));
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure('order tracking javobi obyekt emas');
    }
    return OrderTrackingData.fromJson(map);
  }

  OrderData _order(Object? data) {
    final map = JsonRead.map(data);
    if (map == null) throw const UnknownFailure('order javobi obyekt emas');
    return OrderData.fromJson(map);
  }
}
