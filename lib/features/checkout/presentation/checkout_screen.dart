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
import 'widgets/checkout_receipt_paper.dart';

/// Final review only: fulfillment, location and minimum are prepared in cart.
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
    setState(() {
      _preparing = true;
      _entryCheckComplete = false;
    });
    try {
      await ref
          .read(orderDraftProvider(widget.storeType).notifier)
          .prepare(revalidateQuote: true);
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
        submission.lastOrder != null;
  }

  void _openCreatedOrder(OrderData order, PaymentMethod method) {
    if (!mounted || _orderOpened) return;
    _orderOpened = true;
    final router = GoRouter.maybeOf(context);
    final autoPay =
        ref.read(paymeEnabledProvider) && method == PaymentMethod.payme;
    ref.read(orderDraftProvider(widget.storeType).notifier).clear();
    if (router != null) {
      AppBackCoordinator.of(router).discardCheckout();
      router.go(
        Routes.orderDetail(widget.storeType.wire, order.id, autoPay: autoPay),
      );
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
      } else if (pickup) {
        if (!CheckoutRules.pickupAllowed(cart) ||
            (!branches.isLoading && !branches.hasError && branch == null)) {
          _scheduleCart('pickup_branch_missing', 'fulfillment');
        }
      } else if (!addressesAsync.isLoading && !addressesAsync.hasError) {
        if (selected == null) {
          _scheduleCart('address_missing', 'location');
        } else if (quote == null) {
          _scheduleCart(draft.notice ?? 'delivery_unavailable', 'location');
        } else if (!cart.meetsDeliveryMinimumIncluding(quote.deliveryPrice)) {
          _scheduleCart('minimum_not_met', 'products');
        }
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
                  _CheckoutPanel(
                    key: const ValueKey('checkout-address-panel'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              pickup
                                  ? Icons.store_mall_directory_outlined
                                  : Icons.location_on_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SectionTitle(
                                text: pickup
                                    ? l10n.checkoutPickup
                                    : l10n.checkoutAddress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          pickup
                              ? branch?.name ?? l10n.checkoutSelectBranch
                              : selected?.displayTitle(l10n) ??
                                    l10n.checkoutSelectAddress,
                          key: const ValueKey('checkout-location-summary'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if ((pickup
                                    ? branch?.address
                                    : selected?.formattedAddress)
                                ?.trim()
                                .isNotEmpty ==
                            true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              pickup
                                  ? branch!.address
                                  : selected!.formattedAddress,
                            ),
                          ),
                        if (!pickup && quote?.deliveryPrice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${l10n.cartDeliveryFee}: ${Uzs.format(quote!.deliveryPrice)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        TextButton.icon(
                          key: const ValueKey('checkout-edit-location'),
                          onPressed: checkout.isSubmitting
                              ? null
                              : () => _returnToCart(
                                  pickup ? 'fulfillment' : 'location',
                                ),
                          icon: const Icon(
                            Icons.edit_location_alt_outlined,
                            size: 18,
                          ),
                          label: Text(l10n.commonEdit),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (cart != null && cart.items.isNotEmpty) ...[
                    _CheckoutPanel(
                      key: const ValueKey('checkout-products-panel'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            key: const ValueKey('checkout-open-receipt'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showReceipt(cart),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.receipt_long_outlined,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.checkoutProductsSummary(
                                            cart.items.length,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(Uzs.format(cart.subtotal)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('checkout-edit-cart'),
                            onPressed: checkout.isSubmitting
                                ? null
                                : () => _returnToCart('products'),
                            child: Text(l10n.checkoutEditCart),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: FilledButton(
                key: const ValueKey('checkout-submit'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: ready && !checkout.isSubmitting
                    ? () => _submit(branch?.id)
                    : null,
                child: checkout.isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final label = Text(
                            l10n.checkoutSubmit,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          );
                          final price = total == null
                              ? null
                              : Text(
                                  Uzs.format(total),
                                  key: const ValueKey('checkout-submit-total'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                          if (constraints.maxWidth < 350 &&
                              MediaQuery.textScalerOf(context).scale(14) > 20) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                label,
                                if (price != null) ...[
                                  const SizedBox(height: 4),
                                  price,
                                ],
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: label),
                              if (price != null) ...[
                                const SizedBox(width: 10),
                                Flexible(child: price),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
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
          text: TextSpan(text: l10n.checkoutReviewTitle, style: titleStyle),
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
            l10n.checkoutReviewTitle,
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
          _returnToCart(
            reason == 'minimum_delivery_order_not_met'
                ? 'products'
                : 'location',
            notice: reason == 'minimum_delivery_order_not_met'
                ? 'minimum_not_met'
                : 'cart_changed',
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
