import 'dart:ui' show Color;

import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../core/utils/hex_color.dart';

/// `GET /home/` javobining bu bosqichda ishlatiladigan qismi.
///
/// Parsing null-tolerant: UI maydonlari (matn, rang, rasm) yo'q bo'lsa ekran
/// baribir chiziladi. Faqat tuzilma buzuq bo'lsa (massiv o'rniga boshqa tur)
/// element jimgina TASHLANMAYDI — butun ro'yxat bo'sh qaytadi va UI bo'sh
/// holatni ko'rsatadi (crash yo'q).
class HomeData {
  const HomeData({required this.banners, required this.storeHub});

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
    banners: _list(json['banners'], HomeBanner.fromJson),
    storeHub: [..._list(json['store_hub'], StoreHubItem.fromJson)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
  );

  final List<HomeBanner> banners;
  final List<StoreHubItem> storeHub;

  static List<T> _list<T>(
    Object? raw,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) out.add(mapper(item));
    }
    return out;
  }
}

/// Admin qo'ygan banner. O'lchamlari ham admindan (`layout`).
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.showText,
    required this.heightPx,
    required this.radius,
    required this.textColor,
    required this.overlayEnabled,
    required this.overlayOpacity,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    final layout = json['layout'];
    final l = layout is Map<String, dynamic>
        ? layout
        : const <String, dynamic>{};
    return HomeBanner(
      id: '${json['id'] ?? ''}',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      imageUrl: json['image'] as String?,
      showText: l['show_text'] != false,
      heightPx: _clampDouble(
        l['mobile_height_px'] ?? l['display_height_px'],
        min: ServerLayoutBounds.minCardHeight,
        max: ServerLayoutBounds.maxCardHeight,
        fallback: 140,
      ),
      radius: _clampDouble(
        l['card_radius'],
        min: ServerLayoutBounds.minCardRadius,
        max: ServerLayoutBounds.maxCardRadius,
        fallback: 16,
      ),
      textColor: HexColor.tryParse(l['text_color'] as String?),
      overlayEnabled: l['overlay_enabled'] == true,
      overlayOpacity: _clampDouble(
        l['overlay_opacity'],
        min: 0,
        max: ServerLayoutBounds.maxOverlayOpacity,
        fallback: 0.35,
      ),
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool showText;

  /// Admin belgilagan balandlik — chegaralab olingan.
  final double heightPx;
  final double radius;
  final Color? textColor;
  final bool overlayEnabled;
  final double overlayOpacity;
}

/// Bosh ekrandagi do'kon kartasi (`store_hub[]` elementi).
class StoreHubItem {
  const StoreHubItem({
    required this.storeType,
    required this.storeTypeWire,
    required this.label,
    required this.subtitle,
    required this.imageUrl,
    required this.accentColor,
    required this.sortOrder,
  });

  factory StoreHubItem.fromJson(Map<String, dynamic> json) {
    final style = json['style'];
    final s = style is Map<String, dynamic> ? style : const <String, dynamic>{};
    final wire = (json['store_type'] as String?) ?? '';
    return StoreHubItem(
      storeType: StoreType.fromWire(wire),
      storeTypeWire: wire,
      label: (json['label'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      // FAQAT `image` — admin ataylab qo'ygan karta rasmi.
      //
      // `background_image` ATAYLAB olinmaydi: u karta FONI uchun mo'ljallangan
      // va hozir prod'da unda tasodifiy test rasmi turibdi (shashlik uchun
      // kosmosdan Yer surati). `icon` esa URL emas, "grocery" kabi kalit so'z.
      // Server rasm bermasa — UI lokal assetga tushadi.
      imageUrl: _firstUrl([json['image'] as String?]),
      accentColor: HexColor.tryParse(s['accent_color'] as String?),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// `null` — server yangi/noma'lum do'kon turi yubordi. Karta baribir
  /// chiziladi (label serverdan), faqat navigatsiyada wire qiymat ishlatiladi.
  final StoreType? storeType;
  final String storeTypeWire;
  final String label;
  final String subtitle;
  final String? imageUrl;

  /// Admin rangi — yo'q/buzuq bo'lsa UI store_type bo'yicha fallback oladi.
  final Color? accentColor;
  final int sortOrder;

  static String? _firstUrl(List<String?> candidates) {
    for (final c in candidates) {
      if (c != null && c.startsWith('http')) return c;
    }
    return null;
  }
}

double _clampDouble(
  Object? raw, {
  required double min,
  required double max,
  required double fallback,
}) {
  final value = switch (raw) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
  if (value == null) return fallback;
  return value.clamp(min, max);
}
