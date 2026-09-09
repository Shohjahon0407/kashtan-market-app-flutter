import 'api_failure.dart';

/// Backend UCH XIL sahifalash konvertidan foydalanadi. Ularni "sezib olish"
/// (sniffing) ataylab qilinmaydi — har repository qaysi konvert kelishini
/// bilishi va MOS dekoderni chaqirishi shart.
///
/// Eski appdagi `ApiResponseParser` hammasiga toqat qilar edi va shakl
/// o'zgarganda jimgina bo'sh ro'yxat qaytarardi. Bu yerda mos kelmagan shakl
/// [ApiFailure] bilan baland yiqiladi.
sealed class Paged<T> {
  const Paged({required this.items, required this.nextUrl});

  final List<T> items;

  /// Keyingi sahifaning TO'LIQ absolut URL'i (backend shunday qaytaradi).
  /// `null` — boshqa sahifa yo'q.
  final String? nextUrl;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;
  bool get isEmpty => items.isEmpty;
}

/// `{next, previous, results}` — `count` YO'Q.
///
/// Ishlatiladi: `/catalog/products/` va uning `search|featured|popular|
/// discounted` variantlari. Parametrlar: `cursor`, `page_size`.
final class CursorPage<T> extends Paged<T> {
  const CursorPage({
    required super.items,
    required super.nextUrl,
    this.previousUrl,
  });

  final String? previousUrl;
}

/// `{count, next, previous, results}` — sahifa raqami bilan.
///
/// Ishlatiladi: kategoriyalar, buyurtmalar, bildirishnomalar, do'konlar,
/// aksiyalar, bannerlar, store-top-banners, sharhlar.
final class OffsetPage<T> extends Paged<T> {
  const OffsetPage({
    required super.items,
    required super.nextUrl,
    required this.count,
    this.previousUrl,
  });

  /// Serverdagi jami yozuvlar soni.
  final int count;

  final String? previousUrl;
}

/// Yalang'och JSON massiv — sahifalash umuman yo'q.
///
/// Ishlatiladi: `/addresses/`, `/favorites/`, `/support/tickets/`,
/// `/stores/{id}/branches/`.
final class BareList<T> extends Paged<T> {
  const BareList({required super.items}) : super(nextUrl: null);
}

/// JSON dan model yasovchi.
typedef JsonMapper<T> = T Function(Map<String, dynamic> json);

abstract final class PageDecoder {
  /// `{next, previous, results}`.
  static CursorPage<T> cursor<T>(Object? json, JsonMapper<T> mapper) {
    final map = _asMap(json, 'CursorPage');
    return CursorPage<T>(
      items: _results(map, mapper, 'CursorPage'),
      nextUrl: _asNullableString(map['next']),
      previousUrl: _asNullableString(map['previous']),
    );
  }

  /// `{count, next, previous, results}`.
  ///
  /// `count` yo'q bo'lsa ataylab yiqiladi: demak endpoint aslida cursor
  /// konvertida va noto'g'ri dekoder chaqirilgan.
  static OffsetPage<T> offset<T>(Object? json, JsonMapper<T> mapper) {
    final map = _asMap(json, 'OffsetPage');
    final rawCount = map['count'];
    if (rawCount is! int) {
      throw const UnknownFailure.malformed(
        'OffsetPage kutilgan edi, lekin javobda "count" yo\'q — '
        'ehtimol bu cursor sahifalash.',
      );
    }
    return OffsetPage<T>(
      items: _results(map, mapper, 'OffsetPage'),
      nextUrl: _asNullableString(map['next']),
      previousUrl: _asNullableString(map['previous']),
      count: rawCount,
    );
  }

  /// Yalang'och massiv. `{"results": [...]}` shakli ham qabul qilinadi —
  /// `/home/news/` aynan shunday qaytaradi.
  static BareList<T> bare<T>(Object? json, JsonMapper<T> mapper) {
    if (json is List) {
      return BareList<T>(items: _mapList(json, mapper, 'BareList'));
    }
    if (json is Map<String, dynamic> && json['results'] is List) {
      return BareList<T>(
        items: _mapList(json['results'] as List, mapper, 'BareList'),
      );
    }
    throw UnknownFailure.malformed(
      'BareList kutilgan edi, lekin ${json.runtimeType} keldi.',
    );
  }

  // ── Ichki yordamchilar ─────────────────────────────────────────────────────

  static Map<String, dynamic> _asMap(Object? json, String who) {
    if (json is Map<String, dynamic>) return json;
    throw UnknownFailure.malformed(
      '$who kutilgan edi, lekin ${json.runtimeType} keldi.',
    );
  }

  static List<T> _results<T>(
    Map<String, dynamic> map,
    JsonMapper<T> mapper,
    String who,
  ) {
    final raw = map['results'];
    if (raw is! List) {
      throw UnknownFailure.malformed('$who javobida "results" massivi yo\'q.');
    }
    return _mapList(raw, mapper, who);
  }

  static List<T> _mapList<T>(
    List<Object?> raw,
    JsonMapper<T> mapper,
    String who,
  ) {
    final out = <T>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        throw UnknownFailure.malformed(
          '$who elementi obyekt emas: ${item.runtimeType}.',
        );
      }
      out.add(mapper(item));
    }
    return out;
  }

  static String? _asNullableString(Object? value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }
}
