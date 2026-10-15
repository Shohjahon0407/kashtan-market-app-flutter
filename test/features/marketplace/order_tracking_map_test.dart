import 'dart:async';

import 'package:beshkashtan_customer/features/orders/data/mapbox_directions.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/presentation/widgets/order_tracking_map.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _QueuedDirections extends MapboxDirections {
  final requests = <Completer<MapRouteData?>>[];
  final targets = <LatLng>[];

  @override
  Future<MapRouteData?> route({
    required LatLng courier,
    required LatLng destination,
  }) {
    final request = Completer<MapRouteData?>();
    requests.add(request);
    targets.add(destination);
    return request.future;
  }
}

const _home = LatLng(41.350, 69.600);
const _store = LatLng(41.320, 69.550);

void main() {
  Future<_QueuedDirections> pump(
    WidgetTester tester, {
    required CourierLocation? Function() courier,
    required CourierPhase Function() phase,
    required void Function(StateSetter) bind,
  }) async {
    final directions = _QueuedDirections();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapboxDirectionsProvider.overrideWithValue(directions)],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                bind(setState);
                return OrderTrackingMap(
                  home: _home,
                  store: _store,
                  courier: courier(),
                  phase: phase(),
                  vehicleType: 'motorcycle',
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return directions;
  }

  testWidgets('uch marker, yo\'lda eski Directions javobi yangisini bosmaydi', (
    tester,
  ) async {
    var location = _location(sequence: 1, latitude: 41.300);
    late StateSetter update;
    final directions = await pump(
      tester,
      courier: () => location,
      phase: () => CourierPhase.toCustomer,
      bind: (setState) => update = setState,
    );

    expect(find.byKey(const ValueKey('order-map-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-map-store')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-map-courier')), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
    final courierIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('order-map-courier-icon')),
    );
    expect(courierIcon.icon, Icons.delivery_dining_rounded);
    expect(courierIcon.size, 30);
    expect(directions.requests, hasLength(1));
    expect(directions.targets.single, _home);

    update(() => location = _location(sequence: 2, latitude: 41.320));
    await tester.pump();
    expect(directions.requests, hasLength(2));

    directions.requests[1].complete(
      const MapRouteData(
        points: [LatLng(41.320, 69.500), _home],
        duration: Duration(minutes: 5),
        distanceMeters: 8000,
        fromMapbox: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining("Xarita bo'yicha: 5 daqiqa"), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);

    directions.requests[0].complete(
      const MapRouteData(
        points: [LatLng(41.300, 69.500), _home],
        duration: Duration(minutes: 55),
        distanceMeters: 9000,
        fromMapbox: true,
      ),
    );
    await tester.pump();
    expect(find.textContaining("Xarita bo'yicha: 5 daqiqa"), findsOneWidget);
    expect(find.textContaining('55 daqiqa'), findsNothing);

    // Marker yangi nuqtaga silliq siljiydi (900 ms).
    await tester.pump(const Duration(seconds: 1));
    final marker = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .firstWhere((m) => m.key == const ValueKey('order-map-courier'));
    expect(marker.point.latitude, closeTo(41.320, 1e-6));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tayyorlanmoqda: yo\'l do\'konga; kuryer yo\'q — faqat uy va do\'kon',
    (tester) async {
      CourierLocation? location = _location(sequence: 1, latitude: 41.300);
      var phase = CourierPhase.toStore;
      late StateSetter update;
      final directions = await pump(
        tester,
        courier: () => location,
        phase: () => phase,
        bind: (setState) => update = setState,
      );
      expect(directions.targets.single, _store);
      expect(find.byType(PolylineLayer), findsNothing);

      update(() {
        location = null;
        phase = CourierPhase.none;
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('order-map-courier')), findsNothing);
      expect(find.byKey(const ValueKey('order-map-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-map-store')), findsOneWidget);
      expect(directions.requests, hasLength(1));
      expect(find.byType(PolylineLayer), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

CourierLocation _location({required int sequence, required double latitude}) =>
    CourierLocation(
      latitude: latitude,
      longitude: 69.500,
      heading: 90,
      recordedAt: DateTime.now(),
      receivedAt: DateTime.now(),
      clientSequence: sequence,
      ageSeconds: 0,
      isStale: false,
      isUnavailable: false,
    );
