import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../data/catalog_product_images.dart';
import '../../data/product_models.dart';

/// Preserve local fallback photographs and avoid placeholder fade flashes.
class MeatProductImage extends StatelessWidget {
  const MeatProductImage({required this.product, super.key});
  final ProductSummary product;
  @override
  Widget build(BuildContext context) {
    final asset = switch (meatProductKind(product)) {
      MeatProductKind.lamb => 'lamb-meat',
      MeatProductKind.beef => 'beef-meat',
      MeatProductKind.horse => 'horse-meat',
      MeatProductKind.qazi => 'qazi',
      MeatProductKind.beefLiver => 'beef-liver',
      MeatProductKind.lambLiver => 'lamb-liver',
      MeatProductKind.other => null,
    };
    Widget fallback() => Image.asset(
      asset == null
          ? 'assets/stores/meat.webp'
          : 'assets/products/meat/$asset.webp',
      fit: BoxFit.cover,
      cacheWidth: 700,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.image_outlined)),
    );
    final url = product.imageUrl;
    if (url == null || url.isEmpty) return fallback();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 700,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => fallback(),
      errorWidget: (_, _, _) => fallback(),
    );
  }
}
