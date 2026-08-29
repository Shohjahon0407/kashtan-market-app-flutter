import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/ui/offline/offline_banner.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../orders/data/order_models.dart';
import '../data/payment_models.dart';
import '../domain/payme_payment_controller.dart';

/// Payme brend rangi. Real logotip keyin `assets/brand/` ga qo'shilsa
/// (pubspec o'zgarmaydi) tugma ichida Image.asset bilan ishlatiladi.
const _paymeBrandColor = Color(0xFF33CCCC);

/// Buyurtma tafsilotidagi Payme to'lov bo'limi.
///
/// Yakuniy holat manbai — `order.paymentStatus` (backend). Controller faqat
/// jarayonni (yaratish / kutish / tekshirish) boshqaradi.
class PaymePaymentSection extends ConsumerStatefulWidget {
  const PaymePaymentSection({
    required this.order,
    this.autoStart = false,
    super.key,
  });

  final OrderData order;

  /// Checkout'dan Payme tanlab kelindi — to'lov bir marta o'zi boshlanadi.
  final bool autoStart;

  @override
  ConsumerState<PaymePaymentSection> createState() =>
      _PaymePaymentSectionState();
}

class _PaymePaymentSectionState extends ConsumerState<PaymePaymentSection> {
  AppLifecycleListener? _lifecycle;

  /// Har bir ochilgan to'lov uchun resume'da FAQAT bitta avto-tekshiruv.
  bool _resumeCheckDone = false;

  /// Avtomatik urinishda xizmat mavjud bo'lmasa foydalanuvchini bezovta
  /// qilmaymiz — u shunchaki buyurtma sahifasida qoladi.
  bool _silenceUnavailable = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    if (widget.autoStart &&
        PaymentStatus.fromWire(widget.order.paymentStatus) !=
            PaymentStatus.paid) {
      _silenceUnavailable = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startPayment();
      });
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _onResume() {
    final controller = paymePaymentControllerProvider(widget.order.id);
    if (ref.read(controller).phase != PaymePhase.awaitingReturn) return;
    if (_resumeCheckDone) return;
    _resumeCheckDone = true;
    ref.read(controller.notifier).checkStatus();
  }

  Future<void> _startPayment() async {
    if (!OfflineGate.check(ref)) return;
    _resumeCheckDone = false;
    await ref
        .read(paymePaymentControllerProvider(widget.order.id).notifier)
        .startPayment();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(paymePaymentControllerProvider(widget.order.id));

    ref.listen(paymePaymentControllerProvider(widget.order.id), (prev, next) {
      final failure = next.failure;
      if (failure == null || identical(failure, prev?.failure)) return;
      if (next.serviceUnavailable && _silenceUnavailable) {
        _silenceUnavailable = false;
        return;
      }
      final text = next.serviceUnavailable
          ? l10n.paymeUnavailable
          : failure.message.isEmpty
          ? l10n.paymeLinkOpenFailed
          : failure.localize(l10n);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });

    final status = PaymentStatus.fromWire(widget.order.paymentStatus);
    if (status == PaymentStatus.paid) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.paymePaymentPaid,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == PaymentStatus.failed) ...[
          Text(
            l10n.paymePaymentFailed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else if (status == PaymentStatus.cancelled) ...[
          Text(l10n.paymePaymentCancelled, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
        ],
        FilledButton.icon(
          key: ValueKey('payme-pay-${widget.order.id}'),
          onPressed: state.busy
              ? null
              : () {
                  _silenceUnavailable = false;
                  _startPayment();
                },
          style: FilledButton.styleFrom(
            backgroundColor: _paymeBrandColor,
            foregroundColor: Colors.white,
          ),
          icon: state.phase == PaymePhase.creating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.account_balance_wallet_outlined),
          label: Text(l10n.paymePayButton),
        ),
        if (state.phase == PaymePhase.awaitingReturn ||
            state.phase == PaymePhase.checking) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.paymePaymentPending,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: ValueKey('payme-check-${widget.order.id}'),
            onPressed: state.busy
                ? null
                : () => ref
                      .read(
                        paymePaymentControllerProvider(
                          widget.order.id,
                        ).notifier,
                      )
                      .checkStatus(),
            icon: state.phase == PaymePhase.checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(l10n.paymeCheckPayment),
          ),
        ],
      ],
    );
  }
}
