import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/json_read.dart';
import '../data/order_models.dart';

/// WebSocket `user.order_updated` payload'idan olingan, REST detail ustiga
/// qo'yiladigan yamoq. REST kelguncha (bir necha yuz ms) mijoz holatni
/// darhol ko'radi.
class OrderLifecyclePatch {
  const OrderLifecyclePatch({
    required this.status,
    required this.userStatus,
    required this.statusLabel,
    required this.courierName,
    required this.courierPhone,
    required this.courierVehicleType,
    required this.courierEtaMinutes,
    required this.deliveryOption,
    required this.courierComment,
    this.courierAcceptedAt,
    this.deliveryDeadlineAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.serverCanCancel,
    this.paymentStatus = '',
  });

  factory OrderLifecyclePatch.fromEvent(
    Map<String, dynamic> event, {
    required String language,
  }) {
    final courier = JsonRead.map(event['courier']);
    final label = event['status_label_$language'] ?? event['status_label'];
    return OrderLifecyclePatch(
      status: JsonRead.string(event['status']),
      paymentStatus: JsonRead.string(event['payment_status']),
      userStatus: JsonRead.string(event['user_status']),
      statusLabel: JsonRead.string(label),
      courierName: JsonRead.string(
        event['courier_name'] ?? courier?['full_name'],
      ),
      courierPhone: JsonRead.string(
        event['courier_phone'] ?? courier?['phone_number'],
      ),
      courierVehicleType: JsonRead.string(
        event['courier_vehicle_type'] ?? courier?['vehicle_type'],
      ),
      courierEtaMinutes: JsonRead.integer(event['courier_eta_minutes']),
      deliveryOption: JsonRead.string(event['delivery_option']),
      courierComment: JsonRead.string(event['courier_comment']),
      courierAcceptedAt: parseOrderDateTime(event['courier_accepted_at']),
      deliveryDeadlineAt: parseOrderDateTime(event['delivery_deadline_at']),
      pickedUpAt: parseOrderDateTime(event['picked_up_at']),
      deliveredAt: parseOrderDateTime(event['delivered_at']),
      serverCanCancel: event['can_cancel'] is bool
          ? event['can_cancel'] as bool
          : null,
    );
  }

  final String status;
  final String paymentStatus;
  final String userStatus;
  final String statusLabel;
  final String courierName;
  final String courierPhone;
  final String courierVehicleType;
  final int courierEtaMinutes;
  final String deliveryOption;
  final String courierComment;
  final DateTime? courierAcceptedAt;
  final DateTime? deliveryDeadlineAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final bool? serverCanCancel;

  bool get isSearching => userStatus == 'reviewing' || userStatus == 'pending';
}

class OrderLiveState {
  const OrderLiveState({
    this.patch,
    this.location,
    this.previousLocation,
    this.locationAt,
  });

  final OrderLifecyclePatch? patch;

  /// Oxirgi kelgan nuqta va undan oldingisi — marker silliq siljishi uchun.
  final CourierLocation? location;
  final CourierLocation? previousLocation;
  final DateTime? locationAt;
}

/// Ochiq buyurtma uchun jonli holat: WS hodisalari shu yerga darhol
/// qo'llanadi; REST (detail/tracking) kelganda yamoq tozalanadi.
final orderLiveProvider = NotifierProvider.autoDispose
    .family<OrderLiveController, OrderLiveState, String>(
      OrderLiveController.new,
    );

class OrderLiveController extends Notifier<OrderLiveState> {
  OrderLiveController(this.orderId);

  final String orderId;

  @override
  OrderLiveState build() => const OrderLiveState();

  void applyLifecycle(Map<String, dynamic> event, {required String language}) {
    final patch = OrderLifecyclePatch.fromEvent(event, language: language);
    if (patch.status.isEmpty && patch.userStatus.isEmpty) return;
    state = OrderLiveState(
      patch: patch,
      // Qayta qidiruvga tushsa kuryer nuqtasi ham yo'qoladi.
      location: patch.isSearching ? null : state.location,
      previousLocation: patch.isSearching ? null : state.previousLocation,
      locationAt: state.locationAt,
    );
  }

  void applyLocation(Map<String, dynamic> event) {
    final raw = JsonRead.map(event['location']);
    if (raw == null) return;
    final location = CourierLocation.fromJson(raw);
    if (!location.hasValidCoordinates) return;
    final current = state.location;
    // Tarmoqda tartib buzilsa eski nuqta yangisini bosmasin.
    if (current != null && location.clientSequence <= current.clientSequence) {
      return;
    }
    state = OrderLiveState(
      patch: state.patch,
      location: location,
      previousLocation: current,
      locationAt: DateTime.now(),
    );
  }

  /// REST detail keldi — yamoq endi kerak emas (REST source of truth).
  void clearPatch() {
    if (state.patch == null) return;
    state = OrderLiveState(
      location: state.location,
      previousLocation: state.previousLocation,
      locationAt: state.locationAt,
    );
  }
}

/// REST qiymati ustiga jonli yamoq va eng yangi nuqtani qo'yadi.
OrderData applyOrderLive(OrderData order, OrderLiveState live) {
  var result = order;
  final patch = live.patch;
  if (patch != null) {
    final searching = patch.isSearching;
    result = result.copyWith(
      status: patch.status.isEmpty ? null : patch.status,
      userStatus: patch.userStatus.isEmpty ? null : patch.userStatus,
      statusLabel: patch.statusLabel.isEmpty ? null : patch.statusLabel,
      courierName: searching ? '' : _orNull(patch.courierName),
      courierPhone: searching ? '' : _orNull(patch.courierPhone),
      courierVehicleType: searching ? '' : _orNull(patch.courierVehicleType),
      courierEtaMinutes: searching
          ? 0
          : (patch.courierEtaMinutes > 0 ? patch.courierEtaMinutes : null),
      deliveryOption: _orNull(patch.deliveryOption),
      courierComment: searching ? '' : _orNull(patch.courierComment),
      courierAcceptedAt: patch.courierAcceptedAt,
      deliveryDeadlineAt: patch.deliveryDeadlineAt,
      pickedUpAt: patch.pickedUpAt,
      deliveredAt: patch.deliveredAt,
      serverCanCancel: patch.serverCanCancel,
      paymentStatus: _orNull(patch.paymentStatus),
    );
  }
  final location = newerLocation(result.courierLocation, live.location);
  if (location != result.courierLocation) {
    result = result.copyWith(courierLocation: location);
  }
  return result;
}

String? _orNull(String value) => value.isEmpty ? null : value;
