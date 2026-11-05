part of '../cart_screen.dart';

/// Keep the primary action visible even when large text makes the explanation
/// taller than a short/landscape footer. Only the information region scrolls.
class _CartFooterContent extends StatelessWidget {
  const _CartFooterContent({required this.info, required this.action});
  final Widget info;
  final Widget action;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: SingleChildScrollView(child: info)),
            const SizedBox(height: 10),
            action,
          ],
        ),
      ),
    ),
  );
}

/// Shared preparation flow for every store; each keeps its own draft,
/// cart, delivery quote and physical-store boundaries.
class _ShashlikCartFlow extends ConsumerStatefulWidget {
  const _ShashlikCartFlow({
    required this.scroll,
    required this.productsKey,
    required this.recommendationsKey,
    required this.working,
    required this.onRefresh,
    required this.onContinue,
    required this.onFocus,
    this.storeType = StoreType.shashlik,
    this.initialFocus,
  });
  final ScrollController scroll;
  final GlobalKey productsKey, recommendationsKey;
  final bool working;
  final Future<void> Function() onRefresh, onContinue;
  final ValueChanged<String> onFocus;
  final String? initialFocus;
  final StoreType storeType;
  @override
  ConsumerState<_ShashlikCartFlow> createState() => _ShashlikCartFlowState();
}

class _ShashlikCartFlowState extends ConsumerState<_ShashlikCartFlow> {
  final _locationKey = GlobalKey();
  String? _focused;
  bool _choosing = false;
  StoreType get _type => widget.storeType;
  Future<void> _chooseAddress({bool useRestored = false}) async {
    if (_choosing || !await requireAuthentication(context, ref) || !mounted) {
      return;
    }
    setState(() => _choosing = true);
    try {
      final controller = ref.read(orderDraftProvider(_type).notifier);
      if (!await controller.prepare(
            useSavedAddress: true,
            revalidateQuote: useRestored,
          ) ||
          !mounted) {
        return;
      }
      // A primary action after login may restore an existing saved address.
      // Continuation still rechecks the minimum, cart and quote before routing.
      if (useRestored) {
        final current = ref.read(orderDraftProvider(_type));
        final cart = ref.read(cartControllerProvider(_type)).value?.cart;
        final addresses =
            ref.read(addressesControllerProvider).value ??
            const <UserAddress>[];
        if (cart != null && current.quoteFor(cart, addresses) != null) {
          await widget.onContinue();
          return;
        }
      }
      final result = await pickCartDeliveryAddress(
        context,
        ref,
        _type,
        initialAddressId: ref.read(orderDraftProvider(_type)).addressId,
      );
      if (mounted && result != null) await controller.acceptAddress(result);
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  Future<void> _chooseBranch(List<StoreBranch> branches) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppLocalizations.of(context).checkoutSelectBranch),
          for (final branch in branches)
            ListTile(
              title: Text(branch.name),
              subtitle: Text(branch.address),
              onTap: () => Navigator.pop(context, branch.id),
            ),
        ],
      ),
    );
    if (mounted && selected != null) {
      ref.read(orderDraftProvider(_type).notifier).setPickupBranch(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(cartControllerProvider(_type));
    final state = value.value;
    final cart = state?.cart;
    final draft = ref.watch(orderDraftProvider(_type));
    final addresses = ref.watch(addressesControllerProvider);
    final pickup = draft.fulfillment == FulfillmentType.pickup;
    final ids = cart == null
        ? <String>{}
        : CheckoutRules.physicalStoreIds(cart);
    final branches = pickup && ids.length == 1
        ? ref.watch(storeBranchesProvider(ids.single))
        : const AsyncData<List<StoreBranch>>([]);
    final eligible = (branches.value ?? const <StoreBranch>[])
        .where((b) => b.isActive && b.isPickupAvailable)
        .toList();
    final branch =
        eligible.where((b) => b.id == draft.pickupBranchId).firstOrNull ??
        (eligible.length == 1 ? eligible.single : null);
    if (pickup && branch != null && branch.id != draft.pickupBranchId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(orderDraftProvider(_type)).fulfillment ==
                FulfillmentType.pickup) {
          ref
              .read(orderDraftProvider(_type).notifier)
              .setPickupBranch(branch.id);
        }
      });
    }
    final address = (addresses.value ?? const <UserAddress>[])
        .where((a) => a.id == draft.addressId)
        .firstOrNull;
    final quote = cart == null
        ? null
        : addresses.isLoading || addresses.hasError || value.hasError
        ? null
        : draft.quoteFor(cart, addresses.value ?? const []);
    final unconfirmed = state?.unconfirmedKeys.isNotEmpty ?? false;
    final busy =
        widget.working ||
        _choosing ||
        draft.preparing ||
        draft.estimating ||
        value.isLoading ||
        (state?.hasPendingMutation ?? false) ||
        (pickup && branches.isLoading);
    final failure = state?.mutationFailure ?? draft.failure;
    final ready =
        state != null &&
        !busy &&
        failure == null &&
        !unconfirmed &&
        cart!.items.isNotEmpty &&
        CheckoutRules.canSubmit(
          fulfillmentType: draft.fulfillment,
          addressId: draft.addressId,
          estimate: quote,
          isEstimating: draft.estimating,
          pickupBranchId: branch?.id,
          pickupAllowed: CheckoutRules.pickupAllowed(cart),
          cart: cart,
        );
    final missing =
        !pickup &&
        quote != null &&
        cart != null &&
        !cart.meetsDeliveryMinimumIncluding(quote.deliveryPrice);
    final noLocation = pickup ? branch == null : address == null;
    final total = cart == null
        ? null
        : CheckoutRules.displayTotal(
            subtotal: cart.subtotal,
            fulfillment: draft.fulfillment,
            estimate: quote,
            estimating: draft.estimating || busy,
          );
    final unavailable =
        !pickup && address != null && !busy && quote == null && failure == null;
    void locate({bool restore = false}) => pickup
        ? unawaited(_chooseBranch(eligible))
        : unawaited(_chooseAddress(useRestored: restore && address == null));
    void changeMode(FulfillmentType mode) {
      ref.read(orderDraftProvider(_type).notifier).setFulfillment(mode);
      if (mode == FulfillmentType.delivery &&
          ref.read(authControllerProvider).isAuthenticated) {
        unawaited(
          ref
              .read(orderDraftProvider(_type).notifier)
              .prepare(useSavedAddress: true),
        );
      }
    }

    if (widget.initialFocus != null && _focused != widget.initialFocus) {
      _focused = widget.initialFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_focused == 'address' || _focused == 'fulfillment') {
          if (_locationKey.currentContext != null) {
            unawaited(Scrollable.ensureVisible(_locationKey.currentContext!));
          }
        } else {
          widget.onFocus(_focused!);
        }
      });
    }
    final action = FilledButton(
      key: const ValueKey('cart-primary-action'),
      onPressed: busy
          ? null
          : failure != null || unconfirmed || (pickup && branches.hasError)
          ? () {
              if (pickup && ids.length == 1) {
                ref.invalidate(storeBranchesProvider(ids.single));
              }
              unawaited(widget.onRefresh());
            }
          : noLocation || unavailable
          ? () => locate(restore: true)
          : ready
          ? () => unawaited(widget.onContinue())
          : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: missing && !busy
            ? const Color(0xFFBEE7D3)
            : null,
        disabledForegroundColor: missing && !busy
            ? const Color(0xFF174C37)
            : null,
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              failure != null || unconfirmed || (pickup && branches.hasError)
                  ? l10n.commonRetry
                  : noLocation || unavailable
                  ? pickup
                        ? l10n.checkoutSelectBranch
                        : l10n.checkoutChooseAddressAction
                  : l10n.cartContinueOrder,
              textAlign: TextAlign.center,
            ),
    );
    final footer = cart == null || cart.items.isEmpty
        ? null
        : _CartFooterContent(
            action: action,
            info: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!pickup)
                  DeliveryMinimumProgress(
                    cart: cart,
                    deliveryFee: quote?.deliveryPrice,
                    isConfirmed: !busy && !unconfirmed && failure == null,
                    onAddProducts: () => widget.onFocus('recommendations'),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        total == null
                            ? l10n.cartItemsLine(cart.totalQuantity)
                            : l10n.cartTotal,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        total == null
                            ? Uzs.format(cart.subtotal)
                            : Uzs.formatWithFraction(total),
                        key: const ValueKey('cart-footer-total'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (unconfirmed && failure == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.errorNetwork),
                  ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      failure.localize(l10n),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (unavailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      draft.estimate?.reasonCode ==
                              'delivery_tariff_unavailable'
                          ? l10n.checkoutTariffUnavailable
                          : l10n.cartDeliveryNotAvailable,
                    ),
                  ),
              ],
            ),
          );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => appBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          children: [
            Text(l10n.cartTitle, key: const ValueKey('cart-title')),
            Text(
              _orderedStores(
                ref.watch(homeControllerProvider).value,
                l10n,
              ).firstWhere((store) => store.type == _type).label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          StoreSwitchButton(storeType: _type, enabled: !busy),
          if (cart?.items.isNotEmpty == true)
            IconButton(
              key: const ValueKey('cart-clear'),
              tooltip: l10n.cartClear,
              onPressed: busy ? null : () => _confirmClear(context, ref, _type),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: cart == null
          ? value.hasError
                ? _CartError(
                    label: _orderedStores(
                      ref.watch(homeControllerProvider).value,
                      l10n,
                    ).firstWhere((store) => store.type == _type).label,
                    number: null,
                    message: value.error is ApiFailure
                        ? (value.error as ApiFailure).localize(l10n)
                        : l10n.errorUnknown,
                    onRetry: () => unawaited(widget.onRefresh()),
                  )
                : const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 600 && constraints.maxHeight < 400;
                final content = RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: SingleChildScrollView(
                    key: PageStorageKey('cart-${_type.wire}'),
                    controller: widget.scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (cart.items.isEmpty)
                          EmptyCartView(
                            storeLabel: _orderedStores(
                              ref.watch(homeControllerProvider).value,
                              l10n,
                            ).firstWhere((store) => store.type == _type).label,
                            onBrowse: () =>
                                goToStoreTab(context, _type, StoreTab.catalog),
                          )
                        else ...[
                          if (draft.notice != null &&
                              draft.notice != 'minimum_not_met')
                            _Notice(
                              text: l10n.cartOrderChanged,
                              onClose: () => ref
                                  .read(orderDraftProvider(_type).notifier)
                                  .setNotice(null),
                            ),
                          Column(
                            key: _locationKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  for (final mode in FulfillmentType.values)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: FilledButton(
                                          key: ValueKey(
                                            '${_type.wire}-cart-${mode.name}',
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                draft.fulfillment == mode
                                                ? AppColors.primary
                                                : Colors.white,
                                            foregroundColor:
                                                draft.fulfillment == mode
                                                ? Colors.white
                                                : AppColors.lightTextPrimary,
                                            minimumSize: const Size(48, 48),
                                            side: const BorderSide(
                                              color:
                                                  AppColors.lightBorderStrong,
                                            ),
                                          ),
                                          onPressed:
                                              busy ||
                                                  (mode ==
                                                          FulfillmentType
                                                              .pickup &&
                                                      !CheckoutRules.pickupAllowed(
                                                        cart,
                                                      ))
                                              ? null
                                              : () => changeMode(mode),
                                          child: Text(
                                            mode == FulfillmentType.delivery
                                                ? l10n.checkoutDelivery
                                                : l10n.checkoutPickup,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _CartCard(
                                child: ListTile(
                                  key: ValueKey('${_type.wire}-cart-location'),
                                  onTap: busy ? null : locate,
                                  leading: Icon(
                                    pickup
                                        ? Icons.storefront_outlined
                                        : Icons.location_on_outlined,
                                    color: AppColors.primary,
                                  ),
                                  title: Text(
                                    pickup
                                        ? branch?.name ??
                                              l10n.checkoutSelectBranch
                                        : address?.displayTitle(l10n) ??
                                              l10n.checkoutChooseAddressAction,
                                  ),
                                  subtitle: Text(
                                    pickup
                                        ? branch?.address ??
                                              l10n.checkoutPickupFree
                                        : address == null
                                        ? l10n.cartDeliveryUnknown
                                        : [
                                                address.formattedAddress,
                                                if (quote?.deliveryPrice !=
                                                    null)
                                                  Uzs.format(
                                                    quote!.deliveryPrice,
                                                  ),
                                              ]
                                              .where((s) => s.isNotEmpty)
                                              .join(' · '),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                ),
                              ),
                              if (failure != null || unavailable)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: busy ? null : locate,
                                    child: Text(
                                      pickup
                                          ? l10n.checkoutSelectBranch
                                          : l10n.checkoutChangeOther,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _CartCard(
                            key: widget.productsKey,
                            child: Column(
                              children: [
                                for (final item in cart.items)
                                  _CartItemRow(item: item, storeType: _type),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        CartRecommendations(
                          key: widget.recommendationsKey,
                          storeType: _type,
                          minimumMode: missing,
                          showFallback: true,
                          grid: true,
                          onBrowse: () =>
                              goToStoreTab(context, _type, StoreTab.catalog),
                        ),
                      ],
                    ),
                  ),
                );
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: content),
                    if (footer != null)
                      wide
                          ? SizedBox(
                              width: constraints.maxWidth * .45,
                              child: footer,
                            )
                          : ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * .55,
                              ),
                              child: footer,
                            ),
                  ],
                );
              },
            ),
    );
  }
}
