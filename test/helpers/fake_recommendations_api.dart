import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/recommendations/data/recommendations_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tarmoqsiz tavsiya API'si: Home "Siz uchun" testlarda real HTTP'ga
/// chiqmasin (Dio taymerlari test oxirida osilib qolardi).
class FakeRecommendationsApi extends Fake implements RecommendationsApi {
  FakeRecommendationsApi({
    this.forYouItems = const [],
    this.similarItems = const {},
  });

  final List<ProductSummary> forYouItems;
  final Map<String, List<ProductSummary>> similarItems;
  final List<List<Map<String, Object?>>> postedBatches = [];
  final List<({int offset, int? session})> forYouRequests = [];
  int forYouCalls = 0;

  /// Berilsa — sahifalab qaytaradi (cheksiz scroll testlari).
  List<ProductSummary>? pagedItems;

  @override
  Future<void> postEvents(List<Map<String, Object?>> events) async {
    postedBatches.add(List.of(events));
  }

  @override
  Future<ForYouPage> forYou({
    String? storeType,
    int limit = 20,
    int offset = 0,
    int? session,
  }) async {
    forYouCalls++;
    forYouRequests.add((offset: offset, session: session));
    final all = pagedItems;
    if (all == null) return ForYouPage(items: forYouItems, hasMore: false);
    final end = (offset + limit).clamp(0, all.length);
    return ForYouPage(
      items: all.sublist(offset.clamp(0, all.length), end),
      hasMore: end < all.length,
    );
  }

  @override
  Future<List<ProductSummary>> similar(
    String productId, {
    int limit = 12,
  }) async => similarItems[productId] ?? const [];
}
