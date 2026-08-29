import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/theme/app_dimens.dart';
import '../../data/auth_models.dart';

/// 6 xonali kod maydoni.
///
/// Arxitektura (eski appning eng yaxshi qarori): **bitta yashirin TextField**
/// + 6 ta dekorativ box. Paste, backspace, IME va tanlash semantikasi tekin
/// keladi — 6 ta alohida TextField va focus jonglyorligi YO'Q.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = OtpPolicy.codeLength,
    this.enabled = true,
    this.hasError = false,
    this.onChanged,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focusNode = FocusNode();

  void _activateInput() {
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );

    if (_focusNode.hasFocus) {
      // Android back tugmasi IME'ni yopadi, ammo TextField fokusda qoladi.
      // Shunday holatda requestFocus() yangi keyboard so'rovini yubormaydi.
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      return;
    }

    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled || !_focusNode.hasFocus) return;
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ko'rinadigan boxlar. GestureDetector yashirin maydonga fokus beradi.
        GestureDetector(
          key: const ValueKey('otp-code-tap-target'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _activateInput : null,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) => LayoutBuilder(
              builder: (context, constraints) {
                // Tor ekranlarda (180px gacha) siqilib chiqmasligi uchun.
                final boxWidth =
                    ((constraints.maxWidth - (widget.length - 1) * 8) /
                            widget.length)
                        .clamp(38.0, 52.0);
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _DigitBox(
                          key: ValueKey('otp-box-$i'),
                          width: boxWidth,
                          char: i < value.text.length ? value.text[i] : '',
                          isActive:
                              widget.enabled &&
                              _focusNode.hasFocus &&
                              i ==
                                  value.text.length.clamp(0, widget.length - 1),
                          hasError: widget.hasError,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Yashirin haqiqiy maydon.
        IgnorePointer(
          child: SizedBox(
            width: 1,
            height: 1,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                // iOS klaviatura ustida SMS'dagi kodni taklif qiladi.
                // Android SMS Retriever keyingi bosqichda.
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                onChanged: widget.onChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    super.key,
    required this.width,
    required this.char,
    required this.isActive,
    required this.hasError,
  });

  final double width;
  final String char;
  final bool isActive;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final borderColor = hasError
        ? scheme.error
        : isActive
        ? scheme.primary
        : scheme.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: width,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: borderColor,
          width: isActive || hasError ? 1.6 : 1,
        ),
      ),
      child: Text(
        char,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
