import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/route_visibility.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_buttons.dart';
import '../../../core/ui/theme/app_colors.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../core/ui/widgets/smooth_press.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../catalog/data/product_models.dart';
import '../../catalog/domain/catalog_controller.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../catalog/presentation/widgets/shashlik_catalog.dart';
import '../../checkout/data/checkout_models.dart';
import '../../checkout/domain/addresses_controller.dart';
import '../../checkout/domain/checkout_rules.dart';
import '../../checkout/domain/order_draft_controller.dart';
import '../../checkout/presentation/address_display.dart';
import '../../checkout/presentation/delivery_address_navigation.dart';
import '../../checkout/presentation/widgets/delivery_minimum_progress.dart';
import '../../favorites/domain/favorites_controller.dart';
import '../../home/data/home_models.dart';
import '../../home/domain/home_controller.dart';
import '../../store/presentation/widgets/store_switch_button.dart';
import '../data/cart_models.dart';
import '../domain/cart_controller.dart';
import '../domain/cart_recommendations_provider.dart';
import '../domain/main_cart_overview_provider.dart';
import 'widgets/cart_recommendations.dart';
import 'widgets/empty_cart_view.dart';

part 'widgets/shashlik_cart_flow.dart';

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
                  color: AppColors.lightSunken,
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

/// Store-local preparation: fulfillment, address, products and recommendations.
/// Only a ready, confirmed cart may continue to the final checkout.
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
  final _productsKey = GlobalKey();
  final _recommendationsKey = GlobalKey();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Rasmiylashtirishga o'tganda manzil va narx tayyor tursin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(authControllerProvider).isAuthenticated) return;
      final draft = ref.read(orderDraftProvider(widget.storeType));
      if (draft.selection == null &&
          draft.fulfillment == FulfillmentType.delivery) {
        unawaited(
          ref
              .read(orderDraftProvider(widget.storeType).notifier)
              .prepare(useSavedAddress: true),
        );
      }
    });
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
    if (ref.read(authControllerProvider).isAuthenticated) {
      await ref
          .read(orderDraftProvider(widget.storeType).notifier)
          .prepare(useSavedAddress: true);
    } else {
      await ref
          .read(cartControllerProvider(widget.storeType).notifier)
          .refresh();
    }
  }

  /// "Rasmiylashtirish": login → manzil/narx tayyorlash → checkout.
  Future<void> _continue() async {
    if (_working) return;
    if (!await requireAuthentication(context, ref) || !mounted) return;
    setState(() => _working = true);
    try {
      final prepared = await ref
          .read(orderDraftProvider(widget.storeType).notifier)
          .prepare(useSavedAddress: true);
      if (!prepared || !mounted || !isRouteStackCurrent(context)) return;
      final latest = ref.read(cartControllerProvider(widget.storeType)).value;
      if (latest == null || !_canContinue(latest)) return;
      {
        final draft = ref.read(orderDraftProvider(widget.storeType));
        final addresses =
            ref.read(addressesControllerProvider).value ??
            const <UserAddress>[];
        final ids = CheckoutRules.physicalStoreIds(latest.cart);
        final branches =
            draft.fulfillment == FulfillmentType.pickup && ids.length == 1
            ? ref.read(storeBranchesProvider(ids.single)).value ??
                  const <StoreBranch>[]
            : const <StoreBranch>[];
        if (!CheckoutRules.canSubmit(
          fulfillmentType: draft.fulfillment,
          addressId: draft.addressId,
          estimate: draft.quoteFor(latest.cart, addresses),
          isEstimating: draft.estimating,
          pickupBranchId:
              branches.any(
                (b) =>
                    b.id == draft.pickupBranchId &&
                    b.isActive &&
                    b.isPickupAvailable,
              )
              ? draft.pickupBranchId
              : null,
          pickupAllowed: CheckoutRules.pickupAllowed(latest.cart),
          cart: latest.cart,
        )) {
          return;
        }
      }
      // Push future kutilmaydi: checkout savatga go(...) bilan qaytishi mumkin.
      unawaited(context.push<void>(Routes.checkout(widget.storeType.wire)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  bool _canContinue(CartState cart) =>
      cart.cart.items.isNotEmpty &&
      cart.cart.isOrderable &&
      !cart.hasPendingMutation &&
      cart.unconfirmedKeys.isEmpty &&
      cart.mutationFailure == null;

  void _focus(String focus) {
    final key = focus == 'recommendations' ? _recommendationsKey : _productsKey;
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

  @override
  Widget build(BuildContext context) => _ShashlikCartFlow(
    storeType: widget.storeType,
    scroll: _scroll,
    productsKey: _productsKey,
    recommendationsKey: _recommendationsKey,
    working: _working,
    onRefresh: _refresh,
    onContinue: _continue,
    onFocus: _focus,
    initialFocus: widget.initialFocus,
  );
}

class _CartCard extends StatelessWidget {
  const _CartCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('cart-flow-notice'),
    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(child: Text(text)),
        IconButton(
          tooltip: AppLocalizations.of(context).commonClose,
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}

/// Checkout does not provide an ETA yet; never promise a same-day delivery.
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
        : storeType == StoreType.meat
        ? '${item.quantity} ${item.variant?.unit ?? item.product.unit}'
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
    final isFavorite = ref.watch(
      favoritesControllerProvider.select(
        (value) => value.value?.contains(item.product.id) == true,
      ),
    );
    final favoriteBusy = ref.watch(
      favoritesControllerProvider.select(
        (value) => value.value?.busyProductIds.isNotEmpty ?? false,
      ),
    );
    final original = item.originalSubtotal;
    void open() => openStoreProduct(context, storeType, item.product.id);

    final stepper = !item.isOrderable
        ? TextButton.icon(
            key: ValueKey('remove-unavailable-${item.id}'),
            onPressed: () => controller.remove(item),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.commonDelete),
          )
        : CartQuantityStepper(
            quantity: item.quantity,
            quantityText: quantityText,
            onDecrement: () => controller.decrement(item),
            onIncrement: () => controller.increment(item),
            semanticLabel: quantityText ?? l10n.cartItemsCount(item.quantity),
            onEdit: storeType == StoreType.shashlik
                ? () => showShashlikCartQuantityEditor(context, item)
                : storeType == StoreType.meat
                ? () => showMeatQuantityEditor(
                    context,
                    item.product,
                    exactItem: item,
                  )
                : null,
          );

    return Padding(
      key: ValueKey('cart-item-${item.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 88,
                height: 104,
                child: ProductImageView(imageUrl: item.product.imageUrl),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: open,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // Server qator jami: variant, qo'shimchalar va
                              // soni bilan (katalog narxidan farqli).
                              item.subtotal.isEmpty
                                  ? '—'
                                  : Uzs.formatWithFraction(item.subtotal),
                              key: ValueKey('cart-item-price-${item.id}'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            if (original != null)
                              Text(
                                Uzs.format(original),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              item.product.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('cart-item-favorite-${item.id}'),
                      tooltip:
                          storeType == StoreType.shashlik ||
                              storeType == StoreType.meat
                          ? l10n.commonDelete
                          : l10n.favoritesTitle,
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          storeType == StoreType.shashlik ||
                              storeType == StoreType.meat
                          ? () => controller.remove(item)
                          : favoriteBusy
                          ? null
                          : () async {
                              if (!await requireAuthentication(context, ref)) {
                                return;
                              }
                              if (!context.mounted) return;
                              await ref
                                  .read(favoritesControllerProvider.notifier)
                                  .toggle(item.product);
                            },
                      icon: Icon(
                        storeType == StoreType.shashlik ||
                                storeType == StoreType.meat
                            ? Icons.delete_outline
                            : isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isFavorite
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (!item.isOrderable)
                  Text(
                    ValidationFailure('', {
                      'reason_code': [
                        item.unavailableReasonCode ?? 'product_unavailable',
                      ],
                    }).localize(l10n),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                if (configuration.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    configuration,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (item.quantity > 1 && item.subtotal.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.cartPerUnit(Uzs.format(item.unitPrice)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: stepper),
              ],
            ),
          ),
        ],
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
    this.onEdit,
    super.key,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String semanticLabel;
  final String? quantityText;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(icon: Icons.remove, onPressed: onDecrement),
            Flexible(
              fit: FlexFit.loose,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                  maxWidth: quantityText == null ? 64 : 180,
                ),
                child: InkWell(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
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
      color: AppColors.primary,
      visualDensity: VisualDensity.standard,
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
