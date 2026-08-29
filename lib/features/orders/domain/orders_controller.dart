import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../../core/store_scope/store_type.dart';
import '../data/order_models.dart';
import '../data/orders_api.dart';
import 'order_realtime_controller.dart';

final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
  ),
);

class OrdersState {
  const OrdersState({
    required this.items,
    required this.count,
    this.nextUrl,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<OrderData> items;
  final int count;
  final String? nextUrl;
  final bool isLoadingMore;
  final ApiFailure? loadMoreFailure;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  OrdersState copyWith({
    List<OrderData>? items,
    int? count,
    String? Function()? nextUrl,
    bool? isLoadingMore,
    ApiFailure? Function()? loadMoreFailure,
  }) => OrdersState(
    items: items ?? this.items,
    count: count ?? this.count,
    nextUrl: nextUrl == null ? this.nextUrl : nextUrl(),
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure == null
        ? this.loadMoreFailure
        : loadMoreFailure(),
  );
}

enum OrdersPeriod {
  today('today'),
  history('history');

  const OrdersPeriod(this.wire);

  final String wire;
}

typedef OrdersQuery = ({StoreType storeType, OrdersPeriod period});

Iterable<OrdersQuery> orderQueriesForStore(StoreType storeType) =>
    OrdersPeriod.values.map((period) => (storeType: storeType, period: period));

final ordersControllerProvider = AsyncNotifierProvider.autoDispose
    .family<OrdersController, OrdersState, OrdersQuery>(OrdersController.new);

class OrdersController extends AsyncNotifier<OrdersState> {
  OrdersController(this.query);

  final OrdersQuery query;
  Timer? _midnightTimer;
  int _requestRevision = 0;

  @override
  Future<OrdersState> build() async {
    _requestRevision++;
    ref.watch(apiLangProvider);
    ref.onDispose(() => _midnightTimer?.cancel());
    _scheduleTashkentMidnightRefresh();
    final api = ref.watch(ordersApiProvider);
    try {
      final page = await api.fetch(
        storeType: query.storeType.wire,
        period: query.period.wire,
      );
      return OrdersState(
        items: page.items,
        count: page.count,
        nextUrl: page.nextUrl,
      );
    } on ApiFailure {
      // Oflayn: oxirgi ko'rilgan buyurtmalar ro'yxati diskdan.
      final cached = await api.cachedOrders(
        storeType: query.storeType.wire,
        period: query.period.wire,
      );
      if (cached == null) rethrow;
      return OrdersState(items: cached.items, count: cached.count);
    }
  }

  Future<void> refresh() async {
    final revision = ++_requestRevision;
    final previous = state.value;
    state = const AsyncLoading();
    try {
      final page = await ref
          .read(ordersApiProvider)
          .fetch(storeType: query.storeType.wire, period: query.period.wire);
      if (!ref.mounted || revision != _requestRevision) return;
      state = AsyncData(
        OrdersState(
          items: page.items,
          count: page.count,
          nextUrl: page.nextUrl,
        ),
      );
    } on Object catch (error, stack) {
      if (!ref.mounted || revision != _requestRevision) return;
      state = previous == null
          ? AsyncError(error, stack)
          : AsyncData(previous.copyWith(isLoadingMore: false));
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final revision = _requestRevision;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: () => null),
    );
    try {
      final page = await ref
          .read(ordersApiProvider)
          .fetch(
            storeType: query.storeType.wire,
            period: query.period.wire,
            nextUrl: current.nextUrl,
          );
      if (!ref.mounted || revision != _requestRevision) return;
      final latest = state.value;
      if (latest == null || latest.nextUrl != current.nextUrl) return;
      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, ...page.items],
          count: page.count,
          nextUrl: () => page.nextUrl,
          isLoadingMore: false,
        ),
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || revision != _requestRevision) return;
      final latest = state.value;
      if (latest == null || latest.nextUrl != current.nextUrl) return;
      state = AsyncData(
        latest.copyWith(isLoadingMore: false, loadMoreFailure: () => failure),
      );
    }
  }

  void _scheduleTashkentMidnightRefresh() {
    _midnightTimer?.cancel();
    final tashkentNow = DateTime.now().toUtc().add(const Duration(hours: 5));
    final nextMidnight = DateTime.utc(
      tashkentNow.year,
      tashkentNow.month,
      tashkentNow.day + 1,
    );
    final delay =
        nextMidnight.difference(tashkentNow) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay, ref.invalidateSelf);
  }
}

final orderDetailProvider = FutureProvider.autoDispose
    .family<OrderData, String>((ref, id) {
      ref.watch(apiLangProvider);
      return ref.watch(ordersApiProvider).detail(id);
    });

/// Ochiq order detail uchun REST reconciliation.
///
/// WebSocket tezkor signal beradi, lekin ushbu controller socket eventini
/// source of truth deb qabul qilmaydi. Har eventdan keyin va holatga mos
/// intervalda tracking endpoint qayta olinadi.
final orderTrackingControllerProvider = AsyncNotifierProvider.autoDispose
    .family<OrderTrackingController, OrderTrackingData, String>(
      OrderTrackingController.new,
    );

class OrderTrackingController extends AsyncNotifier<OrderTrackingData> {
  OrderTrackingController(this.orderId);

  final String orderId;
  Timer? _timer;
  bool _fetching = false;

  @override
  Future<OrderTrackingData> build() async {
    ref.watch(apiLangProvider);
    ref.watch(
      orderRealtimeProvider.select(
        (value) => value.lastOrderId == orderId ? value.revision : 0,
      ),
    );
    ref.onDispose(() => _timer?.cancel());
    try {
      final tracking = await ref.watch(ordersApiProvider).tracking(orderId);
      _schedule(tracking.refreshInterval);
      return tracking;
    } on Object {
      _schedule(const Duration(seconds: 10));
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final tracking = await ref.read(ordersApiProvider).tracking(orderId);
      state = AsyncData(tracking);
      _schedule(tracking.refreshInterval);
    } on Object catch (error, stack) {
      if (!state.hasValue) state = AsyncError(error, stack);
      _schedule(const Duration(seconds: 10));
    } finally {
      _fetching = false;
    }
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, refresh);
  }
}
