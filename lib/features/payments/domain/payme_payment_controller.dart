import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../../core/network/api_failure.dart';
import '../../../core/storage/account_scope.dart';
import '../../orders/data/order_models.dart';
import '../../orders/domain/orders_controller.dart';
import '../data/payment_models.dart';
import '../data/payments_api.dart';
import 'payment_availability.dart';

/// To'lov jarayonining bosqichi. paid/failed/cancelled bu yerda YO'Q —
/// yakuniy holat faqat buyurtmaning `payment_status` maydonidan o'qiladi,
/// shuning uchun app hech qachon o'zicha "to'landi" deya olmaydi.
enum PaymePhase { idle, creating, awaitingReturn, checking }

class PaymePaymentState {
  const PaymePaymentState({
    this.phase = PaymePhase.idle,
    this.failure,
    this.serviceUnavailable = false,
  });

  final PaymePhase phase;

  /// Oxirgi amaldagi xato — widget `ref.listen` orqali snackbar qiladi.
  final ApiFailure? failure;

  /// Create 404/ulanish xatosi berdi — backend hali tayyor emas.
  final bool serviceUnavailable;

  bool get busy => phase == PaymePhase.creating || phase == PaymePhase.checking;
}

typedef PaymentUrlLauncher =
    Future<bool> Function(Uri url, {url_launcher.LaunchMode mode});

/// URL ochish vositasi alohida provider — testda fake bilan almashtiriladi.
final paymentUrlLauncherProvider = Provider<PaymentUrlLauncher>(
  (ref) => url_launcher.launchUrl,
);

final paymePaymentControllerProvider = NotifierProvider.autoDispose
    .family<PaymePaymentController, PaymePaymentState, String>(
      (orderId) => PaymePaymentController(orderId),
    );

/// Provider autoDispose: foydalanuvchi so'rov paytida orqaga bossa, javob
/// kelganda `state`/`ref` ga tegish UnmountedRefException beradi — shuning
/// uchun HAR await'dan keyin `ref.mounted` tekshiriladi.
class PaymePaymentController extends Notifier<PaymePaymentState> {
  PaymePaymentController(this.orderId);

  final String orderId;
  int _epoch = 0;

  bool _current(int epoch) => ref.mounted && epoch == _epoch;

  @override
  PaymePaymentState build() {
    ref.watch(accountScopeProvider);
    _epoch++;
    return const PaymePaymentState();
  }

  /// Backend'dan payment_url oladi va tashqi brauzerda ochadi.
  Future<void> startPayment() async {
    if (!ref.read(paymeEnabledProvider) || state.busy) return;
    final epoch = _epoch;
    state = const PaymePaymentState(phase: PaymePhase.creating);
    try {
      final result = await ref
          .read(paymentsApiProvider)
          .createPaymePayment(orderId);
      if (!_current(epoch)) return;

      if (const {
        PaymentStatus.paid,
        PaymentStatus.cancelled,
        PaymentStatus.refundPending,
        PaymentStatus.refunded,
      }.contains(result.status)) {
        // Allaqachon to'langan — buyurtmani yangilab natijani ko'rsatamiz.
        await _refreshOrder();
        if (!_current(epoch)) return;
        state = const PaymePaymentState();
        return;
      }

      final uri = Uri.tryParse(result.paymentUrl);
      // Faqat https ochiladi — boshqa scheme'lar (shu jumladan http) rad etiladi.
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          !const {'checkout.paycom.uz', 'test.paycom.uz'}.contains(uri.host)) {
        state = const PaymePaymentState(failure: UnknownFailure());
        return;
      }
      final launcher = ref.read(paymentUrlLauncherProvider);
      var launched = false;
      // A production HTTPS checkout link can be handled by the installed
      // Payme app. Prefer that handler, retaining the exact server URL.
      // Sandbox must never be rewritten to a production/deep-link scheme.
      if (uri.host == 'checkout.paycom.uz') {
        try {
          launched = await launcher(
            uri,
            mode: url_launcher.LaunchMode.externalNonBrowserApplication,
          );
        } on Exception {
          // No supported app / platform launch failure: use HTTPS checkout.
        }
        if (!_current(epoch)) return;
      }
      if (!launched) {
        launched = await launcher(
          uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      }
      if (!_current(epoch)) return;
      if (!launched) {
        state = const PaymePaymentState(failure: UnknownFailure());
        return;
      }
      state = const PaymePaymentState(phase: PaymePhase.awaitingReturn);
    } on NotFoundFailure catch (failure) {
      if (!_current(epoch)) return;
      state = PaymePaymentState(failure: failure, serviceUnavailable: true);
    } on NetworkFailure catch (failure) {
      if (!_current(epoch)) return;
      state = PaymePaymentState(failure: failure, serviceUnavailable: true);
    } on ApiFailure catch (failure) {
      if (!_current(epoch)) return;
      state = PaymePaymentState(failure: failure);
    } on Object {
      // Order refresh'dagi kutilmagan xato (masalan dispose bo'lgan
      // provider) — ekran ochiq bo'lsa umumiy xato, aks holda jim.
      if (!_current(epoch)) return;
      state = const PaymePaymentState(failure: UnknownFailure());
    }
  }

  /// To'lov holatini BIR marta tekshiradi — mavjud order refresh orqali
  /// (alohida status endpoint yo'q, haqiqat `payment_status` maydonida).
  Future<void> checkStatus() async {
    if (state.busy) return;
    final epoch = _epoch;
    state = const PaymePaymentState(phase: PaymePhase.checking);
    try {
      final order = await _refreshOrder();
      if (!_current(epoch)) return;
      final status = PaymentStatus.fromWire(order.paymentStatus);
      state = switch (status) {
        // Yakuniy holat — natija order ma'lumotidan chiziladi.
        PaymentStatus.paid ||
        PaymentStatus.failed ||
        PaymentStatus.refundPending ||
        PaymentStatus.refunded ||
        PaymentStatus.cancelled => const PaymePaymentState(),
        // Hali kutilmoqda — "tekshirish" tugmasi qoladi.
        _ => const PaymePaymentState(phase: PaymePhase.awaitingReturn),
      };
    } on ApiFailure catch (failure) {
      if (!_current(epoch)) return;
      state = PaymePaymentState(
        phase: PaymePhase.awaitingReturn,
        failure: failure,
      );
    } on Object {
      if (!_current(epoch)) return;
      state = const PaymePaymentState(
        phase: PaymePhase.awaitingReturn,
        failure: UnknownFailure(),
      );
    }
  }

  Future<OrderData> _refreshOrder() {
    ref.invalidate(orderDetailProvider(orderId));
    return ref.read(orderDetailProvider(orderId).future);
  }
}
