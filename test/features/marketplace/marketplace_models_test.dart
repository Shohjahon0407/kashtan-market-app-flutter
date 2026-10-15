import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorite_models.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/store/data/store_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> productJson({
  String id = 'product-1',
  String storeType = 'restaurant',
  bool purchasable = true,
}) => {
  'id': id,
  'name': 'Osh',
  'description': 'Mazali osh',
  'price': '35000.00',
  'old_price': '40000.00',
  'main_image': '/media/osh.jpg',
  'image_count': 3,
  'unit_display': 'porsiya',
  'is_purchasable': purchasable,
  'store_type': storeType,
  'store': {'id': 'store-1', 'name': 'Restoran', 'store_type': storeType},
  'category': {'id': 'category-1', 'name': 'Taomlar', 'store_type': storeType},
  'variants': [
    {
      'id': 'variant-1',
      'name': 'Katta',
      'price': '45000.00',
      'old_price': null,
      'unit_display': 'porsiya',
      'is_default': true,
      'is_active': true,
      'stock_quantity': 8,
    },
  ],
};

void main() {
  test('address title va koordinatalargina yangi request uchun yetarli', () {
    const address = UserAddress(
      id: '',
      title: 'Uy',
      latitude: 41.311081,
      longitude: 69.240563,
      isDefault: true,
    );

    expect(address.toRequestJson(), {
      'title': 'Uy',
      'latitude': 41.311081,
      'longitude': 69.240563,
      'is_default': true,
    });
    expect(address.formattedAddress, '41.311081, 69.240563');
  });

  group('ProductDetail', () {
    test(
      'variant, addon validation maydonlari va related mahsulotlarni o‘qiydi',
      () {
        final detail = ProductDetail.fromJson({
          ...productJson(),
          'images': [
            {'id': 'image-1', 'image': '/media/detail.jpg', 'is_main': true},
          ],
          'addon_groups': [
            {
              'id': 'group-1',
              'name': 'Souslar',
              'selection_type': 'multiple',
              'is_required': true,
              'min_select': 1,
              'max_select': 2,
              'options': [
                {
                  'id': 'addon-1',
                  'name': 'Achchiq sous',
                  'price': '3000.00',
                  'is_available': true,
                },
              ],
            },
          ],
          'related_products': [
            productJson(id: 'related-1', storeType: 'household'),
          ],
        });

        expect(detail.product.storeType, StoreType.restaurant);
        expect(detail.product.variants.single.isDefault, isTrue);
        expect(detail.addonGroups.single.isRequired, isTrue);
        expect(detail.addonGroups.single.minSelect, 1);
        expect(detail.addonGroups.single.maxSelect, 2);
        expect(detail.addonGroups.single.options.single.id, 'addon-1');
        expect(detail.relatedProducts.single.id, 'related-1');
        expect(detail.images.single.url, contains('/media/detail.jpg'));
        expect(detail.product.imageCount, 3);
        expect(detail.requiresConfiguration, isTrue);
      },
    );

    test('is_purchasable=false saqlanadi va noma’lum store null', () {
      final product = ProductSummary.fromJson(
        productJson(storeType: 'future-store', purchasable: false),
      );
      expect(product.isPurchasable, isFalse);
      expect(product.storeType, isNull);
    });

    test('image_count bo‘lmagan eski payload uchun 0 fallback ishlaydi', () {
      final json = productJson()..remove('image_count');
      expect(ProductSummary.fromJson(json).imageCount, 0);
    });
  });

  test('StoreLandingData faqat bo‘sh bo‘lmagan curated sectionni qo‘shadi', () {
    final landing = StoreLandingData.fromJson({
      'store': {
        'store_type': 'restaurant',
        'label': 'Restoran',
        'subtitle': 'Issiq taomlar',
        'is_enabled': true,
        'show_store_header': true,
      },
      'categories': [
        {
          'id': 'category-1',
          'name': 'Taomlar',
          'store_type': 'restaurant',
          'product_count': 4,
          'preview_images': [
            '/media/products/thumbnails/osh.webp',
            '/media/products/images/shorva.webp',
          ],
        },
      ],
      'stores': [
        {'id': 'store-1', 'name': 'Restoran', 'store_type': 'restaurant'},
      ],
      'top_banners': [
        {
          'id': 'banner-1',
          'title': 'Aksiya',
          'action_type': 'product',
          'target_product_id': 'product-1',
        },
      ],
      'featured_products': [productJson()],
      'discounted_products': <Map<String, dynamic>>[],
      'popular_products': <Map<String, dynamic>>[],
      'new_products': <Map<String, dynamic>>[],
    });

    expect(landing.header.storeTypeWire, 'restaurant');
    expect(landing.categories.single.productCount, 4);
    expect(landing.categories.single.previewImageUrls, hasLength(2));
    expect(
      landing.categories.single.previewImageUrls.first,
      contains('/media/products/thumbnails/osh.webp'),
    );
    expect(landing.banners.single.targetProductId, 'product-1');
    expect(landing.sections.single.id, 'featured');
    expect(landing.sections.single.products.single.id, 'product-1');
  });

  test('eski category payloadida preview rasmlar bo‘sh ro‘yxat bo‘ladi', () {
    final category = ProductCategory.fromJson({
      'id': 'category-1',
      'name': 'Taomlar',
      'store_type': 'restaurant',
    });

    expect(category.previewImageUrls, isEmpty);
  });

  test(
    'CartConfiguration addon tartibidan qat’i nazar bir xil identity beradi',
    () {
      const first = CartConfiguration(
        productId: 'p-1',
        variantId: 'v-1',
        note: '  kam tuz  ',
        addons: [
          SelectedAddon(id: 'a-2'),
          SelectedAddon(id: 'a-1'),
        ],
      );
      const second = CartConfiguration(
        productId: 'p-1',
        variantId: 'v-1',
        note: 'kam tuz',
        addons: [
          SelectedAddon(id: 'a-1'),
          SelectedAddon(id: 'a-2'),
        ],
      );
      expect(first.identity, second.identity);
    },
  );

  test('global favorites UI’da product.store_type bo‘yicha ajraladi', () {
    final state = FavoritesState(
      items: [
        FavoriteEntry(
          id: 'f-1',
          product: ProductSummary.fromJson(
            productJson(id: 'g-1', storeType: 'grocery'),
          ),
        ),
        FavoriteEntry(
          id: 'f-2',
          product: ProductSummary.fromJson(
            productJson(id: 'h-1', storeType: 'household'),
          ),
        ),
      ],
    );
    expect(state.forStore(StoreType.grocery).single.product.id, 'g-1');
    expect(state.forStore(StoreType.household).single.product.id, 'h-1');
    expect(state.forStore(StoreType.restaurant), isEmpty);
  });

  test('address, delivery estimate va order detail tolerant parsing', () {
    final address = UserAddress.fromJson({
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
    });
    final estimate = DeliveryEstimate.fromJson({
      'delivery_available': true,
      'distance_km': '3.25',
      'delivery_fee': '12000.00',
    });
    final order = OrderData.fromJson({
      'id': 'order-1',
      'order_number': 'BK-100',
      'store_type': 'restaurant',
      'fulfillment_type': 'delivery',
      'status': 'delivered',
      'status_label': 'Yetkazildi',
      'payment_method': 'cash_to_courier',
      'payment_status': 'pending',
      'subtotal': '35000.00',
      'delivery_fee': '12000.00',
      'total': '47000.00',
      'address': address.toRequestJson(),
      'items': [
        {
          'id': 'item-1',
          'product_id': 'product-1',
          'product_name': 'Osh',
          'variant_name': 'Katta',
          'quantity': 1,
          'price': '35000.00',
          'total_price': '35000.00',
          'addons': [
            {'id': 'a-1', 'name': 'Sous', 'price': '0.00'},
          ],
        },
      ],
      'simplified_timeline': [
        {
          'key': 'delivered',
          'label': 'Yetkazildi',
          'state': 'current',
          'completed_at': '2026-07-31T10:00:00Z',
        },
      ],
      'can_confirm_received': true,
      'delivery_confirmation': {
        'code': '1234',
        'qr_token': 'token',
        'qr_payload': 'marketplace://order-confirm?id=order-1&token=token',
      },
      'created_at': '2026-07-31T09:00:00Z',
    });

    expect(address.latitude, closeTo(41.308119, 0.000001));
    expect(estimate.available, isTrue);
    expect(estimate.deliveryPrice, '12000.00');
    expect(order.items.single.addons.single.name, 'Sous');
    expect(order.customerStage, CustomerOrderStage.delivered);
  });

  test('order cancel faqat pending/accepted holatlarda', () {
    OrderData order(String status) => OrderData.fromJson({
      'id': 'order-$status',
      'order_number': status,
      'store_type': 'grocery',
      'fulfillment_type': 'delivery',
      'status': status,
      'status_label': status,
      'payment_method': 'cash_to_courier',
      'payment_status': 'pending',
      'subtotal': '0.00',
      'delivery_fee': '0.00',
      'total': '0.00',
      'items': <Map<String, dynamic>>[],
      'created_at': '2026-07-31T10:00:00Z',
    });

    expect(order('pending').canCancel, isTrue);
    expect(order('accepted').canCancel, isTrue);
    expect(order('preparing').canCancel, isFalse);
    expect(order('completed').canCancel, isFalse);
  });

  test('yetkazish oynasi deadline\'dan 10 daqiqa, filial koordinatasi', () {
    OrderData order(String userStatus, {String option = 'same_day'}) =>
        OrderData.fromJson({
          'id': 'o',
          'order_number': 'BK',
          'store_type': 'grocery',
          'fulfillment_type': 'delivery',
          'status': userStatus,
          'user_status': userStatus,
          'subtotal': '1',
          'delivery_fee': '0',
          'total': '1',
          'delivery_option': option,
          'delivery_deadline_at': '2026-10-08T10:26:00Z',
          'picked_up_at': '2026-10-08T10:00:00Z',
          'pickup_branch': {
            'id': 'b',
            'name': 'Markaz',
            'address': '',
            'phone': '',
            'store_name': 'S',
            'latitude': '41.32',
            'longitude': '69.55',
          },
          'items': <Object>[],
          'created_at': '2026-10-08T09:00:00Z',
        });

    final accepted = order('accepted');
    expect(accepted.deliveryWindow, isNotNull);
    expect(accepted.deliveryWindow!.end.toUtc().minute, 26);
    expect(accepted.deliveryWindow!.start.toUtc().minute, 16);
    expect(accepted.courierPhase, CourierPhase.toStore);
    expect(order('on_way').courierPhase, CourierPhase.toCustomer);
    expect(order('reviewing').deliveryWindow, isNull);
    expect(order('reviewing').courierPhase, CourierPhase.none);
    expect(order('accepted', option: 'one_day').deliveryWindow, isNull);
    expect(accepted.pickupBranch!.hasCoordinates, isTrue);
    expect(accepted.pickupBranch!.latitude, closeTo(41.32, 1e-6));
    expect(accepted.pickedUpAt?.toUtc().hour, 10);
  });

  test('order 1–2 kunlik yetkazish tanlovini parse qiladi', () {
    final order = OrderData.fromJson({
      'id': 'delayed-order',
      'store_type': 'household',
      'fulfillment_type': 'delivery',
      'status': 'accepted',
      'user_status': 'accepted',
      'delivery_option': 'two_days',
      'subtotal': '10000',
      'delivery_fee': '5000',
      'total': '15000',
      'items': <Map<String, dynamic>>[],
      'created_at': '2026-08-22T10:00:00Z',
    });
    expect(order.deliveryOption, 'two_days');
    expect(order.isDelayedDelivery, isTrue);
  });

  test('customer order statuslari beshta sodda bosqichga tushadi', () {
    OrderData order(
      String status, [
      String? userStatus,
      String fulfillmentType = 'delivery',
    ]) => OrderData.fromJson({
      'id': 'order-$status',
      'store_type': 'grocery',
      'fulfillment_type': fulfillmentType,
      'status': status,
      'user_status': ?userStatus,
      'subtotal': '0',
      'delivery_fee': '0',
      'total': '0',
      'items': <Map<String, dynamic>>[],
      'created_at': '2026-08-09T10:00:00Z',
    });

    expect(
      order('pending', 'reviewing').customerStage,
      CustomerOrderStage.searching,
    );
    expect(
      order('accepted', 'reviewing').customerStage,
      CustomerOrderStage.searching,
    );
    expect(order('preparing').customerStage, CustomerOrderStage.accepted);
    expect(
      order('out_for_delivery', 'on_way').customerStage,
      CustomerOrderStage.onWay,
    );
    expect(order('completed').customerStage, CustomerOrderStage.delivered);
    expect(order('cancelled').customerStage, CustomerOrderStage.cancelled);
    expect(
      order('pending', 'pending', 'pickup').customerStage,
      CustomerOrderStage.other,
    );
    expect(
      order('ready_for_pickup', 'ready', 'pickup').customerStage,
      CustomerOrderStage.accepted,
    );
  });
}
