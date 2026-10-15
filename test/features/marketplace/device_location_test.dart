import 'dart:async';

import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position fix({DateTime? timestamp, double accuracy = 5}) => Position(
  latitude: 41.31,
  longitude: 69.24,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Matcher failsWith(DeviceLocationFailure reason) => throwsA(
  isA<DeviceLocationException>().having(
    (error) => error.reason,
    'reason',
    reason,
  ),
);

void main() {
  test('passive access check never opens the permission dialog', () async {
    var prompts = 0;
    final service = DeviceLocationService(
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        prompts++;
        return LocationPermission.whileInUse;
      },
      serviceEnabled: () async => true,
    );
    await expectLater(
      service.checkAccess(),
      failsWith(DeviceLocationFailure.denied),
    );
    expect(prompts, 0);
    await service.prepare();
    expect(prompts, 1);
  });
  test(
    'asks permission before checking GPS; granted permission is not asked again',
    () async {
      final events = <String>[];
      var granted = false;
      final service = DeviceLocationService(
        checkPermission: () async =>
            granted ? LocationPermission.whileInUse : LocationPermission.denied,
        requestPermission: () async {
          events.add('permission');
          granted = true;
          return LocationPermission.whileInUse;
        },
        serviceEnabled: () async {
          events.add('gps');
          return true;
        },
        currentPosition: () async {
          events.add('fix');
          return fix();
        },
      );
      await service.prepare();
      final position = await service.resolve();
      expect(events, ['permission', 'gps', 'gps', 'fix']);
      expect(position.accuracy, 5);
    },
  );

  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('$permission does not request a GPS fix', () async {
      final service = DeviceLocationService(
        checkPermission: () async => permission,
        requestPermission: () async => permission,
        serviceEnabled: () async => fail('Must not access GPS'),
        currentPosition: () async => fail('Must not request a position'),
      );
      await expectLater(
        service.resolve(),
        failsWith(
          permission == LocationPermission.deniedForever
              ? DeviceLocationFailure.deniedForever
              : DeviceLocationFailure.denied,
        ),
      );
    });
  }

  test('GPS disabled has a separate failure', () async {
    final service = DeviceLocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      serviceEnabled: () async => false,
      currentPosition: () async => fail('Must not request a position'),
    );
    await expectLater(
      service.resolve(),
      failsWith(DeviceLocationFailure.serviceDisabled),
    );
  });

  test('checkout and address form share a single in-flight fix', () async {
    final pending = Completer<Position>();
    var requests = 0;
    final service = DeviceLocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      serviceEnabled: () async => true,
      currentPosition: () {
        requests++;
        return pending.future;
      },
    );
    final first = service.resolve();
    final second = service.resolve();
    expect(identical(first, second), isTrue);
    pending.complete(fix());
    expect(await first, same(await second));
    expect(requests, 1);
  });

  test(
    'old coordinates are rejected while low accuracy remains explicit metadata',
    () {
      expect(
        () => validateFreshLocation(
          fix(timestamp: DateTime.now().subtract(const Duration(minutes: 2))),
        ),
        failsWith(DeviceLocationFailure.stale),
      );
      final approximate = fix(accuracy: 1000);
      validateFreshLocation(approximate);
      expect(approximate.accuracy, 1000);
    },
  );

  testWidgets('one-shot GPS acquisition is bounded to 15 seconds', (
    tester,
  ) async {
    final pending = Completer<Position>();
    final service = DeviceLocationService(
      checkPermission: () async => LocationPermission.whileInUse,
      serviceEnabled: () async => true,
      currentPosition: () => pending.future,
    );
    final assertion = expectLater(
      service.resolve(),
      failsWith(DeviceLocationFailure.timeout),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await assertion;
    pending.complete(fix());
  });
}
