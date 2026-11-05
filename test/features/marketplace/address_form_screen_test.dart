import 'dart:async';

import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/maps/neutral_map_widgets.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/address_form_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class _Addresses extends AddressesController {
  static List<UserAddress> items = [];
  static List<UserAddress> saved = [];
  static ApiFailure? failure;
  @override
  Future<List<UserAddress>> build() async => items;
  @override
  Future<UserAddress> save(UserAddress address) async {
    if (failure != null) throw failure!;
    saved.add(address);
    return UserAddress(
      id: address.id.isEmpty ? 'created-id' : address.id,
      title: address.title,
      isDefault: address.isDefault,
      latitude: address.latitude,
      longitude: address.longitude,
      landmark: address.landmark,
    );
  }
}

Position _position({double lat = 41.311081, double lon = 69.240562}) =>
    Position(
      longitude: lon,
      latitude: lat,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

Future<void> _mount(
  WidgetTester tester, {
  AddressLocationResolver? location,
  String? addressId,
  Locale locale = const Locale('uz'),
  double scale = 1,
  double keyboard = 0,
  StoreType? store,
  bool pushed = false,
  void Function(String?)? onResult,
  Future<List<DeliveryCoverageBranch>> Function()? coverage,
  Future<List<DeliveryCoverageBranch>> Function()? storeCoverage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressesControllerProvider.overrideWith(_Addresses.new),
        addressLocationResolverProvider.overrideWithValue(
          location ??
              () async => throw const DeviceLocationException(
                DeviceLocationFailure.denied,
              ),
        ),
        addressCoverageProvider.overrideWith(
          (_) async => coverage != null
              ? coverage()
              : [
                  DeliveryCoverageBranch(
                    id: 'b1',
                    name: 'Filial',
                    latitude: store == null ? 41.5 : 41.31,
                    longitude: store == null ? 69.5 : 69.24,
                    radiusKm: store == null ? 100 : 8,
                  ),
                ],
        ),
        deliveryCoverageProvider.overrideWith(
          (ref, type) async => storeCoverage != null
              ? storeCoverage()
              : const [
                  DeliveryCoverageBranch(
                    id: 'xozmak-branch',
                    name: 'Xozmak',
                    latitude: 41.31,
                    longitude: 69.24,
                    radiusKm: 2,
                  ),
                ],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: pushed
            ? Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open picker'),
                    onPressed: () async {
                      final result = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => AddressFormScreen(
                            addressId: addressId,
                            storeType: store,
                          ),
                        ),
                      );
                      onResult?.call(result);
                    },
                  ),
                ),
              )
            : AddressFormScreen(addressId: addressId, storeType: store),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (pushed) {
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }
}

void _select(WidgetTester tester, LatLng point) {
  tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
    const TapPosition(Offset.zero, Offset.zero),
    point,
  );
}

FilledButton _confirm(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('address-confirm')));

void main() {
  setUp(() {
    _Addresses.items = [];
    _Addresses.saved = [];
    _Addresses.failure = null;
  });

  const smallCircle = DeliveryCoverageBranch(
    id: 'limit',
    name: 'Do‘kon',
    latitude: 41,
    longitude: 69,
    radiusKm: 8,
  );

  testWidgets(
    'late coverage never blocks saving or changes the selected point/camera',
    (tester) async {
      final coverage = Completer<List<DeliveryCoverageBranch>>();
      final gps = Completer<Position>();
      await _mount(
        tester,
        coverage: () => coverage.future,
        location: () => gps.future,
      );
      _select(tester, const LatLng(42, 70));
      await tester.pump();
      expect(_confirm(tester).onPressed, isNotNull);
      final before = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera
          .center;
      coverage.complete(const [smallCircle]);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircleLayer), findsNothing);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
        const LatLng(42, 70),
      );
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center,
        before,
      );
      gps.complete(_position(lat: 43, lon: 71));
      await tester.pump();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
        const LatLng(42, 70),
      );
      expect(_confirm(tester).onPressed, isNotNull);
    },
  );

  testWidgets('coverage error does not block selecting and saving a point', (
    tester,
  ) async {
    await _mount(tester, coverage: () async => throw const NetworkFailure());
    _select(tester, const LatLng(42, 70));
    await tester.pump();
    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pump();
    expect(_Addresses.saved.single.latitude, 42);
    expect(_Addresses.saved.single.longitude, 70);
    expect(find.text('Yetkazish hududi yuklanmoqda…'), findsNothing);
  });

  testWidgets('manual tap and camera can leave the old circle', (tester) async {
    await _mount(tester, coverage: () async => const [smallCircle]);
    _select(tester, const LatLng(42, 70));
    await tester.pump();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
      const LatLng(42, 70),
    );
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(const LatLng(0, 0), 10);
    await tester.pump();
    expect(controller.camera.center, const LatLng(0, 0));
    expect(_confirm(tester).onPressed, isNotNull);
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('GPS outside the old region can be saved', (tester) async {
    await _mount(
      tester,
      coverage: () async => const [smallCircle],
      location: () async => _position(lat: 42, lon: 70),
    );
    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pump();
    expect(_Addresses.saved.single.latitude, 42);
    expect(_Addresses.saved.single.longitude, 70);
  });

  testWidgets('no coverage allows saving a valid address', (tester) async {
    await _mount(
      tester,
      coverage: () async => [],
      location: () async => _position(),
    );
    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pump();
    expect(_Addresses.saved, hasLength(1));
  });

  testWidgets('save does not refresh or enforce a legacy radius', (
    tester,
  ) async {
    var requests = 0;
    await _mount(
      tester,
      coverage: () async {
        requests++;
        return [
          DeliveryCoverageBranch(
            id: 'b',
            name: 'Store',
            latitude: 41,
            longitude: 69,
            radiusKm: requests == 1 ? 8 : 1,
          ),
        ];
      },
    );
    _select(tester, const LatLng(41.04, 69));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pump();
    await tester.pump();
    expect(requests, 1);
    expect(_Addresses.saved.single.latitude, 41.04);
  });

  for (final store in StoreType.values) {
    testWidgets('far address is saved without a radius gate for $store', (
      tester,
    ) async {
      await _mount(
        tester,
        store: store,
        location: () async => _position(lat: 55, lon: 37),
      );
      expect(_confirm(tester).onPressed, isNotNull);
      expect(find.byType(CircleLayer), findsNothing);
      await tester.tap(find.byKey(const ValueKey('address-confirm')));
      await tester.pump();
      expect(_Addresses.saved.single.latitude, 55);
      expect(_Addresses.saved.single.longitude, 37);
    });
  }

  testWidgets('failed save retains point and allows retry without coverage', (
    tester,
  ) async {
    await _mount(
      tester,
      coverage: () async => [],
      location: () async => _position(lat: 55, lon: 37),
    );
    _Addresses.failure = const NetworkFailure();
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(AddressFormScreen), findsOneWidget);
    expect(_Addresses.saved, isEmpty);
    expect(_confirm(tester).onPressed, isNotNull);
    _Addresses.failure = null;
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pumpAndSettle();
    expect(_Addresses.saved.single.latitude, 55);
  });

  for (final size in [const Size(320, 640), const Size(800, 360)]) {
    testWidgets('save error never covers confirm at 200% $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _mount(
        tester,
        locale: const Locale('ru'),
        scale: 2,
        location: () async => _position(),
      );
      _Addresses.failure = const NetworkFailure();
      await tester.tap(find.byKey(const ValueKey('address-confirm')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(
        find.byKey(const ValueKey('address-confirm')).hitTestable(),
        findsOneWidget,
      );
      expect(_Addresses.saved, isEmpty);
    });
  }

  testWidgets('invalid coordinates are not selected or saved', (tester) async {
    await _mount(tester);
    for (final point in [
      const LatLng(91, 69),
      const LatLng(41, 181),
      const LatLng(double.nan, 69),
    ]) {
      _select(tester, point);
      await tester.pump();
      expect(_confirm(tester).onPressed, isNull);
    }
    expect(_Addresses.saved, isEmpty);
  });

  testWidgets(
    'map-led layout, optional details, controls and no mandatory legacy fields',
    (tester) async {
      await _mount(tester);
      expect(find.text('Yangi manzil qo‘shish'), findsOneWidget);
      expect(find.text('Yetkazish nuqtasini belgilang'), findsOneWidget);
      expect(find.byKey(const ValueKey('address-search')), findsNothing);
      expect(find.byIcon(Icons.search_rounded), findsNothing);
      expect(
        find.byKey(const ValueKey('address-details-panel')),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(find.byType(NeutralMapTiles), findsOneWidget);
      expect(find.byType(MapTileAttribution), findsOneWidget);
      expect(find.text('Tuman *'), findsNothing);
      expect(_confirm(tester).onPressed, isNull);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        map.options.interactionOptions.flags & InteractiveFlag.rotate,
        isZero,
      );
      final initialZoom = map.mapController!.camera.zoom;
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(map.mapController!.camera.zoom, closeTo(initialZoom + 1, .000001));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(map.mapController!.camera.zoom, closeTo(initialZoom, .000001));
      _select(tester, const LatLng(41, 69));
      await tester.pump();
      expect(_confirm(tester).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late auto-GPS cannot override a manually selected map point', (
    tester,
  ) async {
    final pending = Completer<Position>();
    await _mount(tester, location: () => pending.future);
    _select(tester, const LatLng(42, 70));
    await tester.pump();
    pending.complete(_position());
    await tester.pump();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
      const LatLng(42, 70),
    );
  });

  testWidgets('new address requests GPS once and moves camera without saving', (
    tester,
  ) async {
    var calls = 0;
    await _mount(
      tester,
      location: () async {
        calls++;
        return _position();
      },
    );
    expect(calls, 1);
    expect(
      tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera
          .zoom,
      16,
    );
    expect(find.text('41.311081, 69.240562'), findsOneWidget);
    expect(_Addresses.saved, isEmpty);
    expect(_confirm(tester).onPressed, isNotNull);
  });

  testWidgets('edit location focuses the map without opening search', (
    tester,
  ) async {
    await _mount(tester, location: () async => _position());
    await tester.tap(find.byIcon(Icons.edit_location_alt_outlined));
    await tester.pump();
    final camera = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;
    expect(camera.center.latitude, closeTo(41.311081, .000001));
    expect(camera.center.longitude, closeTo(69.240562, .000001));
    expect(camera.zoom, 16);
    expect(find.byKey(const ValueKey('address-search')), findsNothing);
    expect(_Addresses.saved, isEmpty);
  });

  testWidgets('address type and courier note saved; title can still be blank', (
    tester,
  ) async {
    await _mount(tester, location: () async => _position());
    await tester.tap(find.text('Boshqa'));
    await tester.pump();
    final title = find.byKey(const ValueKey('address-title'));
    await tester.ensureVisible(title);
    await tester.enterText(title, '');
    final note = find.byKey(const ValueKey('address-courier-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, 'Darvoza kodi 124');
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pump();
    expect(_Addresses.saved, hasLength(1));
    expect(_Addresses.saved.single.title, isEmpty);
    expect(_Addresses.saved.single.landmark, 'Darvoza kodi 124');
    expect(
      _Addresses.saved.single.toRequestJson()['landmark'],
      'Darvoza kodi 124',
    );
  });

  testWidgets(
    'editing preserves existing address, default status and note, no auto GPS',
    (tester) async {
      _Addresses.items = const [
        UserAddress(
          id: 'edit',
          title: 'Uy',
          isDefault: true,
          latitude: 41,
          longitude: 69,
          district: 'Parkent',
          street: 'Ko‘cha',
          house: '14',
          landmark: 'Eski izoh',
        ),
      ];
      var calls = 0;
      await _mount(
        tester,
        addressId: 'edit',
        location: () async {
          calls++;
          return _position();
        },
      );
      expect(calls, 0);
      expect(find.text('Manzilni tahrirlash'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('address-confirm')));
      await tester.pump();
      final saved = _Addresses.saved.single;
      expect(saved.id, 'edit');
      expect(saved.isDefault, isTrue);
      expect(saved.latitude, 41);
      expect(saved.street, 'Ko‘cha');
      expect(saved.house, '14');
      expect(saved.landmark, 'Eski izoh');
    },
  );

  testWidgets(
    'moving edited pin clears stale street but preserves courier note',
    (tester) async {
      _Addresses.items = const [
        UserAddress(
          id: 'edit',
          title: 'Uy',
          isDefault: false,
          latitude: 41,
          longitude: 69,
          street: 'Old street',
          landmark: 'Call',
        ),
      ];
      await _mount(tester, addressId: 'edit');
      _select(tester, const LatLng(42, 70));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('address-confirm')));
      await tester.pump();
      expect(_Addresses.saved.single.street, isEmpty);
      expect(_Addresses.saved.single.landmark, 'Call');
      expect(_Addresses.saved.single.latitude, 42);
    },
  );

  testWidgets('optional store marker has no radius label or circle', (
    tester,
  ) async {
    await _mount(
      tester,
      store: StoreType.household,
      location: () async => _position(),
    );
    expect(find.byType(CircleLayer), findsNothing);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );
    expect(find.textContaining('8 km'), findsNothing);
    expect(find.textContaining('2 km'), findsNothing);
  });

  testWidgets('store coverage error never blocks a valid address', (
    tester,
  ) async {
    await _mount(
      tester,
      store: StoreType.household,
      location: () async => _position(),
      storeCoverage: () async => throw const NetworkFailure(),
    );
    expect(find.byType(CircleLayer), findsNothing);
    expect(_confirm(tester).onPressed, isNotNull);
  });

  testWidgets('saving never revalidates store or global radii', (tester) async {
    var calls = 0;
    await _mount(
      tester,
      store: StoreType.household,
      storeCoverage: () async => [
        DeliveryCoverageBranch(
          id: 'xozmak',
          name: 'Xozmak',
          latitude: 41.31,
          longitude: 69.24,
          radiusKm: ++calls == 1 ? 8 : 1,
        ),
      ],
    );
    _select(tester, const LatLng(43, 71));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(_Addresses.saved.single.latitude, 43);
    expect(_Addresses.saved.single.longitude, 71);
  });

  for (final locale in [
    const Locale('uz'),
    const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    const Locale('ru'),
  ]) {
    for (final size in [
      const Size(320, 640),
      const Size(430, 850),
      const Size(740, 360),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('responsive $locale $size $scale', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await _mount(
            tester,
            locale: locale,
            scale: scale,
            location: () async => _position(),
          );
          expect(tester.takeException(), isNull);
          final button = tester.getRect(
            find.byKey(const ValueKey('address-confirm')),
          );
          expect(button.left, greaterThanOrEqualTo(0));
          expect(button.right, lessThanOrEqualTo(size.width));
          expect(button.bottom, lessThanOrEqualTo(size.height));
          await tester.ensureVisible(
            find.byKey(const ValueKey('address-courier-note')),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('keyboard keeps confirm reachable without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _mount(tester, keyboard: 270, location: () async => _position());
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const ValueKey('address-confirm'))).bottom,
      lessThanOrEqualTo(370),
    );
  });

  for (final failure in DeviceLocationFailure.values) {
    testWidgets('GPS $failure never blocks manual map selection', (
      tester,
    ) async {
      await _mount(
        tester,
        location: () async => throw DeviceLocationException(failure),
      );
      expect(_confirm(tester).onPressed, isNull);
      _select(tester, const LatLng(41, 69));
      await tester.pump();
      expect(_confirm(tester).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dragging map selects the new camera centre', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _mount(tester, location: () async => _position());
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final before = map.mapController!.camera.center;
    final area = tester.getRect(find.byType(FlutterMap));
    await tester.dragFrom(
      Offset(area.left + 100, area.top + 130),
      const Offset(-60, 20),
    );
    await tester.pump();
    expect(map.mapController!.camera.center, isNot(before));
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
      map.mapController!.camera.center,
    );
  });

  testWidgets('system back closes help without leaving address form', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
    expect(find.byType(AddressFormScreen), findsOneWidget);
  });

  testWidgets('tile failure can be retried and does not block confirmation', (
    tester,
  ) async {
    await _mount(tester, location: () async => _position());
    final tiles = tester.widget<NeutralMapTiles>(find.byType(NeutralMapTiles));
    tiles.onTileError!();
    await tester.pump();
    await tester.pump();
    expect(find.text('Xarita yuklanmadi. Qayta yuklash'), findsOneWidget);
    expect(_confirm(tester).onPressed, isNotNull);
    await tester.tap(find.text('Xarita yuklanmadi. Qayta yuklash'));
    await tester.pump();
    expect(
      tester.widget<NeutralMapTiles>(find.byType(NeutralMapTiles)).key,
      isNot(tiles.key),
    );
    expect(_Addresses.saved, isEmpty);
  });

  testWidgets('retry GPS is one shot and still requires confirmation', (
    tester,
  ) async {
    var calls = 0;
    await _mount(
      tester,
      location: () async {
        calls++;
        if (calls == 1) {
          throw const DeviceLocationException(DeviceLocationFailure.timeout);
        }
        return _position();
      },
    );
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(_confirm(tester).onPressed, isNotNull);
    expect(_Addresses.saved, isEmpty);
  });

  testWidgets('confirmation returns saved address ID to checkout', (
    tester,
  ) async {
    String? result;
    await _mount(
      tester,
      pushed: true,
      location: () async => _position(),
      onResult: (id) => result = id,
    );
    await tester.tap(find.byKey(const ValueKey('address-confirm')));
    await tester.pumpAndSettle();
    expect(result, 'created-id');
    expect(find.byType(AddressFormScreen), findsNothing);
  });

  for (final system in [false, true]) {
    testWidgets('cancel address without saving, system back $system', (
      tester,
    ) async {
      await _mount(tester, pushed: true, location: () async => _position());
      if (system) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byType(BackButton));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AddressFormScreen), findsNothing);
      expect(_Addresses.saved, isEmpty);
    });
  }
}
