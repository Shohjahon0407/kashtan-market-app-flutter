import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/payments/data/payments_api.dart';
import 'package:beshkashtan_customer/features/payments/domain/payment_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements PaymentsApi {}

void main() {
  test('build gate off never requests capabilities', () async {
    final api = _Api();
    final container = ProviderContainer(
      overrides: [
        paymeEnabledProvider.overrideWithValue(false),
        paymentsApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(paymentCapabilitiesProvider.future), isEmpty);
    expect(
      container.read(paymeAvailableProvider(StoreType.household)),
      isFalse,
    );
    verifyNever(() => api.availability());
  });

  test(
    'backend capability is store scoped and unknown stores stay closed',
    () async {
      final api = _Api();
      when(() => api.availability()).thenAnswer(
        (_) async => {
          'household': true,
          'grocery': false,
          'restaurant': true,
          'shashlik': true,
        },
      );
      final container = ProviderContainer(
        overrides: [
          paymeEnabledProvider.overrideWithValue(true),
          paymentsApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      await container.read(paymentCapabilitiesProvider.future);
      expect(
        container.read(paymeAvailableProvider(StoreType.household)),
        isTrue,
      );
      expect(
        container.read(paymeAvailableProvider(StoreType.grocery)),
        isFalse,
      );
      expect(container.read(paymeAvailableProvider(StoreType.meat)), isFalse);
      expect(
        container.read(paymeAvailableProvider(StoreType.restaurant)),
        isFalse,
      );
      expect(
        container.read(paymeAvailableProvider(StoreType.shashlik)),
        isFalse,
      );
      verify(() => api.availability()).called(1);
    },
  );

  for (final failure in [const NotFoundFailure(), const NetworkFailure()]) {
    test(
      'old/offline backend hides new payment option: ${failure.runtimeType}',
      () async {
        final api = _Api();
        when(() => api.availability()).thenThrow(failure);
        final container = ProviderContainer(
          overrides: [
            paymeEnabledProvider.overrideWithValue(true),
            paymentsApiProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        await container.read(paymentCapabilitiesProvider.future);
        expect(
          container.read(paymeAvailableProvider(StoreType.restaurant)),
          isFalse,
        );
      },
    );
  }
}
