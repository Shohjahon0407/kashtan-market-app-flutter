import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../domain/delivery_address_selection.dart';
import '../domain/device_location.dart';
import 'address_form_screen.dart' show addressLocationResolverProvider;
import 'delivery_address_screen.dart';

/// Authentication and guest-cart merging are completed by the caller first.
/// OS permission settles before navigation; acquiring a fix never blocks the
/// saved-address list. This session ends when the selection route is popped.
Future<DeliveryAddressSelection?> pickCartDeliveryAddress(
  BuildContext context,
  WidgetRef ref,
  StoreType type, {
  String? initialAddressId,
}) async {
  final session = _LocationSession(ref);
  try {
    await session.prepare();
    if (!context.mounted) return null;
    session.start();
    final args = DeliveryAddressArguments(
      initialAddressId: initialAddressId,
      gps: session.gps,
      onLocate: session.retry,
      locationState: session.status,
      onOpenLocationSettings: session.openSettings,
    );
    final route = Routes.cartDeliveryAddressSelect(type.wire);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      return await context.push<DeliveryAddressSelection>(route, extra: args);
    }
    return await Navigator.of(context).push<DeliveryAddressSelection>(
      MaterialPageRoute(
        builder: (_) => DeliveryAddressScreen(
          storeType: type,
          arguments: args,
          selectionRoute: route,
        ),
      ),
    );
  } finally {
    session.dispose();
  }
}

class _LocationSession with WidgetsBindingObserver {
  _LocationSession(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }
  final WidgetRef ref;
  final gps = ValueNotifier<LatLng?>(null);
  final status = ValueNotifier(const DeliveryAddressLocationState());
  Timer? _expiry;
  bool _disposed = false, _allowed = false, _busy = false;
  bool _retrying = false;
  bool _waitingForSettings = false;
  int _revision = 0;

  Future<void> prepare({bool requestPermission = true}) async {
    try {
      await ref.read(
        requestPermission
            ? addressLocationAccessProvider
            : addressLocationStatusProvider,
      )();
      _allowed = true;
    } on Object catch (error) {
      _allowed = false;
      if (!_disposed) {
        status.value = DeliveryAddressLocationState(
          failure: locationFailureOf(error),
        );
      }
    }
  }

  void start() {
    if (_allowed) unawaited(_locate());
  }

  void retry() => unawaited(_retry());

  Future<void> _retry({bool requestPermission = true}) async {
    if (_disposed || _busy || _retrying) return;
    _retrying = true;
    status.value = const DeliveryAddressLocationState(locating: true);
    try {
      await prepare(requestPermission: requestPermission);
      if (!_disposed) start();
    } finally {
      _retrying = false;
    }
  }

  Future<void> _locate() async {
    if (_disposed || _busy) return;
    _busy = true;
    final revision = ++_revision;
    gps.value = null;
    _expiry?.cancel();
    status.value = const DeliveryAddressLocationState(locating: true);
    try {
      final point = await ref
          .read(addressLocationResolverProvider)()
          .timeout(const Duration(seconds: 15));
      validateFreshLocation(point);
      if (_disposed || revision != _revision) return;
      if (!point.accuracy.isFinite ||
          point.accuracy <= 0 ||
          point.accuracy > 100) {
        status.value = const DeliveryAddressLocationState(approximate: true);
        return;
      }
      gps.value = LatLng(point.latitude, point.longitude);
      status.value = const DeliveryAddressLocationState();
      final age = DateTime.now().difference(point.timestamp);
      final remaining =
          const Duration(seconds: 60) - (age.isNegative ? Duration.zero : age);
      _expiry = Timer(remaining, () {
        if (_disposed || revision != _revision) return;
        gps.value = null;
        status.value = const DeliveryAddressLocationState(
          failure: DeviceLocationFailure.stale,
        );
      });
    } on Object catch (error) {
      if (_disposed || revision != _revision) return;
      gps.value = null;
      status.value = DeliveryAddressLocationState(
        failure: locationFailureOf(error),
      );
    } finally {
      if (!_disposed && revision == _revision) _busy = false;
    }
  }

  void openSettings() => unawaited(_openSettings());

  Future<void> _openSettings() async {
    if (_disposed) return;
    _waitingForSettings = true;
    try {
      final opened = await ref.read(locationSettingsOpenerProvider)(
        gps: status.value.failure == DeviceLocationFailure.serviceDisabled,
      );
      if (!opened) _waitingForSettings = false;
    } on Object {
      _waitingForSettings = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      unawaited(_retry(requestPermission: false));
    }
  }

  void dispose() {
    _disposed = true;
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    gps.dispose();
    status.dispose();
  }
}
