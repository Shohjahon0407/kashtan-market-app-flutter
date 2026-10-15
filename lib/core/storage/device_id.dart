import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/locale_controller.dart';
import 'prefs_store.dart';

const _kDeviceId = 'app.device_id';

/// Anonim qurilma identifikatori (UUID v4) — mehmon foydalanuvchining
/// qiziqishlarini (ko'rgan mahsulotlari) tavsiyada hisobga olish uchun.
/// Hech qanday shaxsiy ma'lumot emas; login'da server tarixni akkauntga
/// birlashtiradi. Ilova qayta o'rnatilsa yangisi yaratiladi.
String readOrCreateDeviceId(PrefsStore prefs, {Random? random}) {
  final existing = prefs.getString(_kDeviceId);
  if (existing != null && isValidUuid(existing)) return existing;
  final created = generateUuidV4(random ?? Random.secure());
  prefs.setString(_kDeviceId, created);
  return created;
}

String generateUuidV4(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versiya 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 varianti
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

bool isValidUuid(String value) => _uuidPattern.hasMatch(value);

/// `null` — prefs ulanmagan muhit (ba'zi testlar): sarlavha yuborilmaydi.
final deviceIdProvider = Provider<String?>((ref) {
  try {
    return readOrCreateDeviceId(ref.watch(prefsStoreProvider));
  } on Object {
    return null;
  }
});
