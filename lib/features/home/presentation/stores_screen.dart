import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../domain/home_controller.dart';
import 'widgets/stores_section.dart';

/// Do'konlar tabi — Home'dagi do'konlar gridining o'zi (bitta
/// `homeControllerProvider`, ikkala tab uchun bitta so'rov).
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.homeStoresTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xxl,
          ),
          children: [
            switch (home) {
              AsyncData(:final value) => StoresSection(
                items: value.storeHub,
                onMissingProductTap: () => pushAuthenticated(
                  context,
                  ref,
                  Routes.requestsFor(kind: 'missing_product'),
                ),
              ),
              AsyncError(:final error) => HomeErrorView(
                message: error is ApiFailure
                    ? error.localize(l10n)
                    : l10n.errorUnknown,
                onRetry: () =>
                    ref.read(homeControllerProvider.notifier).refresh(),
              ),
              _ => const StoresSkeleton(),
            },
          ],
        ),
      ),
    );
  }
}
