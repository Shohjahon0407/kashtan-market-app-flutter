import 'package:flutter/material.dart';

import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';

/// Do'kon ekranining vaqtinchalik joy egallovchisi.
///
/// Keyingi bosqichda bu route `GET /stores/{store_type}/landing/` bilan
/// haqiqiy landing ekraniga aylanadi — route shakli o'zgarmaydi.
class StoreStubScreen extends StatelessWidget {
  const StoreStubScreen({super.key, required this.storeTypeWire, this.label});

  final String storeTypeWire;

  /// Home kartasidan kelgan server label (extra orqali) — bo'lmasa wire.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(label ?? storeTypeWire)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 56,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.storeComingSoon,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
