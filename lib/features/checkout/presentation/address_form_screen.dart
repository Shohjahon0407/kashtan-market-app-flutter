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
import '../../../core/ui/maps/neutral_map_widgets.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/checkout_models.dart';
import '../domain/addresses_controller.dart';
import '../domain/device_location.dart';

export '../domain/device_location.dart' show addressLocationAccessProvider;

typedef AddressLocationResolver = Future<Position> Function();

final addressLocationResolverProvider = Provider<AddressLocationResolver>(
  (ref) => ref.read(deviceLocationServiceProvider).resolve,
);

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({this.addressId, super.key});

  final String? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Ichki messenger (asosiy Scaffold chizilgan bo'lsa), aks holda tashqisi.
  ScaffoldMessengerState get _messenger =>
      _messengerKey.currentState ?? ScaffoldMessenger.of(context);

  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();
  final _title = TextEditingController();
  String? _initializedId;
  double? _latitude;
  double? _longitude;
  bool _existingIsDefault = false;
  bool _saving = false;
  bool _locating = false;
  bool _permissionDenied = false;
  int _locationRevision = 0;

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
    _mapController.dispose();
    super.dispose();
  }

  void _initialize(UserAddress? address) {
    final key = address?.id ?? 'new';
    if (_initializedId == key) return;
    _initializedId = key;
    if (address == null) return;
    _title.text = address.title;
    _latitude = address.latitude;
    _longitude = address.longitude;
    _existingIsDefault = address.isDefault;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final addresses = ref.watch(addressesControllerProvider);
    UserAddress? existing;
    if (widget.addressId != null) {
      for (final address in addresses.value ?? const <UserAddress>[]) {
        if (address.id == widget.addressId) existing = address;
      }
    }
    if (widget.addressId == null || existing != null) _initialize(existing);

    if (widget.addressId != null && addresses.isLoading && existing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutAddress)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.addressId != null && addresses.hasError && existing == null) {
      final error = addresses.error;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutAddress)),
        body: StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () =>
              ref.read(addressesControllerProvider.notifier).refresh(),
        ),
      );
    }
    if (widget.addressId != null && addresses.hasValue && existing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutAddress)),
        body: StoreEmptyView(
          icon: Icons.location_off_outlined,
          title: l10n.errorNotFound,
        ),
      );
    }

    final center = LatLng(
      _latitude ?? AppConfig.defaultLatitude,
      _longitude ?? AppConfig.defaultLongitude,
    );
    // Ekran StoreShell ichida ham ochiladi: floating snackbar tashqi
    // Scaffold'da (shell navbar ustida) emas, shu ekranning o'zida chiqsin.
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutAddress)),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              Text(
                l10n.addressChooseOnMap,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: 14,
                            minZoom: 3,
                            maxZoom: 19,
                            interactionOptions: const InteractionOptions(
                              flags:
                                  InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                            onTap: (_, point) => setState(() {
                              _locationRevision++;
                              _latitude = point.latitude;
                              _longitude = point.longitude;
                              _permissionDenied = false;
                            }),
                          ),
                          children: [
                            NeutralMapTiles(
                              urlTemplate: AppConfig.addressTileUrl,
                              userAgentPackageName: 'uz.beshkashtan.customer',
                              maxZoom: 19,
                            ),
                            if (_latitude != null && _longitude != null)
                              MarkerLayer(
                                rotate: true,
                                markers: [
                                  Marker(
                                    point: LatLng(_latitude!, _longitude!),
                                    width: 48,
                                    height: 48,
                                    child: Icon(
                                      Icons.location_pin,
                                      size: 44,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: MapCurrentLocationButton(
                  label: l10n.addressCurrentLocation,
                  loading: _locating,
                  expanded: true,
                  onPressed: _useCurrentLocation,
                ),
              ),
              if (_permissionDenied)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    l10n.addressLocationDenied,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              _optionalField(_title, l10n.addressTitleOptional),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: _saving || _latitude == null || _longitude == null
                    ? null
                    : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonSave),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  /// Nom IXTIYORIY: yetkazish uchun xaritadagi nuqta yetarli. Bo'sh qoldirilsa
  /// ekranlarda umumiy yozuv ko'rsatiladi (`displayTitle`).
  Widget _optionalField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          // Serverdagi `max_length=100` bilan mos.
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
        ),
      );

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    final revision = ++_locationRevision;
    setState(() {
      _locating = true;
      _permissionDenied = false;
    });
    try {
      final position = await ref
          .read(addressLocationResolverProvider)()
          .timeout(const Duration(seconds: 15));
      if (!mounted || revision != _locationRevision) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 16);
    } on Object catch (error) {
      if (!mounted || revision != _locationRevision) return;
      final reason = locationFailureOf(error);
      final denied =
          reason == DeviceLocationFailure.denied ||
          reason == DeviceLocationFailure.deniedForever;
      setState(() => _permissionDenied = denied);
      if (!denied) {
        _messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).addressLocationUnavailable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    // Faqat lokatsiya majburiy — nom uchun validator yo'q.
    if (_latitude == null || _longitude == null) {
      _messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.addressLocationRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(addressesControllerProvider.notifier)
          .save(
            UserAddress(
              id: widget.addressId ?? '',
              title: _title.text,
              latitude: _latitude,
              longitude: _longitude,
              isDefault: _existingIsDefault,
            ),
          );
      if (mounted) Navigator.pop(context, saved.id);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      _messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.localize(l10n))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
