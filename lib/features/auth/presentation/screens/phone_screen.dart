import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/routing/auth_gate.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/auth_models.dart';
import '../../domain/auth_controller.dart';
import '../../domain/auth_state.dart';
import '../../domain/uzbek_phone.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/phone_field.dart';

/// Telefon va OTP'ni bitta ixcham, blur fonli oynada boshqaradi.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({this.returnTo, this.isModalPrompt = false, super.key});

  final String? returnTo;
  final bool isModalPrompt;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen>
    with WidgetsBindingObserver {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _ticker;
  String? _localError;
  String? _autoSubmittedCode;
  bool _suppressFailure = false;
  bool _completed = false;
  int _resendLeft = 0;
  int _expiryLeft = 0;

  String get _digits => PhoneField.localDigitsOf(_phoneController);
  bool get _phoneComplete => _digits.length == UzbekPhone.localLength;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCountdown();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncCountdown(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authControllerProvider).isAuthenticated) {
        _finishAuthenticated();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncCountdown();
  }

  bool _isOtpStep(AuthState auth) =>
      auth.phone != null &&
      (auth.status == AuthStatus.codeSent ||
          auth.status == AuthStatus.verifying ||
          auth.codeSentAt != null);

  void _syncCountdown() {
    final sentAt = ref.read(authControllerProvider).codeSentAt;
    if (!mounted) return;
    final elapsed = sentAt == null
        ? 0
        : DateTime.now().difference(sentAt).inSeconds;
    final resend = sentAt == null
        ? 0
        : (OtpPolicy.resendCooldown.inSeconds - elapsed).clamp(0, 3600);
    final expiry = sentAt == null
        ? 0
        : (OtpPolicy.codeLifetime.inSeconds - elapsed).clamp(0, 3600);
    if (resend == _resendLeft && expiry == _expiryLeft) return;
    setState(() {
      _resendLeft = resend;
      _expiryLeft = expiry;
    });
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    if (_digits.length != UzbekPhone.localLength) {
      setState(() => _localError = l10n.authErrorInvalidPhone);
      return;
    }
    if (!UzbekPhone.isValidLocal(_digits)) {
      setState(() => _localError = l10n.authPhoneInvalidOperator);
      return;
    }
    setState(() {
      _localError = null;
      _suppressFailure = false;
    });
    await ref.read(authControllerProvider.notifier).sendCode(_digits);
    if (!mounted) return;
    _syncCountdown();
    setState(() {});
  }

  void _onCodeChanged(String value) {
    setState(() => _suppressFailure = true);
    final complete =
        value.length == OtpPolicy.codeLength &&
        RegExp(r'^\d+$').hasMatch(value);
    if (!complete) {
      _autoSubmittedCode = null;
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (auth.isBusy || _autoSubmittedCode == value) return;
    _autoSubmittedCode = value;
    unawaited(_verify(value));
  }

  Future<void> _verify(String code) async {
    setState(() => _suppressFailure = false);
    await ref.read(authControllerProvider.notifier).verifyCode(code);
    if (!mounted || !ref.read(authControllerProvider).isAuthenticated) return;
    _finishAuthenticated();
  }

  void _finishAuthenticated() {
    if (_completed || !mounted) return;
    _completed = true;
    if (widget.isModalPrompt) {
      final coordinator = ref.read(authPromptCoordinatorProvider);
      context.pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        coordinator.complete(true);
      });
    } else {
      context.go(_safeReturnTo(widget.returnTo));
    }
  }

  Future<void> _resend() async {
    _codeController.clear();
    _autoSubmittedCode = null;
    setState(() => _suppressFailure = false);
    await ref.read(authControllerProvider.notifier).resendCode();
    _syncCountdown();
  }

  void _editPhone() {
    _codeController.clear();
    _autoSubmittedCode = null;
    ref.read(authControllerProvider.notifier).editPhone();
    setState(() {
      _localError = null;
      _suppressFailure = false;
      _resendLeft = 0;
      _expiryLeft = 0;
    });
  }

  void _close() {
    _resetTransientAuth();
    ref.read(authPromptCoordinatorProvider).complete(false);
    if (widget.isModalPrompt) {
      context.pop(false);
    } else {
      context.go(Routes.home);
    }
  }

  void _resetTransientAuth() {
    if (_completed) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated && !auth.isCheckingSession) {
      ref.read(authControllerProvider.notifier).editPhone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final otpStep = _isOtpStep(auth);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_completed) {
          _resetTransientAuth();
          ref.read(authPromptCoordinatorProvider).complete(false);
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fon: ilgari shu yerda ikkinchi HomeScreen (va ikkinchi video
            // lenta — 2-3 yashirin video yuklab) qurilardi; statik fon yetarli.
            if (!widget.isModalPrompt)
              ColoredBox(color: Theme.of(context).colorScheme.surface),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
            ),
            SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + viewInsets.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 620,
                    ),
                    child: Material(
                      key: const ValueKey('auth-prompt-modal'),
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 18,
                      shadowColor: Colors.black38,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                key: const ValueKey('auth-prompt-close'),
                                tooltip: AppLocalizations.of(
                                  context,
                                ).commonClose,
                                onPressed: auth.isBusy ? null : _close,
                                icon: const Icon(Icons.close),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: otpStep
                                  ? _buildOtpStep(context, auth)
                                  : _buildPhoneStep(context, auth),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep(BuildContext context, AuthState auth) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final failure = !_suppressFailure && auth.failure != null
        ? auth.failure!.localize(l10n)
        : null;
    return Column(
      key: const ValueKey('auth-phone-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.authRequiredTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.authRequiredSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: PhoneField(
            controller: _phoneController,
            autofocus: true,
            enabled: !auth.isSendingCode,
            errorText: _localError ?? failure,
            onChanged: (_) => setState(() {
              _localError = null;
              _suppressFailure = true;
            }),
            onSubmitted: _sendCode,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const ValueKey('auth-prompt-continue'),
            onPressed: auth.isSendingCode || !_phoneComplete ? null : _sendCode,
            child: auth.isSendingCode
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.commonContinue),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Play/huquqiy talab: kirishda foydalanish shartlariga rozilik.
        const _AuthConsentText(),
      ],
    );
  }

  Widget _buildOtpStep(BuildContext context, AuthState auth) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final failure = !_suppressFailure && auth.failure != null
        ? auth.failure!.localize(l10n)
        : null;
    final expired = auth.codeSentAt != null && _expiryLeft == 0;
    return Column(
      key: const ValueKey('auth-otp-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.authOtpTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.authOtpSubtitle(
            auth.phone == null ? '' : UzbekPhone.formatFull(auth.phone!),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OtpCodeField(
          controller: _codeController,
          enabled: !auth.isVerifying,
          hasError: failure != null,
          onChanged: _onCodeChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        if (auth.isVerifying)
          const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (failure != null)
          Text(
            failure,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (expired)
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
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          key: const ValueKey('auth-change-number'),
          onPressed: auth.isBusy ? null : _editPhone,
          child: Text(l10n.authChangeNumber),
        ),
        if (_resendLeft > 0)
          Text(
            l10n.authOtpResendIn(_resendLeft),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          )
        else
          TextButton(
            onPressed: auth.isBusy ? null : _resend,
            child: Text(l10n.authOtpResend),
          ),
      ],
    );
  }
}

String _safeReturnTo(String? raw) {
  if (raw == null || raw.isEmpty) return Routes.home;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.path.startsWith('/') || uri.hasAuthority) {
    return Routes.home;
  }
  if (Routes.authEntry.contains(uri.path) || uri.path == Routes.splash) {
    return Routes.home;
  }
  return uri.toString();
}

/// "Davom etish orqali ... rozilik bildirasiz" — Shartlar va Maxfiylik
/// havolalari bosiladigan. Recognizer'lar State'da yashaydi (dispose shart).
class _AuthConsentText extends StatefulWidget {
  const _AuthConsentText();

  @override
  State<_AuthConsentText> createState() => _AuthConsentTextState();
}

class _AuthConsentTextState extends State<_AuthConsentText> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => _open(AppConfig.termsUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _open(AppConfig.privacyPolicyUrl);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _open(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final link = base?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );
    return Text.rich(
      key: const ValueKey('auth-consent-text'),
      TextSpan(
        style: base,
        children: [
          TextSpan(text: l10n.authConsentPrefix),
          TextSpan(
            text: l10n.authConsentTerms,
            style: link,
            recognizer: _termsTap,
          ),
          TextSpan(text: l10n.authConsentAnd),
          TextSpan(
            text: l10n.authConsentPrivacy,
            style: link,
            recognizer: _privacyTap,
          ),
          TextSpan(text: l10n.authConsentSuffix),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
