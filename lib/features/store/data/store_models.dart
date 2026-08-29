import 'dart:ui' show Color;

import '../../../core/config/app_config.dart';
import '../../../core/network/json_read.dart';
import '../../../core/utils/hex_color.dart';
import '../../catalog/data/product_models.dart';

class StoreInfo {
  const StoreInfo({
    required this.id,
    required this.name,
    required this.storeTypeWire,
    this.description = '',
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) => StoreInfo(
    id: JsonRead.string(json['id']),
    name: JsonRead.string(json['name']),
    description: JsonRead.string(json['description']),
    storeTypeWire: JsonRead.string(json['store_type']),
  );

  final String id;
  final String name;
  final String description;
  final String storeTypeWire;
}

class StoreHeader {
  const StoreHeader({
    required this.storeTypeWire,
    required this.label,
    required this.subtitle,
    required this.isEnabled,
    required this.showHeader,
    this.imageUrl,
    this.accentColor,
  });

  factory StoreHeader.fromJson(Map<String, dynamic> json) {
    final style = JsonRead.map(json['style']);
    return StoreHeader(
      storeTypeWire: JsonRead.string(json['store_type']),
      label: JsonRead.string(json['label']),
      subtitle: JsonRead.string(json['subtitle']),
      isEnabled: JsonRead.boolean(json['is_enabled'], fallback: true),
      showHeader: JsonRead.boolean(json['show_store_header'], fallback: true),
      imageUrl: AppConfig.resolveMediaUrl(
        JsonRead.nullableString(json['image'] ?? json['background_image']),
      ),
      accentColor: HexColor.tryParse(
        JsonRead.nullableString(style?['accent_color']),
      ),
    );
  }

  final String storeTypeWire;
  final String label;
  final String subtitle;
  final bool isEnabled;
  final bool showHeader;
  final String? imageUrl;
  final Color? accentColor;
}

class StoreBanner {
  const StoreBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionType,
    this.imageUrl,
    this.targetProductId,
    this.targetCategoryId,
    this.targetBundleId,
    this.bundle,
    this.backgroundColor,
    this.textColor,
  });

  factory StoreBanner.fromJson(Map<String, dynamic> json) {
    final actionType = JsonRead.string(
      json['action_type'] ?? json['target_type'],
    );
    return StoreBanner(
      id: JsonRead.string(json['id']),
      title: JsonRead.string(json['title']),
      subtitle: JsonRead.string(json['subtitle']),
      imageUrl: AppConfig.resolveMediaUrl(
        JsonRead.nullableString(json['image']),
      ),
      actionType: actionType,
      targetProductId: JsonRead.nullableString(
        json['target_product_id'] ??
            (actionType == 'product' ? json['target_id'] : null),
      ),
      targetCategoryId: JsonRead.nullableString(
        json['target_category_id'] ??
            (actionType == 'category' ? json['target_id'] : null),
      ),
      targetBundleId: JsonRead.nullableString(json['target_bundle_id']),
      bundle: _promoBundle(json['bundle']),
      backgroundColor: HexColor.tryParse(
        JsonRead.nullableString(json['background_color']),
      ),
      textColor: HexColor.tryParse(JsonRead.nullableString(json['text_color'])),
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String actionType;
  final String? targetProductId;
  final String? targetCategoryId;
  final String? targetBundleId;
  final PromoBundle? bundle;
  final Color? backgroundColor;
  final Color? textColor;
}

PromoBundle? _promoBundle(Object? value) {
  final map = JsonRead.map(value);
  return map == null ? null : PromoBundle.fromJson(map);
}

class PromoBundleItem {
  const PromoBundleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.imageUrl,
  });

  factory PromoBundleItem.fromJson(Map<String, dynamic> json) =>
      PromoBundleItem(
        productId: JsonRead.string(json['product_id']),
        name: JsonRead.string(json['product_name']),
        quantity: JsonRead.integer(json['quantity'], 1),
        price: JsonRead.string(json['price']),
        imageUrl: AppConfig.resolveMediaUrl(
          JsonRead.nullableString(json['image']),
        ),
      );

  final String productId;
  final String name;
  final int quantity;
  final String price;
  final String? imageUrl;
}

class PromoBundle {
  const PromoBundle({
    required this.id,
    required this.storeTypeWire,
    required this.title,
    required this.description,
    required this.price,
    required this.items,
    this.oldPrice,
    this.imageUrl,
  });

  factory PromoBundle.fromJson(Map<String, dynamic> json) => PromoBundle(
    id: JsonRead.string(json['id']),
    storeTypeWire: JsonRead.string(json['store_type']),
    title: JsonRead.string(json['title']),
    description: JsonRead.string(json['description']),
    price: JsonRead.string(json['bundle_price']),
    oldPrice: JsonRead.nullableString(json['old_price']),
    imageUrl: AppConfig.resolveMediaUrl(JsonRead.nullableString(json['image'])),
    items: JsonRead.list(json['items'], PromoBundleItem.fromJson),
  );

  final String id;
  final String storeTypeWire;
  final String title;
  final String description;
  final String price;
  final String? oldPrice;
  final String? imageUrl;
  final List<PromoBundleItem> items;
}

class ProductSection {
  const ProductSection({
    required this.id,
    required this.title,
    required this.products,
    this.subtitle = '',
    this.categoryId,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? categoryId;
  final List<ProductSummary> products;
}

class StoreLandingData {
  const StoreLandingData({
    required this.header,
    required this.categories,
    required this.stores,
    required this.banners,
    required this.sections,
    this.reportButtonEnabled = false,
  });

  factory StoreLandingData.fromJson(Map<String, dynamic> json) {
    final sections = <ProductSection>[];

    void addSection(String id, String title, Object? raw) {
      final products = JsonRead.list(raw, ProductSummary.fromJson);
      if (products.isNotEmpty) {
        sections.add(ProductSection(id: id, title: title, products: products));
      }
    }

    addSection('featured', '', json['featured_products']);
    addSection('discounted', '', json['discounted_products']);
    addSection('popular', '', json['popular_products']);
    addSection('new', '', json['new_products']);

    for (final raw in (json['promotions'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final products = <ProductSummary>[];
      for (final promotionProduct
          in (raw['promotion_products'] as List? ?? const [])) {
        if (promotionProduct is! Map<String, dynamic>) continue;
        final product = JsonRead.map(promotionProduct['product']);
        if (product != null) products.add(ProductSummary.fromJson(product));
      }
      if (products.isNotEmpty) {
        sections.add(
          ProductSection(
            id: 'promotion-${JsonRead.string(raw['id'])}',
            title: JsonRead.string(raw['title']),
            subtitle: JsonRead.string(raw['description']),
            products: products,
          ),
        );
      }
    }

    for (final raw in (json['styled_category_sections'] as List? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final products = JsonRead.list(raw['products'], ProductSummary.fromJson);
      if (products.isEmpty) continue;
      final category = JsonRead.map(raw['category']);
      sections.add(
        ProductSection(
          id: 'styled-${JsonRead.string(raw['id'])}',
          title: JsonRead.string(raw['title']),
          subtitle: JsonRead.string(raw['subtitle']),
          categoryId: JsonRead.nullableString(category?['id']),
          products: products,
        ),
      );
    }

    final banners = <StoreBanner>[
      ...JsonRead.list(json['top_banners'], StoreBanner.fromJson),
      ...JsonRead.list(json['banners'], StoreBanner.fromJson),
    ];

    return StoreLandingData(
      header: StoreHeader.fromJson(
        JsonRead.map(json['store']) ?? const <String, dynamic>{},
      ),
      categories: JsonRead.list(json['categories'], ProductCategory.fromJson),
      stores: JsonRead.list(json['stores'], StoreInfo.fromJson),
      banners: banners,
      sections: sections,
      reportButtonEnabled: JsonRead.boolean(json['report_button_enabled']),
    );
  }

  final StoreHeader header;
  final List<ProductCategory> categories;
  final List<StoreInfo> stores;
  final List<StoreBanner> banners;
  final List<ProductSection> sections;

  /// Admin yoqqan bo'lsa kartalarda "noto'g'ri mahsulot" tugmasi ko'rinadi
  /// (backend buni faqat household uchun true qaytaradi).
  final bool reportButtonEnabled;
}
