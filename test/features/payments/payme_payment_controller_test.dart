import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:beshkashtan_customer/features/payments/data/payments_api.dart';
import 'package:beshkashtan_customer/features/payments/domain/payme_payment_controller.dart';
import 'package:beshkashtan_customer/features/payments/domain/payment_availability.dart';
import 'package:beshkashtan_customer/features/payments/presentation/payme_payment_section.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class _MockPaymentsApi extends Mock implements PaymentsApi {}

class _MockOrdersApi extends Mock implements OrdersApi {}

OrderData _order(String paymentStatus) => OrderData.fromJson({
  'id': 'order-1',
  'order_number': 'BK-1',
  'store_type': 'restaurant',
  'fulfillment_type': 'pickup',
  'status': 'pending',
  'status_label': 'Ko‘rib chiqilmoqda',
  'payment_method': 'payme',
  'payment_status': paymentStatus,
  'subtotal': '30000.00',
  'delivery_fee': '0.00',
  'total': '30000.00',
  'items': <Map<String, dynamic>>[],
  'created_at': '2026-08-22T10:00:00Z',
});

const _createResult = PaymePaymentCreateResult(
  paymentId: 'pay-1',
  paymentUrl: 'https://checkout.paycom.uz/abc',
  status: PaymentStatus.pending,
);

Future<ProviderContainer> _container({
  bool paymeEnabled = true,
  required PaymentsApi paymentsApi,
  required OrdersApi ordersApi,
  required PaymentUrlLauncher launcher,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final container = ProviderContainer(
    overrides: [
      paymeEnabledProvider.overrideWithValue(paymeEnabled),
      prefsStoreProvider.overrideWithValue(prefs),
      paymentsApiProvider.overrideWithValue(paymentsApi),
      ordersApiProvider.overrideWithValue(ordersApi),
      paymentUrlLauncherProvider.overrideWithValue(launcher),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  _autoStartTests();
  test('disabled Payme never creates a payment or launches a URL', () async {
    final api = _MockPaymentsApi();
    var launches = 0;
    final container = await _container(
      paymeEnabled: false,
      paymentsApi: api,
      ordersApi: _MockOrdersApi(),
      launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        launches++;
        return true;
      },
    );
    final provider = paymePaymentControllerProvider('order-1');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.notifier).startPayment();
    expect(container.read(provider).phase, PaymePhase.idle);
    verifyNever(() => api.createPaymePayment(any()));
    expect(launches, 0);
  });
  testWidgets('disabled section stays hidden even with autoStart and resume', (
    tester,
  ) async {
    final api = _MockPaymentsApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentsApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: PaymePaymentSection(
              order: _order('pending'),
              autoStart: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Payme'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    verifyNever(() => api.createPaymePayment(any()));
    expect(tester.takeException(), isNull);
  });
  test(
    'muvaffaqiyat: https URL tashqi rejimda ochiladi, holat awaitingReturn',
    () async {
      final paymentsApi = _MockPaymentsApi();
      when(
        () => paymentsApi.createPaymePayment('order-1'),
      ).thenAnswer((_) async => _createResult);
      Uri? launchedUri;
      LaunchMode? launchedMode;
      final container = await _container(
        paymentsApi: paymentsApi,
        ordersApi: _MockOrdersApi(),
        launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          launchedUri = uri;
          launchedMode = mode;
          return true;
        },
      );
      final provider = paymePaymentControllerProvider('order-1');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(provider.notifier).startPayment();

      expect(launchedUri, Uri.parse('https://checkout.paycom.uz/abc'));
      expect(launchedMode, LaunchMode.externalApplication);
      expect(container.read(provider).phase, PaymePhase.awaitingReturn);
      expect(container.read(provider).failure, isNull);
    },
  );

  test('404 — serviceUnavailable, tugma qayta ishlaydi', () async {
    final paymentsApi = _MockPaymentsApi();
    var calls = 0;
    when(() => paymentsApi.createPaymePayment('order-1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw const NotFoundFailure();
      return _createResult;
    });
    var launches = 0;
    final container = await _container(
      paymentsApi: paymentsApi,
      ordersApi: _MockOrdersApi(),
      launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        launches++;
        return true;
      },
    );
    final provider = paymePaymentControllerProvider('order-1');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);

    await controller.startPayment();
    var state = container.read(provider);
    expect(state.phase, PaymePhase.idle);
    expect(state.serviceUnavailable, isTrue);
    expect(state.failure, isA<NotFoundFailure>());
    expect(launches, 0);

    // Xatodan keyin qayta bosish ishlashi kerak.
    await controller.startPayment();
    state = container.read(provider);
    expect(state.phase, PaymePhase.awaitingReturn);
    expect(state.serviceUnavailable, isFalse);
    expect(launches, 1);
  });

  test('https bo‘lmagan URL hech qachon ochilmaydi', () async {
    final paymentsApi = _MockPaymentsApi();
    when(() => paymentsApi.createPaymePayment('order-1')).thenAnswer(
      (_) async => const PaymePaymentCreateResult(
        paymentId: 'pay-1',
        paymentUrl: 'http://checkout.paycom.uz/abc',
        status: PaymentStatus.pending,
      ),
    );
    var launches = 0;
    final container = await _container(
      paymentsApi: paymentsApi,
      ordersApi: _MockOrdersApi(),
      launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        launches++;
        return true;
      },
    );
    final provider = paymePaymentControllerProvider('order-1');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(provider.notifier).startPayment();

    expect(launches, 0);
    expect(container.read(provider).phase, PaymePhase.idle);
    expect(container.read(provider).failure, isNotNull);
  });

  test('checkStatus: paid → idle, pending → awaitingReturn', () async {
    final ordersApi = _MockOrdersApi();
    var status = 'pending';
    when(
      () => ordersApi.detail('order-1'),
    ).thenAnswer((_) async => _order(status));
    final container = await _container(
      paymentsApi: _MockPaymentsApi(),
      ordersApi: ordersApi,
      launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
          true,
    );
    final provider = paymePaymentControllerProvider('order-1');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);

    await controller.checkStatus();
    expect(container.read(provider).phase, PaymePhase.awaitingReturn);

    status = 'paid';
    await controller.checkStatus();
    expect(container.read(provider).phase, PaymePhase.idle);
    expect(container.read(provider).failure, isNull);
  });
}

// ─── Checkout'dan avtomatik to'lov ───────────────────────────────────────────

void _autoStartTests() {
  testWidgets('autoStart bilan to\'lov bir marta o\'zi boshlanadi', (
    tester,
  ) async {
    final paymentsApi = _MockPaymentsApi();
    var createCalls = 0;
    when(() => paymentsApi.createPaymePayment('order-1')).thenAnswer((_) async {
      createCalls++;
      return _createResult;
    });
    var launches = 0;
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymeEnabledProvider.overrideWithValue(true),
          prefsStoreProvider.overrideWithValue(prefs),
          paymentsApiProvider.overrideWithValue(paymentsApi),
          ordersApiProvider.overrideWithValue(_MockOrdersApi()),
          paymentUrlLauncherProvider.overrideWithValue((
            uri, {
            LaunchMode mode = LaunchMode.platformDefault,
          }) async {
            launches++;
            return true;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: PaymePaymentSection(
              order: _order('pending'),
              autoStart: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(createCalls, 1, reason: 'aynan bitta urinish');
    expect(launches, 1);
  });

  testWidgets("xizmat mavjud bo'lmasa avtomatik urinish jimgina o'tadi", (
    tester,
  ) async {
    final paymentsApi = _MockPaymentsApi();
    when(
      () => paymentsApi.createPaymePayment('order-1'),
    ).thenThrow(const NotFoundFailure());
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymeEnabledProvider.overrideWithValue(true),
          prefsStoreProvider.overrideWithValue(prefs),
          paymentsApiProvider.overrideWithValue(paymentsApi),
          ordersApiProvider.overrideWithValue(_MockOrdersApi()),
          paymentUrlLauncherProvider.overrideWithValue(
            (uri, {LaunchMode mode = LaunchMode.platformDefault}) async => true,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: PaymePaymentSection(
              order: _order('pending'),
              autoStart: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Foydalanuvchi bezovta qilinmaydi — snackbar yo'q, tugma joyida.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Payme orqali to\'lash'), findsOneWidget);
  });
}
