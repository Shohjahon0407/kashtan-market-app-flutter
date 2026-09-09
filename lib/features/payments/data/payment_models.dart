import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../checkout/data/checkout_models.dart';

/// To'lov provayderi. Hozircha faqat Payme; kelajakda `click` qo'shiladi.
enum PaymentProvider {
  payme('payme');

  const PaymentProvider(this.wire);

  final String wire;
}

/// Checkout'da tanlanadigan to'lov usuli.
///
/// Wire qiymati fulfillment'ga bog'liq: naqd yo'lida backend hozir o'zi
/// hisoblaydigan qiymatning AYNAN o'zi yuboriladi, shuning uchun bu yo'lda
/// hech qanday farq yuzaga kelmaydi.
enum PaymentMethod {
  payme,
  cash;

  String wireFor(FulfillmentType fulfillmentType) => switch (this) {
    PaymentMethod.payme => 'payme',
    PaymentMethod.cash =>
      fulfillmentType == FulfillmentType.delivery
          ? 'cash_to_courier'
          : 'pay_at_store',
  };
}

/// Buyurtmaning to'lov holati (backend `payment_status` qiymatlari).
enum PaymentStatus {
  pending('pending'),
  paid('paid'),
  failed('failed'),
  cancelled('cancelled'),
  unknown('');

  const PaymentStatus(this.wire);

  final String wire;

  static PaymentStatus fromWire(String? value) {
    for (final status in PaymentStatus.values) {
      if (status != PaymentStatus.unknown && status.wire == value) {
        return status;
      }
    }
    return PaymentStatus.unknown;
  }
}

/// `POST /payments/payme/create/` javobi.
class PaymePaymentCreateResult {
  const PaymePaymentCreateResult({
    required this.paymentId,
    required this.paymentUrl,
    required this.status,
  });

  factory PaymePaymentCreateResult.fromJson(Map<String, dynamic> json) {
    final paymentUrl = JsonRead.string(json['payment_url']);
    if (paymentUrl.isEmpty) {
      throw const UnknownFailure.malformed("Payme javobida payment_url yo'q");
    }
    return PaymePaymentCreateResult(
      paymentId: JsonRead.string(json['payment_id']),
      paymentUrl: paymentUrl,
      status: PaymentStatus.fromWire(JsonRead.string(json['status'])),
    );
  }

  final String paymentId;
  final String paymentUrl;
  final PaymentStatus status;
}
