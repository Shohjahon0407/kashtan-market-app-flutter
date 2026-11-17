import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:beshkashtan_customer/features/payments/data/payments_api.dart';
import 'package:beshkashtan_customer/features/payments/domain/payment_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements PaymentsApi {}

void main() {
  for (final ready in [false, true]) {
    test(
      'public release requires explicit backend readiness: $ready',
      () async {
        final api = _Api();
        when(() => api.availability()).thenAnswer(
          (_) async => PaymentCapabilities(
            stores: const {'household': true, 'restaurant': true},
            productionReady: ready,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            paymeEnabledProvider.overrideWithValue(true),
            paymeAllowsSandboxProvider.overrideWithValue(false),
            paymentsApiProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        await container.read(paymentCapabilitiesProvider.future);
        expect(
          container.read(paymeAvailableProvider(StoreType.household)),
          ready,
        );
        expect(
          container.read(paymeAvailableProvider(StoreType.restaurant)),
          isFalse,
        );
      },
    );
  }

  test('backend rollout can enable payment without a new app build', () async {
    final api = _Api();
    var ready = false;
    when(() => api.availability()).thenAnswer(
      (_) async => PaymentCapabilities(
        stores: const {'household': true},
        productionReady: ready,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        paymeEnabledProvider.overrideWithValue(true),
        paymeAllowsSandboxProvider.overrideWithValue(false),
        paymentsApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await container.read(paymentCapabilitiesProvider.future);
    expect(
      container.read(paymeAvailableProvider(StoreType.household)),
      isFalse,
    );
    ready = true;
    container.invalidate(paymentCapabilitiesProvider);
    await container.read(paymentCapabilitiesProvider.future);
    expect(container.read(paymeAvailableProvider(StoreType.household)), isTrue);
    ready = false;
    container.invalidate(paymentCapabilitiesProvider);
    await container.read(paymentCapabilitiesProvider.future);
    expect(
      container.read(paymeAvailableProvider(StoreType.household)),
      isFalse,
    );
  });

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
        (_) async => const PaymentCapabilities(
          stores: {
            'household': true,
            'grocery': false,
            'restaurant': true,
            'shashlik': true,
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          paymeEnabledProvider.overrideWithValue(true),
          paymeAllowsSandboxProvider.overrideWithValue(true),
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
