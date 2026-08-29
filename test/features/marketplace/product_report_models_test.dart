import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/store/data/store_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _soldOutTests();
  group('ProductSummary.inReview', () {
    test('in_review=true parse qilinadi', () {
      final product = ProductSummary.fromJson({
        'id': 'p1',
        'name': 'Choynak',
        'description': '',
        'price': '1000.00',
        'unit': 'dona',
        'is_purchasable': false,
        'in_review': true,
        'store_type': 'household',
        'variants': <Map<String, dynamic>>[],
      });
      expect(product.inReview, isTrue);
      expect(product.isPurchasable, isFalse);
    });

    test("maydon bo'lmasa default false (eski backend javobi)", () {
      final product = ProductSummary.fromJson({
        'id': 'p1',
        'name': 'Choynak',
        'description': '',
        'price': '1000.00',
        'unit': 'dona',
        'store_type': 'household',
        'variants': <Map<String, dynamic>>[],
      });
      expect(product.inReview, isFalse);
    });
  });

  group('StoreLandingData.reportButtonEnabled', () {
    Map<String, dynamic> landingJson({Object? flag}) => {
      'store': {'store_type': 'household', 'label': 'Xozmak'},
      'categories': <Object>[],
      'stores': <Object>[],
      'banners': <Object>[],
      'report_button_enabled': ?flag,
    };

    test('true parse qilinadi', () {
      final landing = StoreLandingData.fromJson(landingJson(flag: true));
      expect(landing.reportButtonEnabled, isTrue);
    });

    test("maydon bo'lmasa default false", () {
      final landing = StoreLandingData.fromJson(landingJson());
      expect(landing.reportButtonEnabled, isFalse);
    });
  });
}

// ─── Tugagan taom (botga chiqarilmagan) ──────────────────────────────────────

void _soldOutTests() {
  group('ProductSummary.isSoldOut', () {
    test('is_sold_out=true parse qilinadi', () {
      final product = ProductSummary.fromJson({
        'id': 'p1',
        'name': 'Lag\'mon',
        'description': '',
        'price': '30000.00',
        'unit': 'porsiya',
        'is_purchasable': false,
        'is_sold_out': true,
        'store_type': 'restaurant',
        'variants': <Map<String, dynamic>>[],
      });
      expect(product.isSoldOut, isTrue);
      expect(product.isPurchasable, isFalse);
    });

    test("maydon bo'lmasa default false", () {
      final product = ProductSummary.fromJson({
        'id': 'p1',
        'name': 'Sut',
        'description': '',
        'price': '12000.00',
        'unit': 'dona',
        'store_type': 'grocery',
        'variants': <Map<String, dynamic>>[],
      });
      expect(product.isSoldOut, isFalse);
    });
  });
}
