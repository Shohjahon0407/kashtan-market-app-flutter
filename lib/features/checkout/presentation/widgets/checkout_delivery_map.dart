import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/config/app_config.dart';
import '../../../../core/ui/maps/neutral_map_widgets.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/checkout_models.dart';

String deliveryRadiusLabel(double radius) => radius
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

List<LatLng> deliveryRadiusPoints(LatLng centre, double radiusKm) {
  final angular = radiusKm / 6371;
  final lat = centre.latitude * math.pi / 180;
  final lon = centre.longitude * math.pi / 180;
  return List.generate(128, (index) {
    final bearing = index * 2 * math.pi / 128;
    final nextLat = math.asin(
      math.sin(lat) * math.cos(angular) +
          math.cos(lat) * math.sin(angular) * math.cos(bearing),
    );
    final nextLon =
        lon +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(lat),
          math.cos(angular) - math.sin(lat) * math.sin(nextLat),
        );
    return LatLng(nextLat * 180 / math.pi, nextLon * 180 / math.pi);
  });
}

double deliveryStraightDistanceKm(LatLng start, LatLng end) {
  final lat1 = start.latitude * math.pi / 180;
  final lat2 = end.latitude * math.pi / 180;
  final dLat = lat2 - lat1;
  final dLon = (end.longitude - start.longitude) * math.pi / 180;
  final h =
      (math.pow(math.sin(dLat / 2), 2) +
              math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2))
          .clamp(0.0, 1.0);
  return 6371 * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

DeliveryCoverageBranch? selectCoveragePreview(
  List<DeliveryCoverageBranch> branches,
  LatLng? gps,
) {
  final valid = branches.where((branch) => branch.hasCoordinates).toList();
  if (valid.isEmpty) return null;
  if (gps == null) return valid.first;
  valid.sort(
    (a, b) => deliveryStraightDistanceKm(gps, LatLng(a.latitude!, a.longitude!))
        .compareTo(
          deliveryStraightDistanceKm(gps, LatLng(b.latitude!, b.longitude!)),
        ),
  );
  return valid.first;
}

class CheckoutDeliveryMap extends StatelessWidget {
  const CheckoutDeliveryMap({
    required this.branch,
    required this.gps,
    required this.onLocate,
    this.deliveryPoint,
    this.gpsAccuracyMeters,
    this.locating = false,
    this.locationFailed = false,
    this.compact = false,
    super.key,
  });

  final DeliveryCoverageBranch branch;
  final LatLng? deliveryPoint;
  final double? gpsAccuracyMeters;
  final ValueListenable<LatLng?> gps;
  final VoidCallback onLocate;
  final bool locating;
  final bool locationFailed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            key: const ValueKey('checkout-delivery-map'),
            height: compact ? 180 : 240,
            child: _CoverageMap(
              compact: compact,
              branch: branch,
              deliveryPoint: deliveryPoint,
              gps: gps,
              gpsAccuracyMeters: gpsAccuracyMeters,
              onExpand: () => showDialog<void>(
                context: context,
                useSafeArea: false,
                builder: (context) => Dialog.fullscreen(
                  child: Scaffold(
                    appBar: AppBar(title: Text(l10n.checkoutDeliveryMapTitle)),
                    body: SafeArea(
                      child: _CoverageMap(
                        branch: branch,
                        deliveryPoint: deliveryPoint,
                        gps: gps,
                        gpsAccuracyMeters: gpsAccuracyMeters,
                        expanded: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _Legend(
              label: l10n.checkoutMapStore,
              color: const Color(0xFF7663A7),
            ),
            _Legend(
              label: l10n.checkoutMapAddress,
              color: const Color(0xFF087F65),
            ),
            _Legend(label: l10n.checkoutMapYou, color: const Color(0xFF2778D2)),
          ],
        ),
        if (!compact)
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: locating ? null : onLocate,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(
                  locating ? l10n.checkoutMapLocating : l10n.checkoutMapYou,
                ),
              ),
            ],
          ),
        if (locationFailed)
          Text(
            l10n.checkoutMapGpsUnavailable,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 5),
      Flexible(child: Text(label)),
    ],
  );
}

class _CoverageMap extends StatefulWidget {
  const _CoverageMap({
    required this.branch,
    required this.gps,
    this.deliveryPoint,
    this.gpsAccuracyMeters,
    this.onExpand,
    this.expanded = false,
    this.compact = false,
  });
  final DeliveryCoverageBranch branch;
  final LatLng? deliveryPoint;
  final double? gpsAccuracyMeters;
  final ValueListenable<LatLng?> gps;
  final VoidCallback? onExpand;
  final bool expanded;
  final bool compact;
  @override
  State<_CoverageMap> createState() => _CoverageMapState();
}

class _CoverageMapState extends State<_CoverageMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _tileFailed = false;
  int _tileRetry = 0;
  LatLng get _centre =>
      LatLng(widget.branch.latitude!, widget.branch.longitude!);
  @override
  void initState() {
    super.initState();
    widget.gps.addListener(_gpsChanged);
  }

  void _gpsChanged() {
    if (widget.deliveryPoint == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  void _fit({bool includeGps = true}) {
    if (!_ready || !mounted) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          _centre,
          if (widget.deliveryPoint != null) widget.deliveryPoint!,
          if (includeGps && widget.gps.value != null) widget.gps.value!,
        ]),
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 35),
        maxZoom: 16,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _CoverageMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gps != widget.gps) {
      oldWidget.gps.removeListener(_gpsChanged);
      widget.gps.addListener(_gpsChanged);
    }
    if (oldWidget.branch != widget.branch ||
        oldWidget.deliveryPoint != widget.deliveryPoint) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _fit(includeGps: widget.deliveryPoint == null),
      );
    }
  }

  @override
  void dispose() {
    widget.gps.removeListener(_gpsChanged);
    _controller.dispose();
    super.dispose();
  }

  Marker _marker(
    LatLng point,
    IconData icon,
    Color color,
    String label,
    String key,
  ) => Marker(
    point: point,
    width: 44,
    height: 44,
    child: Semantics(
      label: label,
      child: Container(
        key: ValueKey(key),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(icon, color: Colors.white, size: 23),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<LatLng?>(
      valueListenable: widget.gps,
      builder: (context, gps, _) => Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _centre,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: InteractionOptions(
                flags: widget.expanded
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    // A finger can pan/pinch the mini-map. Wheel scrolling
                    // stays with checkout on Web instead of changing zoom.
                    : InteractiveFlag.all &
                          ~InteractiveFlag.rotate &
                          ~InteractiveFlag.scrollWheelZoom,
              ),
              onMapReady: () {
                _ready = true;
                _fit(includeGps: widget.deliveryPoint == null);
              },
            ),
            children: [
              // Tile failures are visual only: address/store pins still work.
              NeutralMapTiles(
                key: ValueKey('checkout-map-tiles-$_tileRetry'),
                neutralize: false,
                urlTemplate: AppConfig.addressTileUrl,
                userAgentPackageName: 'uz.beshkashtan.customer',
                onTileError: () {
                  if (!_tileFailed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_tileFailed && mounted) {
                        setState(() => _tileFailed = true);
                      }
                    });
                  }
                },
              ),
              MarkerLayer(
                markers: [
                  _marker(
                    _centre,
                    Icons.storefront,
                    const Color(0xFF7663A7),
                    '${l10n.checkoutMapStore}: ${widget.branch.name}',
                    'checkout-map-store-pin',
                  ),
                  if (widget.deliveryPoint != null)
                    _marker(
                      widget.deliveryPoint!,
                      Icons.location_on,
                      const Color(0xFF087F65),
                      l10n.checkoutMapAddress,
                      'checkout-map-address-pin',
                    ),
                  if (gps != null)
                    _marker(
                      gps,
                      Icons.person,
                      const Color(0xFF2778D2),
                      l10n.checkoutMapYou,
                      'checkout-map-gps-pin',
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: widget.compact ? null : 8,
            right: widget.compact ? 8 : null,
            child: Material(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(12),
              child: Flex(
                direction: widget.compact ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.checkoutMapFit,
                    onPressed: _fit,
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                  if (gps != null)
                    IconButton(
                      tooltip: l10n.checkoutMapYou,
                      onPressed: () {
                        if (_ready) _controller.move(gps, 14);
                      },
                      icon: const Icon(Icons.my_location),
                    ),
                  if (widget.onExpand != null)
                    IconButton(
                      tooltip: l10n.checkoutMapExpand,
                      onPressed: widget.onExpand,
                      icon: const Icon(Icons.fullscreen),
                    ),
                ],
              ),
            ),
          ),
          if (widget.expanded)
            Positioned(
              top: 8,
              right: 8,
              child: MapZoomControls(
                controller: _controller,
                zoomInTooltip: l10n.mapZoomIn,
                zoomOutTooltip: l10n.mapZoomOut,
              ),
            ),
          if (_tileFailed)
            Positioned(
              bottom: 30,
              left: 8,
              right: 8,
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.checkoutMapTilesUnavailable,
                        style: const TextStyle(fontSize: 12),
                      ),
                      TextButton.icon(
                        key: const ValueKey('checkout-map-tiles-retry'),
                        onPressed: () => setState(() {
                          _tileFailed = false;
                          _tileRetry++;
                        }),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Positioned(bottom: 4, right: 4, child: MapTileAttribution()),
        ],
      ),
    );
  }
}

class DeliveryCoveragePainter extends CustomPainter {
  DeliveryCoveragePainter({required this.camera, required this.points});
  final MapCamera camera;
  final List<LatLng> points;
  @override
  void paint(Canvas canvas, Size size) {
    if (!size.isFinite || size.isEmpty) return;
    final ring = Path();
    for (var index = 0; index < points.length; index++) {
      final point = camera.latLngToScreenOffset(points[index]);
      if (index == 0) {
        ring.moveTo(point.dx, point.dy);
      } else {
        ring.lineTo(point.dx, point.dy);
      }
    }
    ring.close();
    // Draw only the boundary: neither side dims or tints the map tiles.
    canvas.drawPath(
      ring,
      Paint()
        ..color = const Color(0xFF2778D2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant DeliveryCoveragePainter oldDelegate) =>
      camera != oldDelegate.camera || !listEquals(points, oldDelegate.points);
}
