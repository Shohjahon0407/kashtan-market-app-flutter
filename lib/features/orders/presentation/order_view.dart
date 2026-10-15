import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_models.dart';
import '../domain/order_live_controller.dart';
import '../domain/orders_controller.dart';

/// Ekranlar uchun yagona buyurtma ko'rinishi:
/// REST detail → ustiga tracking → ustiga WS jonli yamoq/nuqta.
AsyncValue<OrderData> watchOrderView(WidgetRef ref, String orderId) {
  final detail = ref.watch(orderDetailProvider(orderId));
  final tracking = ref.watch(orderTrackingControllerProvider(orderId));
  final live = ref.watch(orderLiveProvider(orderId));
  return detail.whenData((value) {
    final trackingValue = tracking.value;
    final merged = trackingValue == null
        ? value
        : value.withTracking(trackingValue);
    return applyOrderLive(merged, live);
  });
}

/// Xarita ko'rsatish mumkinmi: delivery va manzil koordinatasi bor.
bool orderHasMap(OrderData order) =>
    order.isDelivery &&
    order.address?.latitude != null &&
    order.address?.longitude != null;
