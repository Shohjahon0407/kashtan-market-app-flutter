import 'package:shared_preferences/shared_preferences.dart';

/// MAXFIY BO'LMAGAN sozlamalar: til, mavzu, oxirgi tanlangan do'kon turi.
///
/// Tokenlar bu yerda EMAS — ular [SecureTokenStore] da.
class PrefsStore {
  PrefsStore(this._prefs);

  /// `runApp` dan oldin bir marta yuklanadi, shunda birinchi kadr allaqachon
  /// to'g'ri til va mavzu bilan chiziladi (oq ekran chaqnashi bo'lmaydi).
  static Future<PrefsStore> load() async =>
      PrefsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const String _kLocale = 'app.locale_code';
  static const String _kLastStoreType = 'app.last_store_type';
  static const String _kOnboardingSeen = 'app.onboarding_seen';
  static const String _kNotificationsAsked = 'app.notifications_asked';

  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String value) => _prefs.setString(_kLocale, value);

  String? get lastStoreType => _prefs.getString(_kLastStoreType);
  Future<void> setLastStoreType(String value) =>
      _prefs.setString(_kLastStoreType, value);

  bool get onboardingSeen => _prefs.getBool(_kOnboardingSeen) ?? false;
  Future<void> setOnboardingSeen({required bool value}) =>
      _prefs.setBool(_kOnboardingSeen, value);

  /// Android 13+ bildirishnoma ruxsati so'ralganmi.
  /// Ruxsat cold start'da emas, birinchi buyurtmadan keyin so'raladi.
  bool get notificationsAsked => _prefs.getBool(_kNotificationsAsked) ?? false;
  Future<void> setNotificationsAsked({required bool value}) =>
      _prefs.setBool(_kNotificationsAsked, value);

  Future<void> clearSessionScoped() async {
    await _prefs.remove(_kLastStoreType);
  }

  // ── Umumiy kalitlar ─────────────────────────────────────────────────────
  // Feature'lar o'z keshini (masalan auth user JSON) shu orqali saqlaydi.
  // MAXFIY ma'lumot uchun EMAS — tokenlar SecureTokenStore da.

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) async {
    if (!await _prefs.setString(key, value)) {
      throw StateError('Could not persist $key');
    }
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
