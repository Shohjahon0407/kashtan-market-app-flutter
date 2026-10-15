import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/config/app_config.dart';
import '../../../../core/ui/lifecycle/visible_clock.dart';
import '../../../../core/ui/maps/neutral_map_widgets.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/mapbox_directions.dart';
import '../../data/order_models.dart';
import 'order_contact.dart';

/// Buyurtma xaritasi: uy, do'kon va kuryer markerlari. Yo'l chizilmaydi.
///
/// - Directions javobi ETA uchun saqlanadi, lekin xaritada asosiy yoki
///   yordamchi chiziqlar ko'rsatilmaydi.
/// - Kuryer markeri yangi nuqtaga ~900 ms silliq siljiydi, heading bo'yicha
///   "tumshuq" buriladi; nuqta eskirsa (`isCurrentlyStale`) xiralashadi.
/// - Kamera avval barcha markerlarga sig'adi; keyin faqat kuryer
///   ko'rinishdan chiqsa qayta fit (foydalanuvchi surgan xarita sakramasin).
class OrderTrackingMap extends ConsumerStatefulWidget {
  const OrderTrackingMap({
    required this.home,
    this.store,
    this.courier,
    this.phase = CourierPhase.none,
    this.vehicleType = '',
    this.serverDeadline,
    this.interactive = false,
    this.showControls = false,
    this.showStatusChip = true,
    this.fitPadding = const EdgeInsets.all(48),
    this.chipOffset = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    super.key,
  });

  final LatLng home;
  final LatLng? store;
  final CourierLocation? courier;
  final CourierPhase phase;
  final String vehicleType;
  final DateTime? serverDeadline;
  final bool interactive;
  final bool showControls;
  final bool showStatusChip;

  /// Barcha markerlar sig'ishi uchun chekka bo'shliq (pastki panel uchun
  /// `bottom` kattaroq beriladi).
  final EdgeInsets fitPadding;

  /// ETA/yangilik chip'ining joyi (tepa-chap burchakdan).
  final EdgeInsets chipOffset;
  final VoidCallback? onTap;

  @override
  ConsumerState<OrderTrackingMap> createState() => _OrderTrackingMapState();
}

class _OrderTrackingMapState extends ConsumerState<OrderTrackingMap>
    with
        WidgetsBindingObserver,
        RouteAware,
        VisibleClock,
        SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  MapRouteData? _route;
  LatLng? _routeOrigin;
  LatLng? _routeDestination;
  DateTime? _routeFetchedAt;
  bool _loadingRoute = false;
  int _routeGeneration = 0;
  String? _fitSignature;
  bool _mapReady = false;
  LatLng? _slideFrom;
  LatLng? _slideTo;

  LatLng? get _courierPoint {
    final courier = widget.courier;
    if (courier == null ||
        !courier.hasValidCoordinates ||
        courier.isCurrentlyUnavailable ||
        widget.phase == CourierPhase.none) {
      return null;
    }
    return LatLng(courier.latitude, courier.longitude);
  }

  /// Hozir ekranda ko'rinadigan (animatsiyadagi) kuryer nuqtasi.
  LatLng? get _courierShown {
    final to = _slideTo ?? _courierPoint;
    final from = _slideFrom;
    if (to == null) return null;
    if (from == null || _slide.isCompleted) return to;
    final t = Curves.easeInOutCubic.transform(_slide.value);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// Directions/ETA qaysi manzil uchun olinadi.
  LatLng? get _routeTarget => switch (widget.phase) {
    CourierPhase.toStore => widget.store ?? widget.home,
    CourierPhase.toCustomer => widget.home,
    CourierPhase.none => null,
  };

  /// "n soniya oldin" — faqat ekran ko'rinib turganda (mixin).
  @override
  void onVisibleTick() {
    if (widget.showStatusChip && widget.courier != null) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _slideTo = _courierPoint;
    _slide.addListener(() => setState(() {}));
    scheduleMicrotask(_refreshRouteIfNeeded);
  }

  @override
  void dispose() {
    _routeGeneration++;
    _slide.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _courierPoint;
    final previous = _slideTo;
    if (next != previous) {
      if (next != null && previous != null) {
        _slideFrom = _courierShown ?? previous;
        _slideTo = next;
        if (MediaQuery.disableAnimationsOf(context)) {
          _slide.value = 1;
        } else {
          _slide.forward(from: 0);
        }
        _keepCourierVisible(next);
      } else {
        _slideFrom = null;
        _slideTo = next;
        _slide.value = 1;
      }
    }
    if (oldWidget.phase != widget.phase ||
        oldWidget.store != widget.store ||
        oldWidget.home != widget.home ||
        next != previous) {
      scheduleMicrotask(_refreshRouteIfNeeded);
    }
  }

  List<LatLng> get _fitPoints => [widget.home, ?widget.store, ?_courierPoint];

  void _fitIfNeeded() {
    final points = _fitPoints;
    final signature = points.length.toString();
    if (_fitSignature == signature || !_mapReady) return;
    _fitSignature = signature;
    _fitTo(points);
  }

  void _fitTo(List<LatLng> points) {
    if (!_mapReady) return;
    if (points.length == 1) {
      _mapController.move(points.single, 15);
      return;
    }
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: widget.fitPadding,
          maxZoom: 16,
        ),
      );
    } on Object {
      // Xarita hali o'lchanmagan — keyingi kadrda fit bo'ladi.
      _fitSignature = null;
    }
  }

  void _keepCourierVisible(LatLng courier) {
    if (!_mapReady) return;
    try {
      if (!_mapController.camera.visibleBounds.contains(courier)) {
        _fitTo(_fitPoints);
      }
    } on Object {
      // o'lchanmagan kamera — e'tiborsiz
    }
  }

  Future<void> _refreshRouteIfNeeded() async {
    if (!mounted) return;
    final origin = _courierPoint;
    final destination = _routeTarget;
    if (origin == null || destination == null) {
      if (_route != null) {
        setState(() {
          _route = null;
          _routeOrigin = null;
          _routeDestination = null;
        });
      }
      return;
    }
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
    final generation = ++_routeGeneration;
    setState(() => _loadingRoute = true);
    MapRouteData? fetched;
    try {
      fetched = await ref
          .read(mapboxDirectionsProvider)
          .route(courier: origin, destination: destination);
    } on Object {
      // Directions yordamchi servis; xatosi jonli marker va direct
      // fallback'ni buzmasligi kerak.
      fetched = null;
    }
    // Eski javob yangisini bosmasin (generation guard).
    if (!mounted || generation != _routeGeneration) return;
    setState(() {
      _route = fetched ?? MapRouteData.direct(origin, destination);
      _routeOrigin = origin;
      _routeDestination = destination;
      _routeFetchedAt = DateTime.now();
      _loadingRoute = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final courier = _courierShown;
    final store = widget.store;
    final route = _route;

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _fitPoints.length == 1
            ? widget.home
            : LatLngBounds.fromPoints(_fitPoints).center,
        initialZoom: 13.5,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onMapReady: () {
          _mapReady = true;
          _fitIfNeeded();
        },
      ),
      children: [
        NeutralMapTiles(
          urlTemplate: AppConfig.trackingTileUrl,
          userAgentPackageName: 'uz.beshkashtan.customer',
          maxZoom: 19,
        ),
        MarkerLayer(
          rotate: true,
          markers: [
            if (store != null)
              Marker(
                key: const ValueKey('order-map-store'),
                point: store,
                width: 44,
                height: 52,
                alignment: Alignment.topCenter,
                child: const _PinMarker(
                  icon: Icons.storefront_rounded,
                  background: Colors.white,
                  foreground: AppColors.primary,
                  border: AppColors.primary,
                ),
              ),
            Marker(
              key: const ValueKey('order-map-home'),
              point: widget.home,
              width: 48,
              height: 56,
              alignment: Alignment.topCenter,
              child: const _PinMarker(
                icon: Icons.home_rounded,
                background: Color(0xFF064E32),
                foreground: Colors.white,
                border: Colors.white,
              ),
            ),
            if (courier != null)
              Marker(
                key: const ValueKey('order-map-courier'),
                point: courier,
                width: 72,
                height: 72,
                child: _CourierMarker(
                  heading: widget.courier?.heading,
                  vehicle: widget.vehicleType,
                  stale: widget.courier?.isCurrentlyStale ?? false,
                ),
              ),
          ],
        ),
      ],
    );

    // Kuryer markerlari qo'shilib/yo'qolsa — kadrdan keyin qayta fit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitIfNeeded();
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.onTap != null && !widget.interactive)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AbsorbPointer(child: map),
          )
        else
          map,
        if (widget.showControls)
          Positioned(
            top: widget.chipOffset.top,
            right: AppSpacing.lg,
            child: MapZoomControls(
              controller: _mapController,
              zoomInTooltip: l10n.mapZoomIn,
              zoomOutTooltip: l10n.mapZoomOut,
            ),
          ),
        if (widget.showStatusChip && widget.courier != null)
          Positioned(
            top: widget.chipOffset.top,
            left: widget.chipOffset.left,
            child: _StatusChip(
              text: _chipText(l10n, route),
              loading: _loadingRoute,
              warning: widget.courier!.isCurrentlyStale,
            ),
          ),
        const Positioned(right: 8, bottom: 8, child: MapTileAttribution()),
      ],
    );
  }

  String _chipText(AppLocalizations l10n, MapRouteData? route) {
    final courier = widget.courier!;
    if (courier.isCurrentlyUnavailable) return l10n.orderLocationUnavailable;
    final parts = <String>[];
    final mapMinutes = route?.duration == null
        ? null
        : (route!.duration!.inSeconds / 60).ceil();
    if (mapMinutes != null && widget.phase == CourierPhase.toCustomer) {
      parts.add(l10n.orderMapEta(mapMinutes));
    }
    if (courier.isCurrentlyStale) {
      parts.add(l10n.orderLocationDelayed);
    } else {
      parts.add(
        l10n.orderLocationUpdated(courier.currentAgeSeconds.clamp(0, 30)),
      );
    }
    return parts.join(' · ');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.loading,
    required this.warning,
  });

  final String text;
  final bool loading;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: warning ? AppColors.warning : AppColors.success,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dumli pin: doira + pastda uchburchak.
class _PinMarker extends StatelessWidget {
  const _PinMarker({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: Border.all(color: border, width: 2.5),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: Icon(icon, color: foreground, size: 22),
      ),
      CustomPaint(
        size: const Size(12, 8),
        painter: _TailPainter(color: border),
      ),
    ],
  );
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Kuryer markeri: pulsatsiya halqasi, heading bo'yicha burilgan tumshuq,
/// transport ikonkasi. Eskirgan nuqta xira.
class _CourierMarker extends StatefulWidget {
  const _CourierMarker({
    required this.heading,
    required this.vehicle,
    required this.stale,
  });

  final double? heading;
  final String vehicle;
  final bool stale;

  @override
  State<_CourierMarker> createState() => _CourierMarkerState();
}

class _CourierMarkerState extends State<_CourierMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || widget.stale) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _CourierMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stale != widget.stale) didChangeDependencies();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.stale
        ? AppColors.lightTextTertiary
        : AppColors.primary;
    final heading = widget.heading;
    final l10n = AppLocalizations.of(context);
    final label = widget.vehicle.isEmpty
        ? l10n.orderCourier
        : '${l10n.orderCourier} · ${vehicleLabel(l10n, widget.vehicle)}';
    return Semantics(
      label: label,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!widget.stale)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value;
                return Container(
                  width: 40 + 32 * t,
                  height: 40 + 32 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: .25 * (1 - t)),
                  ),
                );
              },
            ),
          if (heading != null)
            Transform.rotate(
              angle: heading * math.pi / 180,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 0,
                  height: 0,
                  margin: const EdgeInsets.only(top: 8),
                  child: OverflowBox(
                    maxWidth: 18,
                    maxHeight: 12,
                    child: CustomPaint(
                      size: const Size(18, 12),
                      painter: _BeakPainter(color: color),
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, widget.stale ? color : const Color(0xFF079D75)],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                  color: color.withValues(alpha: .3),
                ),
              ],
            ),
            child: Icon(
              widget.vehicle == 'motorcycle' || widget.vehicle.isEmpty
                  ? Icons.delivery_dining_rounded
                  : vehicleIcon(widget.vehicle),
              key: const ValueKey('order-map-courier-icon'),
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeakPainter extends CustomPainter {
  const _BeakPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BeakPainter oldDelegate) =>
      oldDelegate.color != color;
}
