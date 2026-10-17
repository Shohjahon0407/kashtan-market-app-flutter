import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/maps/neutral_map_widgets.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/checkout_models.dart';
import '../domain/address_delivery_boundary.dart';
import '../domain/addresses_controller.dart';
import '../domain/device_location.dart';
import 'widgets/checkout_delivery_map.dart';

export '../domain/device_location.dart' show addressLocationAccessProvider;

typedef AddressLocationResolver = Future<Position> Function();
final addressLocationResolverProvider = Provider<AddressLocationResolver>(
  (ref) => ref.read(deviceLocationServiceProvider).resolve,
);

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({
    this.addressId,
    this.storeType,
    this.saveForSelection = false,
    super.key,
  });
  final String? addressId;
  final StoreType? storeType;
  final bool saveForSelection;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  static const _green = Color(0xFF006B53);
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  MapController _mapController = MapController();
  String? _boundarySignature;
  final _title = TextEditingController();
  final _note = TextEditingController();
  String? _initializedId;
  UserAddress? _original;
  LatLng? _point;
  String? _placeLabel;
  int? _kind;
  bool _saving = false, _locating = false;
  bool _pointChanged = false;
  bool _tileFailed = false;
  bool _autoFitDone = false;
  int _tileRevision = 0, _locationRevision = 0;
  DeviceLocationFailure? _locationFailure;
  double? _accuracy;
  AsyncValue<List<DeliveryCoverageBranch>> _coverage = const AsyncLoading();
  AddressDeliveryBoundary? _boundary;
  bool _radiusNotice = false;
  FutureProvider<List<DeliveryCoverageBranch>> get _coverageSource =>
      widget.storeType == null
      ? addressCoverageProvider
      : deliveryCoverageProvider(widget.storeType!.wire);
  bool get _canConfirm =>
      !_coverage.isLoading &&
      !_coverage.hasError &&
      _boundary != null &&
      _point != null &&
      _boundary!.contains(_point!);

  ScaffoldMessengerState get _messenger =>
      _messengerKey.currentState ?? ScaffoldMessenger.of(context);

  @override
  void initState() {
    super.initState();
    if (widget.addressId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_useCurrentLocation());
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _initialize(UserAddress? address) {
    final key = address?.id ?? 'new';
    if (_initializedId == key) return;
    _initializedId = key;
    _original = address;
    if (address == null) {
      _kind = 0;
      _title.text = AppLocalizations.of(context).addressTypeHome;
      return;
    }
    _title.text = address.title;
    _kind = switch (address.title.trim().toLowerCase()) {
      'uy' || 'уй' || 'дом' => 0,
      'ishxona' || 'ишхона' || 'работа' => 1,
      _ => 2,
    };
    _note.text = address.landmark;
    if (address.latitude != null && address.longitude != null) {
      _point = LatLng(address.latitude!, address.longitude!);
    }
    if ([
      address.street,
      address.neighborhood,
      address.district,
    ].any((s) => s.isNotEmpty)) {
      _placeLabel = address.formattedAddress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final addresses = ref.watch(addressesControllerProvider);
    final existing = addresses.value
        ?.where((a) => a.id == widget.addressId)
        .firstOrNull;
    if (widget.addressId == null || existing != null) _initialize(existing);
    if (widget.addressId != null && existing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutAddress)),
        body: addresses.isLoading
            ? const Center(child: CircularProgressIndicator())
            : addresses.hasError
            ? StoreErrorView(
                message: addresses.error is ApiFailure
                    ? (addresses.error as ApiFailure).localize(l10n)
                    : l10n.errorUnknown,
                onRetry: () =>
                    ref.read(addressesControllerProvider.notifier).refresh(),
              )
            : StoreEmptyView(
                icon: Icons.location_off_outlined,
                title: l10n.errorNotFound,
              ),
      );
    }
    _coverage = ref.watch(_coverageSource);
    final branch = largestAddressCoverage(_coverage.value ?? const []);
    _boundary = branch == null ? null : AddressDeliveryBoundary(branch);
    final signature = branch == null
        ? 'none'
        : '${branch.id}:${branch.latitude}:${branch.longitude}:${branch.radiusKm}';
    if (_boundarySignature != null && signature != _boundarySignature) {
      // flutter_map requires a camera already inside a newly supplied
      // constraint. Reset only when the actual policy changes, not on drags
      // or ordinary refreshes. Keep the entered address/note unchanged.
      final previous = _mapController;
      _mapController = MapController();
      _autoFitDone = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    _boundarySignature = signature;
    if (branch != null && !_autoFitDone) {
      _autoFitDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && signature == _boundarySignature) _fit(branch);
      });
    }
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF2EE),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 650 &&
                  constraints.maxWidth > constraints.maxHeight;
              final panel = _addressPanel(l10n);
              return Column(
                children: [
                  _header(l10n),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(child: _mapArea(l10n, branch)),
                              SizedBox(
                                width: constraints.maxWidth * .46,
                                child: panel,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: _mapArea(l10n, branch)),
                              // The form scrolls independently, keeping confirmation reachable.
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: constraints.maxHeight * .48,
                                ),
                                child: panel,
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Material(
      color: Colors.white.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          BackButton(onPressed: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    widget.addressId == null
                        ? l10n.addressAddTitle
                        : l10n.addressEditTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (MediaQuery.textScalerOf(context).scale(1) < 1.6) ...[
                    const SizedBox(height: 3),
                    Text(
                      l10n.addressSelectPoint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: _green,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.addressMapHelp,
            icon: const Icon(Icons.help_outline_rounded, size: 22),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (context) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        color: _green,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.addressMapHelpBody),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.commonClose),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _mapArea(AppLocalizations l10n, DeliveryCoverageBranch? branch) {
    final center =
        (_point != null && (_boundary?.contains(_point!) ?? true)
            ? _point
            : null) ??
        _boundary?.center ??
        const LatLng(AppConfig.defaultLatitude, AppConfig.defaultLongitude);
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxHeight < 320;
        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                key: ValueKey(_boundarySignature),
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                  minZoom: 3,
                  maxZoom: 19,
                  cameraConstraint:
                      _boundary ?? const CameraConstraint.unconstrained(),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, point) => _selectPoint(point),
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) _selectPoint(camera.center, move: false);
                  },
                ),
                children: [
                  NeutralMapTiles(
                    key: ValueKey(_tileRevision),
                    urlTemplate: AppConfig.addressTileUrl,
                    userAgentPackageName: 'uz.beshkashtan.customer',
                    maxZoom: 19,
                    onTileError: () {
                      if (mounted && !_tileFailed) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_tileFailed) {
                            setState(() => _tileFailed = true);
                          }
                        });
                      }
                    },
                  ),
                  if (branch != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(branch.latitude!, branch.longitude!),
                          radius: branch.radiusKm! * 1000,
                          useRadiusInMeter: true,
                          color: _green.withValues(alpha: .12),
                          borderColor: _green,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  if (_point != null || branch != null)
                    MarkerLayer(
                      markers: [
                        if (branch != null)
                          Marker(
                            point: LatLng(branch.latitude!, branch.longitude!),
                            width: 42,
                            height: 42,
                            child: Tooltip(
                              message:
                                  '${l10n.checkoutMapStore}: ${branch.name}',
                              child: _marker(
                                Icons.storefront_rounded,
                                const Color(0xFF7561AF),
                                38,
                              ),
                            ),
                          ),
                        if (_point != null)
                          Marker(
                            point: _point!,
                            width: 52,
                            height: 64,
                            alignment: Alignment.topCenter,
                            child: Semantics(
                              label: l10n.checkoutMapAddress,
                              child: Column(
                                children: [
                                  _marker(
                                    Icons.location_on_rounded,
                                    _green,
                                    46,
                                  ),
                                  Container(
                                    width: 3,
                                    height: 10,
                                    color: _green,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (bounds.maxHeight >= 160)
              Positioned(
                right: 12,
                bottom: 48,
                child: compact
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _control(
                            l10n.addressCurrentLocation,
                            Icons.my_location_rounded,
                            _useCurrentLocation,
                            loading: _locating,
                          ),
                          const SizedBox(width: 6),
                          _control(l10n.mapZoomIn, Icons.add, () => _zoom(1)),
                          const SizedBox(width: 6),
                          _control(
                            l10n.mapZoomOut,
                            Icons.remove,
                            () => _zoom(-1),
                          ),
                          const SizedBox(width: 6),
                          _control(
                            l10n.checkoutMapFit,
                            Icons.fullscreen_rounded,
                            () => _fit(branch),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _control(
                            l10n.addressCurrentLocation,
                            Icons.my_location_rounded,
                            _useCurrentLocation,
                            loading: _locating,
                          ),
                          const SizedBox(height: 8),
                          MapZoomControls(
                            controller: _mapController,
                            zoomInTooltip: l10n.mapZoomIn,
                            zoomOutTooltip: l10n.mapZoomOut,
                          ),
                          const SizedBox(height: 8),
                          _control(
                            l10n.checkoutMapFit,
                            Icons.fullscreen_rounded,
                            () => _fit(branch),
                          ),
                        ],
                      ),
              ),
            if (_tileFailed)
              Positioned(
                left: 12,
                bottom: 88,
                right: 76,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(() {
                      _tileFailed = false;
                      _tileRevision++;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.addressMapRetry),
                    ),
                  ),
                ),
              ),
            const Positioned(left: 12, bottom: 8, child: MapTileAttribution()),
          ],
        );
      },
    );
  }

  Widget _marker(IconData icon, Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * .55),
  );

  Widget _control(
    String label,
    IconData icon,
    VoidCallback action, {
    bool loading = false,
  }) => Material(
    color: Colors.white,
    elevation: 2,
    shadowColor: Colors.black12,
    borderRadius: BorderRadius.circular(14),
    child: IconButton(
      tooltip: label,
      onPressed: loading ? null : action,
      icon: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: _green),
    ),
  );

  Widget _addressPanel(AppLocalizations l10n) {
    final types = [
      l10n.addressTypeHome,
      l10n.addressTypeWork,
      l10n.addressTypeOther,
    ];
    final selectedKind = _kind ?? 2;
    final locationError = switch (_locationFailure) {
      DeviceLocationFailure.denied => l10n.checkoutGpsDenied,
      DeviceLocationFailure.deniedForever => l10n.checkoutGpsDeniedForever,
      DeviceLocationFailure.serviceDisabled => l10n.checkoutGpsDisabled,
      DeviceLocationFailure.timeout => l10n.checkoutGpsTimeout,
      DeviceLocationFailure.stale => l10n.checkoutGpsStale,
      DeviceLocationFailure.unavailable => l10n.addressLocationUnavailable,
      null =>
        _accuracy != null && _accuracy! > 100
            ? l10n.checkoutGpsApproximate
            : null,
    };
    return Material(
      key: const ValueKey('address-details-panel'),
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCD6DF),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('address-details-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F6EE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: _green,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _placeLabel ?? l10n.addressUnnamed,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _point == null
                                    ? l10n.addressChooseOnMap
                                    : '${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF627286),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.commonEdit,
                          icon: const Icon(
                            Icons.edit_location_alt_outlined,
                            color: _green,
                          ),
                          onPressed: () {
                            if (_point != null &&
                                (_boundary?.contains(_point!) ?? false)) {
                              _mapController.move(_point!, 16);
                            } else {
                              _fit(_boundary?.branch);
                            }
                          },
                        ),
                      ],
                    ),
                    if (_boundary != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          l10n.checkoutCoverageRadius(
                            deliveryRadiusLabel(_boundary!.branch.radiusKm!),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: _green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (locationError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationError,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            Wrap(
                              children: [
                                TextButton(
                                  onPressed: _locating
                                      ? null
                                      : _useCurrentLocation,
                                  child: Text(l10n.commonRetry),
                                ),
                                if (_locationFailure ==
                                        DeviceLocationFailure.deniedForever ||
                                    _locationFailure ==
                                        DeviceLocationFailure.serviceDisabled)
                                  TextButton(
                                    onPressed: () async {
                                      await ref.read(
                                        locationSettingsOpenerProvider,
                                      )(
                                        gps:
                                            _locationFailure ==
                                            DeviceLocationFailure
                                                .serviceDisabled,
                                      );
                                    },
                                    child: Text(l10n.checkoutGpsSettings),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (_coverage.isLoading) ...[
                      Text(
                        l10n.addressCoverageLoading,
                        style: const TextStyle(fontSize: 12, color: _green),
                      ),
                      const SizedBox(height: 8),
                    ] else if (_coverage.hasError || _boundary == null) ...[
                      Text(l10n.checkoutMapCoverageUnavailable),
                      TextButton(
                        onPressed: () => ref.invalidate(_coverageSource),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                    if (_radiusNotice ||
                        (_point != null &&
                            _boundary != null &&
                            !_boundary!.contains(_point!))) ...[
                      Text(
                        l10n.addressRadiusLimit,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      l10n.addressTypeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF627286),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < types.length; i++)
                          ChoiceChip(
                            label: Text(types[i]),
                            avatar: Icon(
                              [
                                Icons.home_rounded,
                                Icons.work_rounded,
                                Icons.sell_rounded,
                              ][i],
                              size: 16,
                              color: selectedKind == i
                                  ? Colors.white
                                  : const Color(0xFF627286),
                            ),
                            selected: selectedKind == i,
                            showCheckmark: false,
                            selectedColor: _green,
                            backgroundColor: const Color(0xFFF0F4F8),
                            labelStyle: TextStyle(
                              color: selectedKind == i
                                  ? Colors.white
                                  : const Color(0xFF243449),
                              fontSize: 12,
                            ),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (_) => setState(() {
                              _kind = i;
                              _title.text = i == 2 ? '' : types[i];
                            }),
                          ),
                      ],
                    ),
                    if (selectedKind < 0 || selectedKind == 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.addressTitleOptional,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF627286),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const ValueKey('address-title'),
                              controller: _title,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(100),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.addressCourierNote,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF627286),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const ValueKey('address-courier-note'),
                      controller: _note,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 255,
                      decoration: InputDecoration(
                        hintText: l10n.addressCourierNoteHint,
                        filled: true,
                        fillColor: const Color(0xFFF7F9FC),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('address-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saving || !_canConfirm ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.saveForSelection
                                  ? l10n.deliveryAddressSave
                                  : l10n.addressConfirmPoint,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPoint(LatLng point, {bool move = true}) {
    final boundary = _boundary;
    // Allow drafting while coverage is loading/failed. Only confirmation is
    // blocked until the real radius is known; the pin must not appear frozen.
    final outside = boundary != null && !boundary.contains(point);
    final selected = boundary?.clamp(point) ?? point;
    _locationRevision++;
    setState(() {
      _point = selected;
      _radiusNotice = outside;
      _placeLabel = null;
      _pointChanged = true;
      _locationFailure = null;
      _accuracy = null;
    });
    if (move || outside) {
      _mapController.move(selected, _mapController.camera.zoom);
    }
  }

  void _fit(DeliveryCoverageBranch? branch) {
    final points = <LatLng>[
      if (_point != null && (_boundary?.contains(_point!) ?? false)) _point!,
      if (branch != null)
        ...deliveryRadiusPoints(
          LatLng(branch.latitude!, branch.longitude!),
          branch.radiusKm!,
        ),
    ];
    if (points.length == 1) _mapController.move(points.single, 16);
    if (points.length > 1) {
      final padding = (_mapController.camera.nonRotatedSize.shortestSide / 6)
          .clamp(4.0, 30.0);
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: EdgeInsets.all(padding),
          maxZoom: 16,
        ),
      );
    }
  }

  void _zoom(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3, 19));
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    final revision = ++_locationRevision;
    setState(() {
      _locating = true;
      _locationFailure = null;
    });
    try {
      final position = await ref
          .read(addressLocationResolverProvider)()
          .timeout(const Duration(seconds: 15));
      if (!mounted || revision != _locationRevision) return;
      setState(() {
        _point = LatLng(position.latitude, position.longitude);
        _radiusNotice = _boundary != null && !_boundary!.contains(_point!);
        _autoFitDone = false;
        _placeLabel = null;
        _pointChanged = true;
        _accuracy = position.accuracy;
      });
      _mapController.move(_point!, 16);
    } on Object catch (error) {
      if (!mounted || revision != _locationRevision) return;
      setState(() => _locationFailure = locationFailureOf(error));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_canConfirm) return;
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      // Refresh before saving: an admin may have reduced the radius while
      // this form was open. Do not save against an old preview circle.
      final latest = largestAddressCoverage(
        await ref.refresh(_coverageSource.future),
      );
      if (!mounted) return;
      if (latest == null ||
          !AddressDeliveryBoundary(latest).contains(_point!)) {
        setState(() => _radiusNotice = true);
        _messenger.showSnackBar(
          SnackBar(content: Text(l10n.addressRadiusLimit)),
        );
        return;
      }
      final old = _original;
      final label = _placeLabel ?? '';
      final saved = await ref
          .read(addressesControllerProvider.notifier)
          .save(
            UserAddress(
              id: widget.addressId ?? '',
              title: _title.text,
              latitude: _point!.latitude,
              longitude: _point!.longitude,
              isDefault: old?.isDefault ?? false,
              landmark: _note.text,
              district: _pointChanged ? '' : old?.district ?? '',
              neighborhood: _pointChanged ? '' : old?.neighborhood ?? '',
              street: _pointChanged
                  ? String.fromCharCodes(label.runes.take(255))
                  : old?.street ?? '',
              house: _pointChanged ? '' : old?.house ?? '',
              apartment: _pointChanged ? '' : old?.apartment ?? '',
            ),
          );
      if (mounted) {
        Navigator.pop(context, saved.id);
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        _messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.localize(l10n))));
      }
    } on Object {
      if (mounted) {
        _messenger.showSnackBar(
          SnackBar(content: Text(l10n.checkoutMapCoverageUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
