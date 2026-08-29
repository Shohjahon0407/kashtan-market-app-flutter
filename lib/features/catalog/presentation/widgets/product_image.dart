import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductImageView extends StatelessWidget {
  const ProductImageView({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.iconSize = 38,
    this.imageBuilder,
    super.key,
  });

  final String? imageUrl;
  final BoxFit fit;
  final double iconSize;
  final ImageWidgetBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: fit,
      imageBuilder: imageBuilder,
      // Dekodlangan rasm xotirada ~700px kenglikda saqlanadi: grid/reyllarda
      // scroll ravon bo'ladi va RAM ancha tejaladi (fayl keshi to'liq qoladi).
      memCacheWidth: 700,
      placeholder: (_, _) => _fallback(context, loading: true),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context, {bool loading = false}) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.image_outlined,
                size: iconSize,
                color: colors.outlineVariant,
              ),
      ),
    );
  }
}
