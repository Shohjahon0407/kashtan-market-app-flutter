import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hodisa navbati: taymersiz yuborish qoidalari, xato saqlanishi, prefs.
void main() {
  late DateTime now;
  late List<List<Map<String, Object?>>> sent;
  late bool failSend;
  late PrefsStore prefs;
  late List<ProductViewSignal?> signals;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PrefsStore.load();
    now = DateTime(2026, 10, 9, 12);
    sent = [];
    failSend = false;
    signals = [];
  });

  InteractionTracker tracker() => InteractionTracker(
    send: (events) async {
      if (failSend) throw StateError('offline');
      sent.add(List.of(events));
    },
    prefs: prefs,
    clock: () => now,
    onActivity: signals.add,
  );

  void view(InteractionTracker t, String id, {int seconds = 10}) =>
      t.recordView(
        productId: id,
        dwell: Duration(seconds: seconds),
        scrollDepth: 0.95,
        name: 'Mahsulot $id',
        storeType: StoreType.household,
      );

  test('8 ta hodisagacha yubormaydi, 8-chisida paket ketadi', () async {
    final t = tracker();
    for (var i = 0; i < 7; i++) {
      view(t, 'p$i');
    }
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);
    view(t, 'p7');
    await Future<void>.delayed(Duration.zero);
    expect(sent.single, hasLength(8));
    expect(t.pending, isEmpty);
    expect(sent.single.first['dwell_ms'], 10000);
    expect(sent.single.first['scroll_depth'], 0.95);
    expect(signals.last?.productId, 'p7');
    expect(signals.last?.storeType, StoreType.household);
  });

  test('15 soniyadan keyin bitta hodisa ham yuboriladi', () async {
    final t = tracker();
    now = now.add(const Duration(seconds: 16));
    view(t, 'p1');
    await Future<void>.delayed(Duration.zero);
    expect(sent.single.single['product_id'], 'p1');
  });

  test('xato bo\'lsa navbatda qoladi va prefs\'dan tiklanadi', () async {
    failSend = true;
    final t = tracker();
    for (var i = 0; i < 8; i++) {
      view(t, 'p$i');
    }
    await Future<void>.delayed(Duration.zero);
    expect(t.pending, hasLength(8));

    final restored = tracker();
    expect(restored.pending, hasLength(8));
    failSend = false;
    await restored.flush();
    expect(sent.single, hasLength(8));
    expect(tracker().pending, isEmpty);
  });

  test('qidiruv debounce ketma-ketligi bitta hodisaga birlashadi', () {
    final t = tracker()
      ..recordSearch('ch')
      ..recordSearch('choy')
      ..recordSearch('choynak', storeType: StoreType.household)
      ..recordSearch('x'); // juda qisqa — yozilmaydi
    expect(t.pending, hasLength(1));
    expect(t.pending.single['query'], 'choynak');
    expect(t.pending.single['store_type'], 'household');

    now = now.add(const Duration(minutes: 1));
    t.recordSearch('choynakka qopqoq');
    expect(t.pending, hasLength(2));
  });

  test('navbat 100 ta bilan chegaralangan', () {
    failSend = true;
    final t = tracker();
    for (var i = 0; i < 130; i++) {
      t.recordSearch('soz $i ${'x' * (i % 3)}');
      now = now.add(const Duration(minutes: 1));
    }
    expect(t.pending.length, InteractionTracker.maxQueue);
  });
}
