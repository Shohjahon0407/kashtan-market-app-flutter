import '../../../core/network/json_read.dart';
import '../../catalog/data/product_models.dart';

class FavoriteEntry {
  const FavoriteEntry({required this.id, required this.product});

  factory FavoriteEntry.fromJson(Map<String, dynamic> json) {
    final product = JsonRead.map(json['product']) ?? const <String, dynamic>{};
    return FavoriteEntry(
      id: JsonRead.string(json['id']),
      product: ProductSummary.fromJson(product),
    );
  }

  final String id;
  final ProductSummary product;
}
