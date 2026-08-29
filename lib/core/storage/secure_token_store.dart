import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT tokenlarni platforma xavfsiz omborida saqlaydi.
///
/// iOS → Keychain, Android → EncryptedSharedPreferences.
/// Eski app tokenlarni oddiy `SharedPreferences` da ochiq saqlar edi —
/// root qilingan qurilmada yoki backup orqali o'qish mumkin edi.
abstract interface class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> saveAccess(String access);
  Future<void> clear();
}

abstract interface class GuestCartTokenStore {
  Future<String?> readGuestCartToken();
  Future<void> saveGuestCartToken(String token);
  Future<void> clearGuestCartToken();
}

class SecureTokenStore implements TokenStore, GuestCartTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const String _kAccess = 'auth.access_token';
  static const String _kRefresh = 'auth.refresh_token';
  static const String _kGuestCart = 'cart.guest_token';

  /// Har o'qishda Keychain'ga bormaslik uchun kichik keshlar.
  /// `AuthInterceptor` har so'rovda access tokenni o'qiydi.
  String? _accessCache;
  String? _refreshCache;
  String? _guestCartCache;
  bool _warmed = false;

  /// Xavfsiz ombor ba'zi qurilmalarda (keystore buzilgan, MIUI cheklovlari,
  /// birinchi ishga tushishdagi migratsiya) xato berishi mumkin.
  ///
  /// Bunday holatda so'rov BUTUNLAY yiqilmasligi kerak — token yo'q deb
  /// hisoblanadi va foydalanuvchi qaytadan kiradi. Aks holda xato butun
  /// interceptor zanjiridan o'tib, "Internet aloqasi yo'q" kabi mutlaqo
  /// aloqasiz xabarga aylanardi.
  Future<void> _warm() async {
    if (_warmed) return;
    try {
      _accessCache = await _storage.read(key: _kAccess);
      _refreshCache = await _storage.read(key: _kRefresh);
      _guestCartCache = await _storage.read(key: _kGuestCart);
    } on Object catch (error, stack) {
      _accessCache = null;
      _refreshCache = null;
      _guestCartCache = null;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'secure_token_store',
          context: ErrorDescription('tokenlarni o‘qishda'),
        ),
      );
    }
    _warmed = true;
  }

  @override
  Future<String?> readAccess() async {
    await _warm();
    return _accessCache;
  }

  @override
  Future<String?> readRefresh() async {
    await _warm();
    return _refreshCache;
  }

  @override
  Future<void> save({required String access, required String refresh}) async {
    _accessCache = access;
    _refreshCache = refresh;
    _warmed = true;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  @override
  Future<void> saveAccess(String access) async {
    _accessCache = access;
    _warmed = true;
    await _storage.write(key: _kAccess, value: access);
  }

  @override
  Future<String?> readGuestCartToken() async {
    await _warm();
    return _guestCartCache;
  }

  @override
  Future<void> saveGuestCartToken(String token) async {
    _guestCartCache = token;
    _warmed = true;
    await _storage.write(key: _kGuestCart, value: token);
  }

  @override
  Future<void> clearGuestCartToken() async {
    _guestCartCache = null;
    await _storage.delete(key: _kGuestCart);
  }

  @override
  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    _warmed = true;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

/// Testlar va `flutter test` uchun xotiradagi variant.
class InMemoryTokenStore implements TokenStore, GuestCartTokenStore {
  InMemoryTokenStore({String? access, String? refresh, String? guestCartToken})
    : _access = access,
      _refresh = refresh,
      _guestCart = guestCartToken;

  String? _access;
  String? _refresh;
  String? _guestCart;

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> saveAccess(String access) async => _access = access;

  @override
  Future<String?> readGuestCartToken() async => _guestCart;

  @override
  Future<void> saveGuestCartToken(String token) async => _guestCart = token;

  @override
  Future<void> clearGuestCartToken() async => _guestCart = null;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
