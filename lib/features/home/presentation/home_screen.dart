import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../cart/domain/main_cart_overview_provider.dart';
import '../../checkout/data/checkout_models.dart';
import '../../checkout/domain/addresses_controller.dart';
import '../../checkout/presentation/address_display.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../../videos/domain/video_feed_controller.dart';
import '../../videos/presentation/widgets/video_feed_section.dart';
import '../data/home_models.dart';
import '../domain/home_controller.dart';
import 'home_reels_snap.dart';
import 'widgets/language_picker.dart';
import 'widgets/store_grid.dart';

/// Ixcham marketplace bosh sahifasi:
/// header -> do'konlar -> yo'q tovar murojaati -> video lenta.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  final _reelsStartKey = GlobalKey(debugLabel: 'home-reels-start');
  final _activeReelIndex = ValueNotifier<int>(-1);
  var _settledReelIndex = -1;
  var _lastScrollDelta = 0.0;
  var _snapping = false;
  double? _viewportExtent;

  @override
  void dispose() {
    _activeReelIndex.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeControllerProvider);
    final authenticated = ref.watch(
      authControllerProvider.select((auth) => auth.isAuthenticated),
    );
    final addresses = authenticated
        ? ref.watch(addressesControllerProvider)
        : const AsyncValue<List<UserAddress>>.data([]);
    // Faqat soni — har like/komment yangilanishida butun Home rebuild bo'lmasin.
    final reelCount = ref.watch(
      videoFeedControllerProvider.select(
        (value) => value.value?.items.length ?? 0,
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _handleViewportResize(constraints.maxHeight, reelCount);
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) => _handleScrollNotification(
                notification,
                reelCount: reelCount,
                viewportExtent: constraints.maxHeight,
              ),
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    ref.read(homeControllerProvider.notifier).refresh(),
                    if (authenticated)
                      ref.read(addressesControllerProvider.notifier).refresh(),
                    ref.read(videoFeedControllerProvider.notifier).refresh(),
                  ]);
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _HomeList(
                      controller: _scrollController,
                      home: home,
                      addresses: addresses,
                      reelPageExtent: constraints.maxHeight,
                      reelsStartKey: _reelsStartKey,
                      activeReelIndex: _activeReelIndex,
                      onRetry: () =>
                          ref.read(homeControllerProvider.notifier).refresh(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _handleScrollNotification(
    ScrollNotification notification, {
    required int reelCount,
    required double viewportExtent,
  }) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }
    if (_snapping) return false;

    if (notification case ScrollStartNotification()) {
      _restoreSettledIndex(viewportExtent, reelCount);
    } else if (notification case ScrollUpdateNotification(
      :final scrollDelta?,
    )) {
      if (scrollDelta.abs() > .01) _lastScrollDelta = scrollDelta;
    } else if (notification case OverscrollNotification(:final overscroll)) {
      if (overscroll.abs() > .01) _lastScrollDelta = overscroll;
    } else if (notification case ScrollEndNotification()) {
      final delta = _lastScrollDelta;
      _lastScrollDelta = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _snapAfterScroll(
            reelCount: reelCount,
            viewportExtent: viewportExtent,
            scrollDelta: delta,
          ),
        );
      });
    }
    return false;
  }

  Future<void> _snapAfterScroll({
    required int reelCount,
    required double viewportExtent,
    required double scrollDelta,
  }) async {
    if (!mounted || !_scrollController.hasClients || _snapping) return;
    final reelsStart = _reelsStartOffset();
    if (reelsStart == null) return;
    final position = _scrollController.position;
    final decision = calculateHomeReelsSnap(
      settledIndex: _settledReelIndex,
      pixels: position.pixels,
      viewportExtent: viewportExtent,
      reelsStart: reelsStart,
      reelCount: reelCount,
      scrollDelta: scrollDelta,
    );
    if (decision == null) return;

    final target = decision.offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - target).abs() < 1) {
      _setSettledReel(decision.settledIndex);
      return;
    }

    _snapping = true;
    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      if (!mounted || !_scrollController.hasClients) return;
      if ((_scrollController.position.pixels - target).abs() < 2) {
        _setSettledReel(decision.settledIndex);
      }
    } finally {
      _snapping = false;
    }
  }

  void _restoreSettledIndex(double viewportExtent, int reelCount) {
    if (_settledReelIndex >= 0 || reelCount <= 0) return;
    final reelsStart = _reelsStartOffset();
    if (reelsStart == null || !_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    if (pixels < reelsStart - 2) return;
    _setSettledReel(
      ((pixels - reelsStart) / viewportExtent).round().clamp(0, reelCount - 1),
    );
  }

  void _setSettledReel(int index) {
    _settledReelIndex = index;
    if (_activeReelIndex.value != index) _activeReelIndex.value = index;
  }

  double? _reelsStartOffset() {
    final renderObject = _reelsStartKey.currentContext?.findRenderObject();
    if (renderObject == null || !renderObject.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    return viewport?.getOffsetToReveal(renderObject, 0).offset;
  }

  void _handleViewportResize(double extent, int reelCount) {
    final previous = _viewportExtent;
    _viewportExtent = extent;
    if (previous == null || (previous - extent).abs() < 1) return;
    if (_settledReelIndex < 0 || reelCount <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _snapping) return;
      final reelsStart = _reelsStartOffset();
      if (reelsStart == null) return;
      final target = (reelsStart + _settledReelIndex * extent).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    });
  }
}

class _HomeList extends ConsumerWidget {
  const _HomeList({
    required this.controller,
    required this.home,
    required this.addresses,
    required this.reelPageExtent,
    required this.reelsStartKey,
    required this.activeReelIndex,
    required this.onRetry,
  });

  final ScrollController controller;
  final AsyncValue<HomeData> home;
  final AsyncValue<List<UserAddress>> addresses;
  final double reelPageExtent;
  final GlobalKey reelsStartKey;
  final ValueListenable<int> activeReelIndex;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      key: const PageStorageKey('home-scroll'),
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: _HomeHeader(addresses: addresses),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: switch (home) {
                    AsyncData(:final value) => _StoresSection(
                      items: value.storeHub,
                      onMissingProductTap: () => pushAuthenticated(
                        context,
                        ref,
                        Routes.requestsFor(kind: 'missing_product'),
                      ),
                    ),
                    AsyncError(:final error) => _HomeError(
                      message: error is ApiFailure
                          ? error.localize(l10n)
                          : l10n.errorUnknown,
                      onRetry: onRetry,
                    ),
                    _ => const _StoresSkeleton(),
                  },
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: VideoFeedSection(
            pageExtent: reelPageExtent,
            reelsStartKey: reelsStartKey,
            activeIndexListenable: activeReelIndex,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.addresses});

  final AsyncValue<List<UserAddress>> addresses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cartQuantity = ref.watch(mainCartOverviewProvider).totalQuantity;
    final addressTitle = switch (addresses) {
      AsyncData(:final value) =>
        _defaultAddress(value)?.displayTitle(l10n) ??
            l10n.homeAddressNotSelected,
      AsyncLoading() => l10n.commonLoading,
      _ => l10n.homeAddressNotSelected,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Semantics(
                button: true,
                label: l10n.profileAddresses,
                child: InkWell(
                  key: const ValueKey('home-address-button'),
                  onTap: () =>
                      pushAuthenticated(context, ref, Routes.addresses),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            addressTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        NotificationBellButton(
          onPressed: () =>
              pushAuthenticated(context, ref, Routes.notifications),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderIconButton(
          key: const ValueKey('home-language-button'),
          tooltip: l10n.profileLanguage,
          icon: Icons.translate_rounded,
          onTap: () => showAppLanguagePicker(context, ref),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderIconButton(
          key: const ValueKey('home-main-cart-button'),
          tooltip: l10n.cartTitle,
          icon: Icons.shopping_bag_outlined,
          badgeCount: cartQuantity,
          onTap: () => context.push(Routes.cart),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderIconButton(
          tooltip: l10n.profileTitle,
          icon: Icons.person_outline,
          onTap: () => pushAuthenticated(context, ref, Routes.profile),
        ),
      ],
    );
  }

  static UserAddress? _defaultAddress(List<UserAddress> addresses) {
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }
}

class _StoresSection extends StatelessWidget {
  const _StoresSection({
    required this.items,
    required this.onMissingProductTap,
  });

  final List<StoreHubItem> items;
  final VoidCallback onMissingProductTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final orderedItems = [...items]..sort(_compareHomeStores);
    final totalCardCount = orderedItems.length + 1;
    final count = totalCardCount.toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.homeStoresTitle.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              '$count / $count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        StoreGrid(
          items: orderedItems,
          trailingCard: _MissingProductGridCard(
            number: totalCardCount,
            onTap: onMissingProductTap,
          ),
          onTap: (item) =>
              context.push(Routes.storeCatalog(item.storeTypeWire)),
        ),
      ],
    );
  }

  static int _compareHomeStores(StoreHubItem left, StoreHubItem right) {
    final priority = _homeStorePriority(
      left.storeType,
    ).compareTo(_homeStorePriority(right.storeType));
    if (priority != 0) return priority;
    return left.sortOrder.compareTo(right.sortOrder);
  }

  static int _homeStorePriority(StoreType? storeType) => switch (storeType) {
    StoreType.household => 0,
    StoreType.grocery => 1,
    StoreType.shashlik => 2,
    StoreType.restaurant => 3,
    StoreType.meat => 4,
    null => 5,
  };
}

class _MissingProductGridCard extends StatelessWidget {
  const _MissingProductGridCard({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const ValueKey('home-missing-product-card'),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/stores/missing_product.webp',
                    key: const ValueKey('home-missing-product-image'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: colors.primaryContainer,
                      child: Icon(
                        Icons.add_shopping_cart_rounded,
                        color: colors.primary,
                        size: 34,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: colors.primary),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Text(
                          number.toString().padLeft(2, '0'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 7, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.supportMissingProductTitle.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10.5,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.supportMissingProductSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                child: Icon(icon, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
    // Vizual 40 dp, bosish maydoni 48 dp (minimal tap target).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: 48, height: 48, child: Center(child: visual)),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}

class _StoresSkeleton extends StatelessWidget {
  const _StoresSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _box(base, height: 12, width: 84),
              const Spacer(),
              _box(base, height: 10, width: 42),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var row = 0; row < 3; row++) ...[
            Row(
              children: [
                Expanded(child: _card(base)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _card(base)),
              ],
            ),
            if (row < 2) const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  static Widget _box(Color color, {required double height, double? width}) =>
      Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      );

  static Widget _card(Color color) => AspectRatio(
    aspectRatio: 0.90,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    ),
  );
}
