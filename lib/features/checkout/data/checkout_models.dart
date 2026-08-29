import '../../../core/network/json_read.dart';
import '../../store/data/store_models.dart';

class UserAddress {
  const UserAddress({
    required this.id,
    required this.title,
    required this.isDefault,
    this.district = '',
    this.neighborhood = '',
    this.street = '',
    this.house = '',
    this.apartment = '',
    this.landmark = '',
    this.latitude,
    this.longitude,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) => UserAddress(
    id: JsonRead.string(json['id']),
    title: JsonRead.string(json['title']),
    district: JsonRead.string(json['district']),
    neighborhood: JsonRead.string(json['neighborhood']),
    street: JsonRead.string(json['street']),
    house: JsonRead.string(json['house']),
    apartment: JsonRead.string(json['apartment']),
    landmark: JsonRead.string(json['landmark']),
    latitude: JsonRead.nullableDouble(json['latitude']),
    longitude: JsonRead.nullableDouble(json['longitude']),
    isDefault: JsonRead.boolean(json['is_default']),
  );

  final String id;
  final String title;
  final String district;
  final String neighborhood;
  final String street;
  final String house;
  final String apartment;
  final String landmark;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  String get formattedAddress {
    final legacyText = [
      district,
      neighborhood,
      street,
      house,
      if (apartment.isNotEmpty) apartment,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    if (legacyText.isNotEmpty) return legacyText;
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(6)}, '
          '${longitude!.toStringAsFixed(6)}';
    }
    return title;
  }

  Map<String, dynamic> toRequestJson() => {
    'title': title.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'is_default': isDefault,
  };
}

class StoreBranch {
  const StoreBranch({
    required this.id,
    required this.store,
    required this.name,
    required this.address,
    required this.phone,
    required this.isPickupAvailable,
    required this.isActive,
    this.latitude,
    this.longitude,
  });

  factory StoreBranch.fromJson(Map<String, dynamic> json) {
    final store = JsonRead.map(json['store']) ?? const <String, dynamic>{};
    return StoreBranch(
      id: JsonRead.string(json['id']),
      store: StoreInfo.fromJson(store),
      name: JsonRead.string(json['name']),
      address: JsonRead.string(json['address']),
      phone: JsonRead.string(json['phone']),
      isPickupAvailable: JsonRead.boolean(json['is_pickup_available']),
      isActive: JsonRead.boolean(json['is_active'], fallback: true),
      latitude: JsonRead.nullableDouble(json['latitude']),
      longitude: JsonRead.nullableDouble(json['longitude']),
    );
  }

  final String id;
  final StoreInfo store;
  final String name;
  final String address;
  final String phone;
  final bool isPickupAvailable;
  final bool isActive;
  final double? latitude;
  final double? longitude;
}

class DeliveryEstimate {
  const DeliveryEstimate({
    required this.available,
    required this.detail,
    this.distanceKm,
    this.deliveryPrice,
    this.maxDistanceKm,
  });

  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) =>
      DeliveryEstimate(
        available: JsonRead.boolean(
          json['available'] ?? json['delivery_available'],
        ),
        distanceKm: JsonRead.nullableString(json['distance_km']),
        deliveryPrice: JsonRead.nullableString(
          json['delivery_price'] ?? json['delivery_fee'],
        ),
        maxDistanceKm: JsonRead.nullableString(json['max_distance_km']),
        detail: JsonRead.string(json['detail'] ?? json['message']),
      );

  final bool available;
  final String? distanceKm;
  final String? deliveryPrice;
  final String? maxDistanceKm;
  final String detail;
}

enum FulfillmentType {
  delivery('delivery'),
  pickup('pickup');

  const FulfillmentType(this.wire);
  final String wire;
}
