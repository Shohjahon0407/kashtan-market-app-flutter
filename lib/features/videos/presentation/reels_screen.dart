import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/route_visibility.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../home/domain/home_tab_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/video_cache.dart';
import '../data/video_models.dart';
import '../domain/reels_feed_controller.dart';
import '../domain/video_feed_controller.dart';
import 'reel_player_pool.dart';
import 'widgets/video_comments_sheet.dart';
import 'widgets/video_product_rail.dart';
import 'widgets/video_reel_card.dart';

/// Videolar tabi: to'liq ekranli vertikal reels, har sahifa ostida shu
/// videoning mahsulot kartalari. Tartib sessiyaviy-tasodifiy
/// ([reelsFeedControllerProvider]); tepadan tortilsa yangi tartib.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  static const pageKeyPrefix = 'reels-page-';

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with WidgetsBindingObserver, RouteAware {
  late final ReelPlayerPool _pool;
  final _page = PageController();
  final Set<String> _productRailIds = {};
  String? _lastFeedSignature;
  int _activeIndex = 0;
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
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _pool.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  void didPushNext() => _pool.pauseAll();

  @override
  void didPopNext() => _playActiveIfAllowed();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pool.pauseAll();
    if (state == AppLifecycleState.resumed) _playActiveIfAllowed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(reelsFeedControllerProvider);
    final muted = !ref.watch(videoSoundProvider);
    ref.listen<bool>(videoSoundProvider, (_, soundOn) {
      unawaited(_pool.setVolume(soundOn));
    });
    // Tab almashganda RouteAware ishlamaydi — provider orqali pauza/davom.
    ref.listen<HomeTab>(homeTabProvider, (_, tab) {
      if (tab == HomeTab.videos) {
        _playActiveIfAllowed();
      } else {
        _pool.pauseAll();
      }
    });
    final notifier = ref.read(reelsFeedControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.navVideos),
      ),
      body: SafeArea(
        bottom: false,
        child: switch (feed) {
          AsyncData(:final value) when value.items.isEmpty => RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * .7,
                  child: StoreEmptyView(
                    icon: Icons.play_circle_outline,
                    title: l10n.videoFeedTitle,
                  ),
                ),
              ],
            ),
          ),
          AsyncData(:final value) => _buildFeed(context, value, muted),
          AsyncError(:final error) => StoreErrorView(
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.videoLoadError,
            onRetry: notifier.refresh,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildFeed(BuildContext context, VideoFeedState state, bool muted) {
    final items = state.items;
    final signature = items
        .map((video) => '${video.id}:${video.videoUrl}')
        .join('|');
    if (_lastFeedSignature != signature) {
      _lastFeedSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastFeedSignature != signature) return;
        _ensureProductRails(items, _activeIndex);
        unawaited(_pool.syncWindow(items, _activeIndex));
      });
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final productCardHeight = (constraints.maxHeight * .27)
              .clamp(170.0, 220.0)
              .toDouble();
          return PageView.builder(
            key: const PageStorageKey('reels-pages'),
            controller: _page,
            scrollDirection: Axis.vertical,
            // `AlwaysScrollable` — 0-sahifada tepadan tortish
            // RefreshIndicator'ga yetib boradi (yangi tartib).
            physics: const PageScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            onPageChanged: (index) => _onPageChanged(index, items),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildPage(
              items,
              index,
              muted: muted,
              productCardHeight: productCardHeight,
            ),
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.read(reelsFeedControllerProvider.notifier).refresh();
    if (!mounted) return;
    // Yangi tartib — boshidan.
    _activeIndex = 0;
    if (_page.hasClients) _page.jumpToPage(0);
  }

  Widget _buildPage(
    List<StoreVideo> items,
    int index, {
    required bool muted,
    required double productCardHeight,
  }) {
    final video = items[index];
    return Center(
      key: ValueKey('${ReelsScreen.pageKeyPrefix}${video.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: VideoReelCard(
                  video: video,
                  controller: _pool.controllerFor(video.id),
                  hasPlayerError: _pool.hasError(video.id),
                  muted: muted,
                  onToggleSound: () =>
                      ref.read(videoSoundProvider.notifier).toggle(),
                  onSeekFinished: (resume) {
                    if (resume) _playActiveIfAllowed();
                  },
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
    );
  }

  void _onPageChanged(int index, List<StoreVideo> items) {
    if (!mounted || items.isEmpty) return;
    _activeIndex = index.clamp(0, items.length - 1);
    _pool.pauseAll(exceptId: items[_activeIndex].id);
    _ensureProductRails(items, _activeIndex);
    unawaited(_pool.syncWindow(items, _activeIndex));
    _playActiveIfAllowed();
    if (index >= items.length - 2) {
      unawaited(ref.read(reelsFeedControllerProvider.notifier).loadMore());
    }
  }

  void _ensureProductRails(List<StoreVideo> items, int center) {
    var changed = false;
    for (var index = center; index <= center + 1; index++) {
      if (index >= 0 && index < items.length) {
        changed = _productRailIds.add(items[index].id) || changed;
      }
    }
    final keep = <String>{
      for (var index = center - 2; index <= center + 2; index++)
        if (index >= 0 && index < items.length) items[index].id,
    };
    final before = _productRailIds.length;
    _productRailIds.retainWhere(keep.contains);
    changed = changed || _productRailIds.length != before;
    if (changed && mounted) setState(() {});
  }

  void _playActiveIfAllowed() {
    if (!mounted ||
        _modalOpen ||
        ref.read(homeTabProvider) != HomeTab.videos ||
        !isRouteStackCurrent(context)) {
      return;
    }
    final items = ref.read(reelsFeedControllerProvider).value?.items;
    if (items == null || items.isEmpty) return;
    _pool.play(items[_activeIndex.clamp(0, items.length - 1)].id);
  }

  Future<void> _toggleLike(String id) async {
    if (!await requireAuthentication(context, ref) || !mounted) return;
    try {
      await ref.read(reelsFeedControllerProvider.notifier).toggleLike(id);
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _likeOnly(String id) async {
    if (!await requireAuthentication(context, ref) || !mounted) return;
    try {
      await ref.read(reelsFeedControllerProvider.notifier).like(id);
    } on Object catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
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

  Future<void> _openComments(StoreVideo video) async {
    _modalOpen = true;
    _pool.pauseAll();
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
    _pool.pauseAll();
    await context.push(Routes.productDetail(product.storeType, product.id));
    _modalOpen = false;
    _playActiveIfAllowed();
  }

  Future<void> _openStore(StoreVideo video) async {
    _modalOpen = true;
    _pool.pauseAll();
    await context.push(Routes.storeCatalog(video.store.storeType));
    _modalOpen = false;
    _playActiveIfAllowed();
  }
}
