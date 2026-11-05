import 'package:beshkashtan_customer/features/notifications/data/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification parses additive lifecycle metadata', () {
    final notification = CustomerNotification.fromJson({
      'id': 'notification-1',
      'title': 'Kuryer yo‘lda',
      'body': 'Buyurtmangiz yetkazilmoqda',
      'type': 'order_update',
      'event_key': 'order_on_way',
      'is_read': false,
      'related_order': 'order-1',
      'data': {'store_type': 'household', 'order_id': 'order-1'},
      'created_at': '2026-08-08T10:00:00Z',
    });

    expect(notification.id, 'notification-1');
    expect(notification.eventKey, 'order_on_way');
    expect(notification.relatedOrderId, 'order-1');
    expect(notification.storeTypeWire, 'household');
    expect(notification.opensOrder, isTrue);
    expect(notification.createdAt, DateTime.utc(2026, 8, 8, 10));
  });

  test('old notification payload remains compatible', () {
    final notification = CustomerNotification.fromJson({
      'id': 'notification-2',
      'title': 'Yangilik',
      'body': 'Matn',
      'type': 'system',
      'is_read': true,
      'related_order': null,
      'created_at': 'not-a-date',
    });

    expect(notification.eventKey, isEmpty);
    expect(notification.data, isEmpty);
    expect(notification.createdAt, isNull);
    expect(notification.opensOrder, isFalse);
  });

  test(
    'push target only opens when order and supported store metadata exist',
    () {
      final complete = CustomerPushMessage.fromData(
        data: {'order_id': 'order-1', 'store_type': 'grocery'},
      );
      final incomplete = CustomerPushMessage.fromData(
        data: {'order_id': 'order-1'},
      );

      expect(complete.opensOrder, isTrue);
      expect(incomplete.opensOrder, isFalse);
    },
  );

  test('importance=high muhim push sifatida aniqlanadi', () {
    bool important(Object? value) =>
        CustomerPushMessage.fromData(data: {'importance': value}).isImportant;

    expect(important('high'), isTrue);
    expect(important(' HIGH '), isTrue);
    expect(important('normal'), isFalse);
    expect(important(null), isFalse);
    expect(CustomerPushMessage.fromData(data: {}).isImportant, isFalse);
  });
}
