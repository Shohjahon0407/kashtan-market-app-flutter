import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_read.dart';
import '../../catalog/data/product_models.dart';

class ForYouPage {
  const ForYouPage({required this.items, required this.hasMore});

  final List<ProductSummary> items;
  final bool hasMore;
}

/// Shaxsiy tavsiyalar API'si (`/recommendations/*`).
class RecommendationsApi {
  const RecommendationsApi(this._client);

  final ApiClient _client;

  /// Ko'rish/qidiruv hodisalari (batch). Xato chaqiruvchiga — navbat saqlanadi.
  Future<void> postEvents(List<Map<String, Object?>> events) async {
    if (events.isEmpty) return;
    await _client.post(Api.recoEvents, body: {'events': events});
  }

  /// "Siz uchun" — cheksiz gorizontal lentaning bir bo'lagi. [session]
  /// bitta scroll davomida o'zgarmaydi (server tartibni shu bo'yicha
  /// saqlaydi); [storeType] berilmasa — barcha do'konlardan.
  Future<ForYouPage> forYou({
    String? storeType,
    String? categoryId,
    bool imagesOnly = false,
    int limit = 20,
    int offset = 0,
    int? session,
  }) async {
    final data = await _client.get(
      Api.recoForYou,
      query: {
        'limit': limit,
        if (offset > 0) 'offset': offset,
        'session': ?session,
        'store_type': ?storeType,
        'category': ?categoryId,
        if (imagesOnly) 'images_only': true,
      },
    );
    final map = JsonRead.map(data);
    return ForYouPage(
      items: _results(data),
      hasMore: JsonRead.boolean(map?['has_more']),
    );
  }

  Future<List<ProductSummary>> similar(
    String productId, {
    int limit = 12,
  }) async {
    final data = await _client.get(
      Api.recoSimilar(productId),
      query: {'limit': limit},
    );
    return _results(data);
  }

  List<ProductSummary> _results(Object? data) {
    final map = JsonRead.map(data);
    return JsonRead.list(map?['results'], ProductSummary.fromJson);
  }
}
