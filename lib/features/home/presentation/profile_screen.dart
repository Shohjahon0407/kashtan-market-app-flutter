import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/uzbek_phone.dart';
import '../../auth/presentation/widgets/delete_account_sheet.dart';
import 'widgets/language_picker.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final locale = ref.watch(localeControllerProvider);
    final fullName = user?.fullName.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xxxl,
            ),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: colors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isEmpty ? l10n.profileUnnamed : fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (user != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              UzbekPhone.formatFull(user.phoneNumber),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.location_on_outlined,
                label: l10n.profileAddresses,
                onTap: () => context.push(Routes.addresses),
              ),
              _ProfileMenuRow(
                icon: Icons.receipt_long_outlined,
                label: l10n.ordersTitle,
                onTap: () => _openStoreDestination(
                  context,
                  destination: (store) => Routes.storeOrders(store.wire),
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.notifications_none,
                label: l10n.profileNotifications,
                onTap: () => context.push(Routes.notifications),
              ),
              _ProfileMenuRow(
                icon: Icons.add_shopping_cart_outlined,
                label: l10n.supportMissingProductTitle,
                onTap: () => context.push(Routes.missingProductRequest),
              ),
              _ProfileMenuRow(
                icon: Icons.support_agent_outlined,
                label: l10n.supportCenterTitle,
                onTap: () => context.push(Routes.requests),
              ),
              _ProfileMenuRow(
                icon: Icons.favorite_border,
                label: l10n.favoritesTitle,
                onTap: () => _openStoreDestination(
                  context,
                  destination: (store) => Routes.storeFavorites(store.wire),
                ),
              ),
              _ProfileMenuRow(
                icon: Icons.translate,
                label: l10n.profileLanguage,
                trailing: locale.nativeName,
                onTap: () => showAppLanguagePicker(context, ref),
              ),
              // Play Store talabi: maxfiylik siyosati ilova ichidan ochilsin.
              _ProfileMenuRow(
                key: const ValueKey('profile-privacy'),
                icon: Icons.privacy_tip_outlined,
                label: l10n.profilePrivacyPolicy,
                onTap: () => launchUrl(
                  Uri.parse(AppConfig.privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _ProfileMenuRow(
                key: const ValueKey('profile-terms'),
                icon: Icons.description_outlined,
                label: l10n.ugcTerms,
                onTap: () => launchUrl(
                  Uri.parse(AppConfig.termsUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _ProfileMenuRow(
                key: const ValueKey('profile-community-guidelines'),
                icon: Icons.groups_outlined,
                label: l10n.ugcCommunityGuidelines,
                onTap: () => launchUrl(
                  Uri.parse(AppConfig.communityGuidelinesUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _ProfileMenuRow(
                key: const ValueKey('profile-blocked-users'),
                icon: Icons.person_off_outlined,
                label: l10n.ugcBlockedUsers,
                onTap: () => context.push(Routes.blockedUsers),
              ),
              _ProfileMenuRow(
                key: const ValueKey('profile-logout'),
                icon: Icons.logout,
                label: l10n.authLogout,
                destructive: true,
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              // Play Store talabi: foydalanuvchi hisobini ilovadan o'chira olsin.
              _ProfileMenuRow(
                key: const ValueKey('profile-delete-account'),
                icon: Icons.person_remove_outlined,
                label: l10n.profileDeleteAccount,
                destructive: true,
                onTap: () => showDeleteAccountSheet(context),
              ),
              const _AppVersionFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStoreDestination(
    BuildContext context, {
    required String Function(StoreType) destination,
  }) async {
    final selected = await showModalBottomSheet<StoreType>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _StorePickerSheet(),
    );
    if (selected == null || !context.mounted) return;
    await context.push(destination(selected));
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = destructive ? colors.error : colors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: destructive ? colors.error : colors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorePickerSheet extends StatelessWidget {
  const _StorePickerSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileChooseStore,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            // Ro'yxat aylanadigan: do'kon turlari soni o'sganda past ekranli
            // telefonlarda varaq toshib ketmasligi kerak.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final store in StoreType.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: OutlinedButton(
                          key: ValueKey('profile-store-${store.wire}'),
                          onPressed: () => Navigator.pop(context, store),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            alignment: Alignment.centerLeft,
                            shape: const RoundedRectangleBorder(),
                          ),
                          child: Text(_storeLabel(l10n, store)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _storeLabel(AppLocalizations l10n, StoreType store) => switch (store) {
  StoreType.grocery => l10n.storeGrocery,
  StoreType.household => l10n.storeHousehold,
  StoreType.restaurant => l10n.storeRestaurant,
  StoreType.shashlik => l10n.storeShashlik,
  StoreType.meat => l10n.storeMeat,
};

/// Ilova versiyasi — do'kondagi versiya bilan solishtirish oson bo'lsin.
class _AppVersionFooter extends StatelessWidget {
  const _AppVersionFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          if (info == null) return const SizedBox.shrink();
          return Center(
            child: Text(
              AppLocalizations.of(
                context,
              ).profileAppVersion('${info.version} (${info.buildNumber})'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}
