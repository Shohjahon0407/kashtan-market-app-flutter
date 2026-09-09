import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_controller.dart';
import 'json_disk_cache.dart';

/// Stable storage ownership; never use a phone number or a bearer token in keys.
final accountScopeProvider = Provider<String>((ref) {
  final id = ref.watch(
    authControllerProvider.select(
      (auth) => auth.isAuthenticated ? auth.user?.id : null,
    ),
  );
  return id == null
      ? 'guest'
      : 'user_${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';
});

/// Old unscoped private entries are intentionally not read or migrated: their
/// owner cannot be established safely. They expire via existing cache cleanup.
final privateJsonCacheProvider = Provider<JsonDiskCache>((ref) {
  final owner = ref.watch(accountScopeProvider);
  return AccountJsonCache(
    ref.watch(jsonDiskCacheProvider),
    owner,
    () => ref.mounted && ref.read(accountScopeProvider) == owner,
  );
});

class AccountJsonCache extends JsonDiskCache {
  AccountJsonCache(this.delegate, this.owner, this.isCurrent);
  final JsonDiskCache delegate;
  final String owner;
  final bool Function() isCurrent;
  String _key(String key) => 'private_v2_${owner}_$key';
  bool get _allowed => owner != 'guest' && isCurrent();

  @override
  Future<void> writeJson(String key, Object json) async {
    if (_allowed) await delegate.writeJson(_key(key), json);
  }

  @override
  Future<CachedEntry?> readEntry(String key, {Duration? maxAge}) async {
    if (!_allowed) return null;
    final entry = await delegate.readEntry(_key(key), maxAge: maxAge);
    return _allowed ? entry : null;
  }

  @override
  Future<void> delete(String key) async {
    if (_allowed) await delegate.delete(_key(key));
  }

  @override
  Future<void> clear() async {
    // Clearing this wrapper must never delete another account's cached data.
    // Account deletion uses the existing root cache cleanup explicitly.
  }
}
