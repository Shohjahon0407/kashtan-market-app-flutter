import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/store_scope/store_type.dart';
import '../data/payments_api.dart';

/// One switch for checkout, order actions and payment initiation.
/// Existing order payment/status data remains unchanged.
final paymeEnabledProvider = Provider<bool>((_) => AppConfig.paymeEnabled);

/// No network request when the build gate is off; old/offline backends fail
/// closed. This endpoint contains capabilities only, never merchant secrets.
final paymentCapabilitiesProvider = FutureProvider<Map<String, bool>>((
  ref,
) async {
  if (!ref.watch(paymeEnabledProvider)) return const {};
  try {
    final capabilities = await ref.watch(paymentsApiProvider).availability();
    return {'household': capabilities['household'] == true};
  } on Object {
    return const {};
  }
});

final paymeAvailableProvider = Provider.family<bool, StoreType>((ref, store) {
  return store == StoreType.household &&
      ref.watch(paymeEnabledProvider) &&
      ref.watch(paymentCapabilitiesProvider).value?[store.wire] == true;
});
