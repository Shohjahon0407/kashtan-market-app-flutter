import '../../../core/network/json_read.dart';

/// Customer notification returned by `/notifications/`.
///
/// [data] is intentionally preserved: lifecycle notifications can gain new
/// deep-link metadata without requiring another client model migration.
class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.eventKey,
    required this.isRead,
    required this.createdAt,
    required this.data,
    this.relatedOrderId,
    this.storeTypeWire,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    final relatedOrder = JsonRead.map(json['related_order']);
    final data = JsonRead.map(json['data']) ?? const <String, dynamic>{};
    final orderId = JsonRead.nullableString(
      relatedOrder?['id'] ??
          json['related_order'] ??
          json['related_order_id'] ??
          data['order_id'],
    );
    final storeType = JsonRead.nullableString(
      relatedOrder?['store_type'] ?? json['store_type'] ?? data['store_type'],
    );
    return CustomerNotification(
      id: JsonRead.string(json['id']),
      title: JsonRead.string(json['title']),
      body: JsonRead.string(json['body']),
      type: JsonRead.string(json['type'], 'system'),
      eventKey: JsonRead.string(json['event_key'] ?? data['event_key']),
      isRead: JsonRead.boolean(json['is_read']),
      createdAt: DateTime.tryParse(JsonRead.string(json['created_at'])),
      relatedOrderId: orderId,
      storeTypeWire: storeType,
      data: Map<String, dynamic>.unmodifiable(data),
    );
  }

  final String id;
  final String title;
  final String body;
  final String type;
  final String eventKey;
  final bool isRead;
  final DateTime? createdAt;
  final String? relatedOrderId;
  final String? storeTypeWire;
  final Map<String, dynamic> data;

  bool get opensOrder =>
      relatedOrderId != null &&
      relatedOrderId!.isNotEmpty &&
      storeTypeWire != null &&
      storeTypeWire!.isNotEmpty;

  bool get hasRelatedOrder =>
      relatedOrderId != null && relatedOrderId!.isNotEmpty;

  CustomerNotification copyWith({bool? isRead}) => CustomerNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    eventKey: eventKey,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    relatedOrderId: relatedOrderId,
    storeTypeWire: storeTypeWire,
    data: data,
  );
}

class NotificationDevice {
  const NotificationDevice({
    required this.id,
    required this.token,
    required this.platform,
    required this.deviceId,
    required this.locale,
    required this.isActive,
  });

  factory NotificationDevice.fromJson(Map<String, dynamic> json) =>
      NotificationDevice(
        id: JsonRead.string(json['id']),
        // Some deployments deliberately omit the token from responses.
        token: JsonRead.string(json['token']),
        platform: JsonRead.string(json['platform']),
        deviceId: JsonRead.string(json['device_id']),
        locale: JsonRead.string(json['locale'], 'uz'),
        isActive: JsonRead.boolean(json['is_active'], fallback: true),
      );

  final String id;
  final String token;
  final String platform;
  final String deviceId;
  final String locale;
  final bool isActive;
}

/// Normalized push payload used by FCM, local-notification taps and tests.
class CustomerPushMessage {
  const CustomerPushMessage({
    required this.title,
    required this.body,
    required this.data,
  });

  factory CustomerPushMessage.fromData({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) => CustomerPushMessage(
    title: title ?? JsonRead.string(data['title']),
    body: body ?? JsonRead.string(data['body']),
    data: Map<String, dynamic>.unmodifiable(data),
  );

  final String title;
  final String body;
  final Map<String, dynamic> data;

  String? get orderId => JsonRead.nullableString(
    data['order_id'] ?? data['related_order_id'] ?? data['related_order'],
  );

  String? get storeTypeWire => JsonRead.nullableString(data['store_type']);

  bool get opensOrder =>
      orderId != null &&
      orderId!.isNotEmpty &&
      storeTypeWire != null &&
      storeTypeWire!.isNotEmpty;

  bool get hasOrderTarget => orderId != null && orderId!.isNotEmpty;

  /// Backend muhim buyurtma hodisalarida (kuryer yo'lda, yetkazildi,
  /// bekor qilindi) `importance=high` yuboradi; qolganlari `normal`.
  bool get isImportant =>
      (JsonRead.nullableString(data['importance']) ?? '').toLowerCase() ==
      'high';
}
