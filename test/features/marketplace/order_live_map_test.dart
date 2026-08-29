import 'dart:async';

import 'package:beshkashtan_customer/features/orders/data/mapbox_directions.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/presentation/widgets/order_live_map.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _QueuedDirections extends MapboxDirections {
  final requests = <Completer<MapRouteData?>>[];

  @override
  Future<MapRouteData?> route({
    required LatLng courier,
    required LatLng destination,
  }) {
    final request = Completer<MapRouteData?>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  testWidgets(
    'eski Directions javobi yangi courier route va ETAsini bosmaydi',
    (tester) async {
      final directions = _QueuedDirections();
      var location = _location(sequence: 1, latitude: 41.300);
      late StateSetter updateHost;

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
                  updateHost = setState;
                  return OrderLiveMap(
                    location: location,
                    destinationLatitude: 41.350,
                    destinationLongitude: 69.600,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(directions.requests, hasLength(1));

      updateHost(() {
        location = _location(sequence: 2, latitude: 41.320);
      });
      await tester.pump();
      expect(directions.requests, hasLength(2));

      directions.requests[1].complete(
        const MapRouteData(
          points: [LatLng(41.320, 69.500), LatLng(41.350, 69.600)],
          duration: Duration(minutes: 5),
          distanceMeters: 8000,
          fromMapbox: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text("Xarita bo'yicha: 5 daqiqa"), findsOneWidget);

      directions.requests[0].complete(
        const MapRouteData(
          points: [LatLng(41.300, 69.500), LatLng(41.350, 69.600)],
          duration: Duration(minutes: 55),
          distanceMeters: 9000,
          fromMapbox: true,
        ),
      );
      await tester.pump();
      expect(find.text("Xarita bo'yicha: 5 daqiqa"), findsOneWidget);
      expect(find.text("Xarita bo'yicha: 55 daqiqa"), findsNothing);

      // Unmount MapController va periodic freshness clockni dispose qiladi.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}

CourierLocation _location({required int sequence, required double latitude}) =>
    CourierLocation(
      latitude: latitude,
      longitude: 69.500,
      recordedAt: DateTime.now(),
      receivedAt: DateTime.now(),
      clientSequence: sequence,
      ageSeconds: 0,
      isStale: false,
      isUnavailable: false,
    );
