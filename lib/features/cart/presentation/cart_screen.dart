import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_buttons.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../core/ui/widgets/smooth_press.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../catalog/data/product_models.dart';
import '../../catalog/domain/catalog_controller.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../checkout/data/checkout_models.dart';
import '../../checkout/domain/addresses_controller.dart';
import '../../checkout/domain/checkout_rules.dart';
import '../../checkout/domain/order_draft_controller.dart';
import '../../checkout/presentation/address_display.dart';
import '../../checkout/presentation/delivery_address_navigation.dart';
import '../../checkout/presentation/widgets/delivery_minimum_card.dart';
import '../../home/data/home_models.dart';
import '../../home/domain/home_controller.dart';
import '../data/cart_models.dart';
import '../domain/cart_controller.dart';
import '../domain/cart_recommendations_provider.dart';
import '../domain/main_cart_overview_provider.dart';
import 'widgets/cart_recommendations.dart';
import 'widgets/empty_cart_view.dart';

class MainCartScreen extends ConsumerWidget {
  const MainCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stores = _orderedStores(
      ref.watch(homeControllerProvider).value,
      l10n,
    );
    final overview = ref.watch(mainCartOverviewProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => appBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(l10n.cartTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cartRecommendationsProvider(null));
          await Future.wait([
            ref.read(homeControllerProvider.notifier).refresh(),
            for (final type in StoreType.values)
              ref.read(cartControllerProvider(type).notifier).refresh(),
          ]);
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              key: const PageStorageKey('main-cart'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  l10n.cartMainSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < stores.length; index++) ...[
                  _StoreCartOverview(
                    key: ValueKey(
                      'main-cart-section-${stores[index].type.wire}',
                    ),
                    store: stores[index],
                  ),
                  const SizedBox(height: 12),
                ],
                if (overview.isSettled && !overview.hasAnyItem)
                  const EmptyCartView(),
                const CartRecommendations(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreCartOverview extends ConsumerWidget {
  const _StoreCartOverview({required this.store, super.key});
  final _CartStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider(store.type));
    final data = cart.value?.cart;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('open-store-cart-${store.type.wire}'),
        onTap: () => context.push<void>(Routes.storeCart(store.type.wire)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (data != null)
                      Text(
                        data.items.isEmpty
                            ? l10n.cartEmptyStore
                            : l10n.cartItemsCount(data.totalQuantity),
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else if (cart.hasError)
                      TextButton(
                        onPressed: () => ref
                            .read(cartControllerProvider(store.type).notifier)
                            .refresh(),
                        child: Text(l10n.commonRetry),
                      )
                    else
                      const LinearProgressIndicator(minHeight: 2),
                    if (data?.items.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        Uzs.format(data!.subtotal),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({required this.storeType, this.initialFocus, super.key});
  final StoreType storeType;
  final String? initialFocus;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _locationKey = GlobalKey();
  final _productsKey = GlobalKey();
  final _recommendationsKey = GlobalKey();
  bool _working = false;
  String? _appliedFocus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFocus != widget.initialFocus) _appliedFocus = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(cartRecommendationsProvider(widget.storeType));
    final before = ref
        .read(cartControllerProvider(widget.storeType))
        .value
        ?.cart;
    if (before != null && CheckoutRules.pickupAllowed(before)) {
      ref.invalidate(
        storeBranchesProvider(CheckoutRules.physicalStoreIds(before).single),
      );
    }
    if (ref.read(authControllerProvider).isAuthenticated) {
      await ref.read(orderDraftProvider(widget.storeType).notifier).prepare();
    } else {
      await ref
          .read(cartControllerProvider(widget.storeType).notifier)
          .refresh();
    }
  }

  Future<void> _chooseAddress() async {
    if (_working) return;
    if (!await requireAuthentication(context, ref) || !mounted) return;
    setState(() => _working = true);
    try {
      final controller = ref.read(
        orderDraftProvider(widget.storeType).notifier,
      );
      if (!await controller.prepare(revalidateQuote: false) || !mounted) return;
      final result = await pickCartDeliveryAddress(
        context,
        ref,
        widget.storeType,
        initialAddressId: ref
            .read(orderDraftProvider(widget.storeType))
            .addressId,
      );
      if (!mounted) return;
      if (result != null) await controller.acceptAddress(result);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _continue() async {
    if (_working) return;
    final guest = !ref.read(authControllerProvider).isAuthenticated;
    final intent = ref.read(orderDraftProvider(widget.storeType));
    if (!await requireAuthentication(context, ref) || !mounted) return;
    setState(() => _working = true);
    try {
      final controller = ref.read(
        orderDraftProvider(widget.storeType).notifier,
      );
      // Login resets account-scoped drafts. Carry only this explicit guest
      // fulfillment intent, never another account's address, note or quote.
      if (guest && intent.fulfillment == FulfillmentType.pickup) {
        controller.setFulfillment(FulfillmentType.pickup);
      }
      if (!await controller.prepare() || !mounted) return;
      final data = ref.read(cartControllerProvider(widget.storeType)).value;
      if (guest &&
          data != null &&
          intent.fulfillment == FulfillmentType.pickup &&
          CheckoutRules.pickupAllowed(data.cart)) {
        try {
          final branches = await ref.read(
            storeBranchesProvider(
              CheckoutRules.physicalStoreIds(data.cart).single,
            ).future,
          );
          if (!mounted) return;
          final eligible = branches
              .where((branch) => branch.isActive && branch.isPickupAvailable)
              .toList();
          final previous = eligible
              .where((branch) => branch.id == intent.pickupBranchId)
              .firstOrNull;
          controller.setPickupBranch(
            previous?.id ?? (eligible.length == 1 ? eligible.single.id : null),
          );
        } on Object {
          // The branch provider exposes its error and retry action in cart.
          return;
        }
      }
      final latestData = ref
          .read(cartControllerProvider(widget.storeType))
          .value;
      final draft = ref.read(orderDraftProvider(widget.storeType));
      final addresses = ref.read(addressesControllerProvider).value ?? [];
      final quote = latestData == null
          ? null
          : draft.quoteFor(latestData.cart, addresses);
      if (latestData == null || !_eligible(latestData, draft, quote)) return;
      await context.push<void>(Routes.checkout(widget.storeType.wire));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  bool _pickupReady(CartData cart, OrderDraftState draft) {
    if (!CheckoutRules.pickupAllowed(cart)) return false;
    final branches = ref.read(
      storeBranchesProvider(CheckoutRules.physicalStoreIds(cart).single),
    );
    return !branches.isLoading &&
        !branches.hasError &&
        branches.value?.any(
              (branch) =>
                  branch.id == draft.pickupBranchId &&
                  branch.isActive &&
                  branch.isPickupAvailable,
            ) ==
            true;
  }

  bool _eligible(
    CartState cart,
    OrderDraftState draft,
    DeliveryEstimate? quote,
  ) =>
      !cart.hasPendingMutation &&
      cart.unconfirmedKeys.isEmpty &&
      cart.mutationFailure == null &&
      !draft.preparing &&
      !draft.estimating &&
      (draft.fulfillment != FulfillmentType.pickup ||
          _pickupReady(cart.cart, draft)) &&
      CheckoutRules.displayTotal(
            subtotal: cart.cart.subtotal,
            fulfillment: draft.fulfillment,
            estimate: quote,
          ) !=
          null &&
      CheckoutRules.canSubmit(
        fulfillmentType: draft.fulfillment,
        addressId: draft.addressId,
        estimate: quote,
        isEstimating: draft.estimating,
        pickupBranchId: draft.pickupBranchId,
        pickupAllowed: CheckoutRules.pickupAllowed(cart.cart),
        cart: cart.cart,
      );

  void _focus(String focus) {
    final key = switch (focus) {
      'location' || 'fulfillment' => _locationKey,
      'recommendations' => _recommendationsKey,
      _ => _productsKey,
    };
    final target = key.currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 280),
          alignment: .05,
        ),
      );
    }
  }

  Future<void> _retry() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _refresh();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String? _noticeText(
    OrderDraftState draft,
    CartData cart,
    DeliveryEstimate? quote,
    AppLocalizations l10n,
  ) {
    if (draft.notice == null) return null;
    return switch (draft.notice) {
      'address_missing' => l10n.cartSelectDeliveryAddress,
      'pickup_branch_missing' => l10n.cartChoosePickup,
      'minimum_not_met' when quote?.available == true =>
        l10n.checkoutMinimumRemaining(
          Uzs.formatWithFraction(
            cart.deliveryMinimumRemaining(deliveryFee: quote!.deliveryPrice),
          ),
        ),
      _ => l10n.cartOrderChanged,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = cartControllerProvider(widget.storeType);
    final cartAsync = ref.watch(provider);
    final cartState = cartAsync.value;
    final cart = cartState?.cart;
    final draft = ref.watch(orderDraftProvider(widget.storeType));
    final addresses = ref.watch(addressesControllerProvider);
    final quote = cart == null
        ? null
        : draft.quoteFor(cart, addresses.value ?? []);
    final descriptors = _orderedStores(
      ref.watch(homeControllerProvider).value,
      l10n,
    );
    final descriptor = descriptors.firstWhere(
      (store) => store.type == widget.storeType,
    );
    ref.listen<AsyncValue<CartState>>(provider, (previous, next) {
      final error = next.value?.mutationFailure;
      if (error != null && error != previous?.value?.mutationFailure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.localize(l10n))));
      }
    });
    if (cart != null &&
        cart.items.isNotEmpty &&
        widget.initialFocus != null &&
        _appliedFocus != widget.initialFocus) {
      _appliedFocus = widget.initialFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus(widget.initialFocus!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => appBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cartTitle),
            Text(
              descriptor.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (cart?.items.isNotEmpty == true)
            IconButton(
              key: const ValueKey('cart-clear'),
              tooltip: l10n.cartClear,
              onPressed: cartState!.hasPendingMutation
                  ? null
                  : () => _confirmClear(context, ref, widget.storeType),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: cart == null
          ? cartAsync.hasError
                ? _CartError(
                    label: descriptor.label,
                    number: null,
                    message: cartAsync.error is ApiFailure
                        ? (cartAsync.error as ApiFailure).localize(l10n)
                        : l10n.errorUnknown,
                    onRetry: () => unawaited(_refresh()),
                  )
                : const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 600 && constraints.maxHeight < 400;
                final footer = cart.items.isEmpty
                    ? null
                    : _footer(l10n, cartState!, draft, quote);
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: SingleChildScrollView(
                          key: PageStorageKey('cart-${widget.storeType.wire}'),
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  28,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (cart.items.isEmpty)
                                      EmptyCartView(
                                        storeLabel: descriptor.label,
                                        onBrowse: () => goToStoreTab(
                                          context,
                                          widget.storeType,
                                          StoreTab.catalog,
                                        ),
                                      )
                                    else ...[
                                      _fulfillment(l10n, cart, draft),
                                      if (_noticeText(draft, cart, quote, l10n)
                                          case final String notice) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          key: const ValueKey(
                                            'cart-flow-notice',
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF5E6),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(notice)),
                                              IconButton(
                                                tooltip: l10n.commonClose,
                                                onPressed: () => ref
                                                    .read(
                                                      orderDraftProvider(
                                                        widget.storeType,
                                                      ).notifier,
                                                    )
                                                    .setNotice(null),
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (draft.fulfillment ==
                                              FulfillmentType.delivery &&
                                          cart.hasDeliveryMinimum) ...[
                                        const SizedBox(height: 16),
                                        DeliveryMinimumCard(
                                          cart: cart,
                                          statusOverride:
                                              cartState?.hasPendingMutation ==
                                                      true ||
                                                  cartState
                                                          ?.unconfirmedKeys
                                                          .isNotEmpty ==
                                                      true ||
                                                  draft.preparing ||
                                                  draft.estimating ||
                                                  _working
                                              ? l10n.cartUpdating
                                              : draft.failure != null ||
                                                    cartState
                                                            ?.mutationFailure !=
                                                        null
                                              ? l10n.cartRefreshError
                                              : draft.selection != null &&
                                                    quote == null
                                              ? _quoteError(
                                                  draft.estimate,
                                                  l10n,
                                                )
                                              : null,
                                          deliveryFee: quote?.available == true
                                              ? quote?.deliveryPrice
                                              : null,
                                        ),
                                      ],
                                      const SizedBox(height: 24),
                                      Text(
                                        l10n.cartProductsTitle,
                                        key: _productsKey,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Material(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          children: [
                                            for (
                                              var index = 0;
                                              index < cart.items.length;
                                              index++
                                            ) ...[
                                              if (index != 0)
                                                const Divider(
                                                  height: 1,
                                                  indent: 16,
                                                  endIndent: 16,
                                                ),
                                              _CartItemRow(
                                                item: cart.items[index],
                                                storeType: widget.storeType,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                    CartRecommendations(
                                      key: _recommendationsKey,
                                      storeType: widget.storeType,
                                      minimumMode:
                                          cart.items.isNotEmpty &&
                                          draft.fulfillment ==
                                              FulfillmentType.delivery &&
                                          cart.hasDeliveryMinimum &&
                                          quote?.available == true &&
                                          !cart.meetsDeliveryMinimumIncluding(
                                            quote?.deliveryPrice,
                                          ),
                                      showFallback: true,
                                      onBrowse: () => goToStoreTab(
                                        context,
                                        widget.storeType,
                                        StoreTab.catalog,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (footer != null)
                      if (wide)
                        SizedBox(
                          width: (constraints.maxWidth * .5).clamp(
                            360.0,
                            420.0,
                          ),
                          child: footer,
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * .6,
                          ),
                          child: footer,
                        ),
                  ],
                );
              },
            ),
    );
  }

  Widget _fulfillment(
    AppLocalizations l10n,
    CartData cart,
    OrderDraftState draft,
  ) {
    final pickupAllowed = CheckoutRules.pickupAllowed(cart);
    final controller = ref.read(orderDraftProvider(widget.storeType).notifier);
    final physicalIds = CheckoutRules.physicalStoreIds(cart);
    final branches =
        pickupAllowed && draft.fulfillment == FulfillmentType.pickup
        ? ref.watch(storeBranchesProvider(physicalIds.single))
        : const AsyncData<List<StoreBranch>>([]);
    final pickup = branches.value
        ?.where(
          (branch) =>
              branch.id == draft.pickupBranchId &&
              branch.isActive &&
              branch.isPickupAvailable,
        )
        .firstOrNull;
    final eligible =
        branches.value
            ?.where((branch) => branch.isActive && branch.isPickupAvailable)
            .toList() ??
        [];
    if (draft.fulfillment == FulfillmentType.pickup &&
        draft.pickupBranchId == null &&
        eligible.length == 1) {
      final onlyId = eligible.single.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(orderDraftProvider(widget.storeType)).pickupBranchId ==
                null) {
          controller.setPickupBranch(onlyId);
        }
      });
    }
    return Container(
      key: _locationKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<FulfillmentType>(
            key: const ValueKey('cart-fulfillment'),
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            segments: [
              ButtonSegment(
                value: FulfillmentType.delivery,
                label: Text(l10n.checkoutDelivery),
                icon: const Icon(Icons.delivery_dining_outlined),
              ),
              ButtonSegment(
                value: FulfillmentType.pickup,
                label: Text(l10n.checkoutPickup),
                icon: const Icon(Icons.storefront_outlined),
                enabled: pickupAllowed,
              ),
            ],
            selected: {draft.fulfillment},
            onSelectionChanged: _working
                ? null
                : (values) => controller.setFulfillment(values.single),
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          if (draft.fulfillment == FulfillmentType.delivery)
            _locationTile(
              key: const ValueKey('cart-address'),
              icon: Icons.location_on_outlined,
              title:
                  draft.selection?.address.displayTitle(l10n) ??
                  l10n.cartSelectDeliveryAddress,
              subtitle:
                  draft.selection?.address.formattedAddress ??
                  l10n.cartDeliveryUnknown,
              onTap: _working ? null : _chooseAddress,
            )
          else ...[
            _locationTile(
              key: const ValueKey('cart-pickup'),
              icon: Icons.storefront_outlined,
              title: pickup?.name ?? l10n.cartChoosePickup,
              subtitle:
                  pickup?.address ??
                  (branches.hasError
                      ? l10n.errorUnknown
                      : l10n.checkoutSelectBranch),
              onTap: _working
                  ? null
                  : () => _choosePickup(eligible, branches.hasError),
            ),
            if (branches.isLoading) const LinearProgressIndicator(minHeight: 2),
          ],
          if (!pickupAllowed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.checkoutMixedStorePickup,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _locationTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => Material(
    key: key,
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );

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
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .55,
        minChildSize: .3,
        maxChildSize: .9,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
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
                key: ValueKey('cart-pickup-option-${branch.id}'),
                title: Text(branch.name),
                subtitle: Text(branch.address),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, branch.id),
              ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) {
      ref
          .read(orderDraftProvider(widget.storeType).notifier)
          .setPickupBranch(selected);
    }
  }

  void _chooseCurrentPickup() {
    final cart = ref.read(cartControllerProvider(widget.storeType)).value?.cart;
    if (cart == null || !CheckoutRules.pickupAllowed(cart)) return;
    final branches = ref.read(
      storeBranchesProvider(CheckoutRules.physicalStoreIds(cart).single),
    );
    if (branches.isLoading) return;
    unawaited(
      _choosePickup(
        branches.value
                ?.where((branch) => branch.isActive && branch.isPickupAvailable)
                .toList() ??
            [],
        branches.hasError,
      ),
    );
  }

  Widget _footer(
    AppLocalizations l10n,
    CartState cartState,
    OrderDraftState draft,
    DeliveryEstimate? quote,
  ) {
    final cart = cartState.cart;
    final delivery = draft.fulfillment == FulfillmentType.delivery;
    final branchState = !delivery && CheckoutRules.pickupAllowed(cart)
        ? ref.watch(
            storeBranchesProvider(CheckoutRules.physicalStoreIds(cart).single),
          )
        : const AsyncData<List<StoreBranch>>([]);
    final busy =
        _working ||
        cartState.hasPendingMutation ||
        cartState.unconfirmedKeys.isNotEmpty ||
        draft.preparing ||
        draft.estimating ||
        (!delivery && branchState.isLoading);
    final mutationError = cartState.mutationFailure;
    final error =
        draft.failure ??
        mutationError ??
        (branchState.hasError
            ? branchState.error is ApiFailure
                  ? branchState.error as ApiFailure
                  : const UnknownFailure()
            : null);
    final missingAddress = delivery && draft.selection == null;
    final total = CheckoutRules.displayTotal(
      subtotal: cart.subtotal,
      fulfillment: draft.fulfillment,
      estimate: quote,
      estimating: busy,
    );
    final rejected =
        delivery &&
        !missingAddress &&
        (quote == null || !quote.available || total == null);
    final minimumShort =
        delivery &&
        !missingAddress &&
        !rejected &&
        !cart.meetsDeliveryMinimumIncluding(quote?.deliveryPrice);
    String label;
    VoidCallback? action;
    if (busy) {
      label = l10n.cartUpdating;
    } else if (error != null) {
      label = l10n.commonRetry;
      action = () => unawaited(_retry());
    } else if (missingAddress) {
      label = l10n.cartSelectDeliveryAddress;
      action = () => unawaited(_chooseAddress());
    } else if (rejected) {
      label = l10n.deliveryAddressChange;
      action = () => unawaited(_chooseAddress());
    } else if (!delivery && !_pickupReady(cart, draft)) {
      label = l10n.cartChoosePickup;
      action = _chooseCurrentPickup;
    } else if (minimumShort) {
      label = l10n.checkoutAddProducts;
      action = () => _focus('recommendations');
    } else {
      label = l10n.cartContinueOrder;
      action = () => unawaited(_continue());
    }
    final status = busy
        ? l10n.cartUpdating
        : error != null
        ? error.localize(l10n)
        : missingAddress
        ? l10n.cartDeliveryUnknown
        : rejected
        ? _quoteError(quote ?? draft.estimate, l10n)
        : minimumShort
        ? l10n.checkoutMinimumRemaining(
            Uzs.formatWithFraction(
              cart.deliveryMinimumRemaining(deliveryFee: quote?.deliveryPrice),
            ),
          )
        : delivery && cart.hasDeliveryMinimum
        ? l10n.checkoutMinimumReached
        : null;
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 5,
                        children: [
                          Text(
                            total == null
                                ? l10n.cartProductsTitle
                                : l10n.cartTotal,
                          ),
                          Text(
                            Uzs.format(total ?? cart.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          status,
                          key: const ValueKey('cart-footer-status'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: error != null || rejected
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                        ),
                      ],
                      if (minimumShort) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress(cart, quote?.deliveryPrice),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('cart-primary-action'),
                onPressed: action,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _quoteError(DeliveryEstimate? quote, AppLocalizations l10n) =>
      switch (quote?.reasonCode) {
        'outside_delivery_radius' => l10n.cartDeliveryNotAvailable,
        'delivery_tariff_unavailable' => l10n.checkoutTariffUnavailable,
        _ => l10n.checkoutEstimateUnavailable,
      };

  double _progress(CartData cart, String? fee) {
    final minimum =
        double.tryParse(cart.minimumDeliveryOrderAmount ?? '0') ?? 0;
    return minimum <= 0
        ? 1
        : (((double.tryParse(cart.subtotal) ?? 0) +
                      (double.tryParse(fee ?? '0') ?? 0)) /
                  minimum)
              .clamp(0.0, 1.0);
  }
}

class _CartItemRow extends ConsumerWidget {
  const _CartItemRow({required this.item, required this.storeType});

  final CartItem item;
  final StoreType storeType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    ref.watch(cartControllerProvider(storeType));
    final controller = ref.read(cartControllerProvider(storeType).notifier);
    final quantityText = storeType == StoreType.shashlik
        ? _shashlikCartQuantityLabel(l10n, item.product, item.quantity)
        : null;
    final needsAddonNames = item.selectedAddons.any(
      (addon) => addon.name.isEmpty,
    );
    final detail = needsAddonNames
        ? ref.watch(productDetailProvider(item.product.id)).value
        : null;
    final addonNames = [
      for (final selected in item.selectedAddons)
        if (selected.name.isNotEmpty)
          selected.name
        else
          for (final group in detail?.addonGroups ?? const <AddonGroup>[])
            for (final option in group.options)
              if (option.id == selected.id) option.name,
    ];
    final configuration = [
      if (item.variant != null) item.variant!.name,
      ...addonNames,
      if (item.note.trim().isNotEmpty) item.note.trim(),
    ].join(' · ');

    return Padding(
      key: ValueKey('cart-item-${item.id}'),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
          final stacked =
              constraints.maxWidth < 340 || scale > 1.3 || quantityText != null;
          final stepper = CartQuantityStepper(
            quantity: item.quantity,
            quantityText: quantityText,
            onDecrement: () => controller.decrement(item),
            onIncrement: () => controller.increment(item),
            semanticLabel: quantityText ?? l10n.cartItemsCount(item.quantity),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () =>
                        openStoreProduct(context, storeType, item.product.id),
                    borderRadius: BorderRadius.circular(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox.square(
                        dimension: 72,
                        child: ProductImageView(
                          imageUrl: item.product.imageUrl,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          openStoreProduct(context, storeType, item.product.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (configuration.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              configuration,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            // Server line total includes the selected variant,
                            // extras and quantity, unlike the base catalog price.
                            Uzs.formatWithFraction(item.subtotal),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!stacked) ...[const SizedBox(width: 10), stepper],
                ],
              ),
              if (stacked) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: stepper),
              ],
            ],
          );
        },
      ),
    );
  }
}

class CartQuantityStepper extends StatelessWidget {
  const CartQuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.semanticLabel,
    this.quantityText,
    super.key,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String semanticLabel;
  final String? quantityText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(icon: Icons.remove, onPressed: onDecrement),
            Flexible(
              fit: FlexFit.loose,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 32,
                  maxWidth: quantityText == null ? 64 : 180,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    quantityText ?? '$quantity',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            _StepperButton(icon: Icons.add, onPressed: onIncrement),
          ],
        ),
      ),
    );
  }
}

String _shashlikCartQuantityLabel(
  AppLocalizations l10n,
  ProductSummary product,
  int quantity,
) {
  final unit = product.unitCode.trim().toLowerCase();
  final normalizedName = product.name.toLowerCase();
  final isKilogram = unit == 'kg' || normalizedName.contains('kilo');
  return isKilogram
      ? l10n.shashlikKilogramQuantity(quantity)
      : l10n.shashlikPieceQuantity(quantity);
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SmoothPress(
    enabled: onPressed != null,
    child: IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      tooltip: icon == Icons.add
          ? AppLocalizations.of(context).cartIncreaseQuantity
          : AppLocalizations.of(context).cartDecreaseQuantity,
      icon: Icon(icon, size: 20),
    ),
  );
}

class _StoreCartHeader extends StatelessWidget {
  const _StoreCartHeader({required this.label, required this.number});

  final String label;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            _StoreNumber(number: number),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreNumber extends StatelessWidget {
  const _StoreNumber({required this.number});

  final int? number;

  @override
  Widget build(BuildContext context) {
    final value = number;
    if (value == null) {
      return Icon(
        Icons.storefront_outlined,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          value.toString().padLeft(2, '0'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CartError extends StatelessWidget {
  const _CartError({
    required this.label,
    required this.number,
    required this.message,
    required this.onRetry,
  });

  final String label;
  final int? number;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      side: BorderSide(color: Theme.of(context).colorScheme.errorContainer),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoreCartHeader(label: label, number: number),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _confirmClear(
  BuildContext context,
  WidgetRef ref,
  StoreType storeType,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cartClear),
      content: Text(l10n.cartClearConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: AppButtons.dialogAction,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(cartControllerProvider(storeType).notifier).clear();
  }
}

class _CartStore {
  const _CartStore(this.type, this.label);

  final StoreType type;
  final String label;
}

List<_CartStore> _orderedStores(HomeData? home, AppLocalizations l10n) {
  final result = <_CartStore>[];
  final seen = <StoreType>{};
  for (final item in home?.storeHub ?? const <StoreHubItem>[]) {
    final type = item.storeType;
    if (type == null || !seen.add(type)) continue;
    result.add(
      _CartStore(
        type,
        item.label.trim().isEmpty
            ? _fallbackStoreLabel(l10n, type)
            : item.label.trim(),
      ),
    );
  }
  for (final type in StoreType.values) {
    if (seen.add(type)) {
      result.add(_CartStore(type, _fallbackStoreLabel(l10n, type)));
    }
  }
  return result;
}

String _fallbackStoreLabel(AppLocalizations l10n, StoreType type) =>
    switch (type) {
      StoreType.grocery => l10n.storeGrocery,
      StoreType.household => l10n.storeHousehold,
      StoreType.restaurant => l10n.storeRestaurant,
      StoreType.shashlik => l10n.storeShashlik,
      StoreType.meat => l10n.storeMeat,
    };
