import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/back_navigation.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../home/data/home_models.dart';
import '../../../home/domain/home_controller.dart';

/// Shared AppBar action. Store discovery is loaded only after opening the
/// picker, not for every catalogue/cart rebuild. No auth or cart mutation.
class StoreSwitchButton extends StatefulWidget {
  const StoreSwitchButton({
    required this.storeType,
    this.enabled = true,
    super.key,
  });
  final StoreType storeType;
  final bool enabled;

  @override
  State<StoreSwitchButton> createState() => _StoreSwitchButtonState();
}

class _StoreSwitchButtonState extends State<StoreSwitchButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening || !widget.enabled) return;
    FocusScope.of(context).unfocus();
    setState(() => _opening = true);
    try {
      final target = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => _StorePicker(current: widget.storeType),
      );
      if (!mounted || target == null) return;
      // A push retains the source shell (scroll/tab/cart) underneath. Choosing
      // a store already in the return path restores it rather than nesting it.
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        AppBackCoordinator.of(router).go(
          target,
          // The global Stores tab belongs to HomeShell, which may already
          // be underneath this store. Do not push a duplicate HomeShell.
          keepCurrentPage: target != Routes.stores,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('store-switch-button'),
    tooltip: AppLocalizations.of(context).storeSwitchTitle,
    onPressed: _opening || !widget.enabled ? null : _open,
    icon: const Icon(Icons.swap_horiz_rounded),
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  );
}

class _StorePicker extends ConsumerWidget {
  const _StorePicker({required this.current});
  final StoreType current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final home = ref.watch(homeControllerProvider);
    final stores = <StoreType, StoreHubItem>{};
    for (final item in home.value?.storeHub ?? const <StoreHubItem>[]) {
      if (item.isEnabled && item.storeType != null) {
        stores.putIfAbsent(item.storeType!, () => item);
      }
    }
    final choices = stores.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: ListView(
        key: const ValueKey('store-switch-picker'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.storeSwitchTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(l10n.storeSwitchKeepsCart),
          const SizedBox(height: 12),
          if (home.isLoading && choices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (home.hasError && choices.isEmpty)
            Column(
              children: [
                Text(l10n.errorNetwork),
                TextButton(
                  onPressed: () =>
                      ref.read(homeControllerProvider.notifier).refresh(),
                  child: Text(l10n.commonRetry),
                ),
              ],
            )
          else if (choices.isEmpty)
            Text(l10n.catalogEmpty),
          for (final item in choices)
            ListTile(
              key: ValueKey('switch-store-${item.storeTypeWire}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              leading: const Icon(Icons.storefront_outlined),
              title: Text(
                item.label.trim().isEmpty
                    ? _label(l10n, item.storeType!)
                    : item.label,
              ),
              subtitle: item.subtitle.trim().isEmpty
                  ? null
                  : Text(item.subtitle),
              trailing: item.storeType == current
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(
                context,
                item.storeType == current
                    ? null
                    : Routes.storeCatalog(item.storeTypeWire),
              ),
            ),
          const Divider(),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, Routes.stores),
            icon: const Icon(Icons.apps_outlined),
            label: Text(l10n.homeStoresTitle),
          ),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, StoreType type) => switch (type) {
    StoreType.household => l10n.storeHousehold,
    StoreType.grocery => l10n.storeGrocery,
    StoreType.restaurant => l10n.storeRestaurant,
    StoreType.shashlik => l10n.storeShashlik,
    StoreType.meat => l10n.storeMeat,
  };
}
