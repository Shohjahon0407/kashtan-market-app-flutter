import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/ui/theme/app_buttons.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/checkout_models.dart';
import '../domain/addresses_controller.dart';

/// Home va checkout bir xil server manzillaridan foydalanadigan global ro'yxat.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final addresses = ref.watch(addressesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAddresses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addressNew),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.checkoutAddAddress),
      ),
      body: switch (addresses) {
        AsyncData(:final value) when value.isEmpty => StoreEmptyView(
          icon: Icons.location_off_outlined,
          title: l10n.addressesEmpty,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () =>
              ref.read(addressesControllerProvider.notifier).refresh(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              104,
            ),
            itemCount: value.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _AddressCard(
              address: value[index],
              onSelect: value[index].isDefault
                  ? null
                  : () => _setDefault(context, ref, value[index]),
              onEdit: () => context.push(Routes.addressEdit(value[index].id)),
              onDelete: () => _delete(context, ref, value[index]),
            ),
          ),
        ),
        AsyncError(:final error) => StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () =>
              ref.read(addressesControllerProvider.notifier).refresh(),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _setDefault(
    BuildContext context,
    WidgetRef ref,
    UserAddress address,
  ) async {
    try {
      await ref
          .read(addressesControllerProvider.notifier)
          .setDefault(address.id);
    } on ApiFailure catch (failure) {
      if (!context.mounted) return;
      _showError(context, failure);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    UserAddress address,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(address.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: AppButtons.dialogAction,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(addressesControllerProvider.notifier).delete(address.id);
    } on ApiFailure catch (failure) {
      if (!context.mounted) return;
      _showError(context, failure);
    }
  }

  void _showError(BuildContext context, ApiFailure failure) {
    final message = failure.localize(AppLocalizations.of(context));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final UserAddress address;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: address.isDefault
          ? colors.primaryContainer.withValues(alpha: 0.38)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: address.isDefault ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                address.isDefault
                    ? Icons.location_on
                    : Icons.location_on_outlined,
                color: address.isDefault ? colors.primary : colors.outline,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            address.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.addressDefaultLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      address.formattedAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_AddressAction>(
                tooltip: l10n.commonEdit,
                onSelected: (action) => switch (action) {
                  _AddressAction.edit => onEdit(),
                  _AddressAction.delete => onDelete(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _AddressAction.edit,
                    child: Text(l10n.commonEdit),
                  ),
                  PopupMenuItem(
                    value: _AddressAction.delete,
                    child: Text(l10n.commonDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AddressAction { edit, delete }
