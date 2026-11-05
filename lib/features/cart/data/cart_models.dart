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
    this.isOrderable = true,
    this.unavailableReasonCode,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productJson =
        JsonRead.map(json['product']) ?? const <String, dynamic>{};
    final variantJson = JsonRead.map(json['variant']);
    return CartItem(
      isOrderable: json['is_orderable'] != false,
      unavailableReasonCode: json['unavailable_reason_code'] as String?,
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
      subtotal: json.containsKey('subtotal') && json['subtotal'] == null
          ? ''
          : JsonRead.string(json['subtotal'], '0'),
    );
  }

  final String id;
  final ProductSummary product;
  final ProductVariant? variant;
  final bool isOrderable;
  final String? unavailableReasonCode;
  final int quantity;
  final List<SelectedAddon> selectedAddons;
  final String note;
  final String subtotal;

  /// Bitta dona narxi (server qator jamidan, variant/qo'shimchalar bilan).
  String get unitPrice {
    final total = _parseMoneyMinor(subtotal);
    if (subtotal.isEmpty || quantity <= 0) return subtotal;
    return _formatMoneyMinor(total ~/ quantity);
  }

  /// Chegirmagacha qator jami (eski narx bo'yicha); chegirma bo'lmasa `null`.
  String? get originalSubtotal {
    final price = variant?.price ?? product.price;
    final old = variant != null ? variant!.oldPrice : product.oldPrice;
    if (old == null || subtotal.isEmpty) return null;
    final saving = _parseMoneyMinor(old) - _parseMoneyMinor(price);
    if (saving <= 0) return null;
    return _formatMoneyMinor(_parseMoneyMinor(subtotal) + saving * quantity);
  }

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
    isOrderable: isOrderable,
    unavailableReasonCode: unavailableReasonCode,
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
    this.minimumDeliveryOrderAmount,
    this.revision,
  });

  factory CartData.fromJson(Map<String, dynamic> json) => CartData(
    id: JsonRead.string(json['id']),
    storeTypeWire: JsonRead.string(json['store_type']),
    revision: (json['revision'] as num?)?.toInt(),
    items: JsonRead.list(json['items'], CartItem.fromJson),
    totalItems: JsonRead.integer(json['total_items']),
    totalQuantity: JsonRead.integer(json['total_quantity']),
    subtotal: json.containsKey('subtotal') && json['subtotal'] == null
        ? ''
        : JsonRead.string(json['subtotal'], '0'),
    minimumDeliveryOrderAmount: JsonRead.nullableString(
      json['minimum_delivery_order_amount'],
    ),
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
  final int? revision;
  bool get isOrderable => items.every((item) => item.isOrderable);
  final List<CartItem> items;
  final int totalItems;
  final int totalQuantity;
  final String subtotal;

  /// Null for older servers: do not invent a store-specific policy.
  final String? minimumDeliveryOrderAmount;

  /// Chegirmagacha mahsulotlar jami (Uzum'dagi "N tovar" qatori).
  String get originalSubtotal => _formatMoneyMinor(
    items.fold<int>(
      0,
      (sum, item) =>
          sum + _parseMoneyMinor(item.originalSubtotal ?? item.subtotal),
    ),
  );

  /// Eski narxlar bo'yicha jami chegirma (0 bo'lishi mumkin).
  String get discountTotal {
    final saving =
        _parseMoneyMinor(originalSubtotal) - _parseMoneyMinor(subtotal);
    return _formatMoneyMinor(saving > 0 ? saving : 0);
  }

  bool get hasDiscount => _parseMoneyMinor(discountTotal) > 0;

  bool get hasDeliveryMinimum =>
      _parseMoneyMinor(minimumDeliveryOrderAmount ?? '0') > 0;

  String get remainingForDelivery => deliveryMinimumRemaining();

  /// Only a confirmed server quote should be passed as deliveryFee. Without
  /// one, this is the conservative products-only remainder, not a guessed fee.
  String deliveryMinimumRemaining({String? deliveryFee}) {
    final remaining =
        _parseMoneyMinor(minimumDeliveryOrderAmount ?? '0') -
        _parseMoneyMinor(subtotal) -
        _parseMoneyMinor(deliveryFee ?? '0');
    return _formatMoneyMinor(remaining > 0 ? remaining : 0);
  }

  bool get meetsDeliveryMinimum => _parseMoneyMinor(remainingForDelivery) == 0;

  bool meetsDeliveryMinimumIncluding(String? deliveryFee) =>
      _parseMoneyMinor(deliveryMinimumRemaining(deliveryFee: deliveryFee)) == 0;

  int quantityForProduct(String productId) => items
      .where((item) => item.product.id == productId)
      .fold(0, (total, item) => total + item.quantity);

  CartData replaceItem(CartItem replacement) {
    final updated = <CartItem>[
      for (final item in items) item.id == replacement.id ? replacement : item,
    ];
    return _withItems(updated);
  }

  CartData upsertItem(CartItem replacement) {
    final exists = items.any((item) => item.id == replacement.id);
    final updated = exists
        ? [
            for (final item in items)
              item.id == replacement.id ? replacement : item,
          ]
        : [...items, replacement];
    return _withItems(updated);
  }

  CartData removeItem(String itemId) {
    final updated = items.where((item) => item.id != itemId).toList();
    return _withItems(updated);
  }

  CartData _withItems(List<CartItem> updated) => copyWith(
    items: updated,
    totalItems: updated.length,
    totalQuantity: updated.fold<int>(0, (total, item) => total + item.quantity),
    subtotal: _formatMoneyMinor(
      updated.fold<int>(
        0,
        (total, item) => total + _parseMoneyMinor(item.subtotal),
      ),
    ),
  );

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
    minimumDeliveryOrderAmount: minimumDeliveryOrderAmount,
    revision: revision,
  );
}

int _parseMoneyMinor(String raw) {
  final normalized = raw.trim().replaceAll(' ', '');
  if (normalized.isEmpty) return 0;
  final negative = normalized.startsWith('-');
  final unsigned = negative ? normalized.substring(1) : normalized;
  final parts = unsigned.split('.');
  final whole = int.tryParse(parts.first) ?? 0;
  final fractionRaw = parts.length > 1 ? parts[1] : '';
  final fraction = int.tryParse('${fractionRaw}00'.substring(0, 2)) ?? 0;
  final value = whole * 100 + fraction;
  return negative ? -value : value;
}

String _formatMoneyMinor(int value) {
  final negative = value < 0;
  final absolute = value.abs();
  final result =
      '${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  return negative ? '-$result' : result;
}
