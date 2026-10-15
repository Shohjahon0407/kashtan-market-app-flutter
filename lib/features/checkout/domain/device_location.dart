import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum DeviceLocationFailure {
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  stale,
  unavailable,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.reason);
  final DeviceLocationFailure reason;
}

typedef LocationAccessResolver = Future<void> Function();
typedef LocationSettingsOpener = Future<bool> Function({required bool gps});

final deviceLocationServiceProvider = Provider((_) => DeviceLocationService());
final addressLocationAccessProvider = Provider<LocationAccessResolver>(
  (ref) => ref.read(deviceLocationServiceProvider).prepare,
);

/// Re-check existing access after resume without opening another OS dialog.
final addressLocationStatusProvider = Provider<LocationAccessResolver>(
  (ref) => ref.read(deviceLocationServiceProvider).checkAccess,
);
final locationSettingsOpenerProvider = Provider<LocationSettingsOpener>(
  (_) =>
      ({required bool gps}) => gps
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings(),
);

/// One-shot requests only. Sharing the in-flight fix prevents checkout and
/// its address form from starting concurrent native location requests.
class DeviceLocationService {
  DeviceLocationService({
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<bool> Function()? serviceEnabled,
    Future<Position> Function()? currentPosition,
  }) : _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _serviceEnabled = serviceEnabled ?? Geolocator.isLocationServiceEnabled,
       _currentPosition =
           currentPosition ??
           (() => Geolocator.getCurrentPosition(
             locationSettings: const LocationSettings(
               accuracy: LocationAccuracy.high,
               timeLimit: Duration(seconds: 15),
             ),
           ));

  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<bool> Function() _serviceEnabled;
  final Future<Position> Function() _currentPosition;
  Future<void>? _access;
  Future<Position>? _request;

  Future<void> prepare() =>
      _access ??= _prepare().whenComplete(() => _access = null);

  Future<void> checkAccess() => _prepare(requestPermission: false);

  Future<void> _prepare({bool requestPermission = true}) async {
    var permission = await _checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await _requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(DeviceLocationFailure.deniedForever);
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const DeviceLocationException(DeviceLocationFailure.denied);
    }
    if (!await _serviceEnabled()) {
      throw const DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
      );
    }
  }

  Future<Position> resolve() =>
      _request ??= _resolve().whenComplete(() => _request = null);

  Future<Position> _resolve() async {
    await prepare();
    try {
      final fix = await _currentPosition().timeout(const Duration(seconds: 15));
      validateFreshLocation(fix);
      return fix;
    } on TimeoutException {
      throw const DeviceLocationException(DeviceLocationFailure.timeout);
    }
  }
}

void validateFreshLocation(Position fix, {DateTime? now}) {
  if (!fix.latitude.isFinite ||
      !fix.longitude.isFinite ||
      fix.latitude.abs() > 90 ||
      fix.longitude.abs() > 180) {
    throw const DeviceLocationException(DeviceLocationFailure.unavailable);
  }
  final age = (now ?? DateTime.now()).difference(fix.timestamp);
  if (age > const Duration(seconds: 60) || age < const Duration(seconds: -60)) {
    throw const DeviceLocationException(DeviceLocationFailure.stale);
  }
}

DeviceLocationFailure locationFailureOf(Object error) {
  if (error is DeviceLocationException) return error.reason;
  if (error is TimeoutException) return DeviceLocationFailure.timeout;
  if (error is LocationServiceDisabledException) {
    return DeviceLocationFailure.serviceDisabled;
  }
  if (error is PermissionDeniedException) return DeviceLocationFailure.denied;
  if (error is StateError && error.message == 'location_permission_denied') {
    return DeviceLocationFailure.denied;
  }
  return DeviceLocationFailure.unavailable;
}
