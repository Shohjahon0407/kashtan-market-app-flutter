/// Bo'shliq, radius va komponent o'lchamlari.
///
/// Toza/minimal uslub — bo'shliq "havo" beradi, lekin katalog ekranlarida
/// mahsulot zichligini yo'qotmaslik uchun shkala 4 px qadamda.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Ekran chetidan standart chekinish.
  static const double screenH = 16;
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

abstract final class AppSizes {
  static const double buttonHeight = 52;
  static const double fieldHeight = 52;
  static const double bottomNavHeight = 64;
  static const double appBarHeight = 56;
  static const double touchTarget = 48;

  /// Mahsulot kartochkasi — 2 ustunli gridda.
  static const double productCardImageAspect = 1;
  static const double railCardWidth = 156;
}

/// Server bergan o'lchamlar uchun xavfsiz chegaralar.
///
/// Admin `card_height`, `card_radius`, `custom_width_ratio` kabi qiymatlarni
/// erkin kiritadi. Ular to'g'ridan-to'g'ri ishlatilsa bitta xato qiymat
/// layoutni buzadi, shuning uchun hammasi shu chegaralarga qisiladi.
abstract final class ServerLayoutBounds {
  static const double minCardHeight = 80;
  static const double maxCardHeight = 260;
  static const double minCardRadius = 0;
  static const double maxCardRadius = 48;
  static const double minWidthRatio = 0.2;
  static const double maxWidthRatio = 1;
  static const double maxOverlayOpacity = 1;
  static const double maxBlurSigma = 20;
}
