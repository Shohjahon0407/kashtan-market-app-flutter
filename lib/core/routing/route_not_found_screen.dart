import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../generated/l10n/app_localizations.dart';
import '../ui/theme/app_dimens.dart';
import 'routes.dart';

/// go_router `errorBuilder` ekrani: mos route topilmaganda foydalanuvchi
/// qizil "no routes for location" ekranida qolib ketmaydi.
class RouteNotFoundScreen extends StatelessWidget {
  const RouteNotFoundScreen({this.location, super.key});

  final String? location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeNotFoundTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.routeNotFoundMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const ValueKey('route-not-found-home'),
                onPressed: () => context.go(Routes.home),
                child: Text(l10n.unsupportedStoreBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
