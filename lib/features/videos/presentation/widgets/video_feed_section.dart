import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/routing/auth_gate.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/video_cache.dart';
import '../../data/video_models.dart';
import '../../domain/reel_gesture_math.dart';
import '../../domain/video_feed_controller.dart';
import 'video_comments_sheet.dart';
import 'video_product_rail.dart';

class VideoFeedSection extends ConsumerStatefulWidget {
  const VideoFeedSection({
    required this.pageExtent,
    required this.reelsStartKey,
    required this.activeIndexListenable,
    super.key,
  });

  final double pageExtent;
  final Key reelsStartKey;
  final ValueListenable<int> activeIndexListenable;

  @override
  ConsumerState<VideoFeedSection> createState() => _VideoFeedSectionState();
}

class _VideoFeedSectionState extends ConsumerState<VideoFeedSection>
    with WidgetsBindingObserver, RouteAware {
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, String> _controllerUrls = {};
  final Map<int, double> _visibility = {};
  final Set<String> _playerErrors = {};
  final Set<String> _productRailIds = {};
  final Set<String> _initializingPlayers = {};
  String? _lastFeedSignature;
  int _activeIndex = -1;
  bool _modalOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.activeIndexListenable.addListener(_onSettledIndexChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onSettledIndexChanged();
    });
  }

  @override
  void didUpdateWidget(covariant VideoFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndexListenable == widget.activeIndexListenable) return;
    oldWidget.activeIndexListenable.removeListener(_onSettledIndexChanged);
    widget.activeIndexListenable.addListener(_onSettledIndexChanged);
    _onSettledIndexChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.activeIndexListenable.removeListener(_onSettledIndexChanged);
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
    _controllerUrls.clear();
    _initializingPlayers.clear();
    super.dispose();
  }

  @override
  void didPushNext() => _pauseAll();

  @override
  void didPopNext() => _playActiveIfAllowed();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pauseAll();
    if (state == AppLifecycleState.resumed) _playActiveIfAllowed();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(videoFeedControllerProvider);
    final muted = !ref.watch(videoSoundProvider);
    ref.listen<bool>(videoSoundProvider, (_, soundOn) {
      for (final controller in _controllers.values) {
        unawaited(controller.setVolume(soundOn ? 1 : 0));
      }
    });

    return switch (feed) {
      AsyncData(:final value) when value.items.isEmpty =>
        const SizedBox.shrink(),
      AsyncData(:final value) => _buildFeed(context, value, muted),
      AsyncError(:final error) => _FeedError(
        message: error is ApiFailure
            ? error.localize(AppLocalizations.of(context))
            : AppLocalizations.of(context).videoLoadError,
        onRetry: () => ref.read(videoFeedControllerProvider.notifier).refresh(),
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }

  Widget _buildFeed(BuildContext context, VideoFeedState state, bool muted) {
    final signature = state.items
        .map((video) => '${video.id}:${video.videoUrl}')
        .join('|');
    if (_lastFeedSignature != signature) {
      _lastFeedSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastFeedSignature != signature) return;
        _ensureProductRails(state.items, _activeIndex < 0 ? 0 : _activeIndex);
        unawaited(_syncWindow(state.items));
      });
    }
    final l10n = AppLocalizations.of(context);
    final productCardHeight = (widget.pageExtent * .27)
        .clamp(170.0, 220.0)
        .toDouble();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Text(
            l10n.videoFeedTitle.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(key: widget.reelsStartKey),
        for (var index = 0; index < state.items.length; index++) ...[
          SizedBox(
            key: ValueKey('home-reel-page-${state.items[index].id}'),
            height: widget.pageExtent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: VisibilityDetector(
                          key: ValueKey('home-video-${state.items[index].id}'),
                          onVisibilityChanged: (info) => _onVisibility(
                            index,
                            info.visibleFraction,
                            state.items,
                          ),
                          child: _VideoReelCard(
                            video: state.items[index],
                            controller: _controllers[state.items[index].id],
                            hasPlayerError: _playerErrors.contains(
                              state.items[index].id,
                            ),
                            muted: muted,
                            onToggleSound: () =>
                                ref.read(videoSoundProvider.notifier).toggle(),
                            onSeekFinished: _finishSeek,
                            onRetry: () =>
                                _retryPlayer(state.items[index], state.items),
                            onLike: () => _toggleLike(state.items[index].id),
                            onDoubleLike: () =>
                                _likeOnly(state.items[index].id),
                            onComments: () => _openComments(state.items[index]),
                            onStore: () => _openStore(state.items[index]),
                            onProduct: state.items[index].product == null
                                ? null
                                : () =>
                                      _openProduct(state.items[index].product!),
                          ),
                        ),
                      ),
                      if (_productRailIds.contains(state.items[index].id)) ...[
                        const SizedBox(height: AppSpacing.sm),
                        VideoProductRailSection(
                          videoId: state.items[index].id,
                          cardHeight: productCardHeight,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (state.loadMoreError != null)
          Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(videoFeedControllerProvider.notifier).loadMore(),
              child: Text(l10n.commonRetry),
            ),
          ),
      ],
    );
  }

  void _onVisibility(int index, double fraction, List<StoreVideo> items) {
    if (!mounted) return;
    _visibility[index] = fraction;
    if (index >= items.length - 2) {
      unawaited(ref.read(videoFeedControllerProvider.notifier).loadMore());
    }
    if (_activeIndex != index) return;
    if (fraction < .55) {
      _pauseAll();
    } else {
      _playActiveIfAllowed(items: items);
    }
  }

  void _onSettledIndexChanged() {
    if (!mounted) return;
    final items = ref.read(videoFeedControllerProvider).value?.items;
    final requested = widget.activeIndexListenable.value;
    if (items == null || items.isEmpty || requested < 0) {
      _activeIndex = -1;
      _pauseAll();
      return;
    }
    final next = requested.clamp(0, items.length - 1);
    _activeIndex = next;
    _pauseAll(exceptId: items[next].id);
    _ensureProductRails(items, next);
    unawaited(_syncWindow(items));
    _playActiveIfAllowed(items: items);
  }

  Future<void> _syncWindow(List<StoreVideo> items) async {
    if (!mounted || items.isEmpty) return;
    final center = _activeIndex < 0
        ? 0
        : _activeIndex.clamp(0, items.length - 1);
    // Reels hissi uchun avval AKTIV video, keyin keyingisi, oxirida oldingisi.
    // Avvalgi implementatsiya oldingi videoni birinchi initialize qilib, aktiv
    // video autoplayini sekin tarmoqda 20 soniyagacha kechiktirishi mumkin edi.
    final orderedIndexes = calculateReelPlayerWindow(
      center: center,
      itemCount: items.length,
    );
    final desired = <String>{
      for (final index in orderedIndexes) items[index].id,
    };
    final obsolete = _controllers.keys
        .where((id) => !desired.contains(id))
        .toList();
    for (final id in obsolete) {
      final controller = _controllers.remove(id);
      _controllerUrls.remove(id);
      if (controller != null) {
        await controller.pause();
        await controller.dispose();
      }
    }

    for (final index in orderedIndexes) {
      final video = items[index];
      final existing = _controllers[video.id];
      if (existing != null && _controllerUrls[video.id] != video.videoUrl) {
        _controllers.remove(video.id);
        _controllerUrls.remove(video.id);
        _playerErrors.remove(video.id);
        await existing.pause();
        await existing.dispose();
      }
      if (_controllers.containsKey(video.id) ||
          _initializingPlayers.contains(video.id) ||
          _playerErrors.contains(video.id)) {
        continue;
      }
      _initializingPlayers.add(video.id);
      VideoPlayerController? controller;
      try {
        final cachedFile = await ref
            .read(videoCacheProvider)
            .cachedFile(video.videoUrl);
        if (!mounted || !_isCurrentlyDesired(video.id)) continue;
        controller = cachedFile != null
            ? VideoPlayerController.file(cachedFile)
            : VideoPlayerController.networkUrl(Uri.parse(video.videoUrl));
        _controllers[video.id] = controller;
        _controllerUrls[video.id] = video.videoUrl;
        // Sekin tarmoqda initialize cheksiz osilib qolmasin.
        await controller.initialize().timeout(const Duration(seconds: 20));
        if (!mounted || _controllers[video.id] != controller) {
          await controller.dispose();
          continue;
        }
        // Ko'rilgan video diskda qoladi: orqaga scroll va oflaynda fayldan
        // o'ynaydi. Faqat haqiqatan initialize bo'lgan (ko'rilayotgan) video —
        // butun lenta oldindan yuklanmaydi.
        if (cachedFile == null) {
          ref.read(videoCacheProvider).storeInBackground(video.videoUrl);
        }
        await controller.setLooping(true);
        await controller.setVolume(ref.read(videoSoundProvider) ? 1 : 0);
        // Yuqoridagi ikki await paytida ham ekran yopilgan bo'lishi mumkin.
        if (!mounted || _controllers[video.id] != controller) continue;
        setState(() {});
        // Aktiv video tayyor bo'lishi bilan darhol o'ynaydi. Keyingi/oldingi
        // controllerlar tayyor bo'lishini kutmaydi.
        if (index == _activeIndex || (_activeIndex < 0 && index == 0)) {
          _playActiveIfAllowed(items: items);
        }
      } on Object {
        if (_controllers.remove(video.id) == controller) {
          _controllerUrls.remove(video.id);
          await controller?.dispose();
        }
        _playerErrors.add(video.id);
        if (mounted) setState(() {});
      } finally {
        _initializingPlayers.remove(video.id);
      }
    }
    _playActiveIfAllowed(items: items);
  }

  bool _isCurrentlyDesired(String videoId) {
    final items = ref.read(videoFeedControllerProvider).value?.items;
    if (items == null || items.isEmpty) return false;
    final center = _activeIndex < 0
        ? 0
        : _activeIndex.clamp(0, items.length - 1);
    for (var index = center - 1; index <= center + 1; index++) {
      if (index >= 0 && index < items.length && items[index].id == videoId) {
        return true;
      }
    }
    return false;
  }

  void _ensureProductRails(List<StoreVideo> items, int center) {
    var changed = false;
    for (var index = center; index <= center + 1; index++) {
      if (index >= 0 && index < items.length) {
        changed = _productRailIds.add(items[index].id) || changed;
      }
    }
    // Oynadan uzoqlashgan reel'larning rail widget'lari bo'shatiladi — aks
    // holda 60 reel scroll qilinganda 60 ta rail abadiy mounted qolardi.
    final keep = <String>{
      for (var index = center - 2; index <= center + 2; index++)
        if (index >= 0 && index < items.length) items[index].id,
    };
    final before = _productRailIds.length;
    _productRailIds.retainWhere(keep.contains);
    changed = changed || _productRailIds.length != before;
    if (changed && mounted) setState(() {});
  }

  void _playActiveIfAllowed({List<StoreVideo>? items}) {
    if (!mounted ||
        _modalOpen ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    final currentItems =
        items ?? ref.read(videoFeedControllerProvider).value?.items;
    if (currentItems == null ||
        _activeIndex < 0 ||
        _activeIndex >= currentItems.length) {
      return;
    }
    if ((_visibility[_activeIndex] ?? 0) < .55) return;
    final activeId = currentItems[_activeIndex].id;
    final controller = _controllers[activeId];
    if (controller?.value.isInitialized ?? false) unawaited(controller!.play());
  }

  void _pauseAll({String? exceptId}) {
    for (final entry in _controllers.entries) {
      if (entry.key != exceptId && entry.value.value.isPlaying) {
        unawaited(entry.value.pause());
      }
    }
  }

  Future<void> _retryPlayer(StoreVideo video, List<StoreVideo> items) async {
    _playerErrors.remove(video.id);
    final old = _controllers.remove(video.id);
    _controllerUrls.remove(video.id);
    if (old != null) await old.dispose();
    if (mounted) setState(() {});
    await _syncWindow(items);
  }

  Future<void> _toggleLike(String id) async {
    if (!await requireAuthentication(context, ref) || !mounted) return;
    try {
      await ref.read(videoFeedControllerProvider.notifier).toggleLike(id);
    } on Object catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = error is ApiFailure
          ? error.localize(l10n)
          : l10n.errorUnknown;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _likeOnly(String id) async {
    if (!await requireAuthentication(context, ref) || !mounted) return;
    try {
      await ref.read(videoFeedControllerProvider.notifier).like(id);
    } on Object catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is ApiFailure ? error.localize(l10n) : l10n.errorUnknown,
            ),
          ),
        );
    }
  }

  void _finishSeek(bool resume) {
    if (resume) _playActiveIfAllowed();
  }

  Future<void> _openComments(StoreVideo video) async {
    _modalOpen = true;
    _pauseAll();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VideoCommentsSheet(videoId: video.id),
    );
    _modalOpen = false;
    _playActiveIfAllowed();
  }

  Future<void> _openProduct(VideoProduct product) async {
    _modalOpen = true;
    _pauseAll();
    await context.push(Routes.productDetail(product.storeType, product.id));
    _modalOpen = false;
    _playActiveIfAllowed();
  }

  Future<void> _openStore(StoreVideo video) async {
    _modalOpen = true;
    _pauseAll();
    await context.push(Routes.storeCatalog(video.store.storeType));
    _modalOpen = false;
    _playActiveIfAllowed();
  }
}

class _VideoReelCard extends StatefulWidget {
  const _VideoReelCard({
    required this.video,
    required this.controller,
    required this.hasPlayerError,
    required this.muted,
    required this.onToggleSound,
    required this.onSeekFinished,
    required this.onRetry,
    required this.onLike,
    required this.onDoubleLike,
    required this.onComments,
    required this.onStore,
    required this.onProduct,
  });

  final StoreVideo video;
  final VideoPlayerController? controller;
  final bool hasPlayerError;
  final bool muted;
  final VoidCallback onToggleSound;
  final ValueChanged<bool> onSeekFinished;
  final VoidCallback onRetry;
  final VoidCallback onLike;
  final VoidCallback onDoubleLike;
  final VoidCallback onComments;
  final VoidCallback onStore;
  final VoidCallback? onProduct;

  @override
  State<_VideoReelCard> createState() => _VideoReelCardState();
}

class _VideoReelCardState extends State<_VideoReelCard> {
  Timer? _tapIndicatorTimer;
  Timer? _heartTimer;
  IconData? _tapIndicator;
  Offset? _heartPosition;
  var _heartSerial = 0;
  var _seeking = false;
  var _resumeAfterSeek = false;
  var _seekPosition = Duration.zero;
  var _seekStartPosition = Duration.zero;
  DateTime? _lastSeekAt;

  @override
  void dispose() {
    _tapIndicatorTimer?.cancel();
    _heartTimer?.cancel();
    super.dispose();
  }

  void _toggleSound() {
    widget.onToggleSound();
    _tapIndicatorTimer?.cancel();
    setState(() {
      _tapIndicator = widget.muted
          ? Icons.volume_up_rounded
          : Icons.volume_off_rounded;
    });
    _tapIndicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _tapIndicator = null);
    });
  }

  void _doubleLike(TapDownDetails details) {
    widget.onDoubleLike();
    _heartTimer?.cancel();
    setState(() {
      _heartPosition = details.localPosition;
      _heartSerial++;
    });
    _heartTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _heartPosition = null);
    });
  }

  void _startSeeking(LongPressStartDetails details) {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;
    _resumeAfterSeek = controller.value.isPlaying;
    _seekStartPosition = controller.value.position;
    _seekPosition = _seekStartPosition;
    _lastSeekAt = null;
    unawaited(controller.pause());
    setState(() => _seeking = true);
  }

  void _updateSeeking(LongPressMoveUpdateDetails details) {
    final controller = widget.controller;
    final width = context.size?.width ?? 0;
    if (!_seeking || controller == null || width <= 0) return;
    final target = calculateReelSeekTarget(
      start: _seekStartPosition,
      duration: controller.value.duration,
      horizontalDelta: details.offsetFromOrigin.dx,
      width: width,
    );
    setState(() => _seekPosition = target);
    final now = DateTime.now();
    if (_lastSeekAt == null ||
        now.difference(_lastSeekAt!).inMilliseconds >= 50) {
      _lastSeekAt = now;
      unawaited(controller.seekTo(target));
    }
  }

  void _finishSeeking() {
    if (!_seeking) return;
    final controller = widget.controller;
    if (controller != null) unawaited(controller.seekTo(_seekPosition));
    setState(() => _seeking = false);
    widget.onSeekFinished(_resumeAfterSeek);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    final initialized = controller?.value.isInitialized ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              if (widget.video.posterUrl != null)
                CachedNetworkImage(
                  // To'liq o'lchamda dekod qilinmasin — ko'rsatiladigan kenglikka yaqin.
                  memCacheWidth: 720,
                  imageUrl: widget.video.posterUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox(),
                ),
              if (initialized)
                VideoGestureSurface(
                  onSingleTap: _toggleSound,
                  onDoubleTapDown: _doubleLike,
                  onLongPressStart: _startSeeking,
                  onLongPressMoveUpdate: _updateSeeking,
                  onLongPressEnd: (_) => _finishSeeking(),
                  onLongPressCancel: _finishSeeking,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              if (!initialized && !widget.hasPlayerError)
                const Center(
                  child: SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              if (widget.hasPlayerError)
                Center(
                  child: FilledButton.tonalIcon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.commonRetry),
                  ),
                ),
              if (initialized)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller!,
                  builder: (_, value, _) => value.isBuffering
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 32,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xCC000000),
                      ],
                      stops: [0, .55, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: widget.muted ? l10n.videoUnmute : l10n.videoMute,
                    onPressed: _toggleSound,
                    color: Colors.white,
                    icon: Icon(
                      widget.muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 112,
                child: Column(
                  children: [
                    _ReelAction(
                      icon: widget.video.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: widget.video.isLiked
                          ? Colors.redAccent
                          : Colors.white,
                      count: widget.video.likesCount,
                      tooltip: l10n.videoLike,
                      onTap: widget.onLike,
                    ),
                    const SizedBox(height: 18),
                    _ReelAction(
                      icon: Icons.mode_comment_outlined,
                      count: widget.video.commentsCount,
                      tooltip: l10n.videoCommentsTitle,
                      onTap: widget.onComments,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 70,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.video.store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: InkWell(
                            onTap: widget.onStore,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                l10n.videoGoToStore,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.video.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, height: 1.25),
                    ),
                    if (widget.video.product case final product?) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: widget.onProduct,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${l10n.videoProductView} · ${product.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_tapIndicator case final icon?)
                Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Icon(icon, color: Colors.white, size: 42),
                    ),
                  ),
                ),
              if (_heartPosition case final position?)
                Positioned(
                  left: _heartAxisPosition(position.dx, constraints.maxWidth),
                  top: _heartAxisPosition(position.dy, constraints.maxHeight),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_heartSerial),
                    tween: Tween(begin: .45, end: 1.15),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.elasticOut,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 84,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                    ),
                  ),
                ),
              if (_seeking)
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        '${_formatDuration(_seekPosition)} / '
                        '${_formatDuration(controller?.value.duration ?? Duration.zero)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              if (initialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ReelProgress(controller: controller!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double _heartAxisPosition(double pointerPosition, double extent) {
    final maxPosition = (extent - 84).clamp(0.0, double.infinity).toDouble();
    return (pointerPosition - 42).clamp(0.0, maxPosition).toDouble();
  }
}

class _ReelProgress extends StatelessWidget {
  const _ReelProgress({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final progress = durationMs <= 0
            ? 0.0
            : (value.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
        return LinearProgressIndicator(
          key: const ValueKey('reel-playback-progress'),
          value: progress,
          minHeight: 2,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
        );
      },
    ),
  );
}

/// Reel gesture arena: single tap ovozni almashtiradi, double tap esa single
/// callbackni ishga tushirmasdan like gesture'iga o'tadi.
class VideoGestureSurface extends StatelessWidget {
  const VideoGestureSurface({
    required this.child,
    required this.onSingleTap,
    required this.onDoubleTapDown,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    super.key,
  });

  final Widget child;
  final VoidCallback onSingleTap;
  final GestureTapDownCallback onDoubleTapDown;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onSingleTap,
    onDoubleTapDown: onDoubleTapDown,
    onDoubleTap: () {},
    onLongPressStart: onLongPressStart,
    onLongPressMoveUpdate: onLongPressMoveUpdate,
    onLongPressEnd: onLongPressEnd,
    onLongPressCancel: onLongPressCancel,
    child: child,
  );
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          color: color,
          icon: Icon(icon, size: 29),
        ),
      ),
      const SizedBox(height: 3),
      Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 3)],
        ),
      ),
    ],
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenH,
      vertical: AppSpacing.xxl,
    ),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.video_library_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      ),
    ),
  );
}
