import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/uzbek_phone.dart';
import '../../auth/presentation/widgets/phone_field.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/domain/cart_controller.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../orders/data/order_models.dart';
import '../../payments/data/payment_models.dart';
import '../../payments/domain/payment_availability.dart';
import '../data/checkout_models.dart';
import '../domain/addresses_controller.dart';
import '../domain/checkout_controller.dart';
import '../domain/checkout_rules.dart';
import '../domain/order_draft_controller.dart';
import 'address_display.dart';
import 'delivery_address_navigation.dart';
import 'widgets/checkout_receipt_paper.dart';
import 'widgets/delivery_minimum_progress.dart';

/// Rasmiylashtirish (2-bosqich, Uzum uslubi): olish usuli (kuryer standart),
/// manzil/filial, oluvchi, yetkazish vaqti, to'lov turi va xulosa — hammasi
/// shu ekranda tanlanadi; savatga faqat bo'sh savat yoki minimal summa uchun
/// qaytiladi.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.storeType, super.key});
  final StoreType storeType;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with WidgetsBindingObserver {
  static const _noteMaxLength = 500;
  final _noteController = TextEditingController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _entryCheckComplete = false;
  bool _redirectScheduled = false;
  bool _preparing = false;
  bool _submittingPreflight = false;
  bool _orderOpened = false;

  @override
  void initState() {
    super.initState();
    _noteController.text = ref.read(orderDraftProvider(widget.storeType)).note;
    _noteController.addListener(_saveNote);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCheckout());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteController.removeListener(_saveNote);
    _noteController.dispose();
    super.dispose();
  }

  void _saveNote() => ref
      .read(orderDraftProvider(widget.storeType).notifier)
      .setNote(_noteController.text);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        !ref.read(checkoutControllerProvider(widget.storeType)).isSubmitting) {
      unawaited(_prepareCheckout());
    }
  }

  ScaffoldMessengerState get _messenger =>
      _messengerKey.currentState ?? ScaffoldMessenger.of(context);

  Future<void> _prepareCheckout() async {
    if (!mounted || _preparing) return;
    ref.invalidate(paymentCapabilitiesProvider);
    setState(() {
      _preparing = true;
      _entryCheckComplete = false;
    });
    try {
      // Kuryer standart: manzil tanlanmagan bo'lsa saqlangan standart manzil
      // olinadi (GPS so'ralmaydi).
      await ref
          .read(orderDraftProvider(widget.storeType).notifier)
          .prepare(revalidateQuote: true, useSavedAddress: true);
      if (!mounted) return;
      final draft = ref.read(orderDraftProvider(widget.storeType));
      final cart = ref
          .read(cartControllerProvider(widget.storeType))
          .value
          ?.cart;
      if (draft.fulfillment == FulfillmentType.pickup && cart != null) {
        final stores = CheckoutRules.physicalStoreIds(cart);
        if (stores.length == 1) {
          ref.invalidate(storeBranchesProvider(stores.single));
          try {
            await ref.read(storeBranchesProvider(stores.single).future);
          } on Object {
            // The branch provider retains the error for the inline retry UI.
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _preparing = false;
          _entryCheckComplete = true;
        });
      }
    }
  }

  /// A legacy nested address URL can sit above checkout. Wait until checkout
  /// itself is visible before redirecting an incomplete direct-link entry.
  void _scheduleCart(String notice, String focus) {
    if (_redirectScheduled ||
        _orderHandoffActive ||
        !_entryCheckComplete ||
        ModalRoute.of(context)?.isCurrent != true ||
        GoRouter.maybeOf(context) == null) {
      return;
    }
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _orderHandoffActive ||
          ModalRoute.of(context)?.isCurrent != true) {
        _redirectScheduled = false;
        return;
      }
      _returnToCart(focus, notice: notice);
    });
  }

  bool get _orderHandoffActive {
    final submission = ref.read(checkoutControllerProvider(widget.storeType));
    return _submittingPreflight ||
        _orderOpened ||
        submission.isSubmitting ||
        submission.lastOrder != null ||
        ref.read(checkoutIdempotencyStoreProvider).pending(widget.storeType) !=
            null;
  }

  void _openCreatedOrder(OrderData order, PaymentMethod method) {
    if (!mounted || _orderOpened) return;
    _orderOpened = true;
    final router = GoRouter.maybeOf(context);
    final autoPay =
        order.paymentMethod == 'payme' && method == PaymentMethod.payme;
    ref.read(orderDraftProvider(widget.storeType).notifier).clear();
    if (router != null) {
      AppBackCoordinator.of(router).discardCheckout();
      router.go(
        Routes.orderDetail(widget.storeType.wire, order.id, autoPay: autoPay),
      );
      unawaited(
        ref
            .read(checkoutIdempotencyStoreProvider)
            .acknowledge(widget.storeType),
      );
      ref.invalidate(pendingCheckoutProvider);
    }
  }

  void _returnToCart(String focus, {String? notice}) {
    final controller = ref.read(orderDraftProvider(widget.storeType).notifier);
    if (notice != null) controller.setNotice(notice);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      AppBackCoordinator.of(
        router,
      ).go(Routes.storeCartFor(widget.storeType.wire, focus: focus));
    } else {
      Navigator.of(context).maybePop();
    }
  }

  bool _canSubmit(
    CartState cartState,
    List<UserAddress> addresses,
    String? pickupBranchId, {
    bool branchesReady = true,
  }) {
    final draft = ref.read(orderDraftProvider(widget.storeType));
    final cart = cartState.cart;
    if (!_entryCheckComplete ||
        _preparing ||
        draft.preparing ||
        draft.estimating ||
        draft.failure != null ||
        cart.items.isEmpty ||
        cartState.hasPendingMutation ||
        cartState.unconfirmedKeys.isNotEmpty ||
        cartState.mutationFailure != null ||
        !branchesReady) {
      return false;
    }
    return CheckoutRules.canSubmit(
      fulfillmentType: draft.fulfillment,
      addressId: draft.addressId,
      estimate: draft.quoteFor(cart, addresses),
      isEstimating: draft.estimating,
      pickupBranchId: pickupBranchId,
      pickupAllowed: CheckoutRules.pickupAllowed(cart),
      cart: cart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(checkoutControllerProvider(widget.storeType), (previous, next) {
      final order = next.lastOrder;
      if (order == null || previous?.lastOrder?.id == order.id) return;
      final method = ref
          .read(orderDraftProvider(widget.storeType))
          .paymentMethod;
      // Success is terminal: cart refresh/draft reset must never win a redirect
      // to the empty cart while submit's async cleanup is still unwinding.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCreatedOrder(order, method);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    final cartAsync = ref.watch(cartControllerProvider(widget.storeType));
    final addressesAsync = ref.watch(addressesControllerProvider);
    final draft = ref.watch(orderDraftProvider(widget.storeType));
    final checkout = ref.watch(checkoutControllerProvider(widget.storeType));
    final cartState = cartAsync.value;
    final cart = cartState?.cart;
    final addresses = addressesAsync.value ?? const <UserAddress>[];
    final quote = cart == null ? null : draft.quoteFor(cart, addresses);
    final storeIds = cart == null
        ? const <String>{}
        : CheckoutRules.physicalStoreIds(cart);
    final pickup = draft.fulfillment == FulfillmentType.pickup;
    final branches = pickup && storeIds.length == 1
        ? ref.watch(storeBranchesProvider(storeIds.single))
        : const AsyncData<List<StoreBranch>>([]);
    final eligible = (branches.value ?? const <StoreBranch>[])
        .where((branch) => branch.isActive && branch.isPickupAvailable)
        .toList();
    final branch =
        eligible
            .where((branch) => branch.id == draft.pickupBranchId)
            .firstOrNull ??
        (eligible.length == 1 ? eligible.single : null);
    if (pickup && branch != null && branch.id != draft.pickupBranchId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(orderDraftProvider(widget.storeType).notifier)
              .setPickupBranch(branch.id);
        }
      });
    }
    final selected = addresses
        .where((address) => address.id == draft.addressId)
        .firstOrNull;
    final total = cart == null
        ? null
        : CheckoutRules.displayTotal(
            subtotal: cart.subtotal,
            fulfillment: draft.fulfillment,
            estimate: quote,
            estimating: draft.estimating,
          );
    final pending =
        !_entryCheckComplete ||
        _preparing ||
        draft.preparing ||
        draft.estimating ||
        cartAsync.isLoading;
    final failure =
        draft.failure ??
        cartState?.mutationFailure ??
        (cartAsync.error is ApiFailure ? cartAsync.error as ApiFailure : null);

    if (!pending &&
        failure == null &&
        !_orderHandoffActive &&
        cartState?.hasPendingMutation != true &&
        cartState?.unconfirmedKeys.isNotEmpty != true) {
      if (cart == null || cart.items.isEmpty) {
        _scheduleCart('cart_empty', 'products');
      } else if (!pickup &&
          quote != null &&
          !cart.meetsDeliveryMinimumIncluding(quote.deliveryPrice)) {
        _scheduleCart('minimum_not_met', 'recommendations');
      }
    }

    final ready =
        !_orderHandoffActive &&
        cartState != null &&
        !pending &&
        (pickup || (!addressesAsync.hasError && !addressesAsync.isLoading)) &&
        _canSubmit(
          cartState,
          addresses,
          branch?.id,
          branchesReady: !pickup || (!branches.isLoading && !branches.hasError),
        );

    if (widget.storeType == StoreType.shashlik ||
        widget.storeType == StoreType.meat) {
      if (!pending &&
          !ready &&
          !checkout.isSubmitting &&
          !_orderHandoffActive) {
        _scheduleCart(
          OrderDraftNotice.cartNotReady,
          !pickup && selected == null ? 'address' : 'products',
        );
      }
      return _shashlikCheckout(
        l10n,
        cart: cart,
        draft: draft,
        quote: quote,
        pending: pending,
        failure: failure,
        ready: ready,
        selected: selected,
        branch: branch,
        total: total,
      );
    }

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: _checkoutAppBar(l10n, cart: cart),
        body: pending && cart == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const ValueKey('checkout-content'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (pending) ...[
                    const LinearProgressIndicator(
                      key: ValueKey('checkout-revalidating'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (failure != null ||
                      addressesAsync.hasError ||
                      (pickup && branches.hasError)) ...[
                    _CheckoutPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(failure?.localize(l10n) ?? l10n.errorUnknown),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            key: const ValueKey('checkout-retry'),
                            onPressed: pending
                                ? null
                                : () {
                                    if (pickup && storeIds.length == 1) {
                                      ref.invalidate(
                                        storeBranchesProvider(storeIds.single),
                                      );
                                    }
                                    unawaited(_prepareCheckout());
                                  },
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.commonRetry),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _ReceiveMethodPanel(
                    fulfillment: draft.fulfillment,
                    pickupAllowed:
                        cart != null && CheckoutRules.pickupAllowed(cart),
                    deliveryFee: quote?.deliveryPrice,
                    enabled: !checkout.isSubmitting,
                    onChanged: (value) {
                      ref
                          .read(orderDraftProvider(widget.storeType).notifier)
                          .setFulfillment(value);
                      if (value == FulfillmentType.delivery) {
                        unawaited(_prepareCheckout());
                      }
                    },
                    location: pickup
                        ? _LocationRow(
                            key: const ValueKey('checkout-location'),
                            icon: Icons.storefront_rounded,
                            caption: l10n.checkoutPickupStoreLabel,
                            title: branch?.name ?? l10n.checkoutSelectBranch,
                            subtitle: branch?.address,
                            status: branches.isLoading
                                ? l10n.checkoutQuoteCalculating
                                : null,
                          )
                        : _LocationRow(
                            key: const ValueKey('checkout-location'),
                            icon: Icons.local_shipping_rounded,
                            caption: l10n.checkoutDeliveryAddressLabel,
                            title:
                                selected?.formattedAddress.trim().isNotEmpty ==
                                    true
                                ? selected!.formattedAddress
                                : selected?.displayTitle(l10n) ??
                                      l10n.checkoutSelectAddress,
                            subtitle:
                                selected != null &&
                                    selected.formattedAddress.trim().isNotEmpty
                                ? selected.displayTitle(l10n)
                                : null,
                            status: draft.estimating
                                ? l10n.checkoutQuoteCalculating
                                : null,
                            error:
                                selected != null &&
                                    !draft.estimating &&
                                    !pending &&
                                    quote == null
                                ? _quoteError(draft.estimate, l10n)
                                : null,
                          ),
                    actionLabel: pickup || selected != null
                        ? l10n.checkoutChangeOther
                        : l10n.checkoutChooseAddressAction,
                    onAction: checkout.isSubmitting
                        ? null
                        : pickup
                        ? () => _choosePickup(eligible, branches.hasError)
                        : () => unawaited(_chooseAddress()),
                    mixedStoreHint:
                        cart != null && !CheckoutRules.pickupAllowed(cart)
                        ? l10n.checkoutMixedStorePickup
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _RecipientPanel(
                    name: draft.recipientName ?? _profileName(),
                    phone: draft.recipientPhone ?? _profilePhone(),
                    onTap: checkout.isSubmitting ? null : _editRecipient,
                  ),
                  const SizedBox(height: 14),
                  if (cart != null && cart.items.isNotEmpty) ...[
                    _DeliveryTimePanel(
                      cart: cart,
                      pickup: pickup,
                      onOpen: () => _showReceipt(cart),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _CheckoutPanel(
                    key: const ValueKey('checkout-payment-panel'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(text: l10n.checkoutPaymentType),
                        const SizedBox(height: 12),
                        _PaymentMethodSelector(
                          storeType: widget.storeType,
                          selected: draft.paymentMethod,
                          fulfillment: draft.fulfillment,
                          onChanged: (method) => ref
                              .read(
                                orderDraftProvider(widget.storeType).notifier,
                              )
                              .setPaymentMethod(method),
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
                  if (cart != null) ...[
                    const SizedBox(height: 14),
                    _SummaryCard(
                      cart: cart,
                      estimate: quote,
                      fulfillment: draft.fulfillment,
                      total: total,
                    ),
                  ],
                ],
              ),
        bottomNavigationBar: _CheckoutBottomBar(
          minimum: cart == null || pickup
              ? null
              : DeliveryMinimumProgress(
                  cart: cart,
                  deliveryFee: quote?.deliveryPrice,
                  isConfirmed:
                      !pending &&
                      !checkout.isSubmitting &&
                      failure == null &&
                      cartState?.hasPendingMutation == false &&
                      cartState?.unconfirmedKeys.isEmpty == true,
                  onAddProducts: () => _returnToCart('recommendations'),
                ),
          total: total,
          submitting: checkout.isSubmitting,
          label:
              draft.paymentMethod == PaymentMethod.payme &&
                  ref.watch(paymeAvailableProvider(widget.storeType))
              ? l10n.checkoutPayWithPayme
              : l10n.checkoutSubmit,
          onSubmit:
              (ready ||
                      ref
                              .read(checkoutIdempotencyStoreProvider)
                              .pending(widget.storeType) !=
                          null) &&
                  !checkout.isSubmitting
              ? () => _submit(branch?.id)
              : null,
        ),
      ),
    );
  }

  Widget _shashlikCheckout(
    AppLocalizations l10n, {
    required CartData? cart,
    required OrderDraftState draft,
    required DeliveryEstimate? quote,
    required bool pending,
    required ApiFailure? failure,
    required bool ready,
    required UserAddress? selected,
    required StoreBranch? branch,
    required String? total,
  }) {
    final pickup = draft.fulfillment == FulfillmentType.pickup;
    final checkout = ref.watch(checkoutControllerProvider(widget.storeType));
    final locked = checkout.isSubmitting || _submittingPreflight;
    final canResolve =
        ref.read(checkoutIdempotencyStoreProvider).pending(widget.storeType) !=
        null;
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: _checkoutAppBar(l10n, cart: cart),
        body: ListView(
          key: ValueKey('${widget.storeType.wire}-checkout-content'),
          padding: const EdgeInsets.all(16),
          children: [
            if (pending) const LinearProgressIndicator(),
            if (failure != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  failure.localize(l10n),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _CheckoutPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pickup ? l10n.checkoutPickup : l10n.checkoutDelivery,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    pickup
                        ? branch?.name ?? l10n.checkoutSelectBranch
                        : selected?.displayTitle(l10n) ??
                              l10n.checkoutSelectAddress,
                  ),
                  if ((pickup ? branch?.address : selected?.formattedAddress)
                          ?.isNotEmpty ==
                      true)
                    Text(
                      (pickup ? branch?.address : selected?.formattedAddress)!,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: ValueKey(
                        '${widget.storeType.wire}-checkout-edit-address',
                      ),
                      onPressed: locked ? null : () => _returnToCart('address'),
                      child: Text(l10n.commonEdit),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (cart != null)
              _CheckoutPanel(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.cartItemsLine(cart.totalQuantity)),
                      subtitle: Text(Uzs.format(cart.subtotal)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: locked ? null : () => _showReceipt(cart),
                    ),
                    TextButton(
                      key: ValueKey(
                        '${widget.storeType.wire}-checkout-edit-cart',
                      ),
                      onPressed: locked
                          ? null
                          : () => _returnToCart('products'),
                      child: Text(l10n.checkoutEditCart),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _CheckoutPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.checkoutPaymentType,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (ref.watch(paymeAvailableProvider(widget.storeType)))
                    _PaymentMethodSelector(
                      storeType: widget.storeType,
                      selected: draft.paymentMethod,
                      fulfillment: draft.fulfillment,
                      onChanged: (method) => ref
                          .read(orderDraftProvider(widget.storeType).notifier)
                          .setPaymentMethod(method),
                    )
                  else
                    Text(
                      pickup
                          ? l10n.checkoutPayCashStore
                          : l10n.checkoutPayCashCourier,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CheckoutPanel(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.checkoutRecipient),
                subtitle: Text(
                  '${draft.recipientName ?? _profileName()} · ${draft.recipientPhone ?? _profilePhone()}',
                ),
                children: [
                  TextButton(
                    onPressed: locked ? null : _editRecipient,
                    child: Text(l10n.commonEdit),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CheckoutPanel(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                maintainState: true,
                title: Text(l10n.checkoutNote),
                children: [
                  TextField(
                    controller: _noteController,
                    enabled: !locked,
                    maxLength: _noteMaxLength,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l10n.checkoutNotePlaceholder,
                    ),
                  ),
                ],
              ),
            ),
            if (cart != null) ...[
              const SizedBox(height: 12),
              _SummaryCard(
                cart: cart,
                estimate: quote,
                fulfillment: draft.fulfillment,
                total: total,
              ),
            ],
          ],
        ),
        bottomNavigationBar: _CheckoutBottomBar(
          minimum: cart == null || pickup
              ? null
              : DeliveryMinimumProgress(
                  cart: cart,
                  deliveryFee: quote?.deliveryPrice,
                  isConfirmed:
                      !pending &&
                      !locked &&
                      failure == null &&
                      ref
                              .watch(cartControllerProvider(widget.storeType))
                              .value
                              ?.hasPendingMutation ==
                          false &&
                      ref
                              .watch(cartControllerProvider(widget.storeType))
                              .value
                              ?.unconfirmedKeys
                              .isEmpty ==
                          true,
                  onAddProducts: () => _returnToCart('recommendations'),
                ),
          total: total,
          submitting: locked,
          label: l10n.checkoutSubmit,
          onSubmit: !locked && (ready || canResolve)
              ? () => _submit(branch?.id)
              : null,
        ),
      ),
    );
  }

  String _profileName() =>
      ref.read(authControllerProvider).user?.fullName ?? '';

  String _profilePhone() =>
      ref.read(authControllerProvider).user?.phoneNumber ?? '';

  String _quoteError(DeliveryEstimate? quote, AppLocalizations l10n) =>
      switch (quote?.reasonCode) {
        'outside_delivery_radius' => l10n.cartDeliveryNotAvailable,
        'delivery_tariff_unavailable' => l10n.checkoutTariffUnavailable,
        _ => l10n.checkoutEstimateUnavailable,
      };

  /// "Boshqasini tanlash" — manzil xaritasi/ro'yxati; tanlangach narx shu
  /// ekranda qayta hisoblanadi.
  Future<void> _chooseAddress() async {
    final controller = ref.read(orderDraftProvider(widget.storeType).notifier);
    final result = await pickCartDeliveryAddress(
      context,
      ref,
      widget.storeType,
      initialAddressId: ref
          .read(orderDraftProvider(widget.storeType))
          .addressId,
    );
    if (!mounted || result == null) return;
    await controller.acceptAddress(result);
  }

  Future<void> _choosePickup(List<StoreBranch> branches, bool failed) async {
    if (failed) {
      final cart = ref
          .read(cartControllerProvider(widget.storeType))
          .value
          ?.cart;
      final id = cart == null
          ? null
          : CheckoutRules.physicalStoreIds(cart).firstOrNull;
      if (id != null) ref.invalidate(storeBranchesProvider(id));
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            AppLocalizations.of(context).cartChoosePickup,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (branches.isEmpty)
            Text(AppLocalizations.of(context).checkoutEstimateUnavailable),
          for (final branch in branches)
            ListTile(
              key: ValueKey('checkout-pickup-option-${branch.id}'),
              leading: const Icon(Icons.storefront_outlined),
              title: Text(branch.name),
              subtitle: Text(branch.address),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, branch.id),
            ),
        ],
      ),
    );
    if (mounted && selected != null) {
      ref
          .read(orderDraftProvider(widget.storeType).notifier)
          .setPickupBranch(selected);
    }
  }

  Future<void> _editRecipient() async {
    final draft = ref.read(orderDraftProvider(widget.storeType));
    final result = await showModalBottomSheet<({String name, String phone})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => RecipientSheet(
        initialName: draft.recipientName ?? _profileName(),
        initialPhone: draft.recipientPhone ?? _profilePhone(),
        profileName: _profileName(),
        profilePhone: _profilePhone(),
      ),
    );
    if (!mounted || result == null) return;
    final sameAsProfile =
        result.name == _profileName() && result.phone == _profilePhone();
    ref
        .read(orderDraftProvider(widget.storeType).notifier)
        .setRecipient(
          name: sameAsProfile ? null : result.name,
          phone: sameAsProfile ? null : result.phone,
        );
  }

  Future<void> _showReceipt(CartData cart) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .85,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: AppLocalizations.of(context).commonClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              CheckoutReceipt(cart: cart),
            ],
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

  Future<void> _submit(String? pickupBranchId) async {
    if (_preparing || _submittingPreflight) return;
    if (!OfflineGate.check(ref)) return;
    _submittingPreflight = true;
    try {
      if (ref
              .read(checkoutIdempotencyStoreProvider)
              .pending(widget.storeType) !=
          null) {
        final order = await ref
            .read(checkoutControllerProvider(widget.storeType).notifier)
            .retryPending();
        if (mounted && order != null) {
          _openCreatedOrder(order, PaymentMethod.cash);
        }
        return;
      }
      await _prepareCheckout();
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final draft = ref.read(orderDraftProvider(widget.storeType));
      final cart = ref.read(cartControllerProvider(widget.storeType)).value;
      final addresses = ref.read(addressesControllerProvider).value;
      if (draft.fulfillment == FulfillmentType.pickup && cart != null) {
        final stores = CheckoutRules.physicalStoreIds(cart.cart);
        final eligible = stores.length == 1
            ? (ref.read(storeBranchesProvider(stores.single)).value ??
                      const <StoreBranch>[])
                  .where(
                    (branch) => branch.isActive && branch.isPickupAvailable,
                  )
                  .toList()
            : const <StoreBranch>[];
        pickupBranchId =
            eligible
                .where((branch) => branch.id == draft.pickupBranchId)
                .firstOrNull
                ?.id ??
            (eligible.length == 1 ? eligible.single.id : null);
      }
      if (cart == null ||
          (draft.fulfillment == FulfillmentType.delivery &&
              addresses == null) ||
          !_canSubmit(cart, addresses ?? const [], pickupBranchId)) {
        return;
      }
      final order = await ref
          .read(checkoutControllerProvider(widget.storeType).notifier)
          .submit(
            fulfillmentType: draft.fulfillment,
            paymentMethod: draft.paymentMethod,
            addressId: draft.addressId,
            pickupBranchId: pickupBranchId,
            note: _noteController.text,
            recipientName: draft.recipientName,
            recipientPhone: draft.recipientPhone,
          );
      if (!mounted || order == null) return;
      _openCreatedOrder(order, draft.paymentMethod);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      if (failure is ValidationFailure) {
        final reason = failure.forField('reason_code') ?? '';
        final structural =
            reason == 'minimum_delivery_order_not_met' ||
            reason.contains('delivery') ||
            reason.contains('radius') ||
            failure.forField('address') != null ||
            failure.forField('address_id') != null ||
            failure.forField('pickup_branch') != null;
        if (structural) {
          await ref
              .read(orderDraftProvider(widget.storeType).notifier)
              .prepare(revalidateQuote: true);
          if (!mounted) return;
          if (reason == 'minimum_delivery_order_not_met') {
            _returnToCart('recommendations', notice: 'minimum_not_met');
            return;
          }
          // Manzil/hudud muammosi — shu ekranda kartada ko'rinadi.
          _messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(failure.localize(AppLocalizations.of(context))),
              ),
            );
          return;
        }
      }
      // Unknown/network failures keep the draft and controller idempotency key.
      _messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(failure.localize(AppLocalizations.of(context))),
          ),
        );
    } finally {
      if (mounted) setState(() => _submittingPreflight = false);
    }
  }
}

/// To'lov usuli — yonma-yon ikkita rangli karta.
///
/// Rang formulasi ilovadagi mavjud uslub: tanlanmaganda yumshoq tint fon,
/// tanlanganda to'liq brend rangi + oq matn va ✓ belgisi.
class _PaymentMethodSelector extends ConsumerWidget {
  const _PaymentMethodSelector({
    required this.storeType,
    required this.selected,
    required this.fulfillment,
    required this.onChanged,
  });

  static const _paymeColor = Color(0xFF33CCCC);

  final StoreType storeType;

  final PaymentMethod selected;
  final FulfillmentType fulfillment;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final paymeAvailable = ref.watch(paymeAvailableProvider(storeType));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected == PaymentMethod.payme &&
            !paymeAvailable &&
            ref.watch(paymentCapabilitiesProvider).hasValue)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(l10n.paymeUnavailable),
          ),
        if (paymeAvailable) ...[
          _PaymentMethodCard(
            key: const ValueKey('checkout-payment-payme'),
            label: l10n.checkoutPayPayme,
            caption: l10n.checkoutPayOnlineCaption,
            icon: Icons.credit_card_rounded,
            accent: _paymeColor,
            selected: selected == PaymentMethod.payme,
            onTap: () => onChanged(PaymentMethod.payme),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _PaymentMethodCard(
          key: const ValueKey('checkout-payment-cash'),
          label: fulfillment == FulfillmentType.delivery
              ? l10n.checkoutPayCashCourier
              : l10n.checkoutPayCashStore,
          caption: fulfillment == FulfillmentType.delivery
              ? l10n.checkoutPayOnReceipt
              : l10n.checkoutPayOnPickup,
          icon: Icons.account_balance_wallet_rounded,
          accent: AppColors.success,
          selected: selected == PaymentMethod.cash,
          onTap: () => onChanged(PaymentMethod.cash),
        ),
      ],
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
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? AppColors.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppColors.primary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
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
    final theme = Theme.of(context);
    final deliveryValue = fulfillment == FulfillmentType.pickup
        ? l10n.checkoutDeliveryFree
        : estimate?.available == true && estimate?.deliveryPrice != null
        ? ((double.tryParse(estimate!.deliveryPrice!) ?? 0) <= 0
              ? l10n.checkoutDeliveryFree
              : Uzs.format(estimate!.deliveryPrice))
        : '—';
    return _CheckoutPanel(
      key: const ValueKey('checkout-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(text: l10n.checkoutOrderSummary),
          const SizedBox(height: 12),
          _SummaryRow(
            label: l10n.cartItemsLine(cart.totalQuantity),
            value: Uzs.format(cart.originalSubtotal),
          ),
          if (cart.hasDiscount) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: l10n.cartDiscount,
              value: '−${Uzs.format(cart.discountTotal)}',
              color: AppColors.danger,
            ),
          ],
          const SizedBox(height: 8),
          _SummaryRow(label: l10n.cartDeliveryFee, value: deliveryValue),
          const Divider(height: 26),
          _SummaryRow(
            label: l10n.checkoutTotal,
            value: total == null ? '—' : Uzs.format(total),
            prominent: true,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.checkoutReviewHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    this.color,
  });

  final String label;
  final String value;
  final bool prominent;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: prominent ? 18 : 14,
            fontWeight: prominent ? FontWeight.w900 : FontWeight.w400,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: prominent ? 18 : 14,
            color: color ?? (prominent ? AppColors.primary : null),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

/// Read-only order contents: use server line subtotals (including chosen
/// variants/addons), not product.price * quantity.
class CheckoutReceipt extends StatelessWidget {
  const CheckoutReceipt({required this.cart, super.key});
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
  const _CheckoutPanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
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
                        selectedColor: Colors.white,
                        checkmarkColor: AppColors.primary,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
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

/// "Olish usuli": Kuryer | Olib ketish + tanlangan manzil/filial va
/// "Boshqasini tanlash".
class _ReceiveMethodPanel extends StatelessWidget {
  const _ReceiveMethodPanel({
    required this.fulfillment,
    required this.pickupAllowed,
    required this.deliveryFee,
    required this.enabled,
    required this.onChanged,
    required this.location,
    required this.actionLabel,
    required this.onAction,
    this.mixedStoreHint,
  });

  final FulfillmentType fulfillment;
  final bool pickupAllowed;
  final String? deliveryFee;
  final bool enabled;
  final ValueChanged<FulfillmentType> onChanged;
  final Widget location;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? mixedStoreHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget segment(String title, String caption, FulfillmentType value) =>
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: fulfillment == value
                    ? Colors.white
                    : theme.colorScheme.onSurface,
              ),
            ),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: fulfillment == value
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
    final fee = deliveryFee;
    final feeText = fee == null
        ? l10n.checkoutChooseAddressHint
        : (double.tryParse(fee) ?? 0) <= 0
        ? l10n.checkoutPickupFree
        : Uzs.format(fee);
    return _CheckoutPanel(
      key: const ValueKey('checkout-address-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(text: l10n.checkoutReceiveMethod),
          const SizedBox(height: 12),
          SegmentedButton<FulfillmentType>(
            key: const ValueKey('checkout-fulfillment'),
            showSelectedIcon: true,
            selectedIcon: const Icon(Icons.check_circle_rounded, size: 18),
            expandedInsets: EdgeInsets.zero,
            segments: [
              ButtonSegment(
                value: FulfillmentType.delivery,
                label: segment(
                  l10n.checkoutCourier,
                  feeText,
                  FulfillmentType.delivery,
                ),
              ),
              ButtonSegment(
                value: FulfillmentType.pickup,
                enabled: pickupAllowed,
                label: segment(
                  l10n.checkoutPickup,
                  l10n.checkoutPickupFree,
                  FulfillmentType.pickup,
                ),
              ),
            ],
            selected: {fulfillment},
            onSelectionChanged: enabled
                ? (values) => onChanged(values.single)
                : null,
            style:
                SegmentedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                ).copyWith(
                  // Loading must not erase which method was selected.
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : theme.colorScheme.surface,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
          ),
          if (mixedStoreHint != null) ...[
            const SizedBox(height: 8),
            Text(mixedStoreHint!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          location,
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('checkout-change-location'),
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: theme.colorScheme.surface,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.caption,
    required this.title,
    this.subtitle,
    this.status,
    this.error,
    super.key,
  });

  final IconData icon;
  final String caption;
  final String title;
  final String? subtitle;
  final String? status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundIcon(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                key: const ValueKey('checkout-location-summary'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle?.trim().isNotEmpty == true)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (status != null) ...[
                const SizedBox(height: 6),
                Text(status!, style: theme.textTheme.bodySmall),
              ],
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  key: const ValueKey('checkout-location-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: const BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    child: Icon(icon, color: Colors.white, size: 22),
  );
}

class _RecipientPanel extends StatelessWidget {
  const _RecipientPanel({
    required this.name,
    required this.phone,
    required this.onTap,
  });

  final String name;
  final String phone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formatted = UzbekPhone.isNormalized(phone)
        ? UzbekPhone.formatFull(phone)
        : phone;
    return _CheckoutPanel(
      key: const ValueKey('checkout-recipient'),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Row(
          children: [
            const _RoundIcon(icon: Icons.person_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.checkoutRecipient,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (name.trim().isNotEmpty)
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(formatted, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Yetkazish vaqti + mahsulot rasmchalari (bosilsa to'liq chek).
class _DeliveryTimePanel extends StatelessWidget {
  const _DeliveryTimePanel({
    required this.cart,
    required this.pickup,
    required this.onOpen,
  });

  final CartData cart;
  final bool pickup;
  final VoidCallback onOpen;

  static const _maxThumbs = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = cart.items;
    final extra = items.length - _maxThumbs;
    return _CheckoutPanel(
      key: const ValueKey('checkout-delivery-time'),
      child: InkWell(
        key: const ValueKey('checkout-open-receipt'),
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SectionTitle(
                    text: pickup
                        ? l10n.checkoutPickupReadyHint
                        : l10n.deliveryEstimateTitle,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            if (!pickup) ...[
              const SizedBox(height: 4),
              Text(
                l10n.deliveryEstimateAvailabilityHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items.take(_maxThumbs))
                  ClipRRect(
                    key: ValueKey('checkout-thumb-${item.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 64,
                      child: ExcludeSemantics(
                        child: ProductImageView(
                          imageUrl: item.product.imageUrl,
                          iconSize: 24,
                          memCacheWidth: 192,
                        ),
                      ),
                    ),
                  ),
                if (extra > 0)
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lightSunken,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+$extra',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.total,
    required this.submitting,
    required this.label,
    required this.onSubmit,
    this.minimum,
  });

  final String? total;
  final bool submitting;
  final String label;
  final VoidCallback? onSubmit;
  final Widget? minimum;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?minimum,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.checkoutTotal,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        total == null ? '—' : Uzs.format(total),
                        key: const ValueKey('checkout-submit-total'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                key: const ValueKey('checkout-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onSubmit,
                child: submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oluvchini o'zgartirish: ism + telefon (boshqa odamga buyurtma).
@visibleForTesting
class RecipientSheet extends StatefulWidget {
  const RecipientSheet({
    required this.initialName,
    required this.initialPhone,
    required this.profileName,
    required this.profilePhone,
    super.key,
  });

  final String initialName;
  final String initialPhone;
  final String profileName;
  final String profilePhone;

  @override
  State<RecipientSheet> createState() => _RecipientSheetState();
}

class _RecipientSheetState extends State<RecipientSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _phone = TextEditingController(
    text: UzbekPhone.formatLocal(UzbekPhone.localDigits(widget.initialPhone)),
  );
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final normalized = UzbekPhone.normalize(_phone.text);
    if (normalized == null) {
      setState(
        () => _phoneError = AppLocalizations.of(
          context,
        ).checkoutRecipientPhoneInvalid,
      );
      return;
    }
    Navigator.pop(context, (name: _name.text.trim(), phone: normalized));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.checkoutRecipient,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('recipient-name'),
            controller: _name,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.checkoutRecipientName),
          ),
          const SizedBox(height: 8),
          PhoneField(
            key: const ValueKey('recipient-phone'),
            controller: _phone,
            errorText: _phoneError,
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
            onSubmitted: _save,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('recipient-save'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(l10n.checkoutRecipientSave),
          ),
          if (widget.profilePhone.isNotEmpty)
            TextButton(
              key: const ValueKey('recipient-reset'),
              onPressed: () => Navigator.pop(context, (
                name: widget.profileName,
                phone: widget.profilePhone,
              )),
              child: Text(l10n.checkoutRecipientReset),
            ),
        ],
      ),
    );
  }
}
