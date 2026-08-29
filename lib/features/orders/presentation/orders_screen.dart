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
import '../../catalog/presentation/widgets/product_image.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/order_models.dart';
import '../domain/orders_controller.dart';
import 'widgets/order_status_badge.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({required this.storeType, super.key});

  final StoreType storeType;

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

  final StoreType storeType;
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

  void _loadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
      ref.read(ordersControllerProvider(_query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final orders = ref.watch(ordersControllerProvider(_query));
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(ordersControllerProvider(_query).notifier).refresh(),
      child: switch (orders) {
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
            'orders-${widget.storeType.wire}-${widget.period.wire}',
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
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
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
            final order = value.items[index];
            return OrderSummaryCard(
              order: order,
              onTap: () => context.push(
                Routes.orderDetail(widget.storeType.wire, order.id),
              ),
            );
          },
        ),
        AsyncError(:final error) => StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () =>
              ref.read(ordersControllerProvider(_query).notifier).refresh(),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

@visibleForTesting
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({required this.order, required this.onTap, super.key});

  final OrderData order;
  final VoidCallback onTap;

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
