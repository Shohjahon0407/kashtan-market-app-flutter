import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/offline/offline_banner.dart';
import '../../../core/ui/theme/app_colors.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/domain/cart_controller.dart';
import '../../payments/data/payment_models.dart';
import '../data/checkout_models.dart';
import '../domain/addresses_controller.dart';
import '../domain/checkout_controller.dart';
import '../domain/checkout_rules.dart';
import 'address_display.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.storeType, super.key});

  final StoreType storeType;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// Izoh chegarasi — backend `customer_note` TextField (chegarasiz), shuning
  /// uchun mijoz tomonda 500 belgi bilan cheklanadi.
  static const _noteMaxLength = 500;

  final _noteController = TextEditingController();
  // State'ning context'i ichki ScaffoldMessenger'dan YUQORIDA turadi —
  // snackbar'lar shu kalit orqali ichki messenger'ga yuboriladi.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  FulfillmentType _fulfillment = FulfillmentType.delivery;
  // Default — Payme (egasining talabi).
  PaymentMethod _paymentMethod = PaymentMethod.payme;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCheckout());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_prepareFailure != null || (cartAsync.hasError && cart == null)) {
      final error = _prepareFailure ?? cartAsync.error;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
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
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (cart == null || cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
        body: Center(child: Text(l10n.checkoutEmptyCart)),
      );
    }

    final storeIds = CheckoutRules.physicalStoreIds(cart);
    final pickupAllowed = CheckoutRules.pickupAllowed(cart);
    final branches = pickupAllowed
        ? ref.watch(storeBranchesProvider(storeIds.single))
        : const AsyncValue<List<StoreBranch>>.data([]);
    final pickupBranchId = _effectiveBranchId(branches.value ?? const []);

    // Snackbar'lar SHU ekranning Scaffold'i bo'yicha joylashsin: floating
    // snackbar o'z Scaffold'ining bottomNavigationBar'idan YUQORIDA chiziladi.
    // Busiz u tashqi shell (StoreShell) Scaffold'iga tegishli bo'lib, pastdagi
    // "Buyurtmani tasdiqlash" tugmasini to'sib qo'yardi.
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          children: [
            _SectionTitle(text: l10n.checkoutFulfillment),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<FulfillmentType>(
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
            if (!pickupAllowed) ...[
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                icon: Icons.info_outline,
                message: l10n.checkoutMixedStorePickup,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            if (_fulfillment == FulfillmentType.delivery)
              _deliverySection(context, addresses)
            else
              _pickupSection(context, branches, pickupBranchId),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle(text: l10n.checkoutPaymentMethod),
            const SizedBox(height: AppSpacing.sm),
            _PaymentMethodSelector(
              selected: _paymentMethod,
              fulfillment: _fulfillment,
              onChanged: (method) => setState(() => _paymentMethod = method),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle(text: l10n.checkoutNote),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: _noteMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              // Hisoblagich ko'rsatilmaydi — chegara jimgina qo'llanadi.
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
              decoration: InputDecoration(hintText: l10n.productNoteHint),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _SummaryCard(cart: cart, estimate: _estimate),
            const SizedBox(height: 100),
          ],
        ),
        bottomNavigationBar: SafeArea(
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
              onPressed: checkout.isSubmitting || !_canSubmit(pickupBranchId)
                  ? null
                  : () => _submit(pickupBranchId),
              child: checkout.isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.checkoutSubmit),
            ),
          ),
        ),
      ),
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
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (addresses) {
          AsyncData(:final value) => _SelectedAddress(
            address: _addressById(value, _selectedAddressId),
          ),
          AsyncError(:final error) => _InfoCard(
            icon: Icons.error_outline,
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.errorUnknown,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
        if (addresses.hasValue) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('checkout-choose-address'),
              onPressed: _showAddressChooser,
              icon: const Icon(Icons.location_on_outlined),
              label: Text(l10n.checkoutChooseOrChangeAddress),
            ),
          ),
        ],
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
    if (!mounted || result == null) return;
    if (result == _AddressChoiceSheet.newAddressValue) {
      await _addAddress();
      return;
    }
    final address = _addressById(
      ref.read(addressesControllerProvider).value ?? addresses,
      result,
    );
    if (address != null) _selectAddress(address);
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
    if (!mounted || id == null) return;
    await ref.read(addressesControllerProvider.notifier).refresh();
    final address = ref
        .read(addressesControllerProvider)
        .value
        ?.where((item) => item.id == id)
        .firstOrNull;
    if (address != null) _selectAddress(address);
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
      context.go(
        Routes.orderDetail(
          widget.storeType.wire,
          order.id,
          // Payme tanlangan bo'lsa buyurtma sahifasi to'lovni o'zi boshlaydi.
          autoPay: _paymentMethod == PaymentMethod.payme,
        ),
      );
    } on ApiFailure catch (failure) {
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
class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.fulfillment,
    required this.onChanged,
  });

  static const _paymeColor = Color(0xFF33CCCC);
  static const _paymeSoft = Color(0xFFE6FAFA);

  final PaymentMethod selected;
  final FulfillmentType fulfillment;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _PaymentMethodCard(
            key: const ValueKey('checkout-payment-payme'),
            label: l10n.checkoutPayPayme,
            icon: Icons.account_balance_wallet_outlined,
            accent: _paymeColor,
            softAccent: _paymeSoft,
            selected: selected == PaymentMethod.payme,
            onTap: () => onChanged(PaymentMethod.payme),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _PaymentMethodCard(
            key: const ValueKey('checkout-payment-cash'),
            label: fulfillment == FulfillmentType.delivery
                ? l10n.checkoutPayCashCourier
                : l10n.checkoutPayCashStore,
            icon: Icons.payments_outlined,
            accent: AppColors.success,
            softAccent: AppColors.successSoft,
            selected: selected == PaymentMethod.cash,
            onTap: () => onChanged(PaymentMethod.cash),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.softAccent,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color softAccent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected ? Colors.white : accent;
    return Material(
      color: selected ? accent : softAccent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? accent : accent.withValues(alpha: 0.35),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground, size: 22),
                  if (selected) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
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
  const _SelectedAddress({required this.address});

  final UserAddress? address;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = address;
    if (selected == null) {
      return _InfoCard(
        icon: Icons.location_off_outlined,
        message: l10n.checkoutSelectAddress,
      );
    }
    return Card(
      key: ValueKey('checkout-selected-address-${selected.id}'),
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          Icons.location_on,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          selected.displayTitle(AppLocalizations.of(context)),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(selected.formattedAddress),
        trailing: const Icon(Icons.check_circle),
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
      child: Padding(
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
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: addresses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return ListTile(
                      key: ValueKey('checkout-address-option-${address.id}'),
                      contentPadding: EdgeInsets.zero,
                      onTap: () => Navigator.pop(context, address.id),
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        address.displayTitle(AppLocalizations.of(context)),
                      ),
                      subtitle: Text(address.formattedAddress),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
              ),
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
    return _InfoCard(
      icon: estimate.available
          ? Icons.check_circle_outline
          : Icons.location_off,
      message: estimate.available
          ? [
              if (estimate.distanceKm != null)
                '${l10n.checkoutDistance}: ${estimate.distanceKm} km',
              if (estimate.deliveryPrice != null)
                '${l10n.cartDeliveryFee}: ${Uzs.format(estimate.deliveryPrice)}',
            ].join(' · ')
          : estimate.detail.isNotEmpty
          ? estimate.detail
          : l10n.checkoutEstimateUnavailable,
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
  const _SummaryCard({required this.cart, required this.estimate});

  final CartData cart;
  final DeliveryEstimate? estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _SummaryRow(
              label: l10n.cartSubtotal,
              value: Uzs.format(cart.subtotal),
            ),
            if (estimate?.deliveryPrice != null) ...[
              const Divider(),
              _SummaryRow(
                label: l10n.cartDeliveryFee,
                value: Uzs.format(estimate?.deliveryPrice),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}
