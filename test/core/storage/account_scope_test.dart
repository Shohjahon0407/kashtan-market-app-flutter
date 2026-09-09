import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCache extends JsonDiskCache {
  final values = <String, CachedEntry>{};
  @override
  Future<void> writeJson(String key, Object json) async {
    values[key] = CachedEntry(payload: json, cachedAt: DateTime.now());
  }

  @override
  Future<CachedEntry?> readEntry(String key, {Duration? maxAge}) async =>
      values[key];
}

void main() {
  test(
    'private cache is isolated, rejects legacy keys and skips late writes',
    () async {
      final disk = _MemoryCache();
      var owner = 'A';
      final a = AccountJsonCache(disk, 'A', () => owner == 'A');
      final b = AccountJsonCache(disk, 'B', () => owner == 'B');
      await disk.writeJson('addresses_uz', [
        {'id': 'legacy'},
      ]);
      expect(await a.readList('addresses_uz'), isNull);
      await a.writeJson('addresses_uz', [
        {'id': 'A-address'},
      ]);
      owner = 'B';
      expect(await b.readList('addresses_uz'), isNull);
      expect(await a.readList('addresses_uz'), isNull);
      await a.writeJson('addresses_uz', [
        {'id': 'late'},
      ]);
      await b.writeJson('addresses_uz', [
        {'id': 'B-address'},
      ]);
      expect(await b.readList('addresses_uz'), [
        {'id': 'B-address'},
      ]);
      owner = 'A';
      expect(await a.readList('addresses_uz'), [
        {'id': 'A-address'},
      ]);
      final guest = AccountJsonCache(disk, 'guest', () => true);
      await guest.writeJson('addresses_uz', [
        {'id': 'not-public'},
      ]);
      expect(await guest.readList('addresses_uz'), isNull);
    },
  );
}
