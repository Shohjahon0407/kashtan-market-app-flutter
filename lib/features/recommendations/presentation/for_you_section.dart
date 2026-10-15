import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/presentation/widgets/product_rail.dart';
import '../domain/recommendations_controller.dart';

/// Home'dagi "Siz uchun" qatori — userning qiziqishiga qarab barcha
/// do'konlardan. Yuklanayotganda/bo'sh/xato bo'lsa umuman chizilmaydi
/// (Home tartibi sakramasin).
class ForYouSection extends ConsumerWidget {
  const ForYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(forYouControllerProvider).value;
    final items = feed?.items ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const ValueKey('home-for-you'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xxl,
        AppSpacing.screenH,
        0,
      ),
      child: ProductRail(
        title: l10n.homeForYou.toUpperCase(),
        subtitle: l10n.homeForYouSubtitle,
        titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
        products: items,
        maxItems: items.length,
        keyPrefix: 'home-for-you',
        storageKey: const PageStorageKey('home-for-you-rail'),
        loadingMore: feed?.isLoadingMore ?? false,
        onReachEnd: (feed?.hasMore ?? false)
            ? () => ref.read(forYouControllerProvider.notifier).loadMore()
            : null,
      ),
    );
  }
}
