import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'product_models.dart';
import 'product_review_models.dart';

class RestaurantOfflineRepository {
  const RestaurantOfflineRepository(this.storage, this.scope);
  final JsonDiskCache storage;
  final String scope;
  bool get enabled => storage.isPersistentAvailable;

  Future<Map<String, dynamic>?> landing() =>
      storage.read(restaurantLandingKey(scope));
  Future<void> saveLanding(Map<String, dynamic> raw) =>
      storage.write(restaurantLandingKey(scope), raw);
  Future<void> saveMenu(Map<String, dynamic> raw) =>
      storage.write(restaurantMenuKey(scope), raw);
  Future<void> saveDetail(String id, Map<String, dynamic> raw) =>
      storage.write(restaurantDetailKey(id, scope), raw);
  Future<void> saveReviews(String id, Map<String, dynamic> raw) async {
    if (raw['next'] != null) {
      final previous = await reviews(id);
      // A foreground first-page response must never replace a previously
      // downloaded complete review collection.
      if (previous != null && !previous.hasMore) return;
    }
    await storage.write(restaurantReviewsKey(id, scope), raw);
  }

  Future<void> invalidateProduct(String id) async {
    await storage.delete(restaurantReviewsKey(id, scope));
    await storage.delete(restaurantDetailKey(id, scope));
    await storage.delete(restaurantSyncKey(scope));
  }

  Future<ProductDetail?> detail(String id) async {
    try {
      final raw = await storage.read(restaurantDetailKey(id, scope));
      if (raw == null) return null;
      final value = ProductDetail.fromJson(raw);
      return value.product.id == id &&
              value.product.storeTypeWire == 'restaurant'
          ? value
          : null;
    } on Object {
      return null;
    }
  }

  Future<OffsetPage<ProductReview>?> reviews(String id) async {
    try {
      final raw = await storage.read(restaurantReviewsKey(id, scope));
      return raw == null
          ? null
          : PageDecoder.offset(raw, ProductReview.fromJson);
    } on Object {
      return null;
    }
  }

  Future<bool> isRecent(
    String id, {
    Duration age = const Duration(minutes: 15),
  }) async {
    final entry = await storage.readEntry(restaurantDetailKey(id, scope));
    final review = await storage.readEntry(restaurantReviewsKey(id, scope));
    final reviewsPage = await reviews(id);
    return entry != null &&
        review != null &&
        reviewsPage != null &&
        !reviewsPage.hasMore &&
        entry.age < age &&
        review.age < age;
  }

  Future<CursorPage<ProductSummary>?> products({
    String? categoryId,
    String query = '',
  }) async {
    try {
      final raw = await storage.read(restaurantMenuKey(scope));
      if (raw == null) return null;
      final page = PageDecoder.cursor(raw, ProductSummary.fromJson);
      final allowed = <String>{?categoryId};
      if (categoryId != null) {
        final categories = (await landing())?['categories'];
        if (categories is List) {
          var changed = true;
          while (changed) {
            changed = false;
            for (final category
                in categories.whereType<Map<String, dynamic>>()) {
              if (allowed.contains('${category['parent']}') &&
                  allowed.add('${category['id']}')) {
                changed = true;
              }
            }
          }
        }
      }
      final needle = query.trim().toLowerCase();
      return CursorPage(
        items: page.items
            .where(
              (product) =>
                  product.storeTypeWire == 'restaurant' &&
                  (categoryId == null ||
                      allowed.contains(product.category?.id)) &&
                  (needle.isEmpty ||
                      product.name.toLowerCase().contains(needle)),
            )
            .toList(),
        nextUrl: null,
      );
    } on Object {
      return null;
    }
  }
}

final restaurantOfflineRepositoryProvider =
    Provider<RestaurantOfflineRepository>((ref) {
      final storage = ref.watch(restaurantOfflineCacheProvider);
      if (!storage.isPersistentAvailable) {
        return RestaurantOfflineRepository(storage, 'disabled');
      }
      final owner = ref.watch(accountScopeProvider);
      final locale = ref.watch(localeControllerProvider);
      final suffix = ref.read(cacheKeySuffixProvider)();
      return RestaurantOfflineRepository(
        storage,
        '${owner}_${locale.code}_$suffix',
      );
    });

class RestaurantOfflineRevision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final restaurantOfflineRevisionProvider =
    NotifierProvider<RestaurantOfflineRevision, int>(
      RestaurantOfflineRevision.new,
    );
