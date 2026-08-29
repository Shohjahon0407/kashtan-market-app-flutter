import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/store_scope/store_type.dart';
import 'cart_controller.dart';

/// To'rtta server savatini bitta UI snapshotida ko'rsatadi.
///
/// Backenddagi savatlar baribir `store_type` bo'yicha mustaqil. Bu provider
/// faqat mavjud family providerlarni agregatsiya qiladi va yangi API kontrakt
/// yaratmaydi.
class MainCartOverviewState {
  const MainCartOverviewState(this.carts);

  final Map<StoreType, AsyncValue<CartState>> carts;

  int get totalQuantity => carts.values.fold<int>(
    0,
    (total, cart) => total + (cart.value?.cart.totalQuantity ?? 0),
  );

  bool get hasAnyItem => totalQuantity > 0;

  bool get isSettled => carts.values.every((cart) => cart is AsyncData);
}

final mainCartOverviewProvider = Provider.autoDispose<MainCartOverviewState>((
  ref,
) {
  return MainCartOverviewState({
    for (final storeType in StoreType.values)
      storeType: ref.watch(cartControllerProvider(storeType)),
  });
});
