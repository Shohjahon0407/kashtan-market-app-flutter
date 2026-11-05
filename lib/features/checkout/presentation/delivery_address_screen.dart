import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/domain/cart_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/checkout_models.dart';
import '../domain/addresses_controller.dart';
import '../domain/checkout_rules.dart';
import '../domain/delivery_address_selection.dart';
import '../domain/device_location.dart';
import '../domain/order_draft_controller.dart';
import 'address_display.dart';
import 'address_form_screen.dart';
import 'widgets/checkout_delivery_map.dart';

class DeliveryAddressScreen extends ConsumerStatefulWidget {
  const DeliveryAddressScreen({
    required this.storeType,
    this.arguments,
    this.selectionRoute,
    super.key,
  });
  final StoreType storeType;
  final DeliveryAddressArguments? arguments;

  /// Parent selection route; old checkout URLs remain valid as well.
  final String? selectionRoute;

  @override
  ConsumerState<DeliveryAddressScreen> createState() =>
      _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends ConsumerState<DeliveryAddressScreen>
    with WidgetsBindingObserver {
  static const _green = Color(0xFF00795D);
  final _scroll = ScrollController();
  final _ownGps = ValueNotifier<LatLng?>(null);
  final _ownLocation = ValueNotifier(const DeliveryAddressLocationState());
  Timer? _gpsExpiry;
  bool _waitingForLocationSettings = false;
  bool _initialized = false,
      _estimating = false,
      _editing = false,
      _locating = false;
  String? _selectedId, _requestedKey, _estimatedKey;
  DeliveryEstimate? _estimate;
  ApiFailure? _failure;
  int _revision = 0;
  final _cardKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.arguments == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_locate());
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsExpiry?.cancel();
    _ownGps.dispose();
    _ownLocation.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      ref.invalidate(deliveryCoverageProvider(widget.storeType.wire));
      _retry();
      unawaited(ref.read(addressesControllerProvider.notifier).refresh());
      if (_waitingForLocationSettings) {
        _waitingForLocationSettings = false;
        unawaited(_locate(requestAccess: false));
      }
    }
  }

  UserAddress? get _selected => ref
      .read(addressesControllerProvider)
      .value
      ?.where((a) => a.id == _selectedId)
      .firstOrNull;

  String? _keyFor(UserAddress? address) {
    final cart = ref.read(cartControllerProvider(widget.storeType)).value?.cart;
    if (address == null ||
        !hasDeliveryCoordinates(address) ||
        cart == null ||
        cart.items.isEmpty) {
      return null;
    }
    return '${address.id}:${address.latitude}:${address.longitude}:${deliveryStoreScope(cart)}';
  }

  void _select(UserAddress address) {
    if (_selectedId == address.id) return;
    setState(() {
      _selectedId = address.id;
      _revision++;
      _requestedKey = null;
      _estimatedKey = null;
      _estimate = null;
      _failure = null;
      _estimating = false;
    });
  }

  void _retry() {
    setState(() {
      _revision++;
      _requestedKey = null;
      _estimatedKey = null;
      _estimate = null;
      _failure = null;
      _estimating = false;
    });
  }

  Future<void> _quote(UserAddress address, String key) async {
    if (!mounted || _keyFor(_selected) != key || _requestedKey == key) return;
    final revision = ++_revision;
    setState(() {
      _requestedKey = key;
      _estimating = true;
      _estimatedKey = null;
      _estimate = null;
      _failure = null;
    });
    try {
      final estimate = await ref
          .read(checkoutApiProvider)
          .estimate(
            storeType: widget.storeType.wire,
            latitude: address.latitude!,
            longitude: address.longitude!,
          );
      if (!mounted || revision != _revision || _keyFor(_selected) != key) {
        return;
      }
      setState(() {
        _estimate = estimate;
        _estimatedKey = key;
      });
    } on Object catch (error) {
      if (!mounted || revision != _revision || _keyFor(_selected) != key) {
        return;
      }
      setState(
        () => _failure = error is ApiFailure ? error : const UnknownFailure(),
      );
    } finally {
      if (mounted && revision == _revision) setState(() => _estimating = false);
    }
  }

  Future<void> _locate({bool requestAccess = true}) async {
    if (widget.arguments != null) {
      widget.arguments!.onLocate();
      return;
    }
    if (_locating) return;
    setState(() => _locating = true);
    _ownGps.value = null;
    _gpsExpiry?.cancel();
    _ownLocation.value = const DeliveryAddressLocationState(locating: true);
    try {
      await ref.read(
        requestAccess
            ? addressLocationAccessProvider
            : addressLocationStatusProvider,
      )();
      if (!mounted) return;
      final point = await ref
          .read(addressLocationResolverProvider)()
          .timeout(const Duration(seconds: 15));
      validateFreshLocation(point);
      if (!mounted) return;
      if (!point.accuracy.isFinite ||
          point.accuracy <= 0 ||
          point.accuracy > 100) {
        _ownLocation.value = const DeliveryAddressLocationState(
          approximate: true,
        );
        return;
      }
      _ownGps.value = LatLng(point.latitude, point.longitude);
      _ownLocation.value = const DeliveryAddressLocationState();
      _gpsExpiry?.cancel();
      final age = DateTime.now().difference(point.timestamp);
      _gpsExpiry = Timer(
        const Duration(seconds: 60) - (age.isNegative ? Duration.zero : age),
        () {
          if (mounted) {
            _ownGps.value = null;
            _ownLocation.value = const DeliveryAddressLocationState(
              failure: DeviceLocationFailure.stale,
            );
          }
        },
      );
    } on Object catch (error) {
      if (mounted) {
        _ownGps.value = null;
        _ownLocation.value = DeliveryAddressLocationState(
          failure: locationFailureOf(error),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openLocationSettings() async {
    if (widget.arguments?.onOpenLocationSettings != null) {
      widget.arguments!.onOpenLocationSettings!();
      return;
    }
    _waitingForLocationSettings = true;
    try {
      final opened = await ref.read(locationSettingsOpenerProvider)(
        gps:
            _ownLocation.value.failure == DeviceLocationFailure.serviceDisabled,
      );
      if (!opened) _waitingForLocationSettings = false;
    } on Object {
      _waitingForLocationSettings = false;
    }
  }

  Future<void> _editAddress([UserAddress? address]) async {
    if (_editing) return;
    _editing = true;
    final router = GoRouter.maybeOf(context);
    String? id;
    try {
      if (router != null) {
        final base =
            widget.selectionRoute ??
            Routes.deliveryAddressSelect(widget.storeType.wire);
        id = await context.push<String>(
          address == null
              ? '$base/new'
              : '$base/${Uri.encodeComponent(address.id)}/edit',
        );
      } else {
        id = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => AddressFormScreen(
              addressId: address?.id,
              storeType: widget.storeType,
              saveForSelection: true,
            ),
          ),
        );
      }
    } finally {
      _editing = false;
    }
    if (!mounted) return;
    if (id == null) return;
    await ref.read(addressesControllerProvider.notifier).refresh();
    if (!mounted) return;
    final saved = ref
        .read(addressesControllerProvider)
        .value
        ?.where((a) => a.id == id)
        .firstOrNull;
    if (saved == null) return;
    _select(saved);
    _retry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _cardKeys[id]?.currentContext;
      if (target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 250),
            alignment: .3,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final addresses = ref.watch(addressesControllerProvider);
    final cartState = ref.watch(cartControllerProvider(widget.storeType));
    final coverage = ref.watch(deliveryCoverageProvider(widget.storeType.wire));
    final list = addresses.value ?? const <UserAddress>[];
    if (!_initialized && addresses.hasValue) {
      _initialized = true;
      _selectedId = initialDeliveryAddress(
        list,
        widget.arguments?.initialAddressId,
      )?.id;
    }
    final selected = list.where((a) => a.id == _selectedId).firstOrNull;
    final key = _keyFor(selected);
    if (key != null && key != _requestedKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_quote(selected!, key));
      });
    }
    final estimate = key != null && key == _estimatedKey ? _estimate : null;
    final ready =
        !addresses.isLoading &&
        !addresses.hasError &&
        !cartState.isLoading &&
        !cartState.hasError &&
        cartState.value?.hasPendingMutation == false &&
        cartState.value?.mutationFailure == null &&
        !_estimating &&
        estimate?.available == true &&
        estimate?.deliveryPrice != null;
    final ordered = [
      ...list.where((a) => a.isDefault),
      ...list.where((a) => !a.isDefault),
    ];
    final gps = widget.arguments?.gps ?? _ownGps;
    final locationState =
        widget.arguments?.locationState ??
        (widget.arguments == null ? _ownLocation : null);
    final deliveryPoint = selected != null && hasDeliveryCoordinates(selected)
        ? LatLng(selected.latitude!, selected.longitude!)
        : null;
    final branch = estimate?.branch?.hasCoordinates == true
        ? estimate!.branch
        : selectCoveragePreview(coverage.value ?? const [], deliveryPoint);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            MediaQuery.sizeOf(context).width < 500 &&
                MediaQuery.textScalerOf(context).scale(20) > 26
            ? MediaQuery.textScalerOf(context).scale(20) * 2.4 + 16
            : 56,
        leading: IconButton(
          key: const ValueKey('delivery-address-back'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          l10n.deliveryAddressTitle,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 20,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 600 && constraints.maxHeight < 400;
          return Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _retry();
                    ref.invalidate(
                      deliveryCoverageProvider(widget.storeType.wire),
                    );
                    await ref
                        .read(addressesControllerProvider.notifier)
                        .refresh();
                  },
                  child: SingleChildScrollView(
                    key: const ValueKey('delivery-address-list'),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.deliveryAddressSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        if (branch != null)
                          _panel(
                            child: CheckoutDeliveryMap(
                              branch: branch,
                              gps: gps,
                              deliveryPoint: deliveryPoint,
                              onLocate: () => unawaited(_locate()),
                              locating: _locating,
                              compact: true,
                            ),
                          )
                        else if (coverage.isLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(l10n.addressCoverageLoading),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.checkoutMapCoverageUnavailable,
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.commonRetry,
                                onPressed: () => ref.invalidate(
                                  deliveryCoverageProvider(
                                    widget.storeType.wire,
                                  ),
                                ),
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.checkoutSavedLocations,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.deliveryAddressSavedHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (addresses.isLoading && list.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (addresses.hasError)
                          StoreErrorView(
                            message: addresses.error is ApiFailure
                                ? (addresses.error as ApiFailure).localize(l10n)
                                : l10n.errorUnknown,
                            onRetry: () => ref
                                .read(addressesControllerProvider.notifier)
                                .refresh(),
                          )
                        else if (list.isEmpty)
                          _panel(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.add_home_outlined,
                                  size: 48,
                                  color: _green,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.deliveryAddressEmpty,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    key: const ValueKey(
                                      'checkout-add-new-location',
                                    ),
                                    onPressed: () => _editAddress(),
                                    icon: const Icon(
                                      Icons.add_location_alt_outlined,
                                    ),
                                    label: Text(l10n.deliveryAddressAddOnMap),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          for (final address in ordered)
                            Padding(
                              key: _cardKeys.putIfAbsent(
                                address.id,
                                GlobalKey.new,
                              ),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _addressCard(
                                address,
                                selected?.id == address.id,
                                l10n,
                              ),
                            ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            key: const ValueKey('checkout-add-new-location'),
                            onPressed: () => _editAddress(),
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: Text(l10n.deliveryAddressAdd),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          l10n.deliveryAddressGpsHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (locationState != null)
                          ValueListenableBuilder<DeliveryAddressLocationState>(
                            valueListenable: locationState,
                            builder: (context, status, _) =>
                                _locationStatus(status, l10n),
                          )
                        else
                          ValueListenableBuilder<LatLng?>(
                            valueListenable: gps,
                            builder: (context, point, _) => point != null
                                ? const SizedBox.shrink()
                                : Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      key: const ValueKey(
                                        'delivery-address-gps-retry',
                                      ),
                                      onPressed: _locating
                                          ? null
                                          : () => unawaited(_locate()),
                                      icon: const Icon(
                                        Icons.my_location,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _locating
                                            ? l10n.checkoutMapLocating
                                            : l10n.checkoutMapYou,
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (wide)
                SizedBox(
                  width: (constraints.maxWidth * .5).clamp(360.0, 420.0),
                  child: _footer(l10n, selected, estimate, ready),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .6,
                  ),
                  child: _footer(l10n, selected, estimate, ready),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE1E7ED)),
    ),
    child: child,
  );

  Widget _locationStatus(
    DeliveryAddressLocationState status,
    AppLocalizations l10n,
  ) {
    final message = switch (status.failure) {
      DeviceLocationFailure.denied => l10n.checkoutGpsDenied,
      DeviceLocationFailure.deniedForever => l10n.checkoutGpsDeniedForever,
      DeviceLocationFailure.serviceDisabled => l10n.checkoutGpsDisabled,
      DeviceLocationFailure.timeout => l10n.checkoutGpsTimeout,
      DeviceLocationFailure.stale => l10n.checkoutGpsStale,
      DeviceLocationFailure.unavailable => l10n.checkoutMapGpsUnavailable,
      null =>
        status.approximate
            ? l10n.checkoutGpsApproximate
            : status.locating
            ? l10n.checkoutMapLocating
            : null,
    };
    final settings =
        status.failure == DeviceLocationFailure.deniedForever ||
        status.failure == DeviceLocationFailure.serviceDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (message != null || status.failure != null)
          TextButton.icon(
            key: const ValueKey('delivery-address-gps-retry'),
            onPressed: status.locating
                ? null
                : settings
                ? () => unawaited(_openLocationSettings())
                : () => unawaited(_locate()),
            icon: Icon(settings ? Icons.settings_outlined : Icons.my_location),
            label: Text(settings ? l10n.checkoutGpsSettings : l10n.commonRetry),
          ),
      ],
    );
  }

  Widget _addressCard(
    UserAddress address,
    bool selected,
    AppLocalizations l10n,
  ) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? _green : const Color(0xFFE1E7ED),
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('checkout-address-option-${address.id}'),
          onTap: () => _select(address),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: selected ? _green : const Color(0xFF6A7890),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                address.displayTitle(l10n),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              if (address.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD9F4E8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.addressDefaultLabel,
                                    style: const TextStyle(
                                      color: _green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            address.formattedAddress,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (!hasDeliveryCoordinates(address))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                l10n.addressLocationRequired,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? _green : const Color(0xFFBBC7D5),
                      size: 23,
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('delivery-address-edit-${address.id}'),
                    onPressed: () => _editAddress(address),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: Text(l10n.commonEdit),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(
    AppLocalizations l10n,
    UserAddress? selected,
    DeliveryEstimate? estimate,
    bool ready,
  ) {
    final cart = ref
        .watch(cartControllerProvider(widget.storeType))
        .value
        ?.cart;
    final ids = cart == null
        ? <String>{}
        : CheckoutRules.physicalStoreIds(cart);
    final unavailable =
        !_estimating &&
        (_failure != null ||
            (estimate != null &&
                (!estimate.available || estimate.deliveryPrice == null)));
    final branches = unavailable && ids.length == 1
        ? ref.watch(storeBranchesProvider(ids.single))
        : const AsyncData<List<StoreBranch>>([]);
    final canPickup =
        cart != null &&
        CheckoutRules.pickupAllowed(cart) &&
        !branches.isLoading &&
        !branches.hasError &&
        (branches.value ?? const []).any(
          (branch) => branch.isActive && branch.isPickupAvailable,
        );
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_estimating) ...[
                        const LinearProgressIndicator(minHeight: 2),
                        const SizedBox(height: 8),
                        Text(
                          l10n.deliveryAddressCalculating,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ] else if (_failure != null ||
                          (estimate != null &&
                              (!estimate.available ||
                                  estimate.deliveryPrice == null))) ...[
                        Text(
                          _failure?.localize(l10n) ??
                              _estimateMessage(estimate!, l10n),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const ValueKey('delivery-address-quote-retry'),
                            onPressed: _retry,
                            child: Text(l10n.commonRetry),
                          ),
                        ),
                        if (canPickup)
                          TextButton.icon(
                            key: const ValueKey('delivery-address-use-pickup'),
                            icon: const Icon(Icons.storefront_outlined),
                            label: Text(l10n.checkoutPickup),
                            onPressed: _editing
                                ? null
                                : () {
                                    ref
                                        .read(
                                          orderDraftProvider(
                                            widget.storeType,
                                          ).notifier,
                                        )
                                        .setFulfillment(FulfillmentType.pickup);
                                    final router = GoRouter.maybeOf(context);
                                    if (router != null) {
                                      AppBackCoordinator.of(router).go(
                                        Routes.storeCartFor(
                                          widget.storeType.wire,
                                          focus: 'fulfillment',
                                        ),
                                      );
                                    } else {
                                      Navigator.of(context).maybePop();
                                    }
                                  },
                          ),
                      ] else if (estimate?.available == true &&
                          estimate?.deliveryPrice != null) ...[
                        Text(
                          '${l10n.cartDeliveryFee}: ${Uzs.format(estimate!.deliveryPrice)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (estimate.distanceKm != null)
                          Text(
                            '${l10n.checkoutDistance}: ${estimate.distanceKm} km',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ] else
                        Text(
                          l10n.deliveryAddressSavedHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('delivery-address-confirm'),
                  onPressed: !ready
                      ? null
                      : () {
                          final cart = ref
                              .read(cartControllerProvider(widget.storeType))
                              .value
                              ?.cart;
                          if (cart == null ||
                              selected == null ||
                              _keyFor(selected) != _estimatedKey) {
                            return;
                          }
                          Navigator.of(context).pop(
                            DeliveryAddressSelection(
                              address: selected,
                              estimate: estimate!,
                              storeScope: deliveryStoreScope(cart),
                            ),
                          );
                        },
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    l10n.deliveryAddressConfirm,
                    textAlign: TextAlign.center,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    backgroundColor: _green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _estimateMessage(DeliveryEstimate estimate, AppLocalizations l10n) {
    if (estimate.reasonCode == 'outside_delivery_radius') {
      // Compatibility with an older backend; never draw an obsolete limit.
      return l10n.cartDeliveryNotAvailable;
    }
    if (estimate.reasonCode == 'delivery_tariff_unavailable') {
      return l10n.checkoutTariffUnavailable;
    }
    return estimate.detail.isNotEmpty
        ? estimate.detail
        : l10n.checkoutEstimateUnavailable;
  }
}
