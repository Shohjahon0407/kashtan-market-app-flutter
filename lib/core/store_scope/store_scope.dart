import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_type.dart';

/// Joriy do'kon turi — **route holati**, global o'zgaruvchi EMAS.
///
/// `/store/:storeType` ShellRoute o'z bolasini shunday o'raydi:
/// ```dart
/// ProviderScope(
///   overrides: [currentStoreTypeProvider.overrideWithValue(storeType)],
///   child: const StoreShell(),
/// )
/// ```
///
/// Store subtree'dan TASHQARIDA o'qilsa ataylab BALAND yiqiladi. Eski appdagi
/// `store_type ?? grocery` fallback'i aynan shu joyda jimgina noto'g'ri savatni
/// ochib yuborardi.
///
/// Haqiqiy state (savat, katalog) esa root'da `family` bilan turadi —
/// shuning uchun 4 ta savat bir vaqtda tirik bo'la oladi va hub ekrani
/// hech qanday scope'ga kirmasdan hammasini o'qiy oladi.
final currentStoreTypeProvider = Provider<StoreType>(
  (ref) => throw StateError(
    'currentStoreTypeProvider store scope tashqarisida o‘qildi. '
    'Uni faqat /store/:storeType subtree ichida ishlating.',
  ),
);
