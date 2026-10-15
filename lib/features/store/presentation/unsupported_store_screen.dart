import 'package:flutter/material.dart';

import '../../../core/routing/back_navigation.dart';
import '../../../generated/l10n/app_localizations.dart';
import 'widgets/store_state_views.dart';

class UnsupportedStoreScreen extends StatelessWidget {
  const UnsupportedStoreScreen({this.storeTypeWire, super.key});

  final String? storeTypeWire;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.unsupportedStoreTitle)),
      body: StoreEmptyView(
        icon: Icons.store_mall_directory_outlined,
        title: l10n.unsupportedStoreTitle,
        subtitle: [
          l10n.unsupportedStoreMessage,
          if (storeTypeWire != null && storeTypeWire!.isNotEmpty)
            storeTypeWire!,
        ].join('\n'),
        action: FilledButton(
          onPressed: () => appBack(context),
          child: Text(l10n.unsupportedStoreBack),
        ),
      ),
    );
  }
}
