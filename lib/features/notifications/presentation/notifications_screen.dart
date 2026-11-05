import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../orders/domain/orders_controller.dart';
import '../data/notification_models.dart';
import '../domain/notifications_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 280) {
      return;
    }
    unawaited(ref.read(notificationsControllerProvider.notifier).loadMore());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifications = ref.watch(notificationsControllerProvider);
    final unread = ref.watch(notificationUnreadCountProvider).value ?? 0;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.notificationsTitle),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: () => _markAllRead(context),
              icon: const Icon(Icons.done_all, size: 18),
              label: Text(l10n.notificationsReadAll),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: switch (notifications) {
        AsyncData(:final value) when value.items.isEmpty => _NotificationsEmpty(
          onRefresh: _refresh,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              AppSpacing.xxxl,
            ),
            itemCount: value.items.length + (value.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == value.items.length) {
                return _LoadMoreTile(
                  isLoading: value.isLoadingMore,
                  failure: value.loadMoreFailure,
                  onRetry: () => ref
                      .read(notificationsControllerProvider.notifier)
                      .loadMore(),
                );
              }
              final item = value.items[index];
              return _NotificationTile(
                notification: item,
                onTap: () => _openNotification(item),
              );
            },
          ),
        ),
        AsyncError(:final error) => _NotificationsError(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: _refresh,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _refresh() =>
      ref.read(notificationsControllerProvider.notifier).refresh();

  Future<void> _markAllRead(BuildContext context) async {
    try {
      await ref.read(notificationsControllerProvider.notifier).markAllRead();
    } on Object catch (error) {
      if (!context.mounted) return;
      _showFailure(context, error);
    }
  }

  Future<void> _openNotification(CustomerNotification item) async {
    if (!item.isRead) {
      try {
        await ref
            .read(notificationsControllerProvider.notifier)
            .markRead(item.id);
      } on Object catch (error) {
        if (mounted) _showFailure(context, error);
      }
    }
    if (!mounted || !item.hasRelatedOrder) return;
    var storeType = StoreType.fromWire(item.storeTypeWire ?? '');
    if (storeType == null) {
      try {
        final order = await ref
            .read(ordersApiProvider)
            .detail(item.relatedOrderId!);
        storeType = StoreType.fromWire(order.storeTypeWire);
      } on Object catch (error) {
        if (mounted) _showFailure(context, error);
        return;
      }
    }
    if (!mounted || storeType == null) return;
    unawaited(
      context.push(Routes.orderDetail(storeType.wire, item.relatedOrderId!)),
    );
  }

  void _showFailure(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);
    final message = error is ApiFailure
        ? error.localize(l10n)
        : l10n.errorUnknown;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final CustomerNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final createdAt = notification.createdAt?.toLocal();
    return Material(
      color: notification.isRead
          ? colors.surface
          : colors.primaryContainer.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: _iconColor(colors).withValues(alpha: 0.14),
                foregroundColor: _iconColor(colors),
                child: Icon(_icon),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        DateFormat('dd.MM.yyyy  HH:mm').format(createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (notification.hasRelatedOrder) ...[
                const SizedBox(width: AppSpacing.xs),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (notification.eventKey) {
    'order_pending_review' ||
    'order_reviewing' ||
    'order_searching' ||
    'order_searching_again' => Icons.radar,
    'order_accepted' ||
    'order_courier_accepted' ||
    'order_delivery_scheduled' => Icons.check_circle_outline,
    'order_on_way' ||
    'order_out_for_delivery' => Icons.delivery_dining_outlined,
    'order_delivered' || 'order_completed' => Icons.task_alt,
    'order_cancelled' => Icons.cancel_outlined,
    _ =>
      notification.type == 'order' || notification.type == 'order_update'
          ? Icons.receipt_long_outlined
          : Icons.notifications_outlined,
  };

  Color _iconColor(ColorScheme colors) => switch (notification.eventKey) {
    'order_cancelled' => colors.error,
    'order_accepted' ||
    'order_courier_accepted' ||
    'order_delivery_scheduled' ||
    'order_on_way' ||
    'order_out_for_delivery' ||
    'order_delivered' ||
    'order_completed' => colors.primary,
    _ => colors.secondary,
  };
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Icon(
          Icons.notifications_none,
          size: 64,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(child: Text(AppLocalizations.of(context).notificationsEmpty)),
      ],
    ),
  );
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).commonRetry),
          ),
        ],
      ),
    ),
  );
}

class _LoadMoreTile extends StatelessWidget {
  const _LoadMoreTile({
    required this.isLoading,
    required this.failure,
    required this.onRetry,
  });

  final bool isLoading;
  final ApiFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failure != null) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(failure!.localize(AppLocalizations.of(context))),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
