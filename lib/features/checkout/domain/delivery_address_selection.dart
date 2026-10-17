import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../cart/data/cart_models.dart';
import '../data/checkout_models.dart';
import 'checkout_rules.dart';
import 'device_location.dart';

String deliveryStoreScope(CartData cart) =>
    (CheckoutRules.physicalStoreIds(cart).toList()..sort()).join('|');

/// Order-local choice, not a request to change the account's default address.
class DeliveryAddressSelection {
  const DeliveryAddressSelection({
    required this.address,
    required this.estimate,
    required this.storeScope,
  });
  final UserAddress address;
  final DeliveryEstimate estimate;
  final String storeScope;

  bool matches(UserAddress current, CartData cart) =>
      address.id == current.id &&
      address.latitude == current.latitude &&
      address.longitude == current.longitude &&
      storeScope == deliveryStoreScope(cart);
}

class DeliveryAddressArguments {
  const DeliveryAddressArguments({
    this.initialAddressId,
    required this.gps,
    required this.onLocate,
    this.locationState,
    this.onOpenLocationSettings,
  });
  final String? initialAddressId;
  final ValueListenable<LatLng?> gps;
  final VoidCallback onLocate;
  final ValueListenable<DeliveryAddressLocationState>? locationState;
  final VoidCallback? onOpenLocationSettings;
}

/// One-shot GPS feedback only; never a checkout delivery-address selection.
class DeliveryAddressLocationState {
  const DeliveryAddressLocationState({
    this.locating = false,
    this.failure,
    this.approximate = false,
  });
  final bool locating;
  final DeviceLocationFailure? failure;
  final bool approximate;
}

bool hasDeliveryCoordinates(UserAddress address) =>
    address.latitude != null &&
    address.longitude != null &&
    address.latitude!.isFinite &&
    address.longitude!.isFinite &&
    address.latitude!.abs() <= 90 &&
    address.longitude!.abs() <= 180;

UserAddress? initialDeliveryAddress(
  List<UserAddress> addresses,
  String? currentId,
) =>
    addresses
        .where((a) => a.id == currentId && hasDeliveryCoordinates(a))
        .firstOrNull ??
    addresses
        .where((a) => a.isDefault && hasDeliveryCoordinates(a))
        .firstOrNull ??
    addresses.where(hasDeliveryCoordinates).firstOrNull;
