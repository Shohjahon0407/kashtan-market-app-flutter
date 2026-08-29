import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/theme/app_dimens.dart';
import '../../domain/uzbek_phone.dart';

/// +998 prefiksli telefon maydoni.
///
/// Ko'rsatishda raqamlar `90 123 45 67` bo'lib guruhlanadi, qiymat esa
/// doim 9 ta yalang'och raqam ([controller.text] emas — [localDigitsOf]
/// bilan o'qing).
///
/// Eski appdan farqlar:
///  - karetka OXIRGA MAJBURLANMAYDI — o'rtadan tahrirlash ishlaydi;
///  - guruhlab ko'rsatish yozish paytida ham ishlaydi.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  /// Ko'rsatilayotgan (bo'shliqli) matndan 9 lokal raqamni oladi.
  static String localDigitsOf(TextEditingController controller) =>
      UzbekPhone.localDigits(controller.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        letterSpacing: 0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      inputFormatters: const [UzbekPhoneFormatter()],
      onChanged: (value) => onChanged?.call(UzbekPhone.localDigits(value)),
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: '90 123 45 67',
        errorText: errorText,
        errorMaxLines: 2,
        prefixIcon: const _CountryPrefix(),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}

class _CountryPrefix extends StatelessWidget {
  const _CountryPrefix();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            UzbekPhone.countryCode,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(width: 1, height: 24, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}

/// 9 lokal raqamni yozish paytida `XX XXX XX XX` ko'rinishida guruhlaydi.
///
/// Karetka pozitsiyasi saqlanadi: formatlashdan oldin karetkagacha nechta
/// RAQAM borligi hisoblanadi va yangi matnda o'sha raqamdan keyinga qo'yiladi.
/// Public — testda to'g'ridan-to'g'ri `formatEditUpdate` chaqiriladi
/// (`enterText` karetkani doim oxiriga qo'yadi, o'rtadan tahrirni
/// widget-test bilan taqlid qilib bo'lmaydi).
class UzbekPhoneFormatter extends TextInputFormatter {
  const UzbekPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = UzbekPhone.localDigits(newValue.text);
    final formatted = UzbekPhone.formatLocal(digits);

    // Karetkagacha bo'lgan raqamlar soni (yopishtirilgan 998 prefiksi
    // tashlanganini ham hisobga oladi).
    final rawBeforeCaret = newValue.text.substring(
      0,
      newValue.selection.baseOffset.clamp(0, newValue.text.length),
    );
    var digitsBeforeCaret = UzbekPhone.digitsOnly(rawBeforeCaret).length;
    final dropped = UzbekPhone.digitsOnly(newValue.text).length - digits.length;
    digitsBeforeCaret = (digitsBeforeCaret - dropped).clamp(0, digits.length);

    // Yangi matnda o'sha raqamdan keyingi pozitsiya.
    var caret = 0;
    var seen = 0;
    while (caret < formatted.length && seen < digitsBeforeCaret) {
      if (formatted[caret] != ' ') seen++;
      caret++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
