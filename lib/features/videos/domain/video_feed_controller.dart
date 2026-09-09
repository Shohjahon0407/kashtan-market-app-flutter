import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../data/video_api.dart';
import '../data/video_models.dart';

final videoApiProvider = Provider<VideoApi>(
  (ref) => VideoApi(ref.watch(apiClientProvider)),
);

final videoProductRailProvider = FutureProvider.autoDispose
    .family<VideoProductRail, String>((ref, videoId) {
      // keepAlive YO'Q: rail faqat ko'rinish oynasidagi (±2 reel) widget'lar
      // kuzatib turganda tirik — ilgari abadiy keepAlive edi (60 reel = 60
      // javob xotirada). Oynadan chiqib qaytilsa qayta so'raladi.
      ref.watch(apiLangProvider);
      return ref.watch(videoApiProvider).fetchProducts(videoId);
    });

class VideoFeedState {
  const VideoFeedState({
    required this.items,
    this.nextUrl,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<StoreVideo> items;
  final String? nextUrl;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  VideoFeedState copyWith({
    List<StoreVideo>? items,
    String? nextUrl,
    bool clearNextUrl = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) => VideoFeedState(
    items: items ?? this.items,
    nextUrl: clearNextUrl ? null : (nextUrl ?? this.nextUrl),
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );
}

final videoFeedControllerProvider =
    AsyncNotifierProvider<VideoFeedController, VideoFeedState>(
      VideoFeedController.new,
    );

class VideoFeedController extends AsyncNotifier<VideoFeedState> {
  final Set<String> _likeMutations = <String>{};

  @override
  Future<VideoFeedState> build() async {
    listenForConnectionRecovery(ref, () async {
      // Retain loaded reels, pagination and the active player position.
      if (state.hasError && !state.hasValue) await refresh();
    });
    ref.watch(apiLangProvider);
    final page = await ref.watch(videoApiProvider).fetchFeed();
    return VideoFeedState(items: page.items, nextUrl: page.nextUrl);
  }

  Future<void> refresh() async {
    final previous = state.value;
    try {
      final page = await ref.read(videoApiProvider).fetchFeed();
      state = AsyncData(
        VideoFeedState(items: page.items, nextUrl: page.nextUrl),
      );
    } on Object catch (error, stack) {
      state = previous == null ? AsyncError(error, stack) : AsyncData(previous);
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref
          .read(videoApiProvider)
          .fetchFeed(nextUrl: current.nextUrl);
      final known = current.items.map((item) => item.id).toSet();
      state = AsyncData(
        VideoFeedState(
          items: [
            ...current.items,
            ...page.items.where((item) => known.add(item.id)),
          ],
          nextUrl: page.nextUrl,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }

  Future<void> toggleLike(String videoId) async {
    final video = state.value?.items
        .where((item) => item.id == videoId)
        .firstOrNull;
    if (video == null) return;
    await _setLike(videoId, !video.isLiked);
  }

  Future<void> like(String videoId) async {
    final video = state.value?.items
        .where((item) => item.id == videoId)
        .firstOrNull;
    if (video == null || video.isLiked) return;
    await _setLike(videoId, true);
  }

  Future<void> _setLike(String videoId, bool targetLiked) async {
    final current = state.value;
    if (current == null || !_likeMutations.add(videoId)) return;
    final index = current.items.indexWhere((video) => video.id == videoId);
    if (index < 0) {
      _likeMutations.remove(videoId);
      return;
    }
    final previous = current.items[index];
    _replace(
      videoId,
      previous.copyWith(
        isLiked: targetLiked,
        likesCount: _nonNegative(previous.likesCount + (targetLiked ? 1 : -1)),
      ),
    );
    try {
      final result = await ref
          .read(videoApiProvider)
          .setLike(videoId, targetLiked);
      final latest = state.value?.items
          .where((item) => item.id == videoId)
          .firstOrNull;
      if (latest != null) {
        _replace(
          videoId,
          latest.copyWith(isLiked: result.isLiked, likesCount: result.count),
        );
      }
    } on Object {
      _replace(videoId, previous);
      rethrow;
    } finally {
      _likeMutations.remove(videoId);
    }
  }

  void changeCommentCount(String videoId, int delta) {
    final current = state.value;
    if (current == null) return;
    final item = current.items
        .where((video) => video.id == videoId)
        .firstOrNull;
    if (item == null) return;
    _replace(
      videoId,
      item.copyWith(commentsCount: _nonNegative(item.commentsCount + delta)),
    );
  }

  void _replace(String id, StoreVideo replacement) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            if (item.id == id) replacement else item,
        ],
      ),
    );
  }
}

int _nonNegative(int value) => value < 0 ? 0 : value;

final videoSoundProvider = NotifierProvider<VideoSoundController, bool>(
  VideoSoundController.new,
);

class VideoSoundController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
