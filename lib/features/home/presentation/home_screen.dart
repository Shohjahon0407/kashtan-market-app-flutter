import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../cart/domain/main_cart_overview_provider.dart';
import '../../checkout/data/checkout_models.dart';
import '../../checkout/domain/addresses_controller.dart';
import '../../checkout/presentation/address_display.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../../recommendations/domain/recommendations_controller.dart';
import '../../recommendations/presentation/for_you_section.dart';
import '../../videos/domain/video_feed_controller.dart';
import '../../videos/presentation/widgets/video_feed_section.dart';
import '../data/home_models.dart';
import '../domain/home_controller.dart';
import 'home_reels_physics.dart';
import 'widgets/language_picker.dart';
import 'widgets/stores_section.dart';

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
  double? _viewportExtent;

  /// Reels hududi boshining scroll offset'i — KESH.
  ///
  /// Physics buni `createBallisticSimulation` ichida o'qiydi, u esa layout
  /// PAYTIDA ham chaqiriladi (`applyContentDimensions` → `goBallistic`).
  /// O'sha paytda `getOffsetToReveal` hali o'lchanmagan box'ga tegib
  /// assertion beradi — shuning uchun o'lchash faqat kadr tugagach qilinadi.
  double? _reelsStart;

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
            // Har build'dan keyin (header/do'konlar balandligi o'zgargan
            // bo'lishi mumkin) reels boshi qayta o'lchanadi.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _measureReelsStart(),
            );
            return NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    ref.read(homeControllerProvider.notifier).refresh(),
                    if (authenticated)
                      ref.read(addressesControllerProvider.notifier).refresh(),
                    ref.read(videoFeedControllerProvider.notifier).refresh(),
                    ref.read(forYouControllerProvider.notifier).refresh(),
                  ]);
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _HomeList(
                      controller: _scrollController,
                      // Snap physics ichida: fling bitta sahifada tugaydi.
                      // Getter'lar — Scrollable birinchi physics instansiyasini
                      // saqlab qoladi, qiymatlar esa jonli bo'lishi shart.
                      physics: HomeReelsScrollPhysics(
                        reelsStart: () => _reelsStart,
                        pageExtent: () => _viewportExtent ?? 0,
                        reelCount: _reelCount,
                        parent: const AlwaysScrollableScrollPhysics(),
                      ),
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

  int _reelCount() =>
      ref.read(videoFeedControllerProvider).value?.items.length ?? 0;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }
    // Physics fling'ni sahifa chegarasida tugatadi — ScrollEnd endi aynan
    // o'sha joyda bir marta keladi; faol reel shundan hisoblanadi.
    if (notification is ScrollEndNotification) {
      // Gesture/animatsiya callback'i — layout tashqarisi, o'lchash xavfsiz.
      _measureReelsStart();
      _syncSettledReelFromPosition();
    }
    return false;
  }

  void _measureReelsStart() {
    if (!mounted) return;
    _reelsStart = _reelsStartOffset();
  }

  void _syncSettledReelFromPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    final reelsStart = _reelsStart;
    final extent = _viewportExtent;
    final reelCount = _reelCount();
    if (reelsStart == null || extent == null || extent <= 0 || reelCount <= 0) {
      _setSettledReel(-1);
      return;
    }
    final page = ((_scrollController.position.pixels - reelsStart) / extent)
        .round();
    _setSettledReel(page < 0 ? -1 : page.clamp(0, reelCount - 1));
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
      if (!mounted || !_scrollController.hasClients) return;
      _measureReelsStart();
      final reelsStart = _reelsStart;
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
    required this.physics,
    required this.home,
    required this.addresses,
    required this.reelPageExtent,
    required this.reelsStartKey,
    required this.activeReelIndex,
    required this.onRetry,
  });

  final ScrollController controller;
  final ScrollPhysics physics;
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
      physics: physics,
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
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: switch (home) {
                    AsyncData(:final value) => StoresSection(
                      items: value.storeHub,
                      onMissingProductTap: () => pushAuthenticated(
                        context,
                        ref,
                        Routes.requestsFor(kind: 'missing_product'),
                      ),
                    ),
                    AsyncError(:final error) => HomeErrorView(
                      message: error is ApiFailure
                          ? error.localize(l10n)
                          : l10n.errorUnknown,
                      onRetry: onRetry,
                    ),
                    _ => const StoresSkeleton(),
                  },
                ),
              ],
            ),
          ),
        ),
        // Shaxsiy tavsiyalar — do'konlar va reels orasida. Bo'sh bo'lsa
        // 0 balandlik; reels boshi baribir kadrdan keyin o'lchanadi.
        const SliverToBoxAdapter(child: ForYouSection()),
        // Sliver: reel sahifalari lazy quriladi (ilgari hammasi Column'da).
        VideoFeedSection(
          pageExtent: reelPageExtent,
          reelsStartKey: reelsStartKey,
          activeIndexListenable: activeReelIndex,
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

    final identity = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Semantics(
            button: true,
            label: l10n.profileAddresses,
            child: InkWell(
              key: const ValueKey('home-address-button'),
              onTap: () => pushAuthenticated(context, ref, Routes.addresses),
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
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      spacing: 0,
      runSpacing: AppSpacing.sm,
      children: [
        NotificationBellButton(
          onPressed: () =>
              pushAuthenticated(context, ref, Routes.notifications),
        ),
        _HeaderIconButton(
          key: const ValueKey('home-language-button'),
          tooltip: l10n.profileLanguage,
          icon: Icons.translate_rounded,
          onTap: () => showAppLanguagePicker(context, ref),
        ),
        _HeaderIconButton(
          key: const ValueKey('home-main-cart-button'),
          tooltip: l10n.cartTitle,
          icon: Icons.shopping_bag_outlined,
          badgeCount: cartQuantity,
          onTap: () => context.push(Routes.cart),
        ),
        _HeaderIconButton(
          tooltip: l10n.profileTitle,
          icon: Icons.person_outline,
          onTap: () => pushAuthenticated(context, ref, Routes.profile),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the normal phone header on one compact row. Only large
        // accessibility text needs a separate row for the actions.
        if (MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity.child,
              const SizedBox(height: AppSpacing.sm),
              actions,
            ],
          );
        }
        return Row(children: [identity, const SizedBox(width: 4), actions]);
      },
    );
  }

  static UserAddress? _defaultAddress(List<UserAddress> addresses) {
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
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
