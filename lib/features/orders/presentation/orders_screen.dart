import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/data/product_models.dart';
import '../../catalog/presentation/widgets/catalog_loading_skeleton.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../home/data/home_models.dart';
import '../../home/domain/home_controller.dart';
import '../../recommendations/domain/recommendations_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/order_models.dart';
import '../domain/orders_controller.dart';
import 'widgets/order_status_badge.dart';

/// [storeType] `null` — barcha do'konlardan buyurtmalar (Home'dagi
/// Buyurtmalar tabi); har kartada do'kon nomi ko'rsatiladi.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({this.storeType, super.key});

  final StoreType? storeType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: OrdersPeriod.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.ordersTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.ordersToday),
              Tab(text: l10n.ordersHistory),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersPeriodView(storeType: storeType, period: OrdersPeriod.today),
            _OrdersPeriodView(
              storeType: storeType,
              period: OrdersPeriod.history,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersPeriodView extends ConsumerStatefulWidget {
  const _OrdersPeriodView({required this.storeType, required this.period});

  final StoreType? storeType;
  final OrdersPeriod period;

  @override
  ConsumerState<_OrdersPeriodView> createState() => _OrdersPeriodViewState();
}

class _OrdersPeriodViewState extends ConsumerState<_OrdersPeriodView>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  OrdersQuery get _query =>
      (storeType: widget.storeType, period: widget.period);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_loadMore)
      ..dispose();
    super.dispose();
  }

  /// Home'dagi (barcha do'kon) Buyurtmalar tabi: ro'yxat ostida tavsiya
  /// kartalari — ekran bo'sh turmaydi.
  bool get _showsRecommendations => widget.storeType == null;

  void _loadMore() {
    if (!_scroll.hasClients || _scroll.position.extentAfter >= 400) return;
    final orders = ref.read(ordersControllerProvider(_query)).value;
    if (orders != null && orders.hasMore) {
      ref.read(ordersControllerProvider(_query).notifier).loadMore();
      return;
    }
    // Buyurtmalar tugadi — pastdagi tavsiyalar davom etadi.
    if (_showsRecommendations) {
      unawaited(ref.read(forYouControllerProvider.notifier).loadMore());
    }
  }

  Widget _orderCard(
    BuildContext context,
    OrderData order,
    Map<String, String> storeLabels,
  ) => OrderSummaryCard(
    order: order,
    storeLabel: widget.storeType == null
        ? (storeLabels[order.storeTypeWire] ??
              StoreType.fromWire(order.storeTypeWire)?.wire ??
              order.storeTypeWire)
        : null,
    onTap: () => context.push(
      Routes.orderDetail(
        widget.storeType?.wire ?? order.storeTypeWire,
        order.id,
      ),
    ),
  );

  /// Buyurtmalar + "Sizga yoqishi mumkin" (avval shaxsiy tavsiyalar, keyin
  /// mashhurlar — server tartibi) bitta scroll'da.
  Widget _ordersWithRecommendations(
    BuildContext context,
    OrdersState value,
    Map<String, String> storeLabels,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final feed = ref.watch(forYouControllerProvider).value;
    final products = [
      for (final product in feed?.items ?? const <ProductSummary>[])
        if (product.storeType != null) product,
    ];
    return CustomScrollView(
      key: PageStorageKey('orders-all-${widget.period.wire}'),
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (value.items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              key: const ValueKey('orders-empty-compact'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xxl,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  Icon(
                    widget.period == OrdersPeriod.today
                        ? Icons.receipt_long_outlined
                        : Icons.history_rounded,
                    size: 44,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.period == OrdersPeriod.today
                        ? l10n.ordersTodayEmpty
                        : l10n.ordersHistoryEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.screenH,
              AppSpacing.screenH,
              0,
            ),
            sliver: SliverList.separated(
              itemCount:
                  value.items.length +
                  (value.isLoadingMore || value.loadMoreFailure != null
                      ? 1
                      : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                if (index >= value.items.length) {
                  return value.isLoadingMore
                      ? const _OrderLoadingPlaceholder()
                      : Center(
                          child: TextButton(
                            onPressed: () => ref
                                .read(ordersControllerProvider(_query).notifier)
                                .loadMore(),
                            child: Text(l10n.ordersLoadMore),
                          ),
                        );
                }
                return _orderCard(context, value.items[index], storeLabels);
              },
            ),
          ),
        if (products.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              key: const ValueKey('orders-recommended-header'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xxl,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ordersRecommendedTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.homeForYouSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => KeyedSubtree(
                  key: ValueKey('orders-recommended-${products[index].id}'),
                  child: ProductCard(
                    product: products[index],
                    storeType: products[index].storeType!,
                    catalogStyle: true,
                  ),
                ),
                childCount: products.length,
              ),
            ),
          ),
          if (feed?.isLoadingMore ?? false)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final orders = ref.watch(ordersControllerProvider(_query));
    // Barcha-do'kon ro'yxatida kartaga do'kon nomi (hub label) qo'shiladi.
    final storeLabels = widget.storeType == null
        ? {
            for (final item
                in ref.watch(homeControllerProvider).value?.storeHub ??
                    const <StoreHubItem>[])
              item.storeTypeWire: item.label,
          }
        : const <String, String>{};
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(ordersControllerProvider(_query).notifier).refresh(),
          if (_showsRecommendations)
            ref.read(forYouControllerProvider.notifier).refresh(),
        ]);
      },
      child: switch (orders) {
        AsyncData(:final value) when _showsRecommendations =>
          _ordersWithRecommendations(context, value, storeLabels),
        AsyncData(:final value) when value.items.isEmpty => StoreEmptyView(
          icon: widget.period == OrdersPeriod.today
              ? Icons.receipt_long_outlined
              : Icons.history_rounded,
          title: widget.period == OrdersPeriod.today
              ? l10n.ordersTodayEmpty
              : l10n.ordersHistoryEmpty,
        ),
        AsyncData(:final value) => ListView.separated(
          key: PageStorageKey(
            'orders-${widget.storeType?.wire ?? 'all'}-${widget.period.wire}',
          ),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenH),
          itemCount:
              value.items.length +
              (value.isLoadingMore || value.loadMoreFailure != null ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (index >= value.items.length) {
              if (value.isLoadingMore) {
                return const _OrderLoadingPlaceholder();
              }
              return Center(
                child: TextButton(
                  onPressed: () => ref
                      .read(ordersControllerProvider(_query).notifier)
                      .loadMore(),
                  child: Text(l10n.ordersLoadMore),
                ),
              );
            }
            return _orderCard(context, value.items[index], storeLabels);
          },
        ),
        AsyncError(:final error) => StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () =>
              ref.read(ordersControllerProvider(_query).notifier).refresh(),
        ),
        _ => const CatalogRowsSkeleton(itemCount: 4),
      },
    );
  }
}

class _OrderLoadingPlaceholder extends StatelessWidget {
  const _OrderLoadingPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: const SizedBox(height: 88),
  );
}

@visibleForTesting
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    required this.order,
    required this.onTap,
    this.storeLabel,
    super.key,
  });

  final OrderData order;
  final VoidCallback onTap;

  /// Barcha-do'kon ro'yxatida do'kon nomi; bitta do'kon ekranida `null`.
  final String? storeLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final firstItem = order.items.firstOrNull;
    final remaining = order.items.length > 1 ? order.items.length - 1 : 0;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      width: 76,
                      height: 84,
                      child: ProductImageView(
                        imageUrl: firstItem?.imageUrl,
                        iconSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (storeLabel case final label?) ...[
                          Text(
                            label.toUpperCase(),
                            key: ValueKey('order-store-label-${order.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(
                          firstItem == null
                              ? l10n.orderItems
                              : '${firstItem.productName} × ${firstItem.quantity}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (remaining > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.ordersMoreProducts(remaining),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _formatDate(order.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OrderStatusBadge(stage: order.customerStage),
                        if (order.isDelayedDelivery) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            order.deliveryOption == 'one_day'
                                ? AppLocalizations.of(
                                    context,
                                  ).orderDeliveryWithinOneDay
                                : AppLocalizations.of(
                                    context,
                                  ).orderDeliveryWithinTwoDays,
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    Uzs.format(order.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  return date == null ? raw : DateFormat('dd.MM.yyyy HH:mm').format(date);
}
