import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:beshkashtan_customer/features/payments/data/payments_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    this.statusCode = 200,
    this.body,
    this.throwConnectionError = false,
  });

  final int statusCode;
  final Map<String, Object?>? body;
  final bool throwConnectionError;
  String? path;
  Object? requestData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    requestData = options.data;
    if (throwConnectionError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no network',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body ?? const {'detail': 'Not found.'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_FakeAdapter adapter) => ApiClient.create(
  tokenStore: InMemoryTokenStore(access: 'access', refresh: 'refresh'),
  apiLang: () => 'uz',
  script: () => UzScript.none,
  refresh: (_) async => null,
  onSessionExpired: () async {},
  adapter: adapter,
);

void main() {
  test("create so'rovi to'g'ri path va order_id bilan ketadi", () async {
    final adapter = _FakeAdapter(
      body: const {
        'payment_id': 'pay-1',
        'payment_url': 'https://checkout.paycom.uz/abc',
        'status': 'pending',
      },
    );
    final api = PaymentsApi(_client(adapter));

    final result = await api.createPaymePayment('order-1');

    expect(adapter.path, '/payments/payme/create/');
    expect(adapter.requestData, {'order_id': 'order-1'});
    expect(result.paymentUrl, 'https://checkout.paycom.uz/abc');
    expect(result.status, PaymentStatus.pending);
  });

  test(
    'endpoint hali mavjud emas — 404 NotFoundFailure bilan chiqadi',
    () async {
      final api = PaymentsApi(_client(_FakeAdapter(statusCode: 404)));
      await expectLater(
        api.createPaymePayment('order-1'),
        throwsA(isA<NotFoundFailure>()),
      );
    },
  );

  test('ulanish xatosi NetworkFailure bilan chiqadi', () async {
    final api = PaymentsApi(_client(_FakeAdapter(throwConnectionError: true)));
    await expectLater(
      api.createPaymePayment('order-1'),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
