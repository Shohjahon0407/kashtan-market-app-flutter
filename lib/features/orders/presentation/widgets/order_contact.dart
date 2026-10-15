import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../generated/l10n/app_localizations.dart';

/// Kuryerga qo'ng'iroq: `tel:` ochilmasa (web/emulator) raqam nusxalanadi.
Future<void> callPhone(BuildContext context, String phone) async {
  final clean = phone.replaceAll(RegExp(r'[^+\d]'), '');
  if (clean.isNotEmpty) {
    final launched = await launchUrl(Uri(scheme: 'tel', path: clean));
    if (launched) return;
  }
  if (!context.mounted) return;
  await copyPhone(context, phone);
}

Future<void> copyPhone(BuildContext context, String phone) async {
  await Clipboard.setData(ClipboardData(text: phone));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).orderPhoneCopied)),
    );
}

/// Backend `vehicle_type` (foot/bicycle/motorcycle/car) → mahalliy nom.
String vehicleLabel(AppLocalizations l10n, String wire) => switch (wire) {
  'foot' => l10n.orderVehicleFoot,
  'bicycle' => l10n.orderVehicleBicycle,
  'motorcycle' => l10n.orderVehicleMotorcycle,
  'car' => l10n.orderVehicleCar,
  _ => wire,
};

IconData vehicleIcon(String wire) => switch (wire) {
  'foot' => Icons.directions_walk_rounded,
  'bicycle' => Icons.pedal_bike_rounded,
  'motorcycle' => Icons.two_wheeler_rounded,
  'car' => Icons.directions_car_rounded,
  _ => Icons.delivery_dining_rounded,
};

/// Backend `payment_method` → mahalliy nom.
String paymentMethodLabel(AppLocalizations l10n, String wire) => switch (wire) {
  'payme' => l10n.orderPaymentPayme,
  '' => '',
  _ => l10n.orderPaymentCash,
};
