import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../../core/network/api_failure.dart';
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

  @override
  PaymePaymentState build() => const PaymePaymentState();

  /// Backend'dan payment_url oladi va tashqi brauzerda ochadi.
  Future<void> startPayment() async {
    if (!ref.read(paymeEnabledProvider) || state.busy) return;
    state = const PaymePaymentState(phase: PaymePhase.creating);
    try {
      final result = await ref
          .read(paymentsApiProvider)
          .createPaymePayment(orderId);
      if (!ref.mounted) return;

      if (result.status == PaymentStatus.paid) {
        // Allaqachon to'langan — buyurtmani yangilab natijani ko'rsatamiz.
        await _refreshOrder();
        if (!ref.mounted) return;
        state = const PaymePaymentState();
        return;
      }

      final uri = Uri.tryParse(result.paymentUrl);
      // Faqat https ochiladi — boshqa scheme'lar (shu jumladan http) rad etiladi.
      if (uri == null || uri.scheme != 'https') {
        state = const PaymePaymentState(failure: UnknownFailure());
        return;
      }
      final launched = await ref.read(paymentUrlLauncherProvider)(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
      if (!ref.mounted) return;
      if (!launched) {
        state = const PaymePaymentState(failure: UnknownFailure());
        return;
      }
      state = const PaymePaymentState(phase: PaymePhase.awaitingReturn);
    } on NotFoundFailure catch (failure) {
      if (!ref.mounted) return;
      state = PaymePaymentState(failure: failure, serviceUnavailable: true);
    } on NetworkFailure catch (failure) {
      if (!ref.mounted) return;
      state = PaymePaymentState(failure: failure, serviceUnavailable: true);
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return;
      state = PaymePaymentState(failure: failure);
    } on Object {
      // Order refresh'dagi kutilmagan xato (masalan dispose bo'lgan
      // provider) — ekran ochiq bo'lsa umumiy xato, aks holda jim.
      if (!ref.mounted) return;
      state = const PaymePaymentState(failure: UnknownFailure());
    }
  }

  /// To'lov holatini BIR marta tekshiradi — mavjud order refresh orqali
  /// (alohida status endpoint yo'q, haqiqat `payment_status` maydonida).
  Future<void> checkStatus() async {
    if (state.busy) return;
    state = const PaymePaymentState(phase: PaymePhase.checking);
    try {
      final order = await _refreshOrder();
      if (!ref.mounted) return;
      final status = PaymentStatus.fromWire(order.paymentStatus);
      state = switch (status) {
        // Yakuniy holat — natija order ma'lumotidan chiziladi.
        PaymentStatus.paid ||
        PaymentStatus.failed ||
        PaymentStatus.cancelled => const PaymePaymentState(),
        // Hali kutilmoqda — "tekshirish" tugmasi qoladi.
        _ => const PaymePaymentState(phase: PaymePhase.awaitingReturn),
      };
    } on ApiFailure catch (failure) {
      if (!ref.mounted) return;
      state = PaymePaymentState(
        phase: PaymePhase.awaitingReturn,
        failure: failure,
      );
    } on Object {
      if (!ref.mounted) return;
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
