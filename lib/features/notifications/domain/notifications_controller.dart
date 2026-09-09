import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/account_scope.dart';
import '../../auth/domain/auth_controller.dart';
import '../data/notification_models.dart';
import '../data/notifications_api.dart';

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(privateJsonCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
  ),
);

class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.count,
    this.nextUrl,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<CustomerNotification> items;
  final int count;
  final String? nextUrl;
  final bool isLoadingMore;
  final ApiFailure? loadMoreFailure;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  NotificationsState copyWith({
    List<CustomerNotification>? items,
    int? count,
    String? Function()? nextUrl,
    bool? isLoadingMore,
    ApiFailure? Function()? loadMoreFailure,
  }) => NotificationsState(
    items: items ?? this.items,
    count: count ?? this.count,
    nextUrl: nextUrl == null ? this.nextUrl : nextUrl(),
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure == null
        ? this.loadMoreFailure
        : loadMoreFailure(),
  );
}

final notificationsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      NotificationsState
    >(NotificationsController.new);

class NotificationsController extends AsyncNotifier<NotificationsState> {
  int _generation = 0;
  @override
  Future<NotificationsState> build() async {
    _generation++;
    ref.watch(accountScopeProvider);
    ref.onDispose(() => _generation++);
    ref.watch(apiLangProvider);
    final api = ref.watch(notificationsApiProvider);
    try {
      final page = await api.fetch();
      return NotificationsState(
        items: page.items,
        count: page.count,
        nextUrl: page.nextUrl,
      );
    } on ApiFailure {
      final cached = await api.cachedNotifications();
      if (cached == null) rethrow;
      return NotificationsState(items: cached.items, count: cached.count);
    }
  }

  /// Yangilash ro'yxatni BO'SHATMAYDI (pull-to-refresh paytida eski ro'yxat
  /// qoladi); spinner faqat hali hech narsa yo'q bo'lganda.
  Future<void> refresh() async {
    final generation = _generation;
    final previous = state.value;
    if (previous == null) state = const AsyncLoading();
    try {
      final page = await ref.read(notificationsApiProvider).fetch();
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        NotificationsState(
          items: page.items,
          count: page.count,
          nextUrl: page.nextUrl,
        ),
      );
      unawaited(ref.read(notificationUnreadCountProvider.notifier).refresh());
    } on Object catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      state = previous == null ? AsyncError(error, stack) : AsyncData(previous);
    }
  }

  Future<void> loadMore() async {
    final generation = _generation;
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: () => null),
    );
    try {
      final page = await ref
          .read(notificationsApiProvider)
          .fetch(nextUrl: current.nextUrl);
      if (!ref.mounted || generation != _generation) return;
      final existing = current.items.map((item) => item.id).toSet();
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            ...page.items.where((item) => existing.add(item.id)),
          ],
          count: page.count,
          nextUrl: () => page.nextUrl,
          isLoadingMore: false,
        ),
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailure: () => failure),
      );
    }
  }

  Future<void> markRead(String id) async {
    final generation = _generation;
    final current = state.value;
    if (current == null) return;
    final index = current.items.indexWhere((item) => item.id == id);
    if (index < 0 || current.items[index].isRead) return;
    final optimistic = [...current.items];
    optimistic[index] = optimistic[index].copyWith(isRead: true);
    state = AsyncData(current.copyWith(items: optimistic));
    // Badge provider keepAlive — notifier'ni oldindan olamiz: ekran yopilib
    // bu provider dispose bo'lsa ham xatoda kompensatsiya bajarilishi shart,
    // aks holda badge serverdan doimiy bittaga kam qoladi.
    final unread = ref.read(notificationUnreadCountProvider.notifier);
    unread.decrement();
    try {
      final saved = await ref
          .read(notificationsApiProvider)
          .markRead(id, lang: ref.read(apiLangProvider));
      if (!ref.mounted || generation != _generation) return;
      // Kutish paytida yuklangan sahifalar yo'qolmasligi uchun ENG SO'NGGI
      // holat ustiga yoziladi (await'dan oldingi snapshot emas).
      final latest = state.value ?? current;
      final reconciled = [...latest.items];
      final savedIndex = reconciled.indexWhere((item) => item.id == id);
      if (savedIndex >= 0) reconciled[savedIndex] = saved;
      state = AsyncData(latest.copyWith(items: reconciled));
    } on Object {
      unread.increment();
      if (!ref.mounted || generation != _generation) rethrow;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          items: [
            for (final item in latest.items)
              if (item.id == id) item.copyWith(isRead: false) else item,
          ],
        ),
      );
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final generation = _generation;
    final current = state.value;
    if (current == null || current.items.every((item) => item.isRead)) return;
    state = AsyncData(
      current.copyWith(
        items: [for (final item in current.items) item.copyWith(isRead: true)],
      ),
    );
    final previousUnread = ref.read(notificationUnreadCountProvider).value;
    ref.read(notificationUnreadCountProvider.notifier).setCount(0);
    try {
      await ref.read(notificationsApiProvider).markAllRead();
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(current);
      if (previousUnread != null) {
        ref
            .read(notificationUnreadCountProvider.notifier)
            .setCount(previousUnread);
      } else {
        unawaited(ref.read(notificationUnreadCountProvider.notifier).refresh());
      }
      rethrow;
    }
  }
}

final notificationUnreadCountProvider =
    AsyncNotifierProvider<NotificationUnreadCountController, int>(
      NotificationUnreadCountController.new,
    );

class NotificationUnreadCountController extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    if (!ref.watch(authControllerProvider).isAuthenticated) {
      return 0;
    }
    ref.watch(apiLangProvider);
    // Account-scoped API/cache dependencies may have been invalidated by the
    // login transition. Resolve them after this widget frame's build, so their
    // refresh cannot mark the parent ProviderScope dirty during bell build.
    await Future<void>.value();
    if (!ref.mounted) return 0;
    return ref.read(notificationsApiProvider).unreadCount();
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await ref.read(notificationsApiProvider).unreadCount());
    } on Object catch (error, stack) {
      if (!state.hasValue) state = AsyncError(error, stack);
    }
  }

  void setCount(int value) => state = AsyncData(value < 0 ? 0 : value);

  void increment() => setCount((state.value ?? 0) + 1);

  void decrement() => setCount((state.value ?? 0) - 1);
}

/// Called by WebSocket/FCM integration after any persistent notification event.
void refreshCustomerNotifications(Ref ref) {
  ref.invalidate(notificationsControllerProvider);
  ref.read(notificationUnreadCountProvider.notifier).refresh();
}
