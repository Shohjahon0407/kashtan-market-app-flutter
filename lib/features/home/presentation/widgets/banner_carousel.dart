import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/ui/theme/app_colors.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../data/home_models.dart';

/// Banner karuseli — mockupdagi kabi to'liq en, pastida nuqtalar.
///
/// O'lcham va radius ADMIN qo'ygan qiymatlardan ([HomeBanner.heightPx],
/// [HomeBanner.radius]) — client ularni faqat xavfsiz chegaraga qisadi.
/// Server bo'sh qaytarsa bitta lokal placeholder ko'rsatiladi (rasm YO'Q,
/// gradient + nom — "default ikon bilan chizish" qoidasiga mos).
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    required this.placeholderTitle,
  });

  final List<HomeBanner> banners;

  /// Bo'sh holatdagi lokal karta matni (ilova nomi).
  final String placeholderTitle;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) {
      return _PlaceholderBanner(title: widget.placeholderTitle);
    }

    // Har sahifa o'z balandligiga ega bo'lishi mumkin — karusel eng balandiga
    // moslanadi, qolganlari o'z balandligida markazda turadi.
    final maxHeight = banners
        .map((b) => b.heightPx)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: maxHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: banners.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              child: Center(child: _BannerCard(banner: banners[index])),
            ),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          SmoothPageIndicator(
            controller: _pageController,
            count: banners.length,
            effect: WormEffect(
              dotWidth: 8,
              dotHeight: 8,
              spacing: 8,
              activeDotColor: Theme.of(context).colorScheme.primary,
              dotColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final HomeBanner banner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = banner.textColor ?? Colors.white;

    return Container(
      height: banner.heightPx,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(banner.radius),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (banner.imageUrl != null)
            CachedNetworkImage(
              imageUrl: banner.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => const _BannerFallback(),
              errorWidget: (_, _, _) => const _BannerFallback(),
            )
          else
            const _BannerFallback(),
          if (banner.overlayEnabled)
            ColoredBox(
              color: Colors.black.withValues(alpha: banner.overlayOpacity),
            ),
          if (banner.showText && banner.title.isNotEmpty)
            Positioned(
              left: AppSpacing.lg,
              top: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (banner.subtitle.isNotEmpty)
                    Text(
                      banner.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Rasm yo'q/yuklanmagan holatdagi gradient fon.
class _BannerFallback extends StatelessWidget {
  const _BannerFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.info, Color(0xFF6FB7FF)],
        ),
      ),
      child: Center(
        child: Icon(Icons.image_outlined, size: 40, color: Colors.white70),
      ),
    );
  }
}

class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Container(
        height: 140,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF2BC79A)],
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
