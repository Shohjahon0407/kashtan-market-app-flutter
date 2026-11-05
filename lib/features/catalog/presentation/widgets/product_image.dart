import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/storage/product_image_cache.dart';

class ProductImageView extends StatelessWidget {
  const ProductImageView({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.iconSize = 38,
    this.imageBuilder,
    this.memCacheWidth = 700,
    this.persistent = false,
    this.keepPreviousImage = false,
    this.disableFade = false,
    super.key,
  });

  final String? imageUrl;
  final BoxFit fit;
  final double iconSize;
  final ImageWidgetBuilder? imageBuilder;
  final int memCacheWidth;
  final bool persistent;
  final bool keepPreviousImage;
  final bool disableFade;

  /// Match CachedNetworkImage/OctoImage's resized provider exactly. Warming
  /// the original full-size provider would decode a different cache key.
  static ImageProvider<Object> decodedProvider(
    String url, {
    bool persistent = false,
    int memCacheWidth = 700,
  }) => ResizeImage.resizeIfNeeded(
    memCacheWidth,
    null,
    CachedNetworkImageProvider(
      url,
      cacheManager: persistent ? ProductImageCache.persistentManager : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      cacheManager: persistent ? ProductImageCache.persistentManager : null,
      imageUrl: imageUrl!,
      fit: fit,
      imageBuilder: imageBuilder,
      // Restaurant images already downloaded to disk should appear at full
      // opacity, without the default 1-second placeholder crossfade.
      fadeInDuration: persistent || disableFade
          ? Duration.zero
          : const Duration(milliseconds: 500),
      fadeOutDuration: persistent || disableFade
          ? Duration.zero
          : const Duration(milliseconds: 1000),
      placeholderFadeInDuration: persistent || disableFade
          ? Duration.zero
          : null,
      useOldImageOnUrlChange: keepPreviousImage,
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
