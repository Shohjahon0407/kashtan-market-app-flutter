import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

ProductSummary _product(
  String id,
  String name, [
  String price = '10000.00',
  String unit = 'dona',
]) => ProductSummary.fromJson({
  'id': id,
  'name': name,
  'description': '',
  'price': price,
  'main_image': null,
  'unit': unit,
  'unit_display': unit == 'kg' ? 'Kilogramm' : 'Dona',
  'is_purchasable': true,
  'store_type': 'shashlik',
  'variants': <Map<String, dynamic>>[],
});

void main() {
  test(
    '21 mahsulot beshta family, ko‘mir va boshqa bo‘limga yo‘qotilmaydi',
    () {
      final products = [
        _product('coal-fast', 'Tez yonar kömir'),
        _product('ilik', 'Mol ilik'),
        _product('dumba', 'Dumba'),
        _product('bez', 'Bez'),
        _product('bone', 'Qöy suyak'),
        _product('ragu', 'Mol ragu'),
        _product('beef-kilo', 'Mol jazz kiloligi', '200000.00'),
        _product('lamb-kilo', "Qo'y jazz kiloligi", '220000.00'),
        _product('liver-stick', 'Jigar', '12000.00'),
        _product('wing-stick', 'Qanot', '12000.00'),
        _product('wing-kilo', 'Qanot kiloligi', '13000.00'),
        _product('beef-stick', 'Mol jazz', '18000.00'),
        _product('lamb-stick', "Qo'y jazz", '21000.00'),
        _product('kilo-mince', 'Kilolik qiyma', '140000.00'),
        _product('bread-mince', 'Non qiyma', '14000.00'),
        _product('mince', 'Qiyma', '12500.00'),
        _product('coal-stone', 'Tosh kömır'),
        _product('skewer', 'Zix'),
        _product('liver-kilo', 'Jigar', '115000.00'),
        _product('beef-fat', 'Mol charvi'),
        _product('lamb-fat', 'Qöy charvi'),
      ];

      final groups = ShashlikCatalogGroups.fromProducts(products);

      expect(groups.families.map((family) => family.key), [
        ShashlikFamilyKey.beefJazz,
        ShashlikFamilyKey.lambJazz,
        ShashlikFamilyKey.chicken,
        ShashlikFamilyKey.liver,
        ShashlikFamilyKey.mince,
      ]);
      expect(groups.families.map((family) => family.products.length), [
        2,
        2,
        2,
        2,
        3,
      ]);
      expect(groups.families.last.products.map((product) => product.id), [
        'mince',
        'bread-mince',
        'kilo-mince',
      ]);
      expect(groups.charcoal.map((product) => product.id), [
        'coal-fast',
        'coal-stone',
      ]);
      expect(groups.other.map((product) => product.id), [
        'ragu',
        'bez',
        'ilik',
        'dumba',
        'bone',
        'skewer',
        'beef-fat',
        'lamb-fat',
      ]);
      final visibleIds = <String>{
        for (final family in groups.families)
          for (final product in family.products) product.id,
        for (final product in groups.charcoal) product.id,
        for (final product in groups.other) product.id,
      };
      expect(visibleIds, hasLength(21));
    },
  );

  test('family mahsulotlari dona va kilogramga to‘g‘ri ajratiladi', () {
    final groups = ShashlikCatalogGroups.fromProducts([
      _product('beef-stick', 'Mol jazz', '18000.00'),
      _product('beef-kilo', 'Mol jazz kiloligi', '200000.00', 'kg'),
      _product('liver-kilo', 'Jigar', '115000.00', 'kg'),
      _product('liver-stick', 'Jigar', '12000.00'),
    ]);

    final beef = groups.families.first;
    expect(beef.measureOf(beef.products.first), ShashlikMeasure.piece);
    expect(beef.measureOf(beef.products.last), ShashlikMeasure.kilogram);
    final liver = groups.families.last;
    expect(liver.measureOf(liver.products.first), ShashlikMeasure.piece);
    expect(liver.measureOf(liver.products.last), ShashlikMeasure.kilogram);
  });

  test(
    'bir xil nomli Jigar narx bo‘yicha zixlangan va kilolikka tartiblanadi',
    () {
      final groups = ShashlikCatalogGroups.fromProducts([
        _product('kilo', 'Jigar', '115000.00'),
        _product('stick', 'Jigar', '12000.00'),
      ]);

      expect(groups.families.single.products.map((item) => item.id), [
        'stick',
        'kilo',
      ]);
    },
  );

  test(
    'noma’lum mahsulot Boshqa bo‘limida qoladi va duplicate ID yo‘qoladi',
    () {
      final groups = ShashlikCatalogGroups.fromProducts([
        _product('new', 'Yangi mahsulot'),
        _product('new', 'Yangi mahsulot nusxasi'),
      ]);

      expect(groups.other, hasLength(1));
      expect(groups.other.single.name, 'Yangi mahsulot');
    },
  );
}
