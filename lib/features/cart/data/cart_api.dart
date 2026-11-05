import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../../core/storage/secure_token_store.dart';
import 'cart_models.dart';

class CartApi {
  CartApi(
    this._client, [
    GuestCartTokenStore? tokens,
    bool Function()? isAuthenticated,
    bool Function()? isCurrent,
  ]) : _tokens = tokens,
       _isAuthenticated = isAuthenticated ?? (() => true),
       _isCurrent = isCurrent ?? (() => true);

  final ApiClient _client;
  final GuestCartTokenStore? _tokens;
  final bool Function() _isAuthenticated;
  final bool Function() _isCurrent;
  Future<String>? _guestSessionInFlight;
  final _addReceipts = <String, String>{};
  final _addOffsets = <String, int>{};
  int? addedQuantityOffset(String key) => _addOffsets[key];
  String? addedItemId(String key) => _addReceipts[key];

  static const _guestHeader = 'X-Guest-Cart-Token';

  Future<Map<String, dynamic>?> _cartHeaders() async {
    if (_tokens == null || _isAuthenticated()) return null;
    // Authenticated callers do not invoke this method with guest ownership;
    // [CartController] selects the owner from auth state.
    return {_guestHeader: await _ensureGuestSession()};
  }

  Future<T> _withGuestSessionRecovery<T>(
    Future<T> Function(Map<String, dynamic>? headers) request, {
    bool recoverGuest = true,
  }) async {
    final headers = await _cartHeaders();
    if (!_isCurrent()) throw const CancelledFailure();
    try {
      return await request(headers);
    } on UnauthorizedFailure {
      // Cart endpointlari guest uchun public. Guest token muddati tugagan yoki
      // server cleanup qilgan bo‘lsa yangi session bilan aynan bir marta
      // qayta uriniladi. Network/timeout xatolari bu branchga tushmaydi —
      // mutating POST/PATCH hech qachon noaniq holatda takrorlanmaydi.
      if (!_isCurrent()) throw const CancelledFailure();
      if (!recoverGuest || _tokens == null || _isAuthenticated()) rethrow;
      await _tokens.clearGuestCartToken();
      final recoveredHeaders = await _cartHeaders();
      if (!_isCurrent()) throw const CancelledFailure();
      return request(recoveredHeaders);
    }
  }

  Future<String> _ensureGuestSession() async {
    final stored = await _tokens?.readGuestCartToken();
    if (stored != null && stored.isNotEmpty) return stored;
    final active = _guestSessionInFlight;
    if (active != null) return active;
    final future = _createGuestSession();
    _guestSessionInFlight = future;
    try {
      return await future;
    } finally {
      _guestSessionInFlight = null;
    }
  }

  Future<String> _createGuestSession() async {
    final data = await _client.post(Api.guestCartSession);
    final map = JsonRead.map(data);
    final token = JsonRead.string(map?['token']);
    if (token.isEmpty) {
      throw const UnknownFailure.malformed('guest cart token javobda yo‘q');
    }
    if (!_isCurrent()) throw const CancelledFailure();
    await _tokens!.saveGuestCartToken(token);
    return token;
  }

  Future<CartData> fetch(String storeType) async {
    final data = await _withGuestSessionRecovery(
      (headers) => _client.get(
        Api.cart,
        query: {'store_type': storeType},
        headers: headers,
      ),
    );
    return _decodeCart(data);
  }

  Future<void> addItem({
    required String storeType,
    required CartConfiguration configuration,
    required int quantity,
    String? idempotencyKey,
  }) async => _withGuestSessionRecovery((headers) async {
    final data = await _client.post(
      Api.cartItems,
      headers: {...?headers, 'Idempotency-Key': ?idempotencyKey},
      body: {
        'store_type': storeType,
        'product_id': configuration.productId,
        'quantity': quantity,
        if (configuration.variantId != null)
          'variant_id': configuration.variantId,
        'selected_addons': [
          for (final addon in configuration.addons) addon.toRequestJson(),
        ],
        if (configuration.note.trim().isNotEmpty)
          'note': configuration.note.trim(),
      },
    );
    final id = JsonRead.nullableString(JsonRead.map(data)?['id']);
    if (idempotencyKey != null && id != null) {
      _addReceipts[idempotencyKey] = id;
      _addOffsets[idempotencyKey] = JsonRead.integer(
        JsonRead.map(data)?['merged_quantity_offset'],
      );
    }
  }, recoverGuest: idempotencyKey == null);

  Future<void> updateQuantity(String itemId, int quantity) =>
      _updateQuantity(itemId, quantity);

  Future<void> _updateQuantity(String itemId, int quantity) async =>
      _withGuestSessionRecovery(
        (headers) => _client.patch(
          Api.cartItem(itemId),
          body: {'quantity': quantity},
          headers: headers,
        ),
      );

  Future<void> deleteItem(String itemId) async => _withGuestSessionRecovery(
    (headers) => _client.delete(Api.cartItem(itemId), headers: headers),
  );

  Future<void> clear(String storeType) async => _withGuestSessionRecovery(
    (headers) => _client.delete(
      Api.cartClear,
      query: {'store_type': storeType},
      headers: headers,
    ),
  );

  Future<CartData> addBundle(String bundleId, {int quantity = 1}) async {
    final data = await _withGuestSessionRecovery(
      (headers) => _client.post(
        Api.cartBundleAdd(bundleId),
        headers: headers,
        body: {'quantity': quantity},
      ),
    );
    final map = JsonRead.map(data);
    return _decodeCart(map?['cart']);
  }

  Future<bool> mergeGuestCart() async {
    final token = await _tokens?.readGuestCartToken();
    if (!_isCurrent()) throw const CancelledFailure();
    if (token == null || token.isEmpty) return false;
    await _client.post(Api.mergeGuestCart, headers: {_guestHeader: token});
    // Keep the token until queued guest intents have durably moved to the user.
    // A restart can safely repeat the server's idempotent merge in this window.
    return true;
  }

  Future<void> completeGuestMerge() async {
    await _tokens?.clearGuestCartToken();
  }

  CartData _decodeCart(Object? data) {
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure.malformed('cart javobi obyekt emas');
    }
    return CartData.fromJson(map);
  }
}
