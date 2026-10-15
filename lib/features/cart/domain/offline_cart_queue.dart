import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/account_scope.dart';
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
  OfflineCartQueue(this.ref, this.owner);

  String get _prefsKey => 'cart.offline_queue.v2.$owner';

  /// Bitta "zaharli" amal (429/5xx/auth) navbatni abadiy ushlab turmasin.
  static const _maxAttempts = 5;

  final Ref ref;
  final String owner;
  bool _flushing = false;
  Future<void> _storageTail = Future.value();
  bool get _active => ref.mounted && ref.read(accountScopeProvider) == owner;

  // Serialize only disk edits, not HTTP, so a new intent can be safely queued
  // while flush waits for the network. Acknowledgement removes just its ID.
  Future<void> _mutate(void Function(List<Map<String, dynamic>>) change) {
    final work = _storageTail.then((_) async {
      final ops = _load();
      change(ops);
      for (final op in ops) {
        op.putIfAbsent(
          'operation_id',
          () =>
              '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
        );
      }
      await _save(ops);
    });
    _storageTail = work.catchError((Object _) {});
    return work;
  }

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
    await _mutate((ops) {
      ops.removeWhere(
        (op) =>
            op['type'] == 'add' &&
            op['store_type'] == storeType &&
            _addIdentity(op) == configuration.identity,
      );
      if (quantity < 1) return;
      ops.add({
        'type': 'add',
        'store_type': storeType,
        'product_id': configuration.productId,
        if (configuration.variantId != null)
          'variant_id': configuration.variantId,
        'addon_ids': [for (final addon in configuration.addons) addon.id],
        'note': configuration.note,
        'quantity': quantity,
      });
    });
  }

  /// Online yozuv boshlanishidan oldin shu konfiguratsiyaning eski offline
  /// niyatini olib tashlaydi. Aks holda reconnect paytida bir mahsulot ikki
  /// marta qo'shilishi mumkin.
  Future<void> discardAdd({
    required String storeType,
    required CartConfiguration configuration,
  }) => _mutate(
    (ops) => ops.removeWhere(
      (op) =>
          op['type'] == 'add' &&
          op['store_type'] == storeType &&
          _addIdentity(op) == configuration.identity,
    ),
  );

  String _addIdentity(Map<String, dynamic> op) {
    final addonIds = [
      for (final id in (op['addon_ids'] as List? ?? const [])) '$id',
    ]..sort();
    return '${op['product_id']}|${op['variant_id'] ?? ''}|${addonIds.join(',')}|${'${op['note'] ?? ''}'.trim()}';
  }

  Future<void> enqueueSetQuantity(String itemId, int quantity) async {
    // Bitta element bo'yicha oxirgi qiymat yetarli — eski set'lar olib tashlanadi.
    await _mutate(
      (ops) => ops
        ..removeWhere((op) => op['type'] == 'set' && op['item_id'] == itemId)
        ..add({'type': 'set', 'item_id': itemId, 'quantity': quantity}),
    );
  }

  Future<void> enqueueRemove(String itemId) async {
    await _mutate(
      (ops) => ops
        // O'chirilgan element bo'yicha kutayotgan set'lar ma'nosiz.
        ..removeWhere(
          (op) =>
              (op['type'] == 'set' || op['type'] == 'remove') &&
              op['item_id'] == itemId,
        )
        ..add({'type': 'remove', 'item_id': itemId}),
    );
  }

  Future<void> enqueueClear(String storeType) async {
    await _mutate(
      (ops) => ops
        // Shu do'konning barcha oldingi amallari bekor — clear hammasini yutadi.
        ..removeWhere((op) => op['store_type'] == storeType)
        ..add({'type': 'clear', 'store_type': storeType}),
    );
  }

  /// Navbatni serverga yuboradi (internet qaytганda chaqiriladi).
  ///
  /// Har bir amal bir marta yuboriladi; 4xx (element yo'q va h.k.) —
  /// o'tkazib yuboriladi, tarmoq xatosi — qolganini keyingi urinishga qoldiradi.
  Future<void> flush() async {
    if (_flushing || !_active) return;
    _flushing = true;
    try {
      await _storageTail;
      if (!_active) return;
      var ops = _load();
      if (ops.isEmpty) return;
      final api = ref.read(cartApiProvider);
      final touchedStores = <String>{};

      while (ops.isNotEmpty && _active) {
        final op = ops.first;
        try {
          await _apply(api, op, touchedStores);
        } on NetworkFailure {
          // Hali ham oflayn — qolganlari keyingi ulanishda ketadi.
          break;
        } on NotFoundFailure {
          // Element/mahsulot serverda yo'q — amal eskirgan, tashlab yuboriladi.
          // `add` ham: o'chirilgan mahsulot navbat boshida abadiy qolib,
          // keyingi BARCHA amallarni (remove, miqdor) bloklab qo'yardi.
        } on ValidationFailure {
          // Qat'iy 400 (masalan mahsulot sotuvda yo'q) — qayta yuborish ma'nosiz.
        } on ApiFailure {
          // 429/5xx/auth — niyat eskirmagan, lekin urinishlar chegaralangan.
          final attempts = ((op['attempts'] as num?)?.toInt() ?? 0) + 1;
          if (attempts < _maxAttempts) {
            await _mutate((current) {
              for (final candidate in current) {
                if (candidate['operation_id'] == op['operation_id']) {
                  candidate['attempts'] = attempts;
                }
              }
            });
            break;
          }
        }
        if (!_active) return;
        await _mutate(
          (current) => current.removeWhere(
            (candidate) => candidate['operation_id'] == op['operation_id'],
          ),
        );
        ops = _load();
      }

      // Yuborilgan do'konlarning savati server holati bilan yangilanadi.
      for (final wire in touchedStores) {
        if (!_active) return;
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
  (ref) => OfflineCartQueue(ref, ref.watch(accountScopeProvider)),
);
