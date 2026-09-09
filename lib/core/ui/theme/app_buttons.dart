import 'package:flutter/material.dart';

/// Dialog `actions` ichidagi tugmalar uchun uslub.
///
/// Theme'dagi `minimumSize: Size.fromHeight(52)` (cheksiz kenglik) dialogning
/// `OverflowBar`ida `loosen()` bilan to'liq kenglikka klamplanadi. Natijada
/// "Bekor" + to'liq kenglikdagi tasdiq tugmasi bir qatorga sig'may, OverflowBar
/// ularni vertikal stack qilib qo'yadi. Shu uslub tugmani M3 odatiy ixcham
/// o'lchamiga (64×40) qaytaradi — Filled/Outlined/Text hammasiga mos.
abstract final class AppButtons {
  static const ButtonStyle dialogAction = ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(Size(64, 40)),
  );
}
