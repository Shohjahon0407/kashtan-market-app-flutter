import 'dart:async';
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
  Future<void> _networkTail = Future.value();
  String? _inFlightId;

  Future<T> _serialize<T>(Future<T> Function() work) {
    final next = _networkTail.then((_) => work());
    _networkTail = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  static String _uuid() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> submitAdd({
    required String storeType,
    required CartConfiguration configuration,
    required int quantity,
  }) async {
    await enqueueAdd(
      storeType: storeType,
      configuration: configuration,
      quantity: quantity,
    );
    await _serialize(() async {
      if (!_active) throw const UnauthorizedFailure();
      final ops = _load();
      final target = ops
          .where(
            (op) =>
                op['type'] == 'add' &&
                op['store_type'] == storeType &&
                _addIdentity(op) == configuration.identity,
          )
          .firstOrNull;
      if (target == null) return; // A preceding flush/clear already settled it.
      // Preserve ordering with earlier clear/remove/set operations.
      for (final op in ops) {
        await _execute(op, <String>{});
        if (op['operation_id'] == target['operation_id']) break;
      }
    });
  }

  Future<void> submitClear(String storeType) async {
    await enqueueClear(storeType);
    await _serialize(() async {
      for (final op in _load()) {
        await _execute(op, <String>{});
      }
    });
  }

  Future<void> _execute(Map<String, dynamic> op, Set<String> touched) async {
    if (!_active) throw const UnauthorizedFailure();
    _inFlightId = op['operation_id'] as String?;
    try {
      await _mutate((ops) {
        for (final candidate in ops) {
          if (candidate['operation_id'] == op['operation_id']) {
            candidate['attempted'] = true;
          }
        }
      });
      var acknowledged = false;
      while (!acknowledged && _active) {
        await _apply(ref.read(cartApiProvider), op, touched);
        if (!_active) return;
        await _mutate((ops) {
          final current = ops.where(
            (candidate) => candidate['operation_id'] == op['operation_id'],
          );
          if (current.isEmpty) {
            acknowledged = true;
            return;
          }
          if (op['type'] == 'add' &&
              current.first['desired_quantity'] != op['applied_desired']) {
            return;
          }
          ops.removeWhere(
            (candidate) => candidate['operation_id'] == op['operation_id'],
          );
          acknowledged = true;
        });
      }
    } on ValidationFailure {
      await _mutate(
        (ops) => ops.removeWhere(
          (candidate) => candidate['operation_id'] == op['operation_id'],
        ),
      );
      rethrow;
    } finally {
      _inFlightId = null;
    }
  }

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
        if (op['type'] == 'add') op.putIfAbsent('idempotency_key', _uuid);
        // Dart Web bit shifts are 32-bit: 1 << 32 becomes zero and nextInt(0)
        // throws before the add request is sent. UUID bytes work on both VMs.
        op.putIfAbsent('operation_id', _uuid);
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

  Future<void> adoptMergedGuestQueue() async {
    if (owner == 'guest') return;
    const guestKey = 'cart.offline_queue.v2.guest';
    final prefs = ref.read(prefsStoreProvider);
    final raw = prefs.getString(guestKey);
    if (raw == null) return;
    final guest = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    // Persist legacy IDs at the source before copying: a restart between copy
    // and deletion must not assign fresh IDs and duplicate the migrated work.
    for (final op in guest) {
      op.putIfAbsent('operation_id', _uuid);
      if (op['type'] == 'add') op.putIfAbsent('idempotency_key', _uuid);
    }
    await prefs.setString(guestKey, jsonEncode(guest));
    await _mutate((ops) {
      final existing = ops.map((op) => op['operation_id']).toSet();
      ops.insertAll(
        0,
        guest.where((op) => !existing.contains(op['operation_id'])),
      );
    });
    await prefs.remove(guestKey);
  }

  Future<void> enqueueAdd({
    required String storeType,
    required CartConfiguration configuration,
    required int quantity,
  }) async {
    await _mutate((ops) {
      for (final op in ops) {
        if (op['type'] == 'add' &&
            op['store_type'] == storeType &&
            _addIdentity(op) == configuration.identity) {
          if (op['attempted'] != true) {
            op['quantity'] = quantity > 0 ? quantity : op['quantity'];
          }
          op['desired_quantity'] = quantity;
          return;
        }
      }
      if (quantity < 1) return;
      ops.add({
        'type': 'add',
        'idempotency_key': _uuid(),
        'desired_quantity': quantity,
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
          op['attempted'] != true &&
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

  Future<void> enqueueSetQuantity(
    String itemId,
    int quantity, {
    String? storeType,
  }) async {
    // Bitta element bo'yicha oxirgi qiymat yetarli — eski set'lar olib tashlanadi.
    await _mutate(
      (ops) => ops
        ..removeWhere((op) => op['type'] == 'set' && op['item_id'] == itemId)
        ..add({
          'type': 'set',
          'item_id': itemId,
          'quantity': quantity,
          'store_type': ?storeType,
        }),
    );
  }

  Future<void> enqueueRemove(String itemId, {String? storeType}) async {
    await _mutate(
      (ops) => ops
        // O'chirilgan element bo'yicha kutayotgan set'lar ma'nosiz.
        ..removeWhere(
          (op) =>
              (op['type'] == 'set' || op['type'] == 'remove') &&
              op['item_id'] == itemId,
        )
        ..add({'type': 'remove', 'item_id': itemId, 'store_type': ?storeType}),
    );
  }

  Future<void> enqueueClear(String storeType) async {
    await _mutate(
      (ops) => ops
        // Shu do'konning barcha oldingi amallari bekor — clear hammasini yutadi.
        ..removeWhere(
          (op) =>
              op['store_type'] == storeType &&
              op['operation_id'] != _inFlightId &&
              !(op['type'] == 'add' && op['attempted'] == true),
        )
        ..add({'type': 'clear', 'store_type': storeType}),
    );
  }

  /// Navbatni serverga yuboradi (internet qaytганda chaqiriladi).
  ///
  /// Har bir amal bir marta yuboriladi; 4xx (element yo'q va h.k.) —
  /// o'tkazib yuboriladi, tarmoq xatosi — qolganini keyingi urinishga qoldiradi.
  Future<void> flush() => _serialize(_flush);

  Future<void> _flush() async {
    if (_flushing || !_active) return;
    _flushing = true;
    try {
      await _storageTail;
      if (!_active) return;
      var ops = _load();
      if (ops.isEmpty) return;
      await _mutate((ops) {
        for (final op in ops) {
          if (op['type'] == 'add') op.putIfAbsent('idempotency_key', _uuid);
        }
      });
      ops = _load();
      final touchedStores = <String>{};

      while (ops.isNotEmpty && _active) {
        final op = ops.first;
        try {
          await _execute(op, touchedStores);
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
          // An ambiguous server result must never expire into a duplicate POST.
          break;
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
    if (op['store_type'] == null) {
      // Migrate legacy item operations by resolving their real owner/store.
      for (final type in StoreType.values) {
        final cart = await api.fetch(type.wire);
        if (cart.items.any((item) => item.id == op['item_id'])) {
          op['store_type'] = type.wire;
          await _mutate((ops) {
            for (final candidate in ops) {
              if (candidate['operation_id'] == op['operation_id']) {
                candidate['store_type'] = type.wire;
              }
            }
          });
          break;
        }
      }
      if (op['store_type'] == null) {
        if (op['type'] == 'set' || op['type'] == 'remove') return;
        throw const UnknownFailure();
      }
    }
    touchedStores.add(op['store_type'] as String);
    if (op['type'] == 'set' || op['type'] == 'remove') {
      final remaining = _load()
          .skipWhile(
            (candidate) => candidate['operation_id'] != op['operation_id'],
          )
          .skip(1);
      if (remaining.any(
        (candidate) =>
            candidate['type'] == 'clear' &&
            candidate['store_type'] == op['store_type'],
      )) {
        return;
      }
    }
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
          idempotencyKey: op['idempotency_key'] as String?,
        );
        final current = _load().where(
          (candidate) => candidate['operation_id'] == op['operation_id'],
        );
        final desired =
            ((current.isEmpty ? op : current.first)['desired_quantity'] as num?)
                ?.toInt();
        op['applied_desired'] = desired;
        if (desired != null && desired != op['quantity']) {
          final cart = await api.fetch(storeType);
          final receiptId = api.addedItemId(op['idempotency_key'] as String);
          if (receiptId == null) {
            throw const UnknownFailure.malformed('Cart receipt has no item ID');
          }
          final matches = cart.items.where((item) => item.id == receiptId);
          if (matches.isNotEmpty) {
            if (desired <= 0) {
              final offset =
                  api.addedQuantityOffset(op['idempotency_key'] as String) ?? 0;
              if (offset > 0) {
                await api.updateQuantity(matches.first.id, offset);
              } else {
                await api.deleteItem(matches.first.id);
              }
            } else {
              final offset =
                  api.addedQuantityOffset(op['idempotency_key'] as String) ?? 0;
              await api.updateQuantity(matches.first.id, desired + offset);
            }
          }
        }
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
