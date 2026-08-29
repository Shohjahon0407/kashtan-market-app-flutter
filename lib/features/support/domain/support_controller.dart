import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/network_providers.dart';
import '../data/support_api.dart';
import '../data/support_models.dart';

final supportApiProvider = Provider<SupportApi>(
  (ref) => SupportApi(ref.watch(apiClientProvider)),
);

final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((
  ref,
) async {
  ref.watch(apiLangProvider);
  return ref.watch(supportApiProvider).fetchTickets();
});
