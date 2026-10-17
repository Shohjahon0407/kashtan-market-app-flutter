import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/address_delivery_boundary.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/widgets/checkout_delivery_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

DeliveryCoverageBranch _branch(String id, double radius) =>
    DeliveryCoverageBranch(
      id: id,
      name: id,
      latitude: 41,
      longitude: 69,
      radiusKm: radius,
    );

void main() {
  test(
    'largest of four stores is chosen independently of their input order',
    () {
      final branches = [
        _branch('a', 2),
        _branch('b', 8),
        _branch('c', 12),
        _branch('d', 4),
      ];
      expect(largestAddressCoverage(branches)!.id, 'c');
      expect(largestAddressCoverage(branches.reversed.toList())!.id, 'c');
      expect(
        largestAddressCoverage([
          const DeliveryCoverageBranch(id: 'bad', name: '', radiusKm: 100),
          ...branches,
        ])!.id,
        'c',
      );
      expect(largestAddressCoverage([]), isNull);
    },
  );

  test(
    'all bearings clamp inside the real circle, including rectangle corners',
    () {
      final boundary = AddressDeliveryBoundary(_branch('b', 8));
      for (final point in deliveryRadiusPoints(boundary.center, 80)) {
        expect(boundary.contains(point), isFalse);
        final clamped = boundary.clamp(point);
        expect(boundary.contains(clamped), isTrue);
        expect(
          deliveryStraightDistanceKm(boundary.center, clamped),
          closeTo(7.9999, .000001),
        );
        // Coordinate precision used by address persistence must stay inside too.
        final rounded = LatLng(
          double.parse(clamped.latitude.toStringAsFixed(6)),
          double.parse(clamped.longitude.toStringAsFixed(6)),
        );
        expect(boundary.contains(rounded), isTrue);
      }
    },
  );

  test('inside points are unchanged, outside boundary is never accepted', () {
    final boundary = AddressDeliveryBoundary(_branch('b', 8));
    expect(
      boundary.clamp(const LatLng(41.01, 69.01)),
      const LatLng(41.01, 69.01),
    );
    expect(boundary.contains(const LatLng(41.1, 69.1)), isFalse);
    expect(boundary.contains(const LatLng(0, 0)), isFalse);
  });
}
