import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/prefs_store.dart';
import '../../../core/store_scope/store_type.dart';
import '../data/recommendations_api.dart';

final recommendationsApiProvider = Provider<RecommendationsApi>(
  (ref) => RecommendationsApi(ref.watch(apiClientProvider)),
);

/// Oxirgi ochib ko'rilgan mahsulot — katalog shu signal bilan "«X»ga
/// o'xshashlar" qatorini qo'yadi.
class ProductViewSignal {
  const ProductViewSignal({
    required this.productId,
    required this.name,
    required this.storeType,
    required this.at,
  });

  final String productId;
  final String name;
  final StoreType? storeType;
  final DateTime at;
}

final lastProductViewProvider =
    NotifierProvider<LastProductViewController, ProductViewSignal?>(
      LastProductViewController.new,
    );

class LastProductViewController extends Notifier<ProductViewSignal?> {
  @override
  ProductViewSignal? build() => null;

  void set(ProductViewSignal signal) => state = signal;
}

/// Shu sessiyadagi qiziqish hodisalari soni — "Siz uchun" qachon qayta
/// yuklanishini biladi.
final recoActivityProvider = NotifierProvider<RecoActivityController, int>(
  RecoActivityController.new,
);

class RecoActivityController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final interactionTrackerProvider = Provider<InteractionTracker>((ref) {
  PrefsStore? prefs;
  try {
    prefs = ref.watch(prefsStoreProvider);
  } on Object {
    prefs = null; // ba'zi testlar prefs ulamaydi — navbat faqat xotirada
  }
  final tracker = InteractionTracker(
    send: (events) => ref.read(recommendationsApiProvider).postEvents(events),
    prefs: prefs,
    onActivity: (signal) {
      if (!ref.mounted) return;
      ref.read(recoActivityProvider.notifier).bump();
      if (signal != null) {
        ref.read(lastProductViewProvider.notifier).set(signal);
      }
    },
  );
  return tracker;
});

/// Foydalanuvchi qiziqishi hodisalarini yig'ib, serverga paketlab yuboradi.
///
/// **Taymer ishlatilmaydi** (testlarda osilib qolmasin, fonda batareya
/// yemasin): navbat ≥ [batchSize] bo'lsa, oxirgi yuborishdan ≥ [minInterval]
/// o'tib yangi hodisa kelsa yoki ilova fonga ketganda ([flush]) yuboriladi.
/// Xato bo'lsa navbatda qoladi; prefs'ga ham yoziladi — ilova yopilsa ham
/// yo'qolmaydi.
class InteractionTracker {
  InteractionTracker({
    required Future<void> Function(List<Map<String, Object?>>) send,
    PrefsStore? prefs,
    void Function(ProductViewSignal? signal)? onActivity,
    DateTime Function()? clock,
  }) : _send = send,
       _prefs = prefs,
       _onActivity = onActivity,
       _clock = clock ?? DateTime.now {
    _lastFlushAt = _clock();
    _restore();
  }

  static const batchSize = 8;
  static const maxQueue = 100;
  static const minInterval = Duration(seconds: 15);
  static const _searchMergeWindow = Duration(seconds: 20);
  static const _prefsKey = 'reco.event_queue';

  final Future<void> Function(List<Map<String, Object?>>) _send;
  final PrefsStore? _prefs;
  final void Function(ProductViewSignal? signal)? _onActivity;
  final DateTime Function() _clock;
  final List<Map<String, Object?>> _queue = [];
  late DateTime _lastFlushAt;
  bool _sending = false;

  List<Map<String, Object?>> get pending => List.unmodifiable(_queue);

  /// Mahsulot sahifasidan chiqilganda: qancha qaradi va qancha pastga tushdi.
  void recordView({
    required String productId,
    required Duration dwell,
    required double scrollDepth,
    String name = '',
    StoreType? storeType,
    String source = 'detail',
  }) {
    if (productId.isEmpty) return;
    final now = _clock();
    _enqueue({
      'type': 'view',
      'product_id': productId,
      'dwell_ms': dwell.inMilliseconds.clamp(0, 30 * 60 * 1000),
      'scroll_depth': double.parse(
        scrollDepth.clamp(0.0, 1.0).toStringAsFixed(2),
      ),
      'source': source,
      'at': now.toUtc().toIso8601String(),
    });
    _onActivity?.call(
      ProductViewSignal(
        productId: productId,
        name: name,
        storeType: storeType,
        at: now,
      ),
    );
    _maybeFlush();
  }

  /// Qidiruv so'zi. Debounce ketma-ketligi ("cho" → "choy" → "choynak")
  /// bitta hodisaga birlashadi.
  void recordSearch(String query, {StoreType? storeType}) {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;
    final now = _clock();
    final last = _queue.isEmpty ? null : _queue.last;
    if (last != null && last['type'] == 'search') {
      final previous = (last['query'] as String? ?? '').toLowerCase();
      final at = DateTime.tryParse(last['at'] as String? ?? '');
      final lower = trimmed.toLowerCase();
      final related = lower.startsWith(previous) || previous.startsWith(lower);
      if (related &&
          at != null &&
          now.toUtc().difference(at) <= _searchMergeWindow) {
        _queue.removeLast();
      }
    }
    _enqueue({
      'type': 'search',
      'query': trimmed,
      'store_type': ?storeType?.wire,
      'at': now.toUtc().toIso8601String(),
    });
    _onActivity?.call(null);
    _maybeFlush();
  }

  void _enqueue(Map<String, Object?> event) {
    _queue.add(event);
    while (_queue.length > maxQueue) {
      _queue.removeAt(0);
    }
    _persist();
  }

  void _maybeFlush() {
    if (_queue.length >= batchSize ||
        _clock().difference(_lastFlushAt) >= minInterval) {
      unawaited(flush());
    }
  }

  /// Navbatni yuboradi (ilova fonga ketganda ham chaqiriladi).
  Future<void> flush() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    final batch = _queue.take(50).toList();
    try {
      await _send(batch);
      _queue.removeRange(0, batch.length.clamp(0, _queue.length));
      _lastFlushAt = _clock();
      _persist();
    } on Object {
      // Oflayn/eski backend — navbatda qoladi, keyingi safar.
      _lastFlushAt = _clock();
    } finally {
      _sending = false;
    }
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      if (_queue.isEmpty) {
        unawaited(prefs.remove(_prefsKey));
      } else {
        unawaited(prefs.setString(_prefsKey, jsonEncode(_queue)));
      }
    } on Object {
      // Prefs yozilmasa ham asosiy oqim ishlayveradi.
    }
  }

  void _restore() {
    final raw = _prefs?.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is Map) _queue.add(Map<String, Object?>.from(item));
      }
      while (_queue.length > maxQueue) {
        _queue.removeAt(0);
      }
    } on Object {
      unawaited(_prefs?.remove(_prefsKey));
    }
  }
}
