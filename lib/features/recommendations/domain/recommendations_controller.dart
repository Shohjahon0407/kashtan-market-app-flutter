import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../auth/domain/auth_controller.dart';
import '../../catalog/data/product_models.dart';
import 'interaction_tracker.dart';

/// Home "Siz uchun" lentasi holati.
class ForYouFeed {
  const ForYouFeed({
    this.items = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<ProductSummary> items;
  final bool hasMore;
  final bool isLoadingMore;

  ForYouFeed copyWith({
    List<ProductSummary>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) => ForYouFeed(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// Home "Siz uchun" — barcha do'konlardan shaxsiy tavsiyalar, yon tomonga
/// cheksiz scroll ([loadMore]).
///
/// Hech qachon xato holatiga tushmaydi (bo'sh ro'yxat — bo'lim chizilmaydi):
/// tavsiya qo'shimcha, asosiy ekranni buzmasligi kerak. Foydalanuvchi
/// [refreshEveryActivity] ta yangi mahsulot ko'rgach jim yangilanadi.
final forYouControllerProvider =
    AsyncNotifierProvider<ForYouController, ForYouFeed>(ForYouController.new);

class ForYouController extends AsyncNotifier<ForYouFeed> {
  static const refreshEveryActivity = 3;
  static const pageSize = 20;

  int _loadedAtActivity = 0;
  int _session = _newSession();
  int _generation = 0;
  bool _refreshing = false;

  static int _newSession() =>
      DateTime.now().microsecondsSinceEpoch % 1000000 + 1;

  @override
  Future<ForYouFeed> build() async {
    ref.watch(apiLangProvider);
    // Login/logout — boshqa identity, boshqa tavsiya.
    ref.watch(authControllerProvider.select((auth) => auth.isAuthenticated));
    ref.listen<int>(recoActivityProvider, (_, next) {
      if (next - _loadedAtActivity >= refreshEveryActivity) {
        unawaited(refresh());
      }
    });
    _loadedAtActivity = ref.read(recoActivityProvider);
    _session = _newSession();
    return await _firstPage() ?? const ForYouFeed();
  }

  Future<ForYouFeed?> _firstPage() async {
    try {
      // Yangi ko'rishlar serverga yetib borsin — keyin so'raymiz.
      await ref.read(interactionTrackerProvider).flush();
      final page = await ref
          .read(recommendationsApiProvider)
          .forYou(limit: pageSize, session: _session);
      return ForYouFeed(items: page.items, hasMore: page.hasMore);
    } on Object {
      return null;
    }
  }

  /// Yangi sessiya: so'nggi ko'rishlar hisobga olingan yangi tartib.
  Future<void> refresh() async {
    if (_refreshing || !ref.mounted) return;
    _refreshing = true;
    final generation = ++_generation;
    try {
      _loadedAtActivity = ref.read(recoActivityProvider);
      _session = _newSession();
      final feed = await _firstPage();
      if (!ref.mounted || generation != _generation || feed == null) return;
      state = AsyncData(feed);
    } finally {
      _refreshing = false;
    }
  }

  /// Keyingi bo'lak (rail oxiriga yaqinlashganda).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final generation = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(recommendationsApiProvider)
          .forYou(
            limit: pageSize,
            offset: current.items.length,
            session: _session,
          );
      if (!ref.mounted || generation != _generation) return;
      final known = current.items.map((item) => item.id).toSet();
      state = AsyncData(
        ForYouFeed(
          items: [
            ...current.items,
            ...page.items.where((item) => known.add(item.id)),
          ],
          hasMore: page.hasMore,
        ),
      );
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      // Xato — keyingi scroll'da yana urinadi.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

/// Bitta mahsulotga o'xshashlar (katalogdagi "«X»ga o'xshashlar" qatori).
final similarProductsProvider = FutureProvider.autoDispose
    .family<List<ProductSummary>, String>((ref, productId) async {
      ref.watch(apiLangProvider);
      try {
        return await ref.read(recommendationsApiProvider).similar(productId);
      } on Object {
        return const [];
      }
    });

/// Katalog sessiyasi: backend shu son bo'yicha userning qiziqish
/// snapshot'ini oladi (cursor sahifalari orasida tartib o'zgarmaydi).
/// Pull-to-refresh yangi son oladi — yangi ko'rishlar hisobga olinadi.
final catalogRecoSessionProvider =
    NotifierProvider<CatalogRecoSessionController, int>(
      CatalogRecoSessionController.new,
    );

class CatalogRecoSessionController extends Notifier<int> {
  static int _next() => DateTime.now().microsecondsSinceEpoch % 1000000 + 1;

  @override
  int build() => _next();

  void renew() {
    var next = _next();
    if (next == state) next = next % 1000000 + 1;
    state = next;
  }
}
