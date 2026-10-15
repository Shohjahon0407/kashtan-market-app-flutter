import 'dart:ui' as ui;

import 'package:beshkashtan_customer/core/ui/maps/neutral_map_widgets.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/widgets/checkout_delivery_map.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _branch = DeliveryCoverageBranch(
  id: 'branch',
  name: 'Filial',
  latitude: 41,
  longitude: 69,
  radiusKm: 8,
);

void main() {
  test(
    'blue coverage boundary leaves inside and outside transparent',
    () async {
      final recorder = ui.PictureRecorder();
      final painter = DeliveryCoveragePainter(
        camera: MapCamera(
          crs: const Epsg3857(),
          center: const LatLng(41, 69),
          zoom: 10,
          rotation: 0,
          nonRotatedSize: const Size(360, 240),
        ),
        points: deliveryRadiusPoints(const LatLng(41, 69), 8),
      );
      painter.paint(Canvas(recorder), const Size(360, 240));
      final picture = recorder.endRecording();
      final image = await picture.toImage(360, 240);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(bytes.getUint8((120 * 360 + 180) * 4 + 3), 0);
      expect(bytes.getUint8((2 * 360 + 2) * 4 + 3), 0);
      var bluePixels = 0;
      for (var index = 0; index < bytes.lengthInBytes; index += 4) {
        if (bytes.getUint8(index + 3) == 255 &&
            bytes.getUint8(index) == 0x27 &&
            bytes.getUint8(index + 1) == 0x78 &&
            bytes.getUint8(index + 2) == 0xD2) {
          bluePixels++;
        }
      }
      expect(bluePixels, greaterThan(0));
      image.dispose();
      picture.dispose();
    },
  );
  test('radius ring is 8 km; preview picks nearest valid branch', () {
    const centre = LatLng(41, 69);
    final points = deliveryRadiusPoints(centre, 8);
    expect(points, hasLength(128));
    for (final point in points) {
      expect(deliveryStraightDistanceKm(centre, point), closeTo(8, 1e-8));
    }
    const far = DeliveryCoverageBranch(
      id: 'far',
      name: 'Far',
      latitude: 42,
      longitude: 70,
      radiusKm: 8,
    );
    const invalid = DeliveryCoverageBranch(
      id: 'invalid',
      name: 'No coordinates',
    );
    expect(
      selectCoveragePreview([far, invalid, _branch], centre)?.id,
      'branch',
    );
    expect(selectCoveragePreview([far, _branch], null)?.id, 'far');
    expect(selectCoveragePreview([invalid], centre), isNull);
  });

  test('estimate is backward compatible and keeps authoritative branch', () {
    expect(DeliveryEstimate.fromJson({'available': true}).branch, isNull);
    final estimate = DeliveryEstimate.fromJson({
      'available': false,
      'reason_code': 'outside_delivery_radius',
      'coverage_radius_km': '9.50',
      'branch': {
        'id': 'branch',
        'name': 'Filial',
        'latitude': '41',
        'longitude': '69',
        'delivery_radius_km': '9.50',
      },
    });
    expect(estimate.branch!.hasCoverage, isTrue);
    expect(estimate.branch!.radiusKm, 9.5);
    expect(estimate.coverageRadiusKm, 9.5);
    expect(estimate.reasonCode, 'outside_delivery_radius');
  });

  for (final size in const [
    Size(320, 640),
    Size(360, 800),
    Size(430, 900),
    Size(800, 360),
  ]) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('map markers, scroll and fullscreen back $size $locale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gps = ValueNotifier<LatLng?>(const LatLng(41.01, 69.01));
        var locations = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  CheckoutDeliveryMap(
                    branch: _branch,
                    gps: gps,
                    gpsAccuracyMeters: 45,
                    deliveryPoint: const LatLng(41.02, 69.02),
                    onLocate: () => locations++,
                    locationFailed: true,
                  ),
                  const SizedBox(height: 900),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('checkout-map-store-pin')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('checkout-map-address-pin')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('checkout-map-gps-pin')),
          findsOneWidget,
        );
        final accuracy = tester.widget<CircleLayer>(find.byType(CircleLayer));
        expect(accuracy.circles.single.radius, 45);
        expect(accuracy.circles.single.useRadiusInMeter, isTrue);
        expect(accuracy.circles.single.point, gps.value);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CheckoutDeliveryMap)),
        );
        final mini = tester.widget<FlutterMap>(find.byType(FlutterMap));
        expect(
          InteractiveFlag.hasDrag(mini.options.interactionOptions.flags),
          isTrue,
        );
        expect(
          InteractiveFlag.hasPinchZoom(mini.options.interactionOptions.flags),
          isTrue,
        );
        expect(
          InteractiveFlag.hasScrollWheelZoom(
            mini.options.interactionOptions.flags,
          ),
          isFalse,
        );
        expect(
          tester
              .widget<NeutralMapTiles>(find.byType(NeutralMapTiles))
              .neutralize,
          isFalse,
        );
        expect(
          find.descendant(
            of: find.byType(NeutralMapTiles),
            matching: find.byType(ColorFiltered),
          ),
          findsNothing,
        );
        final before = MapCamera.of(
          tester.element(find.byType(MarkerLayer)),
        ).center;
        final mapRect = tester.getRect(
          find.byKey(const ValueKey('checkout-delivery-map')),
        );
        await tester.dragFrom(
          mapRect.topLeft + Offset(mapRect.width / 3, 80),
          const Offset(60, 0),
        );
        await tester.pump();
        final after = MapCamera.of(
          tester.element(find.byType(MarkerLayer)),
        ).center;
        expect(after.longitude, isNot(closeTo(before.longitude, 1e-8)));
        await tester.tap(find.byTooltip(l10n.checkoutMapExpand));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(CircleLayer), findsNWidgets(2));
        final expanded = tester.widget<FlutterMap>(
          find.byType(FlutterMap).last,
        );
        expect(
          expanded.options.interactionOptions.flags,
          isNot(InteractiveFlag.none),
        );
        gps.value = const LatLng(41.03, 69.03);
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Dialog), findsNothing);
        await tester.drag(
          find.byKey(const ValueKey('checkout-delivery-map')),
          const Offset(0, -150),
        );
        await tester.pump();
        expect(locations, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        gps.dispose();
      });
    }
  }
}
