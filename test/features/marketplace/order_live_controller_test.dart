import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_live_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// WS payload'i REST kelguncha buyurtma ustiga qo'llanadi; eski nuqta
/// yangisini bosmaydi; REST kelganda yamoq tozalanadi.
void main() {
  late ProviderContainer container;
  late ProviderSubscription<OrderLiveState> sub;

  setUp(() {
    container = ProviderContainer();
    sub = container.listen(orderLiveProvider('o-1'), (_, _) {});
  });

  tearDown(() {
    sub.close();
    container.dispose();
  });

  OrderLiveController notifier() =>
      container.read(orderLiveProvider('o-1').notifier);

  test('order_accepted hodisasi statusni va kuryerni darhol qo\'yadi', () {
    notifier().applyLifecycle({
      'type': 'order_accepted',
      'order_id': 'o-1',
      'status': 'accepted',
      'user_status': 'accepted',
      'status_label_uz': 'Tayyorlanmoqda',
      'status_label_ru': 'Готовится',
      'courier': {
        'full_name': 'Shuhrat',
        'phone_number': '+998901234567',
        'vehicle_type': 'car',
      },
      'courier_eta_minutes': 30,
      'delivery_deadline_at': '2026-10-08T10:26:00Z',
    }, language: 'ru');

    final merged = applyOrderLive(
      _pending(),
      container.read(orderLiveProvider('o-1')),
    );
    expect(merged.customerStage, CustomerOrderStage.accepted);
    expect(merged.statusLabel, 'Готовится');
    expect(merged.courierName, 'Shuhrat');
    expect(merged.courierVehicleType, 'car');
    expect(merged.deliveryWindow, isNotNull);
    expect(merged.deliveryWindow!.end.toUtc().hour, 10);
    expect(merged.deliveryWindow!.end.toUtc().minute, 26);
    expect(merged.deliveryWindow!.start.toUtc().minute, 16);

    notifier().clearPatch();
    final cleared = applyOrderLive(
      _pending(),
      container.read(orderLiveProvider('o-1')),
    );
    expect(cleared.customerStage, CustomerOrderStage.searching);
  });

  test('lokatsiya: eski sequence rad etiladi, oldingi nuqta saqlanadi', () {
    notifier().applyLocation({
      'order_id': 'o-1',
      'status': 'out_for_delivery',
      'location': {
        'latitude': '41.30',
        'longitude': '69.50',
        'client_sequence': 5,
      },
    });
    notifier().applyLocation({
      'order_id': 'o-1',
      'location': {
        'latitude': '41.31',
        'longitude': '69.51',
        'client_sequence': 6,
      },
    });
    notifier().applyLocation({
      'order_id': 'o-1',
      'location': {
        'latitude': '41.00',
        'longitude': '69.00',
        'client_sequence': 4,
      },
    });
    final state = container.read(orderLiveProvider('o-1'));
    expect(state.location?.clientSequence, 6);
    expect(state.previousLocation?.clientSequence, 5);

    // REST'dagi eskiroq nuqta jonli nuqtani bosmaydi.
    final order = _pending().copyWith(
      courierLocation: CourierLocation.fromJson({
        'latitude': '41.20',
        'longitude': '69.40',
        'client_sequence': 3,
      }),
    );
    expect(applyOrderLive(order, state).courierLocation?.clientSequence, 6);
  });

  test('qayta qidiruv hodisasi kuryer nuqtasini tozalaydi', () {
    notifier().applyLocation({
      'order_id': 'o-1',
      'location': {
        'latitude': '41.30',
        'longitude': '69.50',
        'client_sequence': 1,
      },
    });
    notifier().applyLifecycle({
      'type': 'order_searching_again',
      'status': 'pending',
      'user_status': 'reviewing',
    }, language: 'uz');
    final state = container.read(orderLiveProvider('o-1'));
    expect(state.location, isNull);
    final merged = applyOrderLive(
      _pending().copyWith(courierName: 'Ali', courierPhone: '+998'),
      state,
    );
    expect(merged.courierName, isEmpty);
    expect(merged.customerStage, CustomerOrderStage.searching);
  });
}

OrderData _pending() => OrderData.fromJson({
  'id': 'o-1',
  'order_number': 'BK-1',
  'store_type': 'grocery',
  'fulfillment_type': 'delivery',
  'status': 'pending',
  'user_status': 'reviewing',
  'subtotal': '1',
  'delivery_fee': '0',
  'total': '1',
  'items': <Object>[],
  'created_at': '2026-10-08T09:00:00Z',
});
