import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/auth_models.dart';
import '../../domain/auth_controller.dart';
import '../../domain/uzbek_phone.dart';
import '../widgets/otp_code_field.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({this.returnTo, super.key});

  final String? returnTo;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with WidgetsBindingObserver {
  final _codeController = TextEditingController();

  Timer? _ticker;

  /// Qolgan soniyalar UI uchun; manba esa doim `state.codeSentAt` (wall-clock)
  /// — shu tufayli fon rejimidan qaytganda ham to'g'ri hisoblanadi
  /// (eski appda `Timer.periodic` bilan lokal int kamaytirilib, fondan
  /// keyin countdown orqada qolib ketardi).
  int _resendLeft = 0;
  int _expiryLeft = 0;

  /// Har bir TO'LIQ kod faqat bir marta auto-submit bo'ladi.
  String? _autoSubmittedCode;

  /// Foydalanuvchi yozayotganda backend xatosi yashirinadi.
  bool _suppressFailure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCountdown();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncCountdown();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncCountdown();
  }

  void _syncCountdown() {
    final sentAt = ref.read(authControllerProvider).codeSentAt;
    if (!mounted) return;
    setState(() {
      if (sentAt == null) {
        _resendLeft = 0;
        _expiryLeft = 0;
        return;
      }
      final elapsed = DateTime.now().difference(sentAt).inSeconds;
      _resendLeft = (OtpPolicy.resendCooldown.inSeconds - elapsed).clamp(
        0,
        3600,
      );
      _expiryLeft = (OtpPolicy.codeLifetime.inSeconds - elapsed).clamp(0, 3600);
    });
  }

  void _onCodeChanged(String value) {
    setState(() => _suppressFailure = true);

    final isComplete =
        value.length == OtpPolicy.codeLength &&
        RegExp(r'^\d+$').hasMatch(value);
    if (!isComplete) {
      _autoSubmittedCode = null;
      return;
    }

    final auth = ref.read(authControllerProvider);
    if (auth.isBusy) return;
    if (_autoSubmittedCode == value) return;
    _autoSubmittedCode = value;
    _verify(value);
  }

  Future<void> _verify(String code) async {
    setState(() => _suppressFailure = false);
    await ref.read(authControllerProvider.notifier).verifyCode(code);
    // Muvaffaqiyatda navigatsiya QILINMAYDI — router redirect'i
    // `authenticated` signaturasini ko'rib o'zi Home'ga olib chiqadi.
  }

  Future<void> _resend() async {
    _codeController.clear();
    _autoSubmittedCode = null;
    setState(() => _suppressFailure = false);
    await ref.read(authControllerProvider.notifier).resendCode();
    _syncCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    final phone = auth.phone;
    final failureText = (!_suppressFailure && auth.failure != null)
        ? auth.failure!.localize(l10n)
        : null;
    final codeExpired = auth.codeSentAt != null && _expiryLeft == 0;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            ref.read(authControllerProvider.notifier).editPhone();
            context.go(Routes.authPhoneFor(returnTo: widget.returnTo));
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.authOtpTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.authOtpSubtitle(
                  phone == null ? '' : UzbekPhone.formatFull(phone),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              OtpCodeField(
                controller: _codeController,
                enabled: !auth.isVerifying,
                hasError: failureText != null,
                onChanged: _onCodeChanged,
              ),

              const SizedBox(height: AppSpacing.lg),

              if (auth.isVerifying)
                const Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (failureText != null)
                Text(
                  failureText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else if (codeExpired)
                Text(
                  l10n.authOtpExpired,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else if (_expiryLeft > 0)
                Text(
                  l10n.authOtpExpiresIn(_expiryLeft),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),

              const Spacer(),

              if (_resendLeft > 0)
                Text(
                  l10n.authOtpResendIn(_resendLeft),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                )
              else
                TextButton(
                  onPressed: auth.isBusy ? null : _resend,
                  child: auth.isSendingCode
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.authOtpResend),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
