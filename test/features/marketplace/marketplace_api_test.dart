import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorites_api.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef RecordedRequest = ({
  String method,
  String path,
  Map<String, dynamic> query,
  Object? body,
});

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final ResponseBody Function(RequestOptions options, Object? body) handler;
  final List<RecordedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes));
    }
    requests.add((
      method: options.method,
      path: options.path,
      query: Map<String, dynamic>.from(options.queryParameters),
      body: body,
    ));
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, dynamic> _product({String storeType = 'household'}) => {
  'id': 'product-1',
  'name': 'Sovun',
  'description': '',
  'price': '12000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': storeType,
  'store': {'id': 'store-1', 'name': 'Xozmak', 'store_type': storeType},
  'variants': <Map<String, dynamic>>[],
};

Map<String, dynamic> _cart({int quantity = 1}) => {
  'id': 'cart-1',
  'store_type': 'household',
  'items': quantity == 0
      ? <Map<String, dynamic>>[]
      : [
          {
            'id': 'item-1',
            'product': _product(),
            'variant': null,
            'quantity': quantity,
            'selected_addons': <Map<String, dynamic>>[],
            'note': '',
            'subtotal': '${12000 * quantity}.00',
          },
        ],
  'total_items': quantity == 0 ? 0 : 1,
  'total_quantity': quantity,
  'subtotal': '${12000 * quantity}.00',
};

Map<String, dynamic> _address() => {
  'id': 'address-1',
  'title': 'Uy',
  'district': 'Parkent',
  'neighborhood': 'Markaz',
  'street': 'Mustaqillik',
  'house': '10',
  'apartment': '',
  'landmark': '',
  'latitude': '41.308119',
  'longitude': '69.564014',
  'is_default': true,
};

Map<String, dynamic> _order() => {
  'id': 'order-1',
  'order_number': 'BK-1',
  'store_type': 'household',
  'fulfillment_type': 'delivery',
  'status': 'pending',
  'status_label': 'Ko‘rib chiqilmoqda',
  'payment_method': 'cash_to_courier',
  'payment_status': 'pending',
  'subtotal': '12000.00',
  'delivery_fee': '5000.00',
  'total': '17000.00',
  'items': <Map<String, dynamic>>[],
  'status_history': <Map<String, dynamic>>[],
  'can_confirm_received': false,
  'created_at': '2026-07-31T09:00:00Z',
};

void main() {
  late _ScriptedAdapter adapter;

  ApiClient client(
    ResponseBody Function(RequestOptions options, Object? body) handler,
  ) {
    adapter = _ScriptedAdapter(handler);
    return ApiClient.create(
      tokenStore: InMemoryTokenStore(access: 'access', refresh: 'refresh'),
      apiLang: () => 'uz',
      script: () => UzScript.none,
      refresh: (_) async => null,
      onSessionExpired: () async {},
      adapter: adapter,
    );
  }

  test(
    'store qidiruvi dedicated endpointga faqat store_type va q yuboradi',
    () async {
      final api = CatalogApi(
        client((options, body) {
          return _json({
            'next': null,
            'previous': null,
            'results': [_product()],
          });
        }),
      );

      final page = await api.fetchProducts(
        storeType: 'household',
        query: '  temir  ',
      );

      expect(page.items.single.name, 'Sovun');
      expect(
        adapter.requests.single.path,
        endsWith('/catalog/products/search/'),
      );
      expect(adapter.requests.single.query, {
        'store_type': 'household',
        'page_size': 20,
        'q': 'temir',
        'lang': 'uz',
      });
      expect(adapter.requests.single.query, isNot(contains('category')));
    },
  );

  test(
    'cart endpointlari store_type va konfiguratsiyani aynan yuboradi',
    () async {
      final api = CartApi(
        client((options, body) {
          if (options.method == 'GET') return _json(_cart());
          return _json(options.method == 'DELETE' ? {} : _cart(quantity: 2));
        }),
      );

      final cart = await api.fetch('household');
      await api.addItem(
        storeType: 'household',
        configuration: const CartConfiguration(
          productId: 'product-1',
          variantId: 'variant-1',
          addons: [SelectedAddon(id: 'addon-1')],
          note: 'kam tuz',
        ),
        quantity: 2,
      );
      await api.updateQuantity('item-1', 3);
      await api.deleteItem('item-1');
      await api.clear('household');

      expect(cart.storeTypeWire, 'household');
      expect(adapter.requests[0].query['store_type'], 'household');
      expect(adapter.requests[1].body, {
        'store_type': 'household',
        'product_id': 'product-1',
        'quantity': 2,
        'variant_id': 'variant-1',
        'selected_addons': [
          {'id': 'addon-1'},
        ],
        'note': 'kam tuz',
      });
      expect(adapter.requests[2].body, {'quantity': 3});
      expect(adapter.requests[3].method, 'DELETE');
      expect(adapter.requests[4].query['store_type'], 'household');
    },
  );

  test('favorites global bare-list va toggle kontrakti', () async {
    final api = FavoritesApi(
      client((options, body) {
        if (options.method == 'GET') {
          return _json([
            {'id': 'favorite-1', 'product': _product()},
          ]);
        }
        return _json({'product_id': 'product-1', 'is_favorite': true});
      }),
    );

    final favorites = await api.fetch();
    final selected = await api.toggle('product-1');
    expect(favorites.single.product.id, 'product-1');
    expect(selected, isTrue);
    expect(adapter.requests.last.path, '/favorites/product-1/toggle/');
  });

  test('address CRUD, estimate va pickup branch wire kontrakti', () async {
    final api = CheckoutApi(
      client((options, body) {
        if (options.path == '/addresses/' && options.method == 'GET') {
          return _json([_address()]);
        }
        if (options.path == '/delivery/estimate/') {
          return _json({
            'available': true,
            'distance_km': '2.50',
            'delivery_price': '8000.00',
          });
        }
        if (options.path.endsWith('/branches/')) {
          return _json([
            {
              'id': 'branch-1',
              'store': {
                'id': 'store-1',
                'name': 'Xozmak',
                'store_type': 'household',
              },
              'name': 'Markaziy filial',
              'address': 'Parkent',
              'phone': '+998901234567',
              'is_pickup_available': true,
              'is_active': true,
            },
          ]);
        }
        return _json(_address());
      }),
    );
    expect((await api.fetchAddresses()).single.id, 'address-1');
    await api.createAddress(
      const UserAddress(
        id: '',
        title: 'Uy',
        latitude: 41.308119,
        longitude: 69.564014,
        isDefault: true,
      ),
    );
    final estimate = await api.estimate(
      storeType: 'household',
      latitude: 41.308119,
      longitude: 69.564014,
    );
    final branches = await api.fetchBranches('store-1');

    final createBody = adapter.requests[1].body! as Map<String, dynamic>;
    expect(createBody, {
      'title': 'Uy',
      'latitude': 41.308119,
      'longitude': 69.564014,
      'is_default': true,
    });
    expect(adapter.requests[2].body, {
      'store_type': 'household',
      'latitude': 41.308119,
      'longitude': 69.564014,
    });
    expect(estimate.available, isTrue);
    expect(branches.single.isPickupAvailable, isTrue);
  });

  test(
    'order create payment yubormaydi va list offset parsing ishlaydi',
    () async {
      final api = OrdersApi(
        client((options, body) {
          if (options.method == 'GET') {
            return _json({
              'count': 1,
              'next': null,
              'previous': null,
              'results': [_order()],
            });
          }
          return _json(_order(), 201);
        }),
      );

      final page = await api.fetch(storeType: 'household', period: 'today');
      await api.create(
        storeType: 'household',
        fulfillmentType: FulfillmentType.delivery,
        paymentMethod: 'payme',
        addressId: 'address-1',
        note: 'tezroq',
      );

      expect(page.count, 1);
      expect(adapter.requests.first.query['store_type'], 'household');
      expect(adapter.requests.first.query['period'], 'today');
      final body = adapter.requests.last.body! as Map<String, dynamic>;
      expect(body, {
        'store_type': 'household',
        'fulfillment_type': 'delivery',
        'payment_method': 'payme',
        'address_id': 'address-1',
        'customer_note': 'tezroq',
      });
      // Backend hozir bu kalitni e'tiborsiz qoldiradi, lekin app oldindan
      // yuboradi — qabul qila boshlaganda yangilanish shart bo'lmaydi.
      expect(body['payment_method'], 'payme');
    },
  );
}
