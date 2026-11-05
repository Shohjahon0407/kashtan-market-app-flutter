import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../core/ui/theme/contrast.dart';
import '../../data/home_models.dart';

/// Backend tartibidagi ixcham, ikki ustunli do'kon kartalari.
class StoreGrid extends StatelessWidget {
  const StoreGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.trailingCard,
  });

  final List<StoreHubItem> items;
  final ValueChanged<StoreHubItem> onTap;
  final Widget? trailingCard;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        childAspectRatio:
            0.90 /
            (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(1, 2),
      ),
      itemCount: items.length + (trailingCard == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == items.length) return trailingCard!;
        return _StoreCard(
          key: ValueKey('home-store-${items[index].storeTypeWire}'),
          item: items[index],
          number: index + 1,
          onTap: () => onTap(items[index]),
        );
      },
    );
  }
}

/// Lokal fallback rasmlar. Tanlangan Shashlik, Ofiyat va Go'sht fotosi ustuvor.
const Map<StoreType, String> _cardAssets = {
  StoreType.household: 'assets/stores/household.webp',
  StoreType.restaurant: 'assets/stores/restaurant.webp',
  StoreType.grocery: 'assets/stores/grocery.webp',
  StoreType.shashlik: 'assets/stores/shashlik.webp',
  StoreType.meat: 'assets/stores/meat.webp',
};

Color _fallbackAccent(StoreType? type) => switch (type) {
  StoreType.household => const Color(0xFF2563A8),
  StoreType.restaurant => const Color(0xFF0B7C5C),
  StoreType.grocery => const Color(0xFF15803D),
  StoreType.shashlik => const Color(0xFF334155),
  StoreType.meat => const Color(0xFF9F1239),
  null => const Color(0xFF64748B),
};

IconData _fallbackIcon(StoreType? type) => switch (type) {
  StoreType.grocery => Icons.shopping_basket_outlined,
  StoreType.household => Icons.inventory_2_outlined,
  StoreType.restaurant => Icons.restaurant_outlined,
  StoreType.shashlik => Icons.outdoor_grill_outlined,
  StoreType.meat => Icons.kebab_dining_outlined,
  null => Icons.storefront_outlined,
};

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.item,
    required this.number,
    required this.onTap,
    super.key,
  });

  final StoreHubItem item;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = item.accentColor ?? _fallbackAccent(item.storeType);
    final title = item.label.trim().isEmpty
        ? item.storeTypeWire
        : item.label.trim();

    return Semantics(
      button: true,
      label: title,
      child: Material(
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
                    _CardImage(item: item, accent: accent),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: accent),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            number.toString().padLeft(2, '0'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _onAccent(accent),
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
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 13,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (item.subtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.subtitle.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _fallbackIcon(item.storeType),
                        size: 15,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _onAccent(Color background) => onAccent(background);
}

/// Shashlik, Ofiyat, Go'sht: tanlangan lokal foto -> server -> ikon.
/// Boshqa do'konlar: server -> lokal asset -> ikon.
class _CardImage extends StatelessWidget {
  const _CardImage({required this.item, required this.accent});

  final StoreHubItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final asset = _cardAssets[item.storeType];
    Widget icon() => _IconFallback(accent: accent, type: item.storeType);
    Widget local() => asset == null
        ? icon()
        : Image.asset(
            asset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => icon(),
          );

    Widget remoteOr(Widget Function() fallback) {
      final url = item.imageUrl;
      if (url == null) return fallback();
      return CachedNetworkImage(
        memCacheWidth: 480,
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback(),
        errorWidget: (_, _, _) => fallback(),
      );
    }

    final preferredPhoto = switch (item.storeType) {
      StoreType.shashlik || StoreType.restaurant || StoreType.meat => true,
      _ => false,
    };
    if (preferredPhoto && asset != null) {
      return Image.asset(
        asset,
        cacheWidth: 480,
        fit: BoxFit.cover,
        // Keep storefront signage visible in the wide card image area.
        alignment: item.storeType == StoreType.shashlik
            ? Alignment.center
            : Alignment.topCenter,
        errorBuilder: (_, _, _) => remoteOr(icon),
      );
    }
    return remoteOr(local);
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.accent, required this.type});

  final Color accent;
  final StoreType? type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _fallbackIcon(type),
          color: accent.withValues(alpha: 0.72),
          size: 32,
        ),
      ),
    );
  }
}
