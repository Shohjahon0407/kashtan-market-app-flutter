import '../../../core/config/app_config.dart';
import '../../../core/network/json_read.dart';
import '../../checkout/data/checkout_models.dart';

class OrderItemAddon {
  const OrderItemAddon({
    required this.id,
    required this.name,
    required this.price,
  });

  factory OrderItemAddon.fromJson(Map<String, dynamic> json) => OrderItemAddon(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    price: JsonRead.string(json['price'], '0'),
  );

  final String id;
  final String name;
  final String price;
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.price,
    required this.totalPrice,
    required this.note,
    required this.addons,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: JsonRead.string(json['id']),
    productId: JsonRead.string(json['product_id']),
    productName: JsonRead.string(json['product_name']),
    variantName: JsonRead.string(json['variant_name']),
    quantity: JsonRead.integer(json['quantity'], 1),
    price: JsonRead.string(json['price'] ?? json['unit_price'], '0'),
    totalPrice: JsonRead.string(json['total_price'], '0'),
    note: JsonRead.string(json['note']),
    addons: JsonRead.list(json['addons'], OrderItemAddon.fromJson),
    imageUrl: AppConfig.resolveMediaUrl(
      JsonRead.nullableString(
        json['product_image_url'] ?? json['product_image'],
      ),
    ),
  );

  final String id;
  final String productId;
  final String productName;
  final String variantName;
  final int quantity;
  final String price;
  final String totalPrice;
  final String note;
  final List<OrderItemAddon> addons;
  final String? imageUrl;
}

class OrderPickupBranch {
  const OrderPickupBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.storeName,
  });

  factory OrderPickupBranch.fromJson(Map<String, dynamic> json) =>
      OrderPickupBranch(
        id: JsonRead.string(json['id']),
        name: JsonRead.string(json['name']),
        address: JsonRead.string(json['address']),
        phone: JsonRead.string(json['phone']),
        storeName: JsonRead.string(json['store_name']),
      );

  final String id;
  final String name;
  final String address;
  final String phone;
  final String storeName;
}

class OrderData {
  const OrderData({
    required this.id,
    required this.orderNumber,
    required this.storeTypeWire,
    required this.fulfillmentType,
    required this.status,
    required this.userStatus,
    required this.statusLabel,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.items,
    required this.createdAt,
    required this.courierName,
    required this.courierPhone,
    required this.courierVehicleType,
    required this.courierEtaMinutes,
    required this.deliveryOption,
    required this.courierComment,
    this.courierAcceptedAt,
    this.deliveryDeadlineAt,
    this.address,
    this.pickupBranch,
    this.distanceKm,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    final address = JsonRead.map(json['address']);
    final pickupBranch = JsonRead.map(json['pickup_branch']);
    return OrderData(
      id: JsonRead.string(json['id']),
      orderNumber: JsonRead.string(json['order_number']),
      storeTypeWire: JsonRead.string(json['store_type']),
      fulfillmentType: JsonRead.string(json['fulfillment_type']),
      status: JsonRead.string(json['status']),
      userStatus: JsonRead.string(
        json['user_status'],
        JsonRead.string(json['status']),
      ),
      statusLabel: JsonRead.string(
        json['status_label'] ?? json['user_status_display_uz'],
      ),
      paymentMethod: JsonRead.string(json['payment_method']),
      paymentStatus: JsonRead.string(json['payment_status']),
      subtotal: JsonRead.string(json['subtotal'], '0'),
      deliveryFee: JsonRead.string(
        json['delivery_fee'] ?? json['delivery_price'],
        '0',
      ),
      distanceKm: JsonRead.nullableString(json['distance_km']),
      total: JsonRead.string(json['total'], '0'),
      address: address == null ? null : UserAddress.fromJson(address),
      pickupBranch: pickupBranch == null
          ? null
          : OrderPickupBranch.fromJson(pickupBranch),
      items: JsonRead.list(json['items'], OrderItem.fromJson),
      courierName: JsonRead.string(json['courier_name']),
      courierPhone: JsonRead.string(json['courier_phone']),
      courierVehicleType: JsonRead.string(json['courier_vehicle_type']),
      courierEtaMinutes: JsonRead.integer(json['courier_eta_minutes']),
      deliveryOption: JsonRead.string(json['delivery_option'], 'same_day'),
      courierComment: JsonRead.string(json['courier_comment']),
      courierAcceptedAt: _dateTime(json['courier_accepted_at']),
      deliveryDeadlineAt: _dateTime(json['delivery_deadline_at']),
      createdAt: JsonRead.string(json['created_at']),
    );
  }

  final String id;
  final String orderNumber;
  final String storeTypeWire;
  final String fulfillmentType;
  final String status;
  final String userStatus;
  final String statusLabel;
  final String paymentMethod;
  final String paymentStatus;
  final String subtotal;
  final String deliveryFee;
  final String? distanceKm;
  final String total;
  final UserAddress? address;
  final OrderPickupBranch? pickupBranch;
  final List<OrderItem> items;
  final String courierName;
  final String courierPhone;
  final String courierVehicleType;
  final int courierEtaMinutes;
  final String deliveryOption;
  final String courierComment;
  final DateTime? courierAcceptedAt;
  final DateTime? deliveryDeadlineAt;
  final String createdAt;

  bool get canCancel => status == 'pending' || status == 'accepted';

  CustomerOrderStage get customerStage {
    // `user_status` is the customer-facing source of truth. In particular, a
    // raw ACCEPTED delivery can still be waiting for an actual courier. Using
    // a union of raw + user status would incorrectly hide the waiting radar.
    final value = userStatus.trim().isEmpty ? status : userStatus;
    if (value == 'cancelled') return CustomerOrderStage.cancelled;
    if (value == 'delivered' || value == 'completed') {
      return CustomerOrderStage.delivered;
    }

    // Pickup has no courier search. Pending pickup remains a neutral/static
    // processing state, while accepted/preparing/ready uses the blue check.
    if (!isDelivery) {
      if (value == 'accepted' ||
          value == 'preparing' ||
          value == 'ready' ||
          value == 'ready_for_pickup') {
        return CustomerOrderStage.accepted;
      }
      return CustomerOrderStage.other;
    }

    if (value == 'out_for_delivery' || value == 'on_way') {
      return CustomerOrderStage.onWay;
    }
    if (value == 'accepted' ||
        value == 'preparing' ||
        value == 'ready' ||
        value == 'ready_for_pickup') {
      return CustomerOrderStage.accepted;
    }
    if (value == 'reviewing' || value == 'pending') {
      return CustomerOrderStage.searching;
    }
    return CustomerOrderStage.other;
  }

  bool get isDelivery => fulfillmentType == 'delivery';
  bool get isSearchingCourier =>
      isDelivery && customerStage == CustomerOrderStage.searching;
  bool get hasAcceptedCourier =>
      isDelivery &&
      customerStage == CustomerOrderStage.accepted &&
      courierName.isNotEmpty;
  bool get isCourierOnWay =>
      isDelivery && customerStage == CustomerOrderStage.onWay;
  bool get isDelivered => customerStage == CustomerOrderStage.delivered;
  bool get isDelayedDelivery =>
      deliveryOption == 'one_day' || deliveryOption == 'two_days';

  DateTime? get createdDateTime => _dateTime(createdAt);

  OrderData withTracking(OrderTrackingData tracking) {
    final searching =
        tracking.userStatus == 'reviewing' || tracking.userStatus == 'pending';
    return OrderData(
      id: id,
      orderNumber: tracking.orderNumber.isEmpty
          ? orderNumber
          : tracking.orderNumber,
      storeTypeWire: tracking.storeTypeWire.isEmpty
          ? storeTypeWire
          : tracking.storeTypeWire,
      fulfillmentType: tracking.fulfillmentType.isEmpty
          ? fulfillmentType
          : tracking.fulfillmentType,
      status: tracking.status.isEmpty ? status : tracking.status,
      userStatus: tracking.userStatus.isEmpty
          ? userStatus
          : tracking.userStatus,
      statusLabel: tracking.statusLabel.isEmpty
          ? statusLabel
          : tracking.statusLabel,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      items: items,
      createdAt: createdAt,
      courierName: searching
          ? ''
          : tracking.courierName.isEmpty
          ? courierName
          : tracking.courierName,
      courierPhone: searching
          ? ''
          : tracking.courierPhone.isEmpty
          ? courierPhone
          : tracking.courierPhone,
      courierVehicleType: searching
          ? ''
          : tracking.courierVehicleType.isEmpty
          ? courierVehicleType
          : tracking.courierVehicleType,
      courierEtaMinutes: searching
          ? 0
          : tracking.courierEtaMinutes > 0
          ? tracking.courierEtaMinutes
          : courierEtaMinutes,
      deliveryOption: searching
          ? 'same_day'
          : tracking.deliveryOption.isEmpty
          ? deliveryOption
          : tracking.deliveryOption,
      courierComment: searching
          ? ''
          : tracking.courierComment.isEmpty
          ? courierComment
          : tracking.courierComment,
      courierAcceptedAt: searching
          ? null
          : tracking.courierAcceptedAt ?? courierAcceptedAt,
      deliveryDeadlineAt: searching
          ? null
          : tracking.deliveryDeadlineAt ?? deliveryDeadlineAt,
      address: tracking.address ?? address,
      pickupBranch: tracking.pickupBranch ?? pickupBranch,
      distanceKm: distanceKm,
    );
  }
}

enum CustomerOrderStage {
  searching,
  accepted,
  onWay,
  delivered,
  cancelled,
  other,
}

/// Kuryerning faqat eng oxirgi koordinatasi. Backend tarix yig'maydi.
class CourierLocation {
  const CourierLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.receivedAt,
    required this.clientSequence,
    required this.ageSeconds,
    required this.isStale,
    required this.isUnavailable,
    this.accuracy,
    this.heading,
    this.speed,
  });

  factory CourierLocation.fromJson(Map<String, dynamic> json) =>
      CourierLocation(
        latitude: JsonRead.nullableDouble(json['latitude']) ?? 0,
        longitude: JsonRead.nullableDouble(json['longitude']) ?? 0,
        accuracy: JsonRead.nullableDouble(json['accuracy']),
        heading: JsonRead.nullableDouble(json['heading']),
        speed: JsonRead.nullableDouble(json['speed']),
        recordedAt: _dateTime(json['recorded_at']),
        receivedAt: _dateTime(json['received_at']),
        clientSequence: JsonRead.integer(json['client_sequence']),
        ageSeconds: JsonRead.integer(json['age_seconds']),
        isStale: JsonRead.boolean(json['is_stale']),
        isUnavailable: JsonRead.boolean(json['is_unavailable']),
      );

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final DateTime? recordedAt;
  final DateTime? receivedAt;
  final int clientSequence;
  final int ageSeconds;
  final bool isStale;
  final bool isUnavailable;

  /// Backend `age_seconds` response vaqtining snapshoti. Network uzilganda u
  /// muzlab qolmasligi uchun UI joriy wall-clock bilan yoshni oshirib boradi.
  int get currentAgeSeconds {
    final anchor = receivedAt ?? recordedAt;
    if (anchor == null) return ageSeconds;
    final live = DateTime.now().difference(anchor).inSeconds;
    final normalized = live < 0 ? 0 : live;
    return normalized > ageSeconds ? normalized : ageSeconds;
  }

  bool get isCurrentlyStale => isStale || currentAgeSeconds > 30;
  bool get isCurrentlyUnavailable => isUnavailable || currentAgeSeconds > 120;

  bool get hasValidCoordinates =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);
}

/// `/orders/{id}/tracking/` ning yengil, tez-tez yangilanadigan javobi.
class OrderTrackingData {
  const OrderTrackingData({
    required this.orderNumber,
    required this.status,
    required this.userStatus,
    required this.statusLabel,
    required this.storeTypeWire,
    required this.fulfillmentType,
    required this.courierName,
    required this.courierPhone,
    required this.courierVehicleType,
    required this.courierEtaMinutes,
    required this.deliveryOption,
    required this.courierComment,
    this.courierAcceptedAt,
    this.deliveryDeadlineAt,
    this.courierLocation,
    this.address,
    this.pickupBranch,
  });

  factory OrderTrackingData.fromJson(Map<String, dynamic> json) {
    final courier = JsonRead.map(json['courier']);
    final address = JsonRead.map(json['address']);
    final pickup = JsonRead.map(json['pickup_branch']);
    final location = JsonRead.map(json['courier_location'] ?? json['location']);
    return OrderTrackingData(
      orderNumber: JsonRead.string(json['order_number']),
      status: JsonRead.string(json['status']),
      userStatus: JsonRead.string(
        json['user_status'],
        JsonRead.string(json['status']),
      ),
      statusLabel: JsonRead.string(
        json['status_label'] ?? json['user_status_display_uz'],
      ),
      storeTypeWire: JsonRead.string(json['store_type']),
      fulfillmentType: JsonRead.string(json['fulfillment_type']),
      courierName: JsonRead.string(
        json['courier_name'] ?? courier?['full_name'],
      ),
      courierPhone: JsonRead.string(
        json['courier_phone'] ?? courier?['phone_number'],
      ),
      courierVehicleType: JsonRead.string(
        json['courier_vehicle_type'] ?? courier?['vehicle_type'],
      ),
      courierEtaMinutes: JsonRead.integer(json['courier_eta_minutes']),
      deliveryOption: JsonRead.string(json['delivery_option'], 'same_day'),
      courierComment: JsonRead.string(json['courier_comment']),
      courierAcceptedAt: _dateTime(json['courier_accepted_at']),
      deliveryDeadlineAt: _dateTime(json['delivery_deadline_at']),
      courierLocation: location == null
          ? null
          : CourierLocation.fromJson(location),
      address: address == null ? null : UserAddress.fromJson(address),
      pickupBranch: pickup == null ? null : OrderPickupBranch.fromJson(pickup),
    );
  }

  final String orderNumber;
  final String status;
  final String userStatus;
  final String statusLabel;
  final String storeTypeWire;
  final String fulfillmentType;
  final String courierName;
  final String courierPhone;
  final String courierVehicleType;
  final int courierEtaMinutes;
  final String deliveryOption;
  final String courierComment;
  final DateTime? courierAcceptedAt;
  final DateTime? deliveryDeadlineAt;
  final CourierLocation? courierLocation;
  final UserAddress? address;
  final OrderPickupBranch? pickupBranch;

  Duration get refreshInterval => switch (userStatus) {
    'reviewing' || 'pending' => const Duration(seconds: 10),
    'accepted' => const Duration(seconds: 30),
    'on_way' || 'out_for_delivery' => const Duration(seconds: 10),
    _ => const Duration(minutes: 2),
  };
}

DateTime? _dateTime(Object? value) {
  final raw = JsonRead.nullableString(value);
  return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
}
