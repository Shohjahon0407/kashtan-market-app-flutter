import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentMethod.wireFor', () {
    test('payme har ikkala fulfillment uchun ham payme yuboradi', () {
      expect(PaymentMethod.payme.wireFor(FulfillmentType.delivery), 'payme');
      expect(PaymentMethod.payme.wireFor(FulfillmentType.pickup), 'payme');
    });

    test('naqd backend semantikasiga mos qiymat yuboradi', () {
      // Backend delivery uchun cash_to_courier, pickup uchun pay_at_store
      // hisoblaydi — app aynan shuni yuboradi, farq yuzaga kelmaydi.
      expect(
        PaymentMethod.cash.wireFor(FulfillmentType.delivery),
        'cash_to_courier',
      );
      expect(
        PaymentMethod.cash.wireFor(FulfillmentType.pickup),
        'pay_at_store',
      );
    });
  });

  group('PaymentStatus.fromWire', () {
    test('barcha backend qiymatlari parse qilinadi', () {
      expect(PaymentStatus.fromWire('pending'), PaymentStatus.pending);
      expect(PaymentStatus.fromWire('unpaid'), PaymentStatus.pending);
      expect(
        PaymentStatus.fromWire('refund_pending'),
        PaymentStatus.refundPending,
      );
      expect(PaymentStatus.fromWire('refunded'), PaymentStatus.refunded);
      expect(PaymentStatus.fromWire('paid'), PaymentStatus.paid);
      expect(PaymentStatus.fromWire('failed'), PaymentStatus.failed);
      expect(PaymentStatus.fromWire('cancelled'), PaymentStatus.cancelled);
    });

    test("noma'lum qiymatlar xavfsiz unknown ga tushadi", () {
      expect(PaymentStatus.fromWire(''), PaymentStatus.unknown);
      expect(PaymentStatus.fromWire(null), PaymentStatus.unknown);
      expect(PaymentStatus.fromWire('weird_value'), PaymentStatus.unknown);
    });
  });

  group('PaymePaymentCreateResult.fromJson', () {
    test('terminal results do not require a checkout URL', () {
      for (final status in [
        'paid',
        'cancelled',
        'refund_pending',
        'refunded',
      ]) {
        final result = PaymePaymentCreateResult.fromJson({
          'status': status,
          'payment_url': '',
        });
        expect(result.status, isNot(PaymentStatus.unknown));
        expect(result.paymentUrl, isEmpty);
      }
    });
    test('happy path parse qilinadi', () {
      final result = PaymePaymentCreateResult.fromJson(const {
        'payment_id': 'pay-1',
        'payment_url': 'https://checkout.paycom.uz/abc',
        'status': 'pending',
      });
      expect(result.paymentId, 'pay-1');
      expect(result.paymentUrl, 'https://checkout.paycom.uz/abc');
      expect(result.status, PaymentStatus.pending);
    });

    test("payment_url bo'lmasa UnknownFailure", () {
      expect(
        () => PaymePaymentCreateResult.fromJson(const {'status': 'pending'}),
        throwsA(isA<UnknownFailure>()),
      );
      expect(
        () => PaymePaymentCreateResult.fromJson(const {'payment_url': ''}),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });
}
