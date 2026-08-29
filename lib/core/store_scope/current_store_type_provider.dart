import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_type.dart';

/// Har bir store shell o'z qiymati bilan override qiladi. Default qiymat
/// ataylab yo'q: scope'siz store UI qurish noto'g'ri savatga yozishi mumkin.
final currentStoreTypeProvider = Provider<StoreType>(
  (ref) => throw UnsupportedError('StoreType scope berilmagan'),
);
