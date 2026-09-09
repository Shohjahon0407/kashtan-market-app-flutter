import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/ui/lifecycle/visible_clock.dart';
import '../../../../core/ui/maps/neutral_map_widgets.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/mapbox_directions.dart';
import '../../data/order_models.dart';

class OrderLiveMap extends ConsumerStatefulWidget {
  const OrderLiveMap({
    required this.location,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.serverDeadline,
    super.key,
  });

  final CourierLocation location;
  final double destinationLatitude;
  final double destinationLongitude;
  final DateTime? serverDeadline;

  @override
  ConsumerState<OrderLiveMap> createState() => _OrderLiveMapState();
}

class _OrderLiveMapState extends ConsumerState<OrderLiveMap>
    with WidgetsBindingObserver, RouteAware, VisibleClock {
  final _mapController = MapController();
  MapRouteData? _route;
  LatLng? _routeOrigin;
  LatLng? _routeDestination;
  DateTime? _routeFetchedAt;
  bool _loadingRoute = false;
  int _routeRequestGeneration = 0;

  LatLng get _courier =>
      LatLng(widget.location.latitude, widget.location.longitude);
  LatLng get _destination =>
      LatLng(widget.destinationLatitude, widget.destinationLongitude);

  /// "n soniya oldin" yangilanishi — faqat ekran ko'rinib turganda (mixin).
  @override
  void onVisibleTick() => setState(() {});

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_refreshRouteIfNeeded);
  }

  @override
  void dispose() {
    _routeRequestGeneration++;
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.clientSequence != widget.location.clientSequence ||
        oldWidget.location.latitude != widget.location.latitude ||
        oldWidget.location.longitude != widget.location.longitude ||
        oldWidget.destinationLatitude != widget.destinationLatitude ||
        oldWidget.destinationLongitude != widget.destinationLongitude) {
      scheduleMicrotask(_refreshRouteIfNeeded);
    }
  }

  Future<void> _refreshRouteIfNeeded() async {
    if (!widget.location.hasValidCoordinates) return;
    final origin = _courier;
    final destination = _destination;
    final lastOrigin = _routeOrigin;
    final lastDestination = _routeDestination;
    final elapsed = _routeFetchedAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_routeFetchedAt!);
    final moved = lastOrigin == null
        ? double.infinity
        : const Distance().distance(lastOrigin, origin);
    final destinationMoved = lastDestination == null
        ? double.infinity
        : const Distance().distance(lastDestination, destination);
    if (_route != null &&
        elapsed < const Duration(seconds: 30) &&
        moved < 100 &&
        destinationMoved < 1) {
      return;
    }
    final generation = ++_routeRequestGeneration;
    setState(() => _loadingRoute = true);
    MapRouteData? mapbox;
    try {
      mapbox = await ref
          .read(mapboxDirectionsProvider)
          .route(courier: origin, destination: destination);
    } on Object {
      // Directions yordamchi servis; uning xatosi jonli marker va direct
      // fallbackni buzmasligi kerak.
      mapbox = null;
    }
    if (!mounted || generation != _routeRequestGeneration) return;
    setState(() {
      _route = mapbox ?? MapRouteData.direct(origin, destination);
      _routeOrigin = origin;
      _routeDestination = destination;
      _routeFetchedAt = DateTime.now();
      _loadingRoute = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _routeRequestGeneration) return;
      final center = LatLng(
        (origin.latitude + destination.latitude) / 2,
        (origin.longitude + destination.longitude) / 2,
      );
      _mapController.move(center, 13.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    if (widget.location.isCurrentlyUnavailable) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.location_off_outlined, color: colors.error),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(l10n.orderLocationUnavailable)),
            ],
          ),
        ),
      );
    }
    final route = _route ?? MapRouteData.direct(_courier, _destination);
    final mapEtaMinutes = route.duration == null
        ? null
        : (route.duration!.inSeconds / 60).ceil();
    final deadlineMinutes = widget.serverDeadline
        ?.difference(DateTime.now())
        .inMinutes
        .clamp(0, 24 * 60);
    final eta = mapEtaMinutes ?? deadlineMinutes;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.radar, color: colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.orderLiveTracking,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_loadingRoute)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _courier,
                      initialZoom: 14,
                      minZoom: 3,
                      maxZoom: 19,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      NeutralMapTiles(
                        urlTemplate: AppConfig.trackingTileUrl,
                        userAgentPackageName: 'uz.beshkashtan.customer',
                        maxZoom: 19,
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.points,
                            color: colors.primary,
                            strokeWidth: 5,
                            borderColor: colors.surface,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        rotate: true,
                        markers: [
                          Marker(
                            point: _destination,
                            width: 46,
                            height: 46,
                            child: _MapMarker(
                              background: colors.error,
                              icon: Icons.home_rounded,
                            ),
                          ),
                          Marker(
                            point: _courier,
                            width: 52,
                            height: 52,
                            child: _MapMarker(
                              background: colors.primary,
                              icon: Icons.delivery_dining_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: MapZoomControls(
                    controller: _mapController,
                    zoomInTooltip: l10n.mapZoomIn,
                    zoomOutTooltip: l10n.mapZoomOut,
                  ),
                ),
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: MapTileAttribution(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eta != null)
                  Text(
                    l10n.orderMapEta(eta),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(_locationMessage(l10n, widget.location)),
                if (!route.fromMapbox) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.orderRouteUnavailable,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _locationMessage(AppLocalizations l10n, CourierLocation location) {
  if (location.isCurrentlyUnavailable) {
    return l10n.orderLocationUnavailable;
  }
  if (location.isCurrentlyStale) {
    return l10n.orderLocationDelayed;
  }
  return l10n.orderLocationUpdated(location.currentAgeSeconds.clamp(0, 30));
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.background, required this.icon});

  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: background,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
    ),
    child: Icon(icon, color: Colors.white),
  );
}
