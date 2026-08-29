import 'dart:async';

import 'package:beshkashtan_customer/core/config/api_endpoints.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

const _emptyCart = <String, dynamic>{
  'id': 'cart-1',
  'store_type': 'grocery',
  'items': <Object>[],
  'total_items': 0,
  'total_quantity': 0,
  'subtotal': '0.00',
};

void main() {
  late _MockApiClient client;
  late InMemoryTokenStore tokens;
  late CartApi api;

  setUp(() {
    client = _MockApiClient();
    tokens = InMemoryTokenStore();
    api = CartApi(client, tokens, () => false);
  });

  test('parallel store fetchlar faqat bitta guest session yaratadi', () async {
    final session = Completer<Object?>();
    when(
      () => client.post(Api.guestCartSession),
    ).thenAnswer((_) => session.future);
    when(
      () => client.get(
        Api.cart,
        query: any(named: 'query'),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => _emptyCart);

    final requests = [
      api.fetch('grocery'),
      api.fetch('household'),
      api.fetch('restaurant'),
      api.fetch('shashlik'),
    ];
    session.complete({'token': 'guest-token'});
    await Future.wait(requests);
    await api.fetch('grocery');

    verify(() => client.post(Api.guestCartSession)).called(1);
    expect(await tokens.readGuestCartToken(), 'guest-token');
    final captured = verify(
      () => client.get(
        Api.cart,
        query: any(named: 'query'),
        headers: captureAny(named: 'headers'),
      ),
    ).captured;
    expect(
      captured.every(
        (headers) =>
            (headers as Map<String, dynamic>)['X-Guest-Cart-Token'] ==
            'guest-token',
      ),
      isTrue,
    );
  });

  test(
    'expired guest token bir marta yangilanib GET qayta bajariladi',
    () async {
      tokens = InMemoryTokenStore(guestCartToken: 'expired-token');
      api = CartApi(client, tokens, () => false);
      var attempts = 0;
      when(
        () => client.get(
          Api.cart,
          query: any(named: 'query'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async {
        attempts += 1;
        if (attempts == 1) throw const UnauthorizedFailure('expired');
        return _emptyCart;
      });
      when(
        () => client.post(Api.guestCartSession),
      ).thenAnswer((_) async => {'token': 'renewed-token'});

      final cart = await api.fetch('grocery');

      expect(cart.totalQuantity, 0);
      expect(attempts, 2);
      expect(await tokens.readGuestCartToken(), 'renewed-token');
      verify(() => client.post(Api.guestCartSession)).called(1);
    },
  );

  test('merge xatosida token qoladi, muvaffaqiyatda tozalanadi', () async {
    tokens = InMemoryTokenStore(guestCartToken: 'guest-token');
    api = CartApi(client, tokens, () => true);
    var attempts = 0;
    when(
      () => client.post(Api.mergeGuestCart, headers: any(named: 'headers')),
    ).thenAnswer((_) async {
      attempts += 1;
      if (attempts == 1) throw const NetworkFailure('offline');
      return <String, dynamic>{'merged': true};
    });

    await expectLater(api.mergeGuestCart(), throwsA(isA<NetworkFailure>()));
    expect(await tokens.readGuestCartToken(), 'guest-token');

    expect(await api.mergeGuestCart(), isTrue);
    expect(await tokens.readGuestCartToken(), isNull);
    expect(attempts, 2);
  });
}
