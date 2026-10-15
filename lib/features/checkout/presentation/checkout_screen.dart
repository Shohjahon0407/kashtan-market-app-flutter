import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/offline/offline_banner.dart';
import '../../../core/ui/theme/app_colors.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/domain/cart_controller.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../payments/data/payment_models.dart';
import '../../payments/domain/payment_availability.dart';
import '../data/checkout_models.dart';
import '../domain/addresses_controller.dart';
import '../domain/checkout_controller.dart';
import '../domain/checkout_rules.dart';
import '../domain/device_location.dart';
import 'address_display.dart';
import 'address_form_screen.dart' show addressLocationResolverProvider;
import 'widgets/checkout_delivery_map.dart';
import 'widgets/checkout_receipt_paper.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.storeType, super.key});

  final StoreType storeType;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with WidgetsBindingObserver {
  /// Izoh chegarasi — backend `customer_note` TextField (chegarasiz), shuning
  /// uchun mijoz tomonda 500 belgi bilan cheklanadi.
  static const _noteMaxLength = 500;

  final _noteController = TextEditingController();
  // State'ning context'i ichki ScaffoldMessenger'dan YUQORIDA turadi —
  // snackbar'lar shu kalit orqali ichki messenger'ga yuboriladi.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  FulfillmentType _fulfillment = FulfillmentType.delivery;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _selectedAddressId;
  String? _selectedBranchId;
  String? _estimatedAddressId;
  DeliveryEstimate? _estimate;
  ApiFailure? _estimateFailure;
  bool _estimating = false;
  int _estimateRevision = 0;
  bool _preparing = true;
  ApiFailure? _prepareFailure;
  bool _addressChoicePrompted = false;
  bool _addressChoiceVisible = false;
  final _gps = ValueNotifier<LatLng?>(null);
  bool _gpsAttempted = false;
  bool _locating = false;
  Position? _gpsFix;
  Timer? _gpsExpiry;
  DeviceLocationFailure? _gpsFailure;
  Future<bool>? _locationAccess;
  bool _accessAttempted = false;
  bool _accessAllowed = false;
  bool _waitingForLocationSettings = false;
  bool _checkingLocationOnReturn = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(paymeEnabledProvider)) _paymentMethod = PaymentMethod.payme;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCheckout());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsExpiry?.cancel();
    _gps.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _waitingForLocationSettings) {
      _waitingForLocationSettings = false;
      unawaited(_locate(retry: true));
    }
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !_preparing &&
        !_locating &&
        !_addressChoiceVisible &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_refreshLocationOnReturn());
      ref.invalidate(deliveryCoverageProvider(widget.storeType.wire));
      final address = _addressById(
        ref.read(addressesControllerProvider).value ?? [],
        _selectedAddressId,
      );
      if (_fulfillment == FulfillmentType.delivery &&
          address != null &&
          !_addressChoiceVisible) {
        _estimatedAddressId = null;
        unawaited(_estimateFor(address));
      }
    }
  }

  Future<void> _locate({bool retry = false}) async {
    if (!mounted ||
        _locating ||
        _addressChoiceVisible ||
        _fulfillment != FulfillmentType.delivery ||
        (_gpsAttempted && !retry)) {
      return;
    }
    _gpsAttempted = true;
    setState(() {
      _locating = true;
    });
    try {
      if (!await _ensureLocationAccess(retry: retry) || !mounted) return;
      setState(() => _gpsFailure = null);
      final point = await ref
          .read(addressLocationResolverProvider)()
          .timeout(const Duration(seconds: 15));
      validateFreshLocation(point);
      if (mounted) {
        _gpsFix = point;
        _gps.value = LatLng(point.latitude, point.longitude);
        _gpsExpiry?.cancel();
        final age = DateTime.now().difference(point.timestamp);
        final remaining =
            const Duration(seconds: 60) -
            (age.isNegative ? Duration.zero : age);
        _gpsExpiry = Timer(remaining, () {
          if (!mounted || _gpsFix != point) return;
          setState(() {
            _gpsFailure = DeviceLocationFailure.stale;
            _gpsFix = null;
            _gps.value = null;
          });
        });
      }
    } on Object catch (error) {
      if (mounted) {
        _gps.value = null;
        _gpsFix = null;
        setState(() {
          _gpsFailure = locationFailureOf(error);
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _refreshLocationOnReturn() async {
    if (!mounted ||
        _preparing ||
        _locating ||
        _locationAccess != null ||
        _checkingLocationOnReturn ||
        _addressChoiceVisible ||
        _fulfillment != FulfillmentType.delivery ||
        ModalRoute.of(context)?.isCurrent != true ||
        (_gpsFix != null && _gpsFailure == null)) {
      return;
    }
    _checkingLocationOnReturn = true;
    try {
      // Quick Settings and Android's app settings can change GPS/permission
      // without using our settings button. Do not retain a cached denial.
      await ref.read(addressLocationStatusProvider)();
      if (mounted &&
          !_addressChoiceVisible &&
          ModalRoute.of(context)?.isCurrent == true) {
        await _locate(retry: true);
      }
    } on Object {
      // Passive checks never prompt or interrupt manual address selection.
    } finally {
      _checkingLocationOnReturn = false;
    }
  }

  Future<bool> _ensureLocationAccess({bool retry = false}) {
    if (_locationAccess != null) return _locationAccess!;
    if (_accessAttempted && !retry) return Future.value(_accessAllowed);
    _accessAttempted = true;
    return _locationAccess = _requestLocationAccess().whenComplete(() {
      _locationAccess = null;
    });
  }

  Future<bool> _requestLocationAccess() async {
    try {
      await ref.read(addressLocationAccessProvider)();
      _accessAllowed = true;
    } on Object catch (error) {
      _accessAllowed = false;
      if (mounted) {
        setState(() {
          _gpsFailure = locationFailureOf(error);
          _gpsFix = null;
          _gps.value = null;
        });
      }
    }
    return _accessAllowed;
  }

  Future<void> _openLocationSettings() async {
    _waitingForLocationSettings = true;
    try {
      final opened = await ref.read(locationSettingsOpenerProvider)(
        gps: _gpsFailure == DeviceLocationFailure.serviceDisabled,
      );
      if (!opened) _waitingForLocationSettings = false;
    } on Object {
      _waitingForLocationSettings = false;
      if (mounted) {
        _messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).checkoutMapGpsUnavailable,
            ),
          ),
        );
      }
    }
  }

  /// Ichki messenger (asosiy Scaffold chizilgan bo'lsa), aks holda tashqisi.
  ScaffoldMessengerState get _messenger =>
      _messengerKey.currentState ?? ScaffoldMessenger.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Provider'ga bog'liq holat (majburiy yetkazish, manzil tanlash oynasi)
    // build ichida emas — listener'larda yangilanadi.
    ref.listen(
      cartControllerProvider(widget.storeType),
      (_, _) => _syncWithProviders(),
    );
    ref.listen(addressesControllerProvider, (_, _) => _syncWithProviders());
    final cartAsync = ref.watch(cartControllerProvider(widget.storeType));
    final addresses = ref.watch(addressesControllerProvider);
    final checkout = ref.watch(checkoutControllerProvider(widget.storeType));
    final cart = cartAsync.value?.cart;

    if (_preparing) {
      return Scaffold(
        appBar: _checkoutAppBar(l10n),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_prepareFailure != null || (cartAsync.hasError && cart == null)) {
      final error = _prepareFailure ?? cartAsync.error;
      return Scaffold(
        appBar: _checkoutAppBar(l10n),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ApiFailure
                      ? error.localize(l10n)
                      : l10n.errorUnknown,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _prepareCheckout,
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (cartAsync.isLoading) {
      return Scaffold(
        appBar: _checkoutAppBar(l10n),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (cart == null || cart.items.isEmpty) {
      return Scaffold(
        appBar: _checkoutAppBar(l10n),
        body: Center(child: Text(l10n.checkoutEmptyCart)),
      );
    }

    final storeIds = CheckoutRules.physicalStoreIds(cart);
    final pickupAllowed = CheckoutRules.pickupAllowed(cart);
    final branches = pickupAllowed
        ? ref.watch(storeBranchesProvider(storeIds.single))
        : const AsyncValue<List<StoreBranch>>.data([]);
    final pickupBranchId = _effectiveBranchId(branches.value ?? const []);
    final total = CheckoutRules.displayTotal(
      subtotal: cart.subtotal,
      fulfillment: _fulfillment,
      estimate: _estimate,
      estimating: _estimating,
    );

    // Snackbar'lar SHU ekranning Scaffold'i bo'yicha joylashsin: floating
    // snackbar o'z Scaffold'ining bottomNavigationBar'idan YUQORIDA chiziladi.
    // Busiz u tashqi shell (StoreShell) Scaffold'iga tegishli bo'lib, pastdagi
    // "Buyurtmani tasdiqlash" tugmasini to'sib qo'yardi.
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: _checkoutAppBar(l10n, cart: cart),
        body: ListView(
          key: const ValueKey('checkout-content'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _CheckoutPanel(
              padding: const EdgeInsets.all(6),
              child: Semantics(
                label: l10n.checkoutFulfillment,
                child: SegmentedButton<FulfillmentType>(
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: FulfillmentType.delivery,
                      icon: const Icon(Icons.delivery_dining),
                      label: Text(l10n.checkoutDelivery),
                    ),
                    ButtonSegment(
                      value: FulfillmentType.pickup,
                      icon: const Icon(Icons.store_mall_directory_outlined),
                      label: Text(l10n.checkoutPickup),
                      enabled: pickupAllowed,
                    ),
                  ],
                  selected: {_fulfillment},
                  onSelectionChanged: (selection) {
                    final next = selection.single;
                    setState(() {
                      _fulfillment = next;
                      if (next == FulfillmentType.pickup) {
                        _estimateRevision++;
                        _estimating = false;
                        _selectedAddressId = null;
                        _estimatedAddressId = null;
                        _estimate = null;
                        _estimateFailure = null;
                      } else {
                        _addressChoicePrompted = false;
                      }
                    });
                    // Yetkazishga qaytilganda manzil tanlovi qayta ochiladi.
                    if (next == FulfillmentType.delivery) _syncWithProviders();
                  },
                ),
              ),
            ),
            if (!pickupAllowed) ...[
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                icon: Icons.info_outline,
                message: l10n.checkoutMixedStorePickup,
              ),
            ],
            const SizedBox(height: 14),
            _CheckoutPanel(
              key: const ValueKey('checkout-address-panel'),
              child: _fulfillment == FulfillmentType.delivery
                  ? _deliverySection(context, addresses)
                  : _pickupSection(context, branches, pickupBranchId),
            ),
            const SizedBox(height: 14),
            _CheckoutPanel(
              key: const ValueKey('checkout-payment-panel'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelHeading(
                    title: l10n.checkoutPaymentMethod,
                    caption: l10n.checkoutPaymentHint,
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodSelector(
                    selected: _paymentMethod,
                    fulfillment: _fulfillment,
                    onChanged: (method) =>
                        setState(() => _paymentMethod = method),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _CheckoutNoteCard(
              controller: _noteController,
              maxLength: _noteMaxLength,
              storeType: widget.storeType,
            ),
            const SizedBox(height: 14),
            _SummaryCard(
              cart: cart,
              estimate: _estimate,
              fulfillment: _fulfillment,
              total: total,
            ),
            const SizedBox(height: 14),
            _CheckoutReceipt(cart: cart),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: .5),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: FilledButton(
                key: const ValueKey('checkout-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: checkout.isSubmitting || !_canSubmit(pickupBranchId)
                    ? null
                    : () => _submit(pickupBranchId),
                child: checkout.isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              l10n.checkoutSubmit,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 18),
                          ),
                          if (total != null)
                            Flexible(
                              flex: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    Uzs.format(total),
                                    key: const ValueKey(
                                      'checkout-submit-total',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _checkoutAppBar(AppLocalizations l10n, {CartData? cart}) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium!.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
    final painter =
        TextPainter(
          text: TextSpan(text: l10n.checkoutTitle, style: titleStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 144).clamp(100, 800),
        );
    final height =
        (painter.height +
                (cart == null
                    ? 0
                    : MediaQuery.textScalerOf(context).scale(14)) +
                20)
            .clamp(68.0, 220.0);
    painter.dispose();
    return AppBar(
      toolbarHeight: height,
      centerTitle: true,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => appBack(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.checkoutTitle,
            softWrap: true,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: titleStyle,
          ),
          if (cart != null)
            Text(
              l10n.checkoutCartCount(cart.items.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          key: const ValueKey('checkout-help'),
          tooltip: l10n.checkoutHelpTitle,
          icon: const Icon(Icons.help_outline),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.checkoutHelpTitle),
              content: Text(l10n.checkoutHelpBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonClose),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _deliverySection(
    BuildContext context,
    AsyncValue<List<UserAddress>> addresses,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(text: l10n.checkoutAddress)),
            const SizedBox(width: 8),
            Flexible(
              child: TextButton.icon(
                onPressed: _locating
                    ? null
                    : () => unawaited(_locate(retry: true)),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.my_location, size: 15),
                label: Text(
                  _locating ? l10n.checkoutMapLocating : l10n.checkoutMapYou,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _coverageMap(addresses),
        if (_gpsFailure != null ||
            (_gpsFix != null &&
                (!_gpsFix!.accuracy.isFinite ||
                    _gpsFix!.accuracy <= 0 ||
                    _gpsFix!.accuracy > 100))) ...[
          const SizedBox(height: AppSpacing.sm),
          _locationStatus(),
        ],
        const SizedBox(height: AppSpacing.sm),
        switch (addresses) {
          AsyncData(:final value) => _SelectedAddress(
            address: _addressById(value, _selectedAddressId),
            onChoose: _showAddressChooser,
          ),
          AsyncError(:final error) => _InfoCard(
            icon: Icons.error_outline,
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.errorUnknown,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
        if (_estimating) ...[
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(),
        ] else if (_estimate != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _EstimateCard(estimate: _estimate!),
        ] else if (_estimateFailure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _InfoCard(
            icon: Icons.error_outline,
            message: _estimateFailure!.localize(l10n),
          ),
        ],
      ],
    );
  }

  Widget _locationStatus() {
    final l10n = AppLocalizations.of(context);
    final message = switch (_gpsFailure) {
      DeviceLocationFailure.denied => l10n.checkoutGpsDenied,
      DeviceLocationFailure.deniedForever => l10n.checkoutGpsDeniedForever,
      DeviceLocationFailure.serviceDisabled => l10n.checkoutGpsDisabled,
      DeviceLocationFailure.timeout => l10n.checkoutGpsTimeout,
      DeviceLocationFailure.stale => l10n.checkoutGpsStale,
      DeviceLocationFailure.unavailable => l10n.checkoutMapGpsUnavailable,
      null => l10n.checkoutGpsApproximate,
    };
    final settings =
        _gpsFailure == DeviceLocationFailure.deniedForever ||
        _gpsFailure == DeviceLocationFailure.serviceDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoCard(icon: Icons.location_searching, message: message),
        TextButton.icon(
          key: const ValueKey('checkout-location-retry'),
          onPressed: _locating
              ? null
              : () {
                  if (settings) {
                    unawaited(_openLocationSettings());
                  } else {
                    unawaited(_locate(retry: true));
                  }
                },
          icon: Icon(settings ? Icons.settings_outlined : Icons.my_location),
          label: Text(settings ? l10n.checkoutGpsSettings : l10n.commonRetry),
        ),
      ],
    );
  }

  Widget _coverageMap(AsyncValue<List<UserAddress>> addresses) {
    final coverage = ref.watch(deliveryCoverageProvider(widget.storeType.wire));
    final selected = _addressById(addresses.value ?? [], _selectedAddressId);
    final deliveryPoint =
        selected?.latitude != null && selected?.longitude != null
        ? LatLng(selected!.latitude!, selected.longitude!)
        : null;
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<LatLng?>(
      valueListenable: _gps,
      builder: (context, gps, _) {
        final authoritative = _estimate?.branch;
        final branch = authoritative?.hasCoverage == true
            ? authoritative
            : selectCoveragePreview(coverage.value ?? const [], gps);
        if (branch != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckoutDeliveryMap(
                compact: true,
                branch: branch,
                deliveryPoint: deliveryPoint,
                gps: _gps,
                gpsAccuracyMeters: _gpsFix?.accuracy,
                onLocate: () => unawaited(_locate(retry: true)),
                locating: _locating,
                locationFailed: false,
              ),
              if (authoritative == null)
                Text(
                  l10n.checkoutMapPreviewHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          );
        }
        if (coverage.isLoading) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F4),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(l10n.checkoutMapCoverageUnavailable),
                TextButton(
                  onPressed: () => ref.invalidate(
                    deliveryCoverageProvider(widget.storeType.wire),
                  ),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pickupSection(
    BuildContext context,
    AsyncValue<List<StoreBranch>> branches,
    String? pickupBranchId,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(text: l10n.checkoutBranch),
        const SizedBox(height: AppSpacing.sm),
        switch (branches) {
          AsyncData(:final value) when value.isEmpty => _InfoCard(
            icon: Icons.store_mall_directory_outlined,
            message: l10n.checkoutSelectBranch,
          ),
          AsyncData(:final value) => RadioGroup<String>(
            groupValue: pickupBranchId,
            onChanged: (value) => setState(() => _selectedBranchId = value),
            child: Column(
              children: [
                for (final branch in value.where(
                  (branch) => branch.isActive && branch.isPickupAvailable,
                ))
                  RadioListTile<String>(
                    value: branch.id,
                    title: Text(branch.name),
                    subtitle: Text(branch.address),
                  ),
              ],
            ),
          ),
          AsyncError(:final error) => _InfoCard(
            icon: Icons.error_outline,
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.errorUnknown,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }

  bool _canSubmit(String? pickupBranchId) {
    final cartState = ref.read(cartControllerProvider(widget.storeType)).value;
    final cart = cartState?.cart;
    if (_preparing ||
        _prepareFailure != null ||
        cart == null ||
        cart.items.isEmpty ||
        cartState!.hasPendingMutation ||
        cartState.mutationFailure != null) {
      return false;
    }
    if (_fulfillment == FulfillmentType.delivery &&
        _addressById(
              ref.read(addressesControllerProvider).value ?? [],
              _selectedAddressId,
            ) ==
            null) {
      return false;
    }
    return CheckoutRules.canSubmit(
      fulfillmentType: _fulfillment,
      addressId: _selectedAddressId,
      estimate: _estimate,
      isEstimating: _estimating,
      pickupBranchId: pickupBranchId,
      pickupAllowed: CheckoutRules.pickupAllowed(cart),
    );
  }

  /// Foydalanuvchi tanlamagan bo'lsa filial faqat AYNAN BITTA mos (faol va
  /// olib ketish mumkin) filial bo'lgandagina avtomatik olinadi — bir nechta
  /// bo'lsa birinchisini olish noto'g'ri filialga olib kelardi. Bu hosila
  /// qiymat: build holatni o'zgartirmaydi.
  String? _effectiveBranchId(List<StoreBranch> branches) {
    if (_selectedBranchId != null) return _selectedBranchId;
    final eligible = branches
        .where((branch) => branch.isActive && branch.isPickupAvailable)
        .toList();
    return eligible.length == 1 ? eligible.single.id : null;
  }

  /// Provider holati o'zgarganda (build'dan TASHQARIDA) chaqiriladi: aralash
  /// savatda majburan yetkazishga o'tadi va manzil tanlash oynasini bir marta
  /// rejalashtiradi. Shartlar build'dagi ekran holati bilan bir xil.
  void _syncWithProviders() {
    if (!mounted || _preparing || _prepareFailure != null) return;
    final cartAsync = ref.read(cartControllerProvider(widget.storeType));
    final cart = cartAsync.value?.cart;
    if (cartAsync.isLoading || cart == null || cart.items.isEmpty) return;
    // Location belongs to checkout entry, not to successfully loading or
    // choosing a saved address. The chooser shares this permission request.
    if (_fulfillment == FulfillmentType.delivery && !_gpsAttempted) {
      unawaited(_locate());
    }
    if (!CheckoutRules.pickupAllowed(cart) &&
        _fulfillment == FulfillmentType.pickup) {
      setState(() {
        _fulfillment = FulfillmentType.delivery;
        _selectedBranchId = null;
        // Majburan yetkazishga o'tganda manzil tanlovi qayta so'raladi —
        // aks holda tasdiqlash tugmasi sababsiz o'chiq qolardi.
        _addressChoicePrompted = false;
      });
    }
    _scheduleAddressChoice(ref.read(addressesControllerProvider));
  }

  void _selectAddress(UserAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _estimatedAddressId = null;
      _estimate = null;
      _estimateFailure = null;
    });
    unawaited(_estimateFor(address));
  }

  UserAddress? _addressById(List<UserAddress> addresses, String? id) {
    if (id == null) return null;
    return addresses.where((address) => address.id == id).firstOrNull;
  }

  void _scheduleAddressChoice(AsyncValue<List<UserAddress>> addresses) {
    if (_fulfillment != FulfillmentType.delivery ||
        _selectedAddressId != null ||
        _addressChoicePrompted ||
        _addressChoiceVisible ||
        !addresses.hasValue) {
      return;
    }
    _addressChoicePrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showAddressChooser());
    });
  }

  Future<void> _showAddressChooser() async {
    if (_addressChoiceVisible || !mounted) return;
    // Permission is settled BEFORE opening the app modal. The slower GPS fix
    // then runs in parallel without selecting a delivery address.
    await _ensureLocationAccess();
    if (!mounted ||
        _addressChoiceVisible ||
        _fulfillment != FulfillmentType.delivery ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    unawaited(_locate());
    final addresses = ref.read(addressesControllerProvider).value ?? const [];
    _addressChoiceVisible = true;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _AddressChoiceSheet(addresses: addresses),
    );
    _addressChoiceVisible = false;
    if (!mounted) return;
    if (result == null) {
      unawaited(_refreshLocationOnReturn());
      return;
    }
    if (result == _AddressChoiceSheet.newAddressValue) {
      await _addAddress();
      return;
    }
    final address = _addressById(
      ref.read(addressesControllerProvider).value ?? addresses,
      result,
    );
    if (address != null) _selectAddress(address);
    unawaited(_refreshLocationOnReturn());
  }

  Future<void> _estimateFor(UserAddress address) async {
    final revision = ++_estimateRevision;
    if (_estimatedAddressId == address.id && _estimate != null) return;
    if (address.latitude == null || address.longitude == null) {
      if (mounted) {
        setState(() {
          _estimate = const DeliveryEstimate(available: false, detail: '');
          _estimatedAddressId = address.id;
          _estimating = false;
        });
      }
      return;
    }
    setState(() {
      _estimating = true;
      _estimateFailure = null;
      _estimate = null;
    });
    ref.invalidate(deliveryCoverageProvider(widget.storeType.wire));
    try {
      final estimate = await ref
          .read(checkoutApiProvider)
          .estimate(
            storeType: widget.storeType.wire,
            latitude: address.latitude!,
            longitude: address.longitude!,
          );
      if (!mounted ||
          revision != _estimateRevision ||
          _selectedAddressId != address.id) {
        return;
      }
      setState(() {
        _estimate = estimate;
        _estimatedAddressId = address.id;
      });
    } on ApiFailure catch (failure) {
      if (!mounted ||
          revision != _estimateRevision ||
          _selectedAddressId != address.id) {
        return;
      }
      setState(() => _estimateFailure = failure);
    } finally {
      if (mounted &&
          revision == _estimateRevision &&
          _selectedAddressId == address.id) {
        setState(() => _estimating = false);
      }
    }
  }

  Future<void> _addAddress() async {
    final id = await context.push<String>(
      Routes.checkoutAddressNew(widget.storeType.wire),
    );
    if (!mounted) return;
    unawaited(_locate());
    if (id == null) return;
    await ref.read(addressesControllerProvider.notifier).refresh();
    final address = ref
        .read(addressesControllerProvider)
        .value
        ?.where((item) => item.id == id)
        .firstOrNull;
    if (address != null) _selectAddress(address);
    unawaited(_locate());
  }

  Future<void> _prepareCheckout() async {
    if (!mounted) return;
    setState(() {
      _preparing = true;
      _prepareFailure = null;
    });
    try {
      await ref.read(guestCartCoordinatorProvider).mergeIfNeeded();
      await Future.wait([
        ref.read(cartControllerProvider(widget.storeType).notifier).refresh(),
        ref.read(addressesControllerProvider.notifier).refresh(),
      ]);
      ref.invalidate(deliveryCoverageProvider(widget.storeType.wire));
      if (!mounted) return;
      final cart = ref.read(cartControllerProvider(widget.storeType));
      final failure = cart.value?.mutationFailure ?? cart.error;
      if (failure is ApiFailure) throw failure;
    } on ApiFailure catch (failure) {
      if (mounted) {
        _prepareFailure = failure;
        _messenger.showSnackBar(
          SnackBar(
            content: Text(failure.localize(AppLocalizations.of(context))),
          ),
        );
      }
    } on Object {
      if (mounted) _prepareFailure = const UnknownFailure();
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    // Tayyor bo'lgach provider'lar allaqachon ma'lumot bergan bo'lishi mumkin
    // (listener endi otmaydi) — bir marta qo'lda sinxronlaymiz.
    _syncWithProviders();
  }

  Future<void> _submit(String? pickupBranchId) async {
    // Buyurtma berish internet talab qiladi — offline'da belgi silkinadi,
    // so'rov yuborilmaydi (ma'lumot yo'qolmaydi, savat joyida qoladi).
    if (!OfflineGate.check(ref)) return;
    try {
      final order = await ref
          .read(checkoutControllerProvider(widget.storeType).notifier)
          .submit(
            fulfillmentType: _fulfillment,
            paymentMethod: _paymentMethod,
            addressId: _selectedAddressId,
            pickupBranchId: pickupBranchId,
            note: _noteController.text,
          );
      if (!mounted || order == null) return;
      AppBackCoordinator.of(GoRouter.of(context)).discardCheckout();
      context.go(
        Routes.orderDetail(
          widget.storeType.wire,
          order.id,
          // Payme tanlangan bo'lsa buyurtma sahifasi to'lovni o'zi boshlaydi.
          autoPay:
              ref.read(paymeEnabledProvider) &&
              _paymentMethod == PaymentMethod.payme,
        ),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      ref.invalidate(deliveryCoverageProvider(widget.storeType.wire));
      final address = _addressById(
        ref.read(addressesControllerProvider).value ?? [],
        _selectedAddressId,
      );
      if (address != null && _fulfillment == FulfillmentType.delivery) {
        _estimatedAddressId = null;
        unawaited(_estimateFor(address));
      }
      if (!mounted) return;
      _messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.localize(AppLocalizations.of(context))),
          ),
        );
    }
  }
}

/// To'lov usuli — yonma-yon ikkita rangli karta.
///
/// Rang formulasi ilovadagi mavjud uslub: tanlanmaganda yumshoq tint fon,
/// tanlanganda to'liq brend rangi + oq matn va ✓ belgisi.
class _PaymentMethodSelector extends ConsumerWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.fulfillment,
    required this.onChanged,
  });

  static const _paymeColor = Color(0xFF33CCCC);

  final PaymentMethod selected;
  final FulfillmentType fulfillment;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ref.watch(paymeEnabledProvider)) ...[
            Expanded(
              child: _PaymentMethodCard(
                key: const ValueKey('checkout-payment-payme'),
                label: l10n.checkoutPayPayme,
                caption: l10n.checkoutPayOnline,
                icon: Icons.account_balance_wallet_outlined,
                accent: _paymeColor,
                selected: selected == PaymentMethod.payme,
                onTap: () => onChanged(PaymentMethod.payme),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: _PaymentMethodCard(
              key: const ValueKey('checkout-payment-cash'),
              label: fulfillment == FulfillmentType.delivery
                  ? l10n.checkoutPayCashCourier
                  : l10n.checkoutPayCashStore,
              caption: fulfillment == FulfillmentType.delivery
                  ? l10n.checkoutPayOnReceipt
                  : l10n.checkoutPayOnPickup,
              icon: Icons.payments_outlined,
              accent: AppColors.success,
              selected: selected == PaymentMethod.cash,
              onTap: () => onChanged(PaymentMethod.cash),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.label,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected
                ? AppColors.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? AppColors.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _SelectedAddress extends StatelessWidget {
  const _SelectedAddress({required this.address, required this.onChoose});

  final UserAddress? address;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = address;
    if (selected == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('checkout-choose-address'),
          onPressed: onChoose,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            minimumSize: const Size(0, 76),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_location_alt_outlined, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.checkoutSelectAddress,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.checkoutAddressActionHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: .92),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: l10n.checkoutChooseOrChangeAddress,
      child: Material(
        key: const ValueKey('checkout-choose-address'),
        color: AppColors.primarySoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChoose,
          child: Padding(
            key: ValueKey('checkout-selected-address-${selected.id}'),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            selected.displayTitle(l10n),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            l10n.checkoutSelectedAddress,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (selected.latitude != null &&
                          selected.longitude != null)
                        Text(
                          '${selected.latitude!.toStringAsFixed(5)}, ${selected.longitude!.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if ([
                        selected.district,
                        selected.neighborhood,
                        selected.street,
                        selected.house,
                        selected.apartment,
                      ].any((part) => part.trim().isNotEmpty))
                        Text(
                          selected.formattedAddress,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.edit_location_alt_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.commonEdit,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressChoiceSheet extends StatelessWidget {
  const _AddressChoiceSheet({required this.addresses});

  static const newAddressValue = '__new_address__';

  final List<UserAddress> addresses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.checkoutLocationPromptTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              l10n.checkoutLocationPromptHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('checkout-add-new-location'),
                onPressed: () => Navigator.pop(context, newAddressValue),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(l10n.checkoutAddNewLocation),
              ),
            ),
            if (addresses.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.checkoutSavedLocations,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final address in addresses) ...[
                ListTile(
                  key: ValueKey('checkout-address-option-${address.id}'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.pop(context, address.id),
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    address.displayTitle(AppLocalizations.of(context)),
                  ),
                  subtitle: Text(address.formattedAddress),
                  trailing: const Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
              ],
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              _InfoCard(
                icon: Icons.location_off_outlined,
                message: l10n.addressesEmpty,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.estimate});

  final DeliveryEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = estimate.available
        ? [
            if (estimate.distanceKm != null)
              '${l10n.checkoutDistance}: ${estimate.distanceKm} km',
            if (estimate.deliveryPrice != null)
              '${l10n.cartDeliveryFee}: ${Uzs.format(estimate.deliveryPrice)}',
          ].join(' · ')
        : estimate.reasonCode == 'outside_delivery_radius'
        ? l10n.checkoutOutsideRadius(
            deliveryRadiusLabel(
              estimate.coverageRadiusKm ?? estimate.branch?.radiusKm ?? 8,
            ),
          )
        : estimate.reasonCode == 'delivery_tariff_unavailable'
        ? l10n.checkoutTariffUnavailable
        : estimate.detail.isNotEmpty
        ? estimate.detail
        : l10n.checkoutEstimateUnavailable;
    return Container(
      key: const ValueKey('checkout-delivery-estimate'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: estimate.available
            ? AppColors.primarySoft
            : Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            estimate.available
                ? Icons.check_circle_outline
                : Icons.location_off,
            size: 18,
            color: estimate.available
                ? AppColors.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.cart,
    required this.estimate,
    required this.fulfillment,
    required this.total,
  });

  final CartData cart;
  final DeliveryEstimate? estimate;
  final FulfillmentType fulfillment;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CheckoutPanel(
      key: const ValueKey('checkout-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.checkoutCostBreakdown,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: '${l10n.cartSubtotal} (${cart.items.length})',
            value: Uzs.format(cart.subtotal),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: l10n.cartDeliveryFee,
            value: fulfillment == FulfillmentType.pickup
                ? Uzs.format('0')
                : estimate?.available == true && estimate?.deliveryPrice != null
                ? Uzs.format(estimate!.deliveryPrice)
                : '—',
          ),
          const Divider(height: 26),
          _SummaryRow(
            label: l10n.checkoutGrandTotal,
            value: total == null ? '—' : Uzs.format(total),
            prominent: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.checkoutReviewHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: prominent ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: prominent ? 16 : 13,
            color: prominent ? AppColors.primary : null,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

/// Read-only order contents: use server line subtotals (including chosen
/// variants/addons), not product.price * quantity.
class _CheckoutReceipt extends StatelessWidget {
  const _CheckoutReceipt({required this.cart});
  final CartData cart;

  String _quantity(AppLocalizations l10n, CartItem item) {
    final variant = item.variant;
    final variantUnit = variant?.unitCode.trim().isNotEmpty == true
        ? variant!.unitCode
        : variant?.unit;
    final code =
        (variantUnit?.trim().isNotEmpty == true
                ? variantUnit!
                : item.product.unitCode.trim().isNotEmpty
                ? item.product.unitCode
                : item.product.unit)
            .trim()
            .toLowerCase();
    if (code == 'kg') return l10n.shashlikKilogramQuantity(item.quantity);
    if (code == 'dona') return l10n.shashlikPieceQuantity(item.quantity);
    final display = variant?.unit.trim().isNotEmpty == true
        ? variant!.unit
        : item.product.unit;
    return display.trim().isEmpty
        ? l10n.cartItemsCount(item.quantity)
        : '${item.quantity} ${display.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return CheckoutReceiptPaper(
      key: const ValueKey('checkout-receipt'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: _SectionTitle(text: l10n.checkoutReceiptTitle)),
            ],
          ),
          for (final item in cart.items) ...[
            const ReceiptDashedDivider(),
            Row(
              key: ValueKey('checkout-receipt-item-${item.id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 52,
                    child: ExcludeSemantics(
                      child: ProductImageView(
                        key: ValueKey('checkout-receipt-image-${item.id}'),
                        imageUrl: item.product.imageUrl,
                        iconSize: 24,
                        memCacheWidth: 160,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.variant?.name.trim().isNotEmpty == true)
                        Text(
                          item.variant!.name,
                          style: theme.textTheme.bodySmall,
                        ),
                      for (final addon in item.selectedAddons.where(
                        (addon) => addon.name.trim().isNotEmpty,
                      ))
                        Text(
                          '+ ${addon.name}',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (item.note.trim().isNotEmpty)
                        Text(
                          item.note.trim(),
                          style: theme.textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      _ReceiptQuantityPrice(
                        quantity: _quantity(l10n, item),
                        price: Uzs.format(item.subtotal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const ReceiptDashedDivider(),
          _ReceiptQuantityPrice(
            quantity: l10n.cartSubtotal,
            price: Uzs.format(cart.subtotal),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _ReceiptQuantityPrice extends StatelessWidget {
  const _ReceiptQuantityPrice({
    required this.quantity,
    required this.price,
    this.emphasized = false,
  });
  final String quantity;
  final String price;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantityStyle = emphasized
        ? theme.textTheme.bodyMedium!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )
        : theme.textTheme.bodySmall!;
    final priceStyle = theme.textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w800,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final result = painter.width;
          painter.dispose();
          return result;
        }

        final quantityText = Text(quantity, style: quantityStyle);
        final priceText = Text(
          price,
          textAlign: TextAlign.end,
          style: priceStyle,
        );
        if (width(quantity, quantityStyle) + width(price, priceStyle) + 12 >
            constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [quantityText, const SizedBox(height: 4), priceText],
          );
        }
        return Row(
          children: [
            Expanded(child: quantityText),
            const SizedBox(width: 12),
            priceText,
          ],
        );
      },
    );
  }
}

class _CheckoutPanel extends StatelessWidget {
  const _CheckoutPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .6),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x040B1B32),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.title, required this.caption});
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 3, child: _SectionTitle(text: title)),
      const SizedBox(width: 10),
      Flexible(
        flex: 2,
        child: Text(
          caption,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

class _CheckoutNoteCard extends StatelessWidget {
  const _CheckoutNoteCard({
    required this.controller,
    required this.maxLength,
    required this.storeType,
  });
  final TextEditingController controller;
  final int maxLength;
  final StoreType storeType;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestions = [
      l10n.checkoutNoteNoBell,
      if (storeType == StoreType.restaurant || storeType == StoreType.shashlik)
        l10n.checkoutNoteNoOnion
      else
        l10n.checkoutNoteCall,
    ];
    return _CheckoutPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            title: l10n.checkoutNote,
            caption: l10n.checkoutOptional,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('checkout-note'),
            controller: controller,
            minLines: 2,
            maxLines: 4,
            maxLength: maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: InputDecoration(
              hintText: l10n.checkoutNotePlaceholder,
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final suggestion in suggestions)
                  Builder(
                    builder: (context) {
                      final parts = value.text
                          .split(';')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      final selected = parts.contains(suggestion);
                      final next = selected
                          ? parts.where((s) => s != suggestion).join('; ')
                          : [...parts, suggestion].join('; ');
                      return FilterChip(
                        label: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected,
                        onSelected: next.characters.length > maxLength
                            ? null
                            : (_) {
                                controller.value = TextEditingValue(
                                  text: next,
                                  selection: TextSelection.collapsed(
                                    offset: next.length,
                                  ),
                                );
                              },
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Theme.of(
                          context,
                        ).scaffoldBackgroundColor,
                        selectedColor: AppColors.primarySoft,
                        side: BorderSide.none,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
