import 'dart:async';

import 'package:beshkashtan_customer/core/ui/maps/neutral_map_widgets.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/address_form_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class _AddressesController extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => const [];
}

/// Saqlangan manzilni yozib oladigan stub.
class _RecordingAddressesController extends AddressesController {
  static final saved = <UserAddress>[];

  @override
  Future<List<UserAddress>> build() async => const [];

  @override
  Future<UserAddress> save(UserAddress address) async {
    saved.add(address);
    return UserAddress(
      id: 'address-1',
      title: address.title,
      latitude: address.latitude,
      longitude: address.longitude,
      isDefault: address.isDefault,
    );
  }
}

Position _position({
  double latitude = 41.311081,
  double longitude = 69.240562,
}) => Position(
  longitude: longitude,
  latitude: latitude,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  testWidgets('late auto-GPS cannot override a manually selected map point', (
    tester,
  ) async {
    final pending = Completer<Position>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesControllerProvider.overrideWith(_AddressesController.new),
          addressLocationResolverProvider.overrideWithValue(
            () => pending.future,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddressFormScreen(),
        ),
      ),
    );
    await tester.pump();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!.call(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(42, 70),
    );
    await tester.pump();
    pending.complete(_position(latitude: 41, longitude: 69));
    await tester.pump();
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markers.markers.single.point, const LatLng(42, 70));
  });

  testWidgets('manzil formida faqat nom va xarita lokatsiyasi qoladi', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesControllerProvider.overrideWith(_AddressesController.new),
          addressLocationResolverProvider.overrideWithValue(
            () async => throw StateError('permission_denied'),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddressFormScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Xaritada nuqtani tanlang'), findsOneWidget);
    expect(find.text('Men turgan joylashuvni aniqlash'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    // Nom endi ixtiyoriy — yorliqda majburiylik yulduzchasi YO'Q.
    expect(find.text('Manzil nomi (ixtiyoriy)'), findsOneWidget);
    expect(find.text('Manzil nomi *'), findsNothing);
    expect(find.text('Tuman *'), findsNothing);
    expect(find.text('Mahalla *'), findsNothing);
    expect(find.text("Ko'cha *"), findsNothing);
    expect(find.text('Uy *'), findsNothing);
    expect(find.text('Xonadon'), findsNothing);
    expect(find.text("Mo'ljal"), findsNothing);
    expect(find.text('Asosiy manzil qilish'), findsNothing);

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(MapCurrentLocationButton),
        matching: find.byType(Stack),
      ),
      findsNothing,
    );

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(
      map.options.interactionOptions.flags & InteractiveFlag.rotate,
      isZero,
    );
    expect(find.byType(NeutralMapTiles), findsOneWidget);

    final controller = map.mapController!;
    expect(controller.camera.zoom, 14);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(controller.camera.zoom, 15);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(controller.camera.zoom, 14);

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    map.options.onTap?.call(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.311081, 69.240562),
    );
    await tester.pump();
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('yangi manzil ochilganda joriy lokatsiya avtomatik tanlanadi', (
    tester,
  ) async {
    var resolveCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesControllerProvider.overrideWith(_AddressesController.new),
          addressLocationResolverProvider.overrideWithValue(() async {
            resolveCalls += 1;
            return _position();
          }),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddressFormScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(resolveCalls, 1);
    expect(find.byType(MarkerLayer), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(
      map.mapController!.camera.center.latitude,
      closeTo(41.311081, 0.000001),
    );
    expect(
      map.mapController!.camera.center.longitude,
      closeTo(69.240562, 0.000001),
    );
    expect(map.mapController!.camera.zoom, 16);
  });

  testWidgets('nom bo\'sh bo\'lsa ham xaritadagi nuqta bilan saqlanadi', (
    tester,
  ) async {
    _RecordingAddressesController.saved.clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesControllerProvider.overrideWith(
            _RecordingAddressesController.new,
          ),
          addressLocationResolverProvider.overrideWithValue(
            () async => throw StateError('location_permission_denied'),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddressFormScreen(),
        ),
      ),
    );
    await tester.pump();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap?.call(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(41.311081, 69.240562),
    );
    await tester.pump();

    // Nom kiritilmaydi — faqat xaritadan nuqta tanlangan.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(_RecordingAddressesController.saved, hasLength(1));
    final saved = _RecordingAddressesController.saved.single;
    expect(saved.title, isEmpty);
    expect(saved.latitude, 41.311081);
    expect(saved.longitude, 69.240562);
    // "Nomni kiriting" degan ogohlantirish CHIQMAYDI.
    expect(find.text('Xaritada lokatsiyani tanlang'), findsNothing);
  });

  testWidgets('lokatsiya tanlanmasa saqlash tugmasi o\'chiq turadi', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesControllerProvider.overrideWith(_AddressesController.new),
          addressLocationResolverProvider.overrideWithValue(
            () async => throw StateError('location_permission_denied'),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddressFormScreen(),
        ),
      ),
    );
    await tester.pump();

    // Nom yozilsa ham lokatsiyasiz saqlab bo'lmaydi.
    await tester.enterText(find.byType(TextFormField), 'Uy');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
