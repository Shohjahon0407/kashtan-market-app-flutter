import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/uzbek_transliterator.dart';
import '../../../core/store_scope/store_type.dart';
import '../../store/domain/store_landing_controller.dart';
import '../data/product_models.dart';
import '../presentation/widgets/photo_category_landing.dart';
import 'catalog_controller.dart';

/// Restoran qidiruv sahifasidagi tezkor kalit so'z (`#baliq`, `#osh` ...).
///
/// Bosilganda ikki manba birlashadi: mos KATEGORIYA ovqatlari va NOMIDA shu
/// so'z bor ovqatlar (masalan "Mol sho‘rva" — "1-taomlar" kategoriyasida).
class RestaurantKeyword {
  const RestaurantKeyword({
    required this.label,
    required this.categoryKeys,
    required this.namePrefixes,
  });

  /// Ekrandagi matn — barcha tillarda bir xil.
  final String label;

  /// `normalizeCategoryAssetKey` ko'rinishidagi kategoriya nomlari.
  final List<String> categoryKeys;

  /// Ovqat nomidagi biror so'z shulardan biri bilan BOSHLANSA mos keladi.
  final List<String> namePrefixes;

  @override
  bool operator ==(Object other) =>
      other is RestaurantKeyword && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// Egasi bergan tartibda.
const restaurantSearchKeywords = <RestaurantKeyword>[
  RestaurantKeyword(
    label: '#baliq',
    categoryKeys: ['baliq', 'baliqlar'],
    namePrefixes: ['baliq'],
  ),
  RestaurantKeyword(
    label: '#halim',
    categoryKeys: ['halim', 'xalim'],
    namePrefixes: ['halim', 'xalim'],
  ),
  RestaurantKeyword(
    label: '#osh',
    categoryKeys: ['osh', 'oshlar'],
    namePrefixes: ['osh'],
  ),
  RestaurantKeyword(
    label: '#shashlik',
    categoryKeys: ['shashlik', 'shashliklar'],
    namePrefixes: ['shashlik'],
  ),
  RestaurantKeyword(
    label: "#sho'rva",
    categoryKeys: ["sho'rva", "sho'rvalar"],
    namePrefixes: ["sho'rva", 'shorva'],
  ),
  RestaurantKeyword(
    label: '#jizz',
    categoryKeys: ['jiz', 'jizz'],
    namePrefixes: ['jiz'],
  ),
  RestaurantKeyword(
    label: '#hasib',
    categoryKeys: ['hasib', 'xasib'],
    namePrefixes: ['hasib', 'xasib'],
  ),
];

/// Lotin, kichik harf, apostroflar bitta `'` ga.
String normalizeDishText(String value) => UzbekTransliterator.toLatin(
  value,
).toLowerCase().replaceAll(RegExp('[‘’`ʻʼ´]'), "'");

/// So'z boshidan solishtirish: "Go‘shtli osh" → `#osh` ha, "Qo‘y go‘sht" → yo'q.
bool dishNameMatches(String name, RestaurantKeyword keyword) {
  final words = normalizeDishText(
    name,
  ).split(RegExp(r"[^a-z0-9']+")).where((word) => word.isNotEmpty);
  for (final word in words) {
    final bare = word.replaceAll("'", '');
    for (final prefix in keyword.namePrefixes) {
      if (word.startsWith(prefix) || bare.startsWith(prefix)) return true;
    }
  }
  return false;
}

/// Kalit so'zga mos kategoriyalar va ularning bola kategoriyalari.
Set<String> keywordCategoryIds(
  Iterable<ProductCategory> categories,
  RestaurantKeyword keyword,
) {
  final list = categories.toList();
  final ids = <String>{
    for (final category in list)
      if (keyword.categoryKeys.contains(
        normalizeCategoryAssetKey(category.canonicalName ?? category.name),
      ))
        category.id,
  };
  var changed = ids.isNotEmpty;
  while (changed) {
    changed = false;
    for (final category in list) {
      if (category.parentId != null &&
          ids.contains(category.parentId) &&
          ids.add(category.id)) {
        changed = true;
      }
    }
  }
  return ids;
}

/// Avval kategoriya ovqatlari (menyu tartibida), keyin nomi mos qolganlari.
List<ProductSummary> filterRestaurantKeyword(
  List<ProductSummary> menu,
  Set<String> categoryIds,
  RestaurantKeyword keyword,
) {
  final byCategory = <ProductSummary>[];
  final byName = <ProductSummary>[];
  for (final product in menu) {
    if (categoryIds.contains(product.category?.id)) {
      byCategory.add(product);
    } else if (dishNameMatches(product.name, keyword)) {
      byName.add(product);
    }
  }
  return [...byCategory, ...byName];
}

final restaurantKeywordResultsProvider = FutureProvider.autoDispose
    .family<List<ProductSummary>, RestaurantKeyword>((ref, keyword) async {
      final api = ref.watch(catalogApiProvider);
      final landing = await ref.watch(
        storeLandingProvider(StoreType.restaurant).future,
      );
      final menu = await api.fetchAllProducts(
        storeType: StoreType.restaurant.wire,
      );
      return filterRestaurantKeyword(
        menu,
        keywordCategoryIds(landing.categories, keyword),
        keyword,
      );
    });
