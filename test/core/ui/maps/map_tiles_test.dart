import 'package:beshkashtan_customer/core/ui/maps/neutral_map_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final density in [1.0, 3.0]) {
    testWidgets('Mapbox 512 tiles preserve projection and sharpness $density', (
      tester,
    ) async {
      tester.view.devicePixelRatio = density;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              children: [
                NeutralMapTiles(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/'
                      'tiles/512/{z}/{x}/{y}{r}.webp?access_token=pk.test',
                  userAgentPackageName: 'uz.beshkashtan.customer',
                ),
              ],
            ),
          ),
        ),
      );
      final layer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(layer.tileDimension, 512);
      expect(layer.zoomOffset, -1);
      expect(
        layer.resolvedRetinaMode,
        density > 1 ? RetinaMode.server : RetinaMode.disabled,
      );
      expect(layer.tileProvider, isA<NetworkTileProvider>());
      expect(find.byType(ColorFiltered), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('OSM stays on its native 256 projection without extra requests', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            children: [
              NeutralMapTiles(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'uz.beshkashtan.customer',
              ),
            ],
          ),
        ),
      ),
    );
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.tileDimension, 256);
    expect(layer.zoomOffset, 0);
    expect(layer.resolvedRetinaMode, RetinaMode.disabled);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final useMapbox in [false, true]) {
    testWidgets('attribution fits narrow screens with large text $useMapbox', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 256,
                child: MapTileAttribution(useMapbox: useMapbox),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('© OpenStreetMap'), findsOneWidget);
      expect(find.text('© Mapbox'), useMapbox ? findsOneWidget : findsNothing);
      expect(
        find.text('Improve this map'),
        useMapbox ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(SvgPicture),
        useMapbox ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
