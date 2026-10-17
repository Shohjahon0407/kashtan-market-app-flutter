import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/checkout_models.dart';

DeliveryCoverageBranch? largestAddressCoverage(
  List<DeliveryCoverageBranch> branches,
) {
  final valid = branches.where((b) => b.hasCoverage).toList()
    ..sort((a, b) {
      final radius = b.radiusKm!.compareTo(a.radiusKm!);
      return radius == 0 ? a.id.compareTo(b.id) : radius;
    });
  return valid.firstOrNull;
}

/// A circular constraint, not just a bounding rectangle whose corners would
/// permit choosing points beyond the configured radius. Same spherical radius
/// as checkout/backend distance calculations (6371 km).
class AddressDeliveryBoundary extends CameraConstraint {
  const AddressDeliveryBoundary(this.branch);
  final DeliveryCoverageBranch branch;
  LatLng get center => LatLng(branch.latitude!, branch.longitude!);

  bool contains(LatLng point) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return false;
    }
    final a = center.latitude * math.pi / 180;
    final b = point.latitude * math.pi / 180;
    final dl = (point.longitude - center.longitude) * math.pi / 180;
    final h =
        (math.pow(math.sin((b - a) / 2), 2) +
                math.cos(a) * math.cos(b) * math.pow(math.sin(dl / 2), 2))
            .clamp(0.0, 1.0);
    final km = 6371 * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return km <= branch.radiusKm!;
  }

  LatLng clamp(LatLng point) {
    if (contains(point)) return point;
    final a = center.latitude * math.pi / 180;
    final b = point.latitude * math.pi / 180;
    final dl = (point.longitude - center.longitude) * math.pi / 180;
    final bearing = math.atan2(
      math.sin(dl) * math.cos(b),
      math.cos(a) * math.sin(b) - math.sin(a) * math.cos(b) * math.cos(dl),
    );
    // Keep ten centimetres inside so the API's six-decimal coordinate rounding
    // cannot accidentally move the pin beyond the displayed boundary.
    final angular = math.max(0, branch.radiusKm! - .0001) / 6371;
    final lat = math.asin(
      math.sin(a) * math.cos(angular) +
          math.cos(a) * math.sin(angular) * math.cos(bearing),
    );
    final lon =
        center.longitude * math.pi / 180 +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(a),
          math.cos(angular) - math.sin(a) * math.sin(lat),
        );
    return LatLng(
      lat * 180 / math.pi,
      ((lon * 180 / math.pi + 540) % 360) - 180,
    );
  }

  @override
  MapCamera constrain(MapCamera camera) => contains(camera.center)
      ? camera
      : camera.withPosition(center: clamp(camera.center));
}
