/// Backend JSON may expose serializer method fields as bool/number in runtime
/// even when Swagger describes them as strings. These helpers keep all wire
/// parsing tolerant in one place without silently inventing identifiers.
abstract final class JsonRead {
  static String string(Object? value, [String fallback = '']) =>
      value == null ? fallback : value.toString();

  static String? nullableString(Object? value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static bool boolean(Object? value, {bool fallback = false}) =>
      switch (value) {
        true => true,
        false => false,
        final num n => n != 0,
        final String s when s.toLowerCase() == 'true' || s == '1' => true,
        final String s when s.toLowerCase() == 'false' || s == '0' => false,
        _ => fallback,
      };

  static int integer(Object? value, [int fallback = 0]) => switch (value) {
    final int n => n,
    final num n => n.toInt(),
    final String s => int.tryParse(s) ?? fallback,
    _ => fallback,
  };

  static double? nullableDouble(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static Map<String, dynamic>? map(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  static List<T> list<T>(
    Object? value,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map<String, dynamic>) mapper(item),
    ];
  }
}
