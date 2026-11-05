import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/product_models.dart';
import 'household_category_landing.dart';

/// Pinned above the root ribbons; the actual search keeps its existing route.
class HouseholdCatalogNavigation extends StatelessWidget {
  const HouseholdCatalogNavigation({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.onSearch,
    required this.onCategories,
    super.key,
  });

  final List<ProductCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final VoidCallback onSearch;
  final VoidCallback onCategories;

  static bool stacked(BuildContext context) =>
      !compact(context) && MediaQuery.textScalerOf(context).scale(14) > 20;

  static bool compact(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 480;

  static double height(BuildContext context) => compact(context)
      ? 56
      : (stacked(context) ? 120 : 56) +
            math.max(48, MediaQuery.textScalerOf(context).scale(14) + 24) +
            8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final search = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDDE1E5)),
      ),
      child: InkWell(
        key: const ValueKey('household-search-entry'),
        borderRadius: BorderRadius.circular(12),
        onTap: onSearch,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.householdSearchHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final index = compact(context)
        ? IconButton.outlined(
            key: const ValueKey('household-categories-button'),
            tooltip: l10n.catalogCategoryFilter,
            onPressed: onCategories,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.grid_view_outlined),
          )
        : OutlinedButton.icon(
            key: const ValueKey('household-categories-button'),
            onPressed: onCategories,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lightTextPrimary,
              backgroundColor: Colors.white,
              minimumSize: const Size(48, 48),
              side: const BorderSide(color: Color(0xFFDDE1E5)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.grid_view_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            label: Text(
              l10n.catalogCategoryFilter,
              style: const TextStyle(fontSize: 14),
            ),
          );
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: stacked(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [search, const SizedBox(height: 8), index],
                  )
                : Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 8),
                      index,
                    ],
                  ),
          ),
          if (!compact(context)) ...[
            HouseholdCategoryShortcuts(
              categories: categories,
              selectedId: selectedId,
              onSelected: onSelected,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class HouseholdCategoryShortcuts extends StatelessWidget {
  const HouseholdCategoryShortcuts({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });
  final List<ProductCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordered = [
      for (final section in buildHouseholdCategorySections(categories))
        for (final item in section.items) item.category,
    ];
    return SizedBox(
      height: math.max(48, MediaQuery.textScalerOf(context).scale(14) + 24),
      child: ListView(
        key: const PageStorageKey('household-category-shortcuts'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Shortcut(
            label: l10n.commonAll,
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final category in ordered)
            _Shortcut(
              key: ValueKey('household-shortcut-${category.id}'),
              label: category.name,
              selected: selectedId == category.id,
              onTap: () => onSelected(category.id),
            ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? AppColors.primary
              : AppColors.lightTextPrimary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

IconData householdCategoryIcon(ProductCategory category) {
  final name = normalizeHouseholdCategoryName(
    category.canonicalName ?? category.name,
  );
  if (name.contains('qurilish')) return Icons.foundation_outlined;
  if (name.contains('ustachilik')) return Icons.handyman_outlined;
  if (name.contains('arra')) return Icons.settings_outlined;
  if (name.contains('plast')) return Icons.plumbing_outlined;
  if (name.contains('texnika')) return Icons.local_laundry_service_outlined;
  if (name.contains('elektron') || name.contains('mp3')) {
    return Icons.headphones_outlined;
  }
  if (name.contains('telefon')) return Icons.phone_android_outlined;
  if (name.contains('mashina')) return Icons.directions_car_outlined;
  if (name.contains('velosiped')) return Icons.pedal_bike_outlined;
  if (name.contains('oshxona')) return Icons.kitchen_outlined;
  if (name.contains('kiyim')) return Icons.checkroom_outlined;
  if (name.contains('konstovar')) return Icons.edit_outlined;
  return Icons.category_outlined;
}
