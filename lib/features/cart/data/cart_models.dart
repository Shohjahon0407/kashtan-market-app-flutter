import '../../../core/network/json_read.dart';
import '../../catalog/data/product_models.dart';

class SelectedAddon {
  const SelectedAddon({required this.id, this.name = '', this.price = '0'});

  factory SelectedAddon.fromJson(Map<String, dynamic> json) => SelectedAddon(
    id: JsonRead.string(json['id'] ?? json['option_id']),
    name: JsonRead.string(json['name']),
    price: JsonRead.string(json['price'], '0'),
  );

  final String id;
  final String name;
  final String price;

  Map<String, dynamic> toRequestJson() => {'id': id};
}

class CartConfiguration {
  const CartConfiguration({
    required this.productId,
    this.variantId,
    this.addons = const [],
    this.note = '',
  });

  final String productId;
  final String? variantId;
  final List<SelectedAddon> addons;
  final String note;

  String get identity {
    final addonIds = addons.map((addon) => addon.id).toList()..sort();
    return '$productId|${variantId ?? ''}|${addonIds.join(',')}|${note.trim()}';
  }
}

class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.selectedAddons,
    required this.note,
    required this.subtotal,
    this.variant,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productJson =
        JsonRead.map(json['product']) ?? const <String, dynamic>{};
    final variantJson = JsonRead.map(json['variant']);
    return CartItem(
      id: JsonRead.string(json['id']),
      product: ProductSummary.fromJson(productJson),
      variant: variantJson == null
          ? null
          : ProductVariant.fromJson(variantJson),
      quantity: JsonRead.integer(json['quantity'], 1),
      selectedAddons: JsonRead.list(
        json['selected_addons'],
        SelectedAddon.fromJson,
      ),
      note: JsonRead.string(json['note']),
      subtotal: JsonRead.string(json['subtotal'], '0'),
    );
  }

  final String id;
  final ProductSummary product;
  final ProductVariant? variant;
  final int quantity;
  final List<SelectedAddon> selectedAddons;
  final String note;
  final String subtotal;

  String get configurationIdentity => CartConfiguration(
    productId: product.id,
    variantId: variant?.id,
    addons: selectedAddons,
    note: note,
  ).identity;

  CartItem copyWith({int? quantity, String? subtotal}) => CartItem(
    id: id,
    product: product,
    variant: variant,
    quantity: quantity ?? this.quantity,
    selectedAddons: selectedAddons,
    note: note,
    subtotal: subtotal ?? this.subtotal,
  );
}

class CartData {
  const CartData({
    required this.id,
    required this.storeTypeWire,
    required this.items,
    required this.totalItems,
    required this.totalQuantity,
    required this.subtotal,
  });

  factory CartData.fromJson(Map<String, dynamic> json) => CartData(
    id: JsonRead.string(json['id']),
    storeTypeWire: JsonRead.string(json['store_type']),
    items: JsonRead.list(json['items'], CartItem.fromJson),
    totalItems: JsonRead.integer(json['total_items']),
    totalQuantity: JsonRead.integer(json['total_quantity']),
    subtotal: JsonRead.string(json['subtotal'], '0'),
  );

  factory CartData.empty(String storeTypeWire) => CartData(
    id: '',
    storeTypeWire: storeTypeWire,
    items: const [],
    totalItems: 0,
    totalQuantity: 0,
    subtotal: '0',
  );

  final String id;
  final String storeTypeWire;
  final List<CartItem> items;
  final int totalItems;
  final int totalQuantity;
  final String subtotal;

  int quantityForProduct(String productId) => items
      .where((item) => item.product.id == productId)
      .fold(0, (total, item) => total + item.quantity);

  CartData replaceItem(CartItem replacement) {
    final updated = <CartItem>[
      for (final item in items) item.id == replacement.id ? replacement : item,
    ];
    return copyWith(
      items: updated,
      totalQuantity: updated.fold<int>(
        0,
        (total, item) => total + item.quantity,
      ),
    );
  }

  CartData removeItem(String itemId) {
    final updated = items.where((item) => item.id != itemId).toList();
    return copyWith(
      items: updated,
      totalItems: updated.length,
      totalQuantity: updated.fold<int>(
        0,
        (total, item) => total + item.quantity,
      ),
    );
  }

  CartData copyWith({
    List<CartItem>? items,
    int? totalItems,
    int? totalQuantity,
    String? subtotal,
  }) => CartData(
    id: id,
    storeTypeWire: storeTypeWire,
    items: items ?? this.items,
    totalItems: totalItems ?? this.totalItems,
    totalQuantity: totalQuantity ?? this.totalQuantity,
    subtotal: subtotal ?? this.subtotal,
  );
}
