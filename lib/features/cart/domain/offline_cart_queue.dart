import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/store_scope/store_type.dart';
import '../data/cart_api.dart';
import '../data/cart_models.dart';
import 'cart_controller.dart';

/// Oflaynda qilingan savat amallarining navbati.
///
/// Egasining qarori: internetsiz ham savatga qo'shish ishlashi kerak. Amallar
/// diskka (prefs) yoziladi — ilova yopilib ochilsa ham yo'qolmaydi — va
/// internet qaytishi bilan TARTIB BILAN serverga yuboriladi, so'ng savat
/// server bilan solishtiriladi.
class OfflineCartQueue {
  OfflineCartQueue(this.ref);

  static const _prefsKey = 'cart.offline_queue';

  final Ref ref;
  bool _flushing = false;

  List<Map<String, dynamic>> _load() {
    final raw = ref.read(prefsStoreProvider).getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.whereType<Map<String, dynamic>>().toList()
          : [];
    } on FormatException {
      return [];
    }
  }

  Future<void> _save(List<Map<String, dynamic>> ops) =>
      ref.read(prefsStoreProvider).setString(_prefsKey, jsonEncode(ops));

  bool get isEmpty => _load().isEmpty;

  Future<void> enqueueAdd({
    required String storeType,
    required CartConfiguration configuration,
    required int quantity,
  }) async {
    final ops = _load()
      ..add({
        'type': 'add',
        'store_type': storeType,
        'product_id': configuration.productId,
        if (configuration.variantId != null)
          'variant_id': configuration.variantId,
        'addon_ids': [for (final addon in configuration.addons) addon.id],
        'note': configuration.note,
        'quantity': quantity,
      });
    await _save(ops);
  }

  Future<void> enqueueSetQuantity(String itemId, int quantity) async {
    // Bitta element bo'yicha oxirgi qiymat yetarli — eski set'lar olib tashlanadi.
    final ops = _load()
      ..removeWhere((op) => op['type'] == 'set' && op['item_id'] == itemId)
      ..add({'type': 'set', 'item_id': itemId, 'quantity': quantity});
    await _save(ops);
  }

  Future<void> enqueueRemove(String itemId) async {
    final ops = _load()
      // O'chirilgan element bo'yicha kutayotgan set'lar ma'nosiz.
      ..removeWhere(
        (op) =>
            (op['type'] == 'set' || op['type'] == 'remove') &&
            op['item_id'] == itemId,
      )
      ..add({'type': 'remove', 'item_id': itemId});
    await _save(ops);
  }

  Future<void> enqueueClear(String storeType) async {
    final ops = _load()
      // Shu do'konning barcha oldingi amallari bekor — clear hammasini yutadi.
      ..removeWhere((op) => op['store_type'] == storeType)
      ..add({'type': 'clear', 'store_type': storeType});
    await _save(ops);
  }

  /// Navbatni serverga yuboradi (internet qaytганda chaqiriladi).
  ///
  /// Har bir amal bir marta yuboriladi; 4xx (element yo'q va h.k.) —
  /// o'tkazib yuboriladi, tarmoq xatosi — qolganini keyingi urinishga qoldiradi.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      var ops = _load();
      if (ops.isEmpty) return;
      final api = ref.read(cartApiProvider);
      final touchedStores = <String>{};

      while (ops.isNotEmpty) {
        final op = ops.first;
        try {
          await _apply(api, op, touchedStores);
        } on NetworkFailure {
          // Hali ham oflayn — qolganlari keyingi ulanishda ketadi.
          break;
        } on ApiFailure {
          // Element allaqachon yo'q / eskirgan amal — tashlab yuboramiz.
        }
        ops = ops..removeAt(0);
        await _save(ops);
      }

      // Yuborilgan do'konlarning savati server holati bilan yangilanadi.
      for (final wire in touchedStores) {
        final storeType = StoreType.fromWire(wire);
        if (storeType != null) {
          ref.invalidate(cartControllerProvider(storeType));
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _apply(
    CartApi api,
    Map<String, dynamic> op,
    Set<String> touchedStores,
  ) async {
    switch (op['type']) {
      case 'add':
        final storeType = '${op['store_type']}';
        await api.addItem(
          storeType: storeType,
          configuration: CartConfiguration(
            productId: '${op['product_id']}',
            variantId: op['variant_id'] as String?,
            addons: [
              for (final id in (op['addon_ids'] as List? ?? const []))
                SelectedAddon(id: '$id'),
            ],
            note: '${op['note'] ?? ''}',
          ),
          quantity: (op['quantity'] as num?)?.toInt() ?? 1,
        );
        touchedStores.add(storeType);
      case 'set':
        await api.updateQuantity(
          '${op['item_id']}',
          (op['quantity'] as num?)?.toInt() ?? 1,
        );
      case 'remove':
        await api.deleteItem('${op['item_id']}');
      case 'clear':
        final storeType = '${op['store_type']}';
        await api.clear(storeType);
        touchedStores.add(storeType);
    }
  }
}

final offlineCartQueueProvider = Provider<OfflineCartQueue>(
  OfflineCartQueue.new,
);
