/// Backenddagi `StoreTypeChoices` (`apps/common/choices.py`).
///
/// Bu enum butun ilovaning o'qi: savat, buyurtma, katalog, landing —
/// hammasi shu bo'yicha bo'linadi. Foydalanuvchida har do'kon turi uchun
/// alohida savat bo'lishi mumkin.
enum StoreType {
  grocery('grocery'),
  household('household'),
  restaurant('restaurant'),
  shashlik('shashlik'),
  meat('meat');

  const StoreType(this.wire);

  /// Serverga yuboriladigan qiymat.
  final String wire;

  /// Noma'lum qiymatda `null` qaytaradi — ATAYLAB `grocery` emas.
  ///
  /// Eski appda noma'lum store_type jimgina `grocery` ga tushardi va
  /// foydalanuvchi noto'g'ri savatga mahsulot qo'shib qo'yardi.
  static StoreType? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in StoreType.values) {
      if (type.wire == value) return type;
    }
    return null;
  }

  /// Restoran mahsulotlarida `addon_groups` va vaqt oynasi bo'ladi,
  /// boshqalarida `related_products`.
  bool get hasAddons => this == StoreType.restaurant;
}
