import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/store_scope/store_type.dart';
import '../../catalog/data/product_models.dart';
import '../../recommendations/domain/interaction_tracker.dart';

/// Optional cart suggestions must not block loading, editing or checkout.
final cartRecommendationsProvider = FutureProvider.autoDispose
    .family<List<ProductSummary>, StoreType?>((ref, storeType) async {
      ref.watch(apiLangProvider);
      ref.watch(accountScopeProvider);
      try {
        final page = await ref
            .watch(recommendationsApiProvider)
            .forYou(storeType: storeType?.wire, imagesOnly: true, limit: 15);
        final seen = <String>{};
        // Older servers may ignore images_only/store_type.
        return page.items.where((product) {
          return (product.imageUrl?.trim().isNotEmpty ?? false) &&
              product.isPurchasable &&
              !product.inReview &&
              StoreType.fromWire(product.storeTypeWire) != null &&
              (storeType == null || product.storeTypeWire == storeType.wire) &&
              seen.add(product.id);
        }).toList();
      } on Object {
        return const [];
      }
    });
