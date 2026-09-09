import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/localization/locale_controller.dart';

Future<void> showAppLanguagePicker(BuildContext context, WidgetRef ref) async {
  final selected = ref.read(localeControllerProvider);
  final picked = await showModalBottomSheet<AppLocale>(
    context: context,
    showDragHandle: true,
    // Landscape yoki yangi til qo'shilganda sheet balandligi yetmasa
    // overflow bo'lmasin — scroll.
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final locale in AppLocale.values)
              ListTile(
                selected: locale == selected,
                leading: Icon(
                  locale == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(locale.nativeName),
                onTap: () => Navigator.pop(context, locale),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked != null) {
    await ref.read(localeControllerProvider.notifier).set(picked);
  }
}
