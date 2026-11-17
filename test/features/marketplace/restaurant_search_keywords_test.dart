import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/restaurant_search_keywords.dart';
import 'package:flutter_test/flutter_test.dart';

RestaurantKeyword _keyword(String label) =>
    restaurantSearchKeywords.firstWhere((k) => k.label == label);

void main() {
  test('kalit so‘zlar egasi bergan tartibda', () {
    expect(restaurantSearchKeywords.map((k) => k.label), [
      '#baliq',
      '#halim',
      '#osh',
      '#shashlik',
      "#sho'rva",
      '#jizz',
      '#hasib',
    ]);
  });

  test(
    'nom so‘z boshidan, apostrof va kirilldan qat’i nazar solishtiriladi',
    () {
      final osh = _keyword('#osh');
      expect(dishNameMatches('Go‘shtli osh', osh), isTrue);
      expect(dishNameMatches('To‘y oshi', osh), isTrue);
      expect(dishNameMatches('Qo‘y go‘sht', osh), isFalse);
      expect(dishNameMatches('Toshkent salati', osh), isFalse);

      final shorva = _keyword("#sho'rva");
      expect(dishNameMatches('Mol sho‘rva', shorva), isTrue);
      expect(dishNameMatches('Mol shoʻrva', shorva), isTrue);
      expect(dishNameMatches('Mol shorva', shorva), isTrue);
      expect(dishNameMatches('Мол шўрва', shorva), isTrue);

      expect(dishNameMatches('Xalim', _keyword('#halim')), isTrue);
      expect(dishNameMatches('Jiz biz', _keyword('#jizz')), isTrue);
      expect(dishNameMatches('Xasib', _keyword('#hasib')), isTrue);
    },
  );

  test('kategoriya bolalari bilan topiladi', () {
    const categories = [
      ProductCategory(
        id: 'fish',
        name: 'BALIQ',
        canonicalName: 'Baliq',
        storeTypeWire: 'restaurant',
      ),
      ProductCategory(
        id: 'fried-fish',
        name: 'Qovurilgan',
        parentId: 'fish',
        storeTypeWire: 'restaurant',
      ),
      ProductCategory(id: 'plov', name: 'Oshlar', storeTypeWire: 'restaurant'),
    ];
    expect(keywordCategoryIds(categories, _keyword('#baliq')), {
      'fish',
      'fried-fish',
    });
    expect(keywordCategoryIds(categories, _keyword('#osh')), {'plov'});
    expect(keywordCategoryIds(categories, _keyword('#hasib')), isEmpty);
  });
}
