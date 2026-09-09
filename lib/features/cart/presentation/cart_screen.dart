import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_buttons.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/data/product_models.dart';
import '../../catalog/domain/catalog_controller.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../home/data/home_models.dart';
import '../../home/domain/home_controller.dart';
import '../data/cart_models.dart';
import '../domain/cart_controller.dart';
import '../domain/main_cart_overview_provider.dart';

class MainCartScreen extends ConsumerWidget {
  const MainCartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeControllerProvider).value;
    final overview = ref.watch(mainCartOverviewProvider);
    final stores = _orderedStores(home, l10n);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l10n.cartTitle.toUpperCase()),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(ref),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: const PageStorageKey('main-cart'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.xxxl,
              ),
              children: [
                Text(
                  l10n.cartMainSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (var index = 0; index < stores.length; index++) ...[
                  StoreCartSection(
                    key: ValueKey(
                      'main-cart-section-${stores[index].type.wire}',
                    ),
                    storeType: stores[index].type,
                    label: stores[index].label,
                    number: index + 1,
                    compactWhenEmpty: true,
                  ),
                  if (index != stores.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
                if (overview.isSettled && !overview.hasAnyItem)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxl),
                    child: Text(
                      l10n.cartEmptyHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    await Future.wait([
      ref.read(homeControllerProvider.notifier).refresh(),
      for (final type in StoreType.values)
        ref.read(cartControllerProvider(type).notifier).refresh(),
    ]);
  }
}

class CartScreen extends ConsumerWidget {
  const CartScreen({required this.storeType, super.key});

  final StoreType storeType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stores = _orderedStores(
      ref.watch(homeControllerProvider).value,
      l10n,
    );
    final descriptor = stores.firstWhere(
      (store) => store.type == storeType,
      orElse: () => _CartStore(storeType, _fallbackStoreLabel(l10n, storeType)),
    );
    final number = stores.indexWhere((store) => store.type == storeType) + 1;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartTitle.toUpperCase())),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(cartControllerProvider(storeType).notifier).refresh(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: PageStorageKey('cart-${storeType.wire}'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.xxxl,
              ),
              children: [
                StoreCartSection(
                  storeType: storeType,
                  label: descriptor.label,
                  number: number <= 0 ? null : number,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Global savat va store-scoped savat bir xil ko'rinish/behavior ishlatadi.
class StoreCartSection extends ConsumerWidget {
  const StoreCartSection({
    required this.storeType,
    required this.label,
    this.number,
    this.compactWhenEmpty = false,
    super.key,
  });

  final StoreType storeType;
  final String label;
  final int? number;
  final bool compactWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = cartControllerProvider(storeType);
    final cartAsync = ref.watch(provider);
    ref.listen<AsyncValue<CartState>>(provider, (previous, next) {
      final failure = next.value?.mutationFailure;
      if (failure == null || failure == previous?.value?.mutationFailure) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.localize(l10n))));
    });

    return switch (cartAsync) {
      AsyncData(:final value) when value.cart.items.isEmpty => _EmptyStoreCart(
        label: label,
        number: number,
        compact: compactWhenEmpty,
        onTap: () => goToStoreTab(context, storeType, StoreTab.catalog),
      ),
      AsyncData(:final value) => _FilledStoreCart(
        storeType: storeType,
        label: label,
        number: number,
        state: value,
        onClear: value.busyKeys.isNotEmpty
            ? null
            : () => _confirmClear(context, ref, storeType),
        onCheckout: value.busyKeys.isNotEmpty
            ? null
            : () => pushAuthenticated(
                context,
                ref,
                Routes.checkout(storeType.wire),
              ),
      ),
      AsyncError(:final error) => _CartError(
        label: label,
        number: number,
        message: error is ApiFailure ? error.localize(l10n) : l10n.errorUnknown,
        onRetry: () => ref.read(provider.notifier).refresh(),
      ),
      _ => _CartLoading(label: label, number: number),
    };
  }
}

class _FilledStoreCart extends StatelessWidget {
  const _FilledStoreCart({
    required this.storeType,
    required this.label,
    required this.state,
    required this.onCheckout,
    required this.onClear,
    this.number,
  });

  final StoreType storeType;
  final String label;
  final int? number;
  final CartState state;
  final VoidCallback? onCheckout;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StoreCartHeader(
            label: label,
            number: number,
            trailing: IconButton(
              tooltip: l10n.cartClear,
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: const Icon(Icons.delete_sweep_outlined, size: 19),
            ),
          ),
          for (var index = 0; index < state.cart.items.length; index++) ...[
            if (index > 0) Divider(height: 1, color: colors.outlineVariant),
            _CartItemRow(item: state.cart.items[index], storeType: storeType),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.cartTotal,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      Text(
                        Uzs.format(state.cart.subtotal),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: ValueKey('cart-checkout-${storeType.wire}'),
                    onPressed: onCheckout,
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(l10n.cartCheckout.toUpperCase()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    final state = ref.watch(cartControllerProvider(storeType)).value;
    final busy = state?.busyKeys.isNotEmpty ?? false;
    final controller = ref.read(cartControllerProvider(storeType).notifier);
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          InkWell(
            onTap: () => openStoreProduct(context, storeType, item.product.id),
            child: SizedBox.square(
              dimension: 54,
              child: ProductImageView(imageUrl: item.product.imageUrl),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: () =>
                  openStoreProduct(context, storeType, item.product.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (configuration.isNotEmpty)
                    Text(
                      configuration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    Uzs.format(item.product.price),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CartQuantityStepper(
            quantity: item.quantity,
            busy: busy,
            onDecrement: () => controller.decrement(item),
            onIncrement: () => controller.increment(item),
            semanticLabel: l10n.cartItemsCount(item.quantity),
          ),
        ],
      ),
    );
  }
}

class CartQuantityStepper extends StatelessWidget {
  const CartQuantityStepper({
    required this.quantity,
    required this.busy,
    required this.onDecrement,
    required this.onIncrement,
    required this.semanticLabel,
    super.key,
  });

  final int quantity;
  final bool busy;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: Container(
        // 40 dp: +/- tugmalari minimal tap target'ga yetsin.
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(
              icon: Icons.remove,
              onPressed: busy ? null : onDecrement,
            ),
            SizedBox(
              width: 32,
              child: Center(
                child: busy
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '$quantity',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            _StepperButton(
              icon: Icons.add,
              onPressed: busy ? null : onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
  );
}

class _EmptyStoreCart extends StatelessWidget {
  const _EmptyStoreCart({
    required this.label,
    required this.number,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final int? number;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('empty-store-cart-$label'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: compact ? AppSpacing.sm : AppSpacing.xl,
          ),
          child: Row(
            children: [
              _StoreNumber(number: number),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$label — ${l10n.cartEmptyStore}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreCartHeader extends StatelessWidget {
  const _StoreCartHeader({
    required this.label,
    required this.number,
    this.trailing,
  });

  final String label;
  final int? number;
  final Widget? trailing;

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
            ?trailing,
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

class _CartLoading extends StatelessWidget {
  const _CartLoading({required this.label, required this.number});

  final String label;
  final int? number;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        _StoreCartHeader(label: label, number: number),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LinearProgressIndicator(),
        ),
      ],
    ),
  );
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
