import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/paginated.dart';
import '../../catalog/data/product_models.dart';
import '../../recommendations/domain/interaction_tracker.dart';

final searchControllerProvider =
    NotifierProvider.autoDispose<ProductSearchController, SearchState>(
      ProductSearchController.new,
    );

class SearchState {
  const SearchState({
    this.query = '',
    this.items = const [],
    this.nextUrl,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.failure,
    this.searched = false,
  });

  final String query;
  final List<ProductSummary> items;

  /// Cursor sahifalashning absolut `next` URL'i.
  final String? nextUrl;
  final bool isLoading;
  final bool isLoadingMore;
  final ApiFailure? failure;

  /// Kamida bitta so'rov yakunlanganmi (bo'sh natijani "yozishni boshlang"
  /// holatidan ajratish uchun).
  final bool searched;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  SearchState copyWith({
    String? query,
    List<ProductSummary>? items,
    String? Function()? nextUrl,
    bool? isLoading,
    bool? isLoadingMore,
    ApiFailure? Function()? failure,
    bool? searched,
  }) => SearchState(
    query: query ?? this.query,
    items: items ?? this.items,
    nextUrl: nextUrl != null ? nextUrl() : this.nextUrl,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    failure: failure != null ? failure() : this.failure,
    searched: searched ?? this.searched,
  );
}

/// Mahsulot qidiruvi.
///
/// Debounce EKRANDA (UI hodisasi), bekor qilish esa BU YERDA: yangi so'rov
/// kelganda oldingi `CancelToken` bekor qilinadi — sekin javob kelib qolib
/// yangi natijani bosib ketmaydi. Kirill matnni interceptor o'zi lotinga
/// o'giradi.
class ProductSearchController extends Notifier<SearchState> {
  CancelToken? _inFlight;

  @override
  SearchState build() {
    listenForConnectionRecovery(ref, () async {
      if (state.query.isNotEmpty && !state.isLoading) await search(state.query);
    });
    ref.onDispose(() => _inFlight?.cancel());
    ref.listen<String>(apiLangProvider, (previous, next) {
      if (previous != null && previous != next && state.query.isNotEmpty) {
        unawaited(search(state.query));
      }
    });
    return const SearchState();
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    _inFlight?.cancel();

    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }

    final token = CancelToken();
    _inFlight = token;
    state = state.copyWith(
      query: trimmed,
      isLoading: true,
      failure: () => null,
    );

    try {
      final data = await ref
          .read(apiClientProvider)
          .get(
            Api.productSearch,
            query: {'q': trimmed, 'page_size': 20},
            cancelToken: token,
          );
      final page = PageDecoder.cursor<ProductSummary>(
        data,
        ProductSummary.fromJson,
      );
      // Javob kelguncha so'rov almashgan bo'lsa natijani tashlaymiz.
      if (state.query != trimmed) return;
      state = state.copyWith(
        items: page.items,
        nextUrl: () => page.nextUrl,
        isLoading: false,
        searched: true,
      );
      ref.read(interactionTrackerProvider).recordSearch(trimmed);
    } on CancelledFailure {
      // Yangi so'rov eskisini bekor qildi — hech narsa qilmaymiz.
    } on ApiFailure catch (failure) {
      if (state.query != trimmed) return;
      state = state.copyWith(
        isLoading: false,
        searched: true,
        failure: () => failure,
      );
    }
  }

  Future<void> loadMore() async {
    final next = state.nextUrl;
    if (next == null || state.isLoadingMore || state.isLoading) return;

    // Yangi qidiruv yoki dispose sahifalashni ham bekor qiladi — ekran
    // yopilgach javob kelib `state` ga tegmaydi.
    final token = CancelToken();
    _inFlight = token;
    state = state.copyWith(isLoadingMore: true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .getUrl(next, cancelToken: token);
      if (!ref.mounted) return;
      final page = PageDecoder.cursor<ProductSummary>(
        data,
        ProductSummary.fromJson,
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextUrl: () => page.nextUrl,
        isLoadingMore: false,
      );
    } on CancelledFailure {
      if (!ref.mounted) return;
      state = state.copyWith(isLoadingMore: false);
    } on ApiFailure {
      if (!ref.mounted) return;
      // Keyingi sahifa xatosi jim yutilmaydi ham, ro'yxatni buzmaydi ham —
      // scroll qayta urinish imkonini beradi.
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
