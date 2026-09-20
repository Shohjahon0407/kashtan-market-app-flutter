import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/routing/auth_gate.dart';
import '../../../../core/routing/route_visibility.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../home/domain/home_tab_controller.dart';
import '../../data/video_cache.dart';
import '../../data/video_models.dart';
import '../../domain/video_feed_controller.dart';
import '../reel_player_pool.dart';
import 'video_comments_sheet.dart';
import 'video_product_rail.dart';
import 'video_reel_card.dart';

export 'video_reel_card.dart' show VideoGestureSurface;

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
  late final ReelPlayerPool _pool;
  final Map<int, double> _visibility = {};
  final Set<String> _productRailIds = {};
  String? _lastFeedSignature;
  int _activeIndex = -1;
  bool _modalOpen = false;

  @override
  void initState() {
    super.initState();
    _pool = ReelPlayerPool(
      cache: ref.read(videoCacheProvider),
      soundOn: () => mounted && ref.read(videoSoundProvider),
      onChanged: () {
        if (mounted) setState(() {});
      },
      onActiveReady: _playActiveIfAllowed,
    );
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
    // Branch navigator ichidamiz — root'ga push bo'lganda ham pauza uchun
    // butun route zanjiriga obuna (qarang route_visibility.dart).
    subscribeToEnclosingRoutes(appRouteObserver, this, context);
  }

  @override
  void dispose() {
    widget.activeIndexListenable.removeListener(_onSettledIndexChanged);
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _pool.dispose();
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
      unawaited(_pool.setVolume(soundOn));
    });
    // Home shell tabi almashganda RouteAware xabar bermaydi — Asosiy'dan
    // chiqilganda pauza, qaytilganda davom.
    ref.listen<HomeTab>(homeTabProvider, (_, tab) {
      if (tab == HomeTab.home) {
        _playActiveIfAllowed();
      } else {
        _pauseAll();
      }
    });

    // Bu widget SLIVER qaytaradi — CustomScrollView'ga to'g'ridan-to'g'ri
    // qo'yiladi. Reel sahifalari lazy quriladi (ilgari hammasi bitta Column
    // ichida edi va 40–60 reel'dan keyin har rebuild hammasini qayta qurardi).
    return switch (feed) {
      AsyncData(:final value) when value.items.isEmpty =>
        const SliverToBoxAdapter(child: SizedBox.shrink()),
      AsyncData(:final value) => _buildFeed(context, value, muted),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: _FeedError(
          message: error is ApiFailure
              ? error.localize(AppLocalizations.of(context))
              : AppLocalizations.of(context).videoLoadError,
          onRetry: () =>
              ref.read(videoFeedControllerProvider.notifier).refresh(),
        ),
      ),
      _ => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
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
    final items = state.items;
    final indexById = {for (var i = 0; i < items.length; i++) items[i].id: i};
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                ),
                child: Text(
                  l10n.videoFeedTitle.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Reels hududining boshi — physics va faol indeks shu nuqtaning
              // offset'idan hisoblanadi.
              SizedBox(key: widget.reelsStartKey),
            ],
          ),
        ),
        // Har sahifa aynan viewport balandligida: offsetlar aniq, faqat
        // ko'rinish + cache oynasidagi reel'lar quriladi.
        SliverFixedExtentList(
          itemExtent: widget.pageExtent,
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildReelPage(
              items,
              index,
              muted: muted,
              productCardHeight: productCardHeight,
              bottomInset: bottomInset,
            ),
            childCount: items.length,
            // Lenta yangilanganda (refresh/loadMore) sahifalar id bo'yicha
            // topiladi — controller'lar va VisibilityDetector holati saqlanadi.
            findChildIndexCallback: (key) => key is ValueKey<String>
                ? indexById[key.value.replaceFirst(_pageKeyPrefix, '')]
                : null,
          ),
        ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (state.loadMoreError != null)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(videoFeedControllerProvider.notifier).loadMore(),
                child: Text(l10n.commonRetry),
              ),
            ),
          ),
      ],
    );
  }

  static const _pageKeyPrefix = 'home-reel-page-';

  Widget _buildReelPage(
    List<StoreVideo> items,
    int index, {
    required bool muted,
    required double productCardHeight,
    required double bottomInset,
  }) {
    final video = items[index];
    return SizedBox(
      key: ValueKey('$_pageKeyPrefix${video.id}'),
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
                    key: ValueKey('home-video-${video.id}'),
                    onVisibilityChanged: (info) =>
                        _onVisibility(index, info.visibleFraction, items),
                    child: VideoReelCard(
                      video: video,
                      controller: _pool.controllerFor(video.id),
                      hasPlayerError: _pool.hasError(video.id),
                      muted: muted,
                      onToggleSound: () =>
                          ref.read(videoSoundProvider.notifier).toggle(),
                      onSeekFinished: _finishSeek,
                      onRetry: () => _pool.retry(video.id),
                      onLike: () => _toggleLike(video.id),
                      onDoubleLike: () => _likeOnly(video.id),
                      onComments: () => _openComments(video),
                      onStore: () => _openStore(video),
                      onProduct: video.product == null
                          ? null
                          : () => _openProduct(video.product!),
                    ),
                  ),
                ),
                if (_productRailIds.contains(video.id)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  VideoProductRailSection(
                    videoId: video.id,
                    cardHeight: productCardHeight,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _syncWindow(List<StoreVideo> items) => _pool.syncWindow(
    items,
    _activeIndex < 0 ? 0 : _activeIndex.clamp(0, items.length - 1),
  );

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
        ref.read(homeTabProvider) != HomeTab.home ||
        !isRouteStackCurrent(context)) {
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
    _pool.play(currentItems[_activeIndex].id);
  }

  void _pauseAll({String? exceptId}) => _pool.pauseAll(exceptId: exceptId);

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
