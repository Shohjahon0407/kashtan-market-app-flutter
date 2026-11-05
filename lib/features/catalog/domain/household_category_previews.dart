import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../../core/store_scope/store_type.dart';
import '../data/product_models.dart';
import 'catalog_controller.dart';

/// Only mounted landing sections request previews. This does not change the
/// catalogue controller/filter/cursor used inside a category. Successful rows
/// survive scrolling off-screen for five minutes; locale/account changes still
/// invalidate them. The full API summaries preserve cart configuration rules.
final householdCategoryPreviewsProvider = StreamProvider.autoDispose
    .family<List<ProductSummary>, String>((ref, categoryId) async* {
      ref.watch(apiLangProvider);
      ref.watch(uzScriptProvider);
      ref.watch(accountScopeProvider);
      final api = ref.watch(catalogApiProvider);
      final link = ref.keepAlive();
      Timer? expiry;
      ref.onCancel(() {
        expiry?.cancel();
        expiry = Timer(const Duration(minutes: 5), link.close);
      });
      ref.onResume(() => expiry?.cancel());
      ref.onDispose(() => expiry?.cancel());

      List<ProductSummary>? cached;
      try {
        final suffix = ref.read(cacheKeySuffixProvider)();
        final raw = await ref
            .read(jsonDiskCacheProvider)
            .read(
              catalogCategoryCacheKey('household', categoryId, suffix),
              maxAge: const Duration(days: 3),
            );
        if (raw != null) {
          cached = householdPreviewProducts(
            PageDecoder.cursor(raw, ProductSummary.fromJson).items,
          );
          if (ref.mounted) yield cached;
        }
      } on Object {
        // A missing/older disk snapshot must not block a normal request.
      }
      if (!ref.mounted) return;
      try {
        final page = await api.fetchProducts(
          storeType: 'household',
          categoryId: categoryId,
        );
        if (ref.mounted) yield householdPreviewProducts(page.items);
      } on Object {
        if (cached == null) {
          // Keep retry in the row, not an automatic request loop on scroll.
          rethrow;
        }
      }
    }, retry: (_, _) => null);

List<ProductSummary> householdPreviewProducts(
  Iterable<ProductSummary> products,
) {
  final ids = <String>{};
  return products
      .where(
        (product) =>
            product.storeType == StoreType.household &&
            product.id.isNotEmpty &&
            (product.imageUrl?.trim().isNotEmpty ?? false) &&
            ids.add(product.id),
      )
      .take(6)
      .toList(growable: false);
}
