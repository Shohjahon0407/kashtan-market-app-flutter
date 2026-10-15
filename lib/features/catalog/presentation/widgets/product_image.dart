import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductImageView extends StatelessWidget {
  const ProductImageView({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.iconSize = 38,
    this.imageBuilder,
    this.memCacheWidth = 700,
    super.key,
  });

  final String? imageUrl;
  final BoxFit fit;
  final double iconSize;
  final ImageWidgetBuilder? imageBuilder;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: fit,
      imageBuilder: imageBuilder,
      // Dekodlangan rasm xotirada ~700px kenglikda saqlanadi: grid/reyllarda
      // scroll ravon bo'ladi va RAM ancha tejaladi (fayl keshi to'liq qoladi).
      memCacheWidth: memCacheWidth,
      placeholder: (_, _) => _fallback(context),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: iconSize,
          color: colors.outlineVariant,
        ),
      ),
    );
  }
}
