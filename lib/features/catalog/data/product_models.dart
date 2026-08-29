import '../../../core/config/app_config.dart';
import '../../../core/network/json_read.dart';
import '../../../core/store_scope/store_type.dart';

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.storeTypeWire,
    this.parentId,
    this.imageUrl,
    this.iconUrl,
    this.productCount = 0,
    this.sortOrder = 0,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: JsonRead.string(json['id']),
        name: JsonRead.string(json['name']),
        storeTypeWire: JsonRead.string(json['store_type']),
        parentId: JsonRead.nullableString(json['parent']),
        imageUrl: AppConfig.resolveMediaUrl(
          JsonRead.nullableString(json['image_url'] ?? json['image']),
        ),
        iconUrl: AppConfig.resolveMediaUrl(
          JsonRead.nullableString(json['icon_url'] ?? json['icon']),
        ),
        productCount: JsonRead.integer(json['product_count']),
        sortOrder: JsonRead.integer(json['sort_order']),
      );

  final String id;
  final String name;
  final String storeTypeWire;
  final String? parentId;
  final String? imageUrl;
  final String? iconUrl;
  final int productCount;
  final int sortOrder;
}

class ProductStore {
  const ProductStore({
    required this.id,
    required this.name,
    required this.storeTypeWire,
  });

  factory ProductStore.fromJson(Map<String, dynamic> json) => ProductStore(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    storeTypeWire: JsonRead.string(json['store_type']),
  );

  final String id;
  final String name;
  final String storeTypeWire;
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.isDefault,
    required this.isActive,
    required this.stockQuantity,
    this.oldPrice,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    price: JsonRead.string(json['price']),
    oldPrice: JsonRead.nullableString(json['old_price']),
    unit: JsonRead.string(json['unit_display'] ?? json['unit']),
    isDefault: JsonRead.boolean(json['is_default']),
    isActive: JsonRead.boolean(json['is_active'], fallback: true),
    stockQuantity: JsonRead.integer(json['stock_quantity']),
  );

  final String id;
  final String name;
  final String price;
  final String? oldPrice;
  final String unit;
  final bool isDefault;
  final bool isActive;
  final int stockQuantity;
}

class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    required this.isMain,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    id: JsonRead.string(json['id']),
    url: AppConfig.resolveMediaUrl(JsonRead.nullableString(json['image'])),
    isMain: JsonRead.boolean(json['is_main']),
  );

  final String id;
  final String? url;
  final bool isMain;
}

class AddonOption {
  const AddonOption({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
  });

  factory AddonOption.fromJson(Map<String, dynamic> json) => AddonOption(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    price: JsonRead.string(json['price']),
    isAvailable: JsonRead.boolean(json['is_available'], fallback: true),
  );

  final String id;
  final String name;
  final String price;
  final bool isAvailable;
}

class AddonGroup {
  const AddonGroup({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.isRequired,
    required this.minSelect,
    required this.maxSelect,
    required this.options,
  });

  factory AddonGroup.fromJson(Map<String, dynamic> json) => AddonGroup(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    selectionType: JsonRead.string(json['selection_type'], 'multiple'),
    isRequired: JsonRead.boolean(json['is_required']),
    minSelect: JsonRead.integer(json['min_select']),
    maxSelect: JsonRead.integer(json['max_select']),
    options: JsonRead.list(json['options'], AddonOption.fromJson),
  );

  final String id;
  final String name;
  final String selectionType;
  final bool isRequired;
  final int minSelect;
  final int maxSelect;
  final List<AddonOption> options;
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.unit,
    required this.isPurchasable,
    required this.storeTypeWire,
    required this.variants,
    this.imageCount = 0,
    this.oldPrice,
    this.category,
    this.store,
    this.preparationTimeMinutes,
    this.requiresConfigurationFromApi = false,
    this.inReview = false,
    this.isSoldOut = false,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) => ProductSummary(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    description: JsonRead.string(json['description']),
    price: JsonRead.string(json['price']),
    oldPrice: JsonRead.nullableString(json['old_price']),
    imageUrl: AppConfig.resolveMediaUrl(
      JsonRead.nullableString(json['main_image'] ?? json['image']),
    ),
    imageCount: JsonRead.integer(json['image_count']),
    unit: JsonRead.string(json['unit_display'] ?? json['unit']),
    isPurchasable: JsonRead.boolean(json['is_purchasable'], fallback: true),
    // Pending report bo'lsa true — karta ko'rinadi, lekin sotib bo'lmaydi.
    inReview: JsonRead.boolean(json['in_review']),
    // Restoran taomi hozir sotuvda emas (tugadi / botga chiqarilmagan).
    isSoldOut: JsonRead.boolean(json['is_sold_out']),
    storeTypeWire: JsonRead.string(json['store_type'] ?? json['product_type']),
    category: _productCategory(json['category']),
    store: _productStore(json['store']),
    variants: JsonRead.list(json['variants'], ProductVariant.fromJson),
    preparationTimeMinutes: json['preparation_time_minutes'] == null
        ? null
        : JsonRead.integer(json['preparation_time_minutes']),
    requiresConfigurationFromApi: JsonRead.boolean(
      json['requires_configuration'],
    ),
  );

  final String id;
  final String name;
  final String description;
  final String price;
  final String? oldPrice;
  final String? imageUrl;
  final int imageCount;
  final String unit;
  final bool isPurchasable;
  final String storeTypeWire;
  final ProductCategory? category;
  final ProductStore? store;
  final List<ProductVariant> variants;
  final int? preparationTimeMinutes;

  /// Summary API detail ochmasdan turib majburiy addon borligini bildiradi.
  /// Eski backend bu maydonni yubormasa, faqat real variantlar detailga olib
  /// o'tadi; restoran turi o'z-o'zidan konfiguratsiya talabi emas.
  final bool requiresConfigurationFromApi;

  /// Mahsulot admin tekshiruvida (rasm/kategoriya xatosi xabar qilingan).
  final bool inReview;

  /// Restoran taomi tugagan — kartada "Tugadi" yozuvi chiqadi.
  final bool isSoldOut;

  StoreType? get storeType => StoreType.fromWire(storeTypeWire);
  bool get requiresConfiguration =>
      variants.isNotEmpty || requiresConfigurationFromApi;
}

ProductCategory? _productCategory(Object? value) {
  final map = JsonRead.map(value);
  return map == null ? null : ProductCategory.fromJson(map);
}

ProductStore? _productStore(Object? value) {
  final map = JsonRead.map(value);
  return map == null ? null : ProductStore.fromJson(map);
}

class ProductDetail {
  const ProductDetail({
    required this.product,
    required this.images,
    required this.addonGroups,
    required this.relatedProducts,
    this.canReview = false,
    this.hasReviewed = false,
    this.userReviewId,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
    product: ProductSummary.fromJson(json),
    images: JsonRead.list(json['images'], ProductImage.fromJson),
    addonGroups: JsonRead.list(json['addon_groups'], AddonGroup.fromJson),
    relatedProducts: JsonRead.list(
      json['related_products'],
      ProductSummary.fromJson,
    ),
    canReview: JsonRead.boolean(json['can_review']),
    hasReviewed: JsonRead.boolean(json['has_reviewed']),
    userReviewId: JsonRead.nullableString(json['user_review_id']),
  );

  final ProductSummary product;
  final List<ProductImage> images;
  final List<AddonGroup> addonGroups;
  final List<ProductSummary> relatedProducts;
  final bool canReview;
  final bool hasReviewed;
  final String? userReviewId;

  bool get requiresConfiguration =>
      product.variants.isNotEmpty || addonGroups.isNotEmpty;
}
