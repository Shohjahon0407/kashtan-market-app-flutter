import 'package:beshkashtan_customer/features/orders/data/mapbox_directions.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'tracking deadline va latest courier locationni tolerant parse qiladi',
    () {
      final tracking = OrderTrackingData.fromJson({
        'order_number': 'BK-100',
        'status': 'out_for_delivery',
        'user_status': 'on_way',
        'status_label': "Yo'lda",
        'store_type': 'grocery',
        'fulfillment_type': 'delivery',
        'courier_name': 'Ali Valiyev',
        'courier_phone': '+998901234567',
        'courier_eta_minutes': 25,
        'courier_comment': "Yetib borganda qo'ng'iroq qilaman",
        'delivery_deadline_at': '2026-08-08T12:30:00Z',
        'courier_location': {
          'latitude': '41.308119',
          'longitude': '69.564014',
          'accuracy': '8.5',
          'recorded_at': '2026-08-08T12:00:00Z',
          'received_at': '2026-08-08T12:00:01Z',
          'client_sequence': 42,
          'age_seconds': 12,
          'is_stale': false,
          'is_unavailable': false,
        },
      });

      expect(tracking.userStatus, 'on_way');
      expect(tracking.refreshInterval, const Duration(seconds: 10));
      expect(tracking.deliveryDeadlineAt, isNotNull);
      expect(tracking.courierLocation?.clientSequence, 42);
      expect(tracking.courierLocation?.hasValidCoordinates, isTrue);
    },
  );

  test('accepted 30s, searching 10s REST reconciliation ishlatadi', () {
    OrderTrackingData tracking(String status) => OrderTrackingData.fromJson({
      'status': status,
      'user_status': status,
      'timeline': <Map<String, dynamic>>[],
    });

    expect(tracking('accepted').refreshInterval, const Duration(seconds: 30));
    expect(tracking('reviewing').refreshInterval, const Duration(seconds: 10));
  });

  test('courier location backend age muzlaganda wall-clock bilan eskiradi', () {
    final location = CourierLocation.fromJson({
      'latitude': '41.308119',
      'longitude': '69.564014',
      'received_at': DateTime.now()
          .subtract(const Duration(minutes: 3))
          .toUtc()
          .toIso8601String(),
      'age_seconds': 0,
      'is_stale': false,
      'is_unavailable': false,
    });

    expect(location.currentAgeSeconds, greaterThanOrEqualTo(179));
    expect(location.isCurrentlyStale, isTrue);
    expect(location.isCurrentlyUnavailable, isTrue);
  });

  test('qayta qidirishda eski courier snapshot UI dan tozalanadi', () {
    final order = _order(
      userStatus: 'accepted',
      courierName: 'Ali',
      courierPhone: '+998901234567',
    );
    final searching = OrderTrackingData.fromJson({
      'status': 'pending',
      'user_status': 'reviewing',
      'store_type': 'grocery',
      'fulfillment_type': 'delivery',
    });

    final merged = order.withTracking(searching);
    expect(merged.isSearchingCourier, isTrue);
    expect(merged.courierName, isEmpty);
    expect(merged.courierPhone, isEmpty);
  });

  test('Mapbox yo‘q holat uchun direct route ikkita nuqta beradi', () {
    final route = MapRouteData.direct(
      const LatLng(41.30, 69.50),
      const LatLng(41.31, 69.56),
    );
    expect(route.points, hasLength(2));
    expect(route.fromMapbox, isFalse);
    expect(route.distanceMeters, greaterThan(0));
  });
}

OrderData _order({
  required String userStatus,
  String courierName = '',
  String courierPhone = '',
}) => OrderData.fromJson({
  'id': 'order-1',
  'order_number': 'BK-1',
  'store_type': 'grocery',
  'fulfillment_type': 'delivery',
  'status': userStatus == 'reviewing' ? 'pending' : userStatus,
  'user_status': userStatus,
  'status_label': userStatus,
  'payment_method': 'cash_to_courier',
  'payment_status': 'pending',
  'subtotal': '10000',
  'delivery_fee': '5000',
  'total': '15000',
  'courier_name': courierName,
  'courier_phone': courierPhone,
  'items': <Map<String, dynamic>>[],
  'created_at': '2026-08-08T10:00:00Z',
});
