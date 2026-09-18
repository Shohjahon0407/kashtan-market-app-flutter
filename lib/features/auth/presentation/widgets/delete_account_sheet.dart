import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/platform/sms_autofill_service.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/auth_models.dart';
import '../../domain/auth_controller.dart';
import 'otp_code_field.dart';

/// Hisobni o'chirish oqimi: ogohlantirish → SMS kod → o'chirish.
///
/// Ikki bosqich ataylab bitta modalda: foydalanuvchi kod kutayotganda
/// kontekstni yo'qotmaydi. Server muvaffaqiyat qaytarmaguncha hech narsa
/// o'chmaydi — xatoda modal ochiq qoladi va qayta urinish mumkin.
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(child: _DeleteAccountFlow()),
  );
}

class _DeleteAccountFlow extends ConsumerStatefulWidget {
  const _DeleteAccountFlow();

  @override
  ConsumerState<_DeleteAccountFlow> createState() => _DeleteAccountFlowState();
}

class _DeleteAccountFlowState extends ConsumerState<_DeleteAccountFlow> {
  final _codeController = TextEditingController();
  late final SmsAutofillService _smsAutofill;
  StreamSubscription<String>? _smsSub;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _smsAutofill = ref.read(smsAutofillServiceProvider);
    _smsSub = _smsAutofill.codes.listen(_applyAutofilledCode);
  }

  @override
  void dispose() {
    unawaited(_smsSub?.cancel());
    unawaited(_smsAutofill.stop());
    _codeController.dispose();
    super.dispose();
  }

  /// Kodni FAQAT to'ldiradi.
  ///
  /// Avtomatik tasdiqlash ATAYLAB yo'q: hisobni o'chirish qaytarib
  /// bo'lmaydigan amal, qizil tugmani foydalanuvchining o'zi bosadi.
  void _applyAutofilledCode(String code) {
    if (!mounted || !_codeSent || _busy) return;
    if (_codeController.text == code) return;
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    setState(() => _error = null);
  }

  Future<void> _requestCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestDeleteAccountCode();
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _busy = false;
      });
      unawaited(_smsAutofill.start(mode: ref.read(smsAutofillModeProvider)));
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.localize(AppLocalizations.of(context));
      });
    }
  }

  Future<void> _confirmDelete() async {
    final code = _codeController.text.trim();
    if (code.length != OtpPolicy.codeLength) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(code);
      if (!mounted) return;
      Navigator.of(context).pop();
      // Router `unauthenticated` holatni ko'rib o'zi kirish ekraniga olib chiqadi.
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.localize(AppLocalizations.of(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Layout bo'yicha ikkita qat'iy shart:
    //  1. AlertDialog ISHLATILMAYDI — u ichida IntrinsicWidth bor, kod
    //     maydonidagi LayoutBuilder esa intrinsic o'lchamni bera olmaydi.
    //  2. Tugmalar Expanded ichida — ilova temasida FilledButton ning minimal
    //     kengligi cheksiz (`Size.fromHeight`), chegaralanmagan Row ichida bu
    //     layout assertion'ga olib keladi.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.profileDeleteAccountTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _codeSent
                        ? l10n.profileDeleteAccountCodeHint
                        : l10n.profileDeleteAccountWarning,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: AppSpacing.lg),
                    OtpCodeField(
                      controller: _codeController,
                      enabled: !_busy,
                      hasError: _error != null,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('delete-account-confirm'),
                  onPressed: _busy
                      ? null
                      : (_codeSent ? _confirmDelete : _requestCode),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  ),
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _codeSent
                              ? l10n.profileDeleteAccountConfirm
                              : l10n.profileDeleteAccountSendCode,
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
