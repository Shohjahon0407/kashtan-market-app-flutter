import '../../../core/config/app_config.dart';
import '../../../core/network/json_read.dart';
import '../../catalog/data/product_models.dart';

class VideoStore {
  const VideoStore({
    required this.id,
    required this.name,
    required this.storeType,
  });

  factory VideoStore.fromJson(Map<String, dynamic> json) => VideoStore(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    storeType: JsonRead.string(json['store_type']),
  );

  final String id;
  final String name;
  final String storeType;
}

class VideoProduct {
  const VideoProduct({
    required this.id,
    required this.name,
    required this.storeType,
    required this.price,
    required this.isPurchasable,
    this.imageUrl,
  });

  factory VideoProduct.fromJson(Map<String, dynamic> json) => VideoProduct(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    storeType: JsonRead.string(json['store_type']),
    price: JsonRead.string(json['price']),
    isPurchasable: JsonRead.boolean(json['is_purchasable'], fallback: true),
    imageUrl: AppConfig.resolveMediaUrl(JsonRead.nullableString(json['image'])),
  );

  final String id;
  final String name;
  final String storeType;
  final String price;
  final bool isPurchasable;
  final String? imageUrl;
}

class StoreVideo {
  const StoreVideo({
    required this.id,
    required this.videoUrl,
    required this.title,
    required this.store,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.publishedAt,
    this.posterUrl,
    this.product,
    this.duration,
  });

  factory StoreVideo.fromJson(Map<String, dynamic> json) {
    final store = JsonRead.map(json['store']);
    final product = JsonRead.map(json['product']);
    return StoreVideo(
      id: JsonRead.string(json['id']),
      videoUrl:
          AppConfig.resolveMediaUrl(
            JsonRead.nullableString(json['video_url']),
          ) ??
          '',
      posterUrl: AppConfig.resolveMediaUrl(
        JsonRead.nullableString(json['poster_url']),
      ),
      title: JsonRead.string(json['title']),
      store: VideoStore.fromJson(store ?? const <String, dynamic>{}),
      product: product == null ? null : VideoProduct.fromJson(product),
      duration: JsonRead.nullableString(json['duration']),
      likesCount: JsonRead.integer(json['likes_count']),
      commentsCount: JsonRead.integer(json['comments_count']),
      isLiked: JsonRead.boolean(json['is_liked']),
      publishedAt: DateTime.tryParse(JsonRead.string(json['published_at'])),
    );
  }

  final String id;
  final String videoUrl;
  final String? posterUrl;
  final String title;
  final VideoStore store;
  final VideoProduct? product;
  final String? duration;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final DateTime? publishedAt;

  StoreVideo copyWith({int? likesCount, int? commentsCount, bool? isLiked}) =>
      StoreVideo(
        id: id,
        videoUrl: videoUrl,
        posterUrl: posterUrl,
        title: title,
        store: store,
        product: product,
        duration: duration,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        isLiked: isLiked ?? this.isLiked,
        publishedAt: publishedAt,
      );
}

class VideoProductRail {
  const VideoProductRail({
    required this.products,
    required this.storeType,
    this.category,
    this.categoryId,
  });

  factory VideoProductRail.fromJson(Map<String, dynamic> json) {
    final category = JsonRead.map(json['category']);
    final seeAll = JsonRead.map(json['see_all']);
    return VideoProductRail(
      products: JsonRead.list(json['results'], ProductSummary.fromJson),
      storeType: JsonRead.string(seeAll?['store_type']),
      category: category == null ? null : JsonRead.string(category['name']),
      categoryId: JsonRead.nullableString(seeAll?['category_id']),
    );
  }

  final List<ProductSummary> products;
  final String storeType;
  final String? category;
  final String? categoryId;

  /// Stable partition also protects rails returned by older backend versions.
  List<ProductSummary> get imageFirstProducts {
    final withImages = <ProductSummary>[];
    final withoutImages = <ProductSummary>[];
    for (final product in products) {
      final hasImage = product.imageUrl?.trim().isNotEmpty ?? false;
      (hasImage ? withImages : withoutImages).add(product);
    }
    return [...withImages, ...withoutImages];
  }
}

class VideoCommentUser {
  const VideoCommentUser({required this.id, required this.name});

  factory VideoCommentUser.fromJson(Map<String, dynamic> json) =>
      VideoCommentUser(
        id: JsonRead.string(json['id']),
        name: JsonRead.string(json['name']),
      );

  final String id;
  final String name;
}

class VideoComment {
  const VideoComment({
    required this.id,
    required this.user,
    required this.text,
    required this.isOwner,
    required this.createdAt,
    this.isPending = false,
  });

  factory VideoComment.fromJson(Map<String, dynamic> json) {
    final user = JsonRead.map(json['user']);
    return VideoComment(
      id: JsonRead.string(json['id']),
      user: VideoCommentUser.fromJson(user ?? const <String, dynamic>{}),
      text: JsonRead.string(json['text']),
      isOwner: JsonRead.boolean(json['is_owner']),
      createdAt:
          DateTime.tryParse(JsonRead.string(json['created_at'])) ??
          DateTime.now(),
    );
  }

  final String id;
  final VideoCommentUser user;
  final String text;
  final bool isOwner;
  final DateTime createdAt;
  final bool isPending;
}
