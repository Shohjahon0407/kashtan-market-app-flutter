import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/routing/store_navigation.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('har store uchun 4 tab va nested yo‘llar store-scoped', () {
    final allPaths = <String>{};
    for (final type in StoreType.values) {
      expect(Routes.storeCatalog(type.wire), '/store/${type.wire}/catalog');
      expect(Routes.storeFavorites(type.wire), '/store/${type.wire}/favorites');
      expect(Routes.storeCart(type.wire), '/store/${type.wire}/cart');
      expect(Routes.storeOrders(type.wire), '/store/${type.wire}/orders');
      expect(
        Routes.productDetail(type.wire, 'p-1'),
        '/store/${type.wire}/catalog/product/p-1',
      );
      expect(
        Routes.checkoutAddressEdit(type.wire, 'a-1'),
        '/store/${type.wire}/cart/checkout/address/a-1/edit',
      );
      expect(
        Routes.orderDetail(type.wire, 'o-1'),
        '/store/${type.wire}/orders/o-1',
      );
      allPaths.addAll([
        Routes.storeCatalog(type.wire),
        Routes.storeFavorites(type.wire),
        Routes.storeCart(type.wire),
        Routes.storeOrders(type.wire),
      ]);
    }
    // Har do'kon turi uchun 4 ta tab — yangi tur qo'shilsa avtomatik o'sadi.
    expect(allPaths, hasLength(StoreType.values.length * 4));
  });

  test('noma’lum store groceryga tushmaydi', () {
    expect(StoreType.fromWire('future-store'), isNull);
    expect(
      Routes.unsupportedStoreFor('future-store'),
      contains('/store-unsupported'),
    );
    expect(
      Routes.unsupportedStoreFor('future-store'),
      contains('future-store'),
    );
  });

  test('murojaatlar route turi va store kontekstini encode qiladi', () {
    expect(Routes.requests, '/requests');
    expect(
      Routes.requestsFor(kind: 'missing_product', storeType: 'household'),
      '/requests/missing-product?storeType=household',
    );
    expect(Routes.missingProductRequest, '/requests/missing-product');
    expect(Routes.requestsFor(), '/requests');
    expect(Routes.cart, '/cart');
    expect(Routes.profile, '/profile');
  });

  test('global manzil route’lari store scope’ga bog‘liq emas', () {
    expect(Routes.addresses, '/addresses');
    expect(Routes.addressNew, '/addresses/new');
    expect(Routes.addressEdit('address-1'), '/addresses/address-1/edit');
  });

  test('catalog route optional category queryni encode qiladi', () {
    expect(
      Routes.storeCatalog('household', categoryId: 'category / 1'),
      '/store/household/catalog?category=category+%2F+1',
    );
    expect(
      Routes.storeCatalog('household', categoryId: ''),
      '/store/household/catalog',
    );
    expect(
      Routes.storeCatalogSearch('household'),
      '/store/household/catalog/search',
    );
    expect(
      Routes.storeCategoryProducts('household', 'category / 1'),
      '/store/household/catalog/category/category%20%2F%201',
    );
  });

  test('store tab helper har bir navbar indexini root routega map qiladi', () {
    for (final type in StoreType.values) {
      expect(
        storeTabLocation(type, StoreTab.catalog),
        Routes.storeCatalog(type.wire),
      );
      expect(
        storeTabLocation(type, StoreTab.favorites),
        Routes.storeFavorites(type.wire),
      );
      expect(
        storeTabLocation(type, StoreTab.cart),
        Routes.storeCart(type.wire),
      );
      expect(
        storeTabLocation(type, StoreTab.orders),
        Routes.storeOrders(type.wire),
      );
    }
  });
}
