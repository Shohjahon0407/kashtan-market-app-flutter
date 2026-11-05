import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../../core/network/network_providers.dart';
import 'payment_models.dart';

final paymentsApiProvider = Provider<PaymentsApi>(
  (ref) => PaymentsApi(ref.watch(apiClientProvider)),
);

class PaymentsApi {
  const PaymentsApi(this._client);

  final ApiClient _client;

  Future<Map<String, bool>> availability() async {
    final raw = JsonRead.map(await _client.get('/payments/availability/'));
    final values = JsonRead.map(raw?['payme']);
    return {
      for (final entry in (values ?? <String, dynamic>{}).entries)
        entry.key: entry.value == true,
    };
  }

  /// Backend'da Payme to'lovini yaratadi va checkout URL qaytaradi.
  /// App faqat order_id yuboradi — summa va merchant logikasi backendda.
  Future<PaymePaymentCreateResult> createPaymePayment(String orderId) async {
    final data = await _client.post(
      Api.paymePaymentCreate,
      body: {'order_id': orderId},
    );
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure.malformed("Payme to'lov javobi obyekt emas");
    }
    return PaymePaymentCreateResult.fromJson(map);
  }
}
