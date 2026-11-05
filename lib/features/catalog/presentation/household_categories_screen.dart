import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../store/domain/store_landing_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import 'widgets/household_catalog_navigation.dart';
import 'widgets/household_category_landing.dart';

/// Uses the same cached category tree as the landing: no per-category requests.
class HouseholdCategoriesScreen extends ConsumerStatefulWidget {
  const HouseholdCategoriesScreen({super.key});

  @override
  ConsumerState<HouseholdCategoriesScreen> createState() =>
      _HouseholdCategoriesScreenState();
}

class _HouseholdCategoriesScreenState
    extends ConsumerState<HouseholdCategoriesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filter(String value) {
    setState(() => _query = normalizeHouseholdCategoryName(value));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final landing = ref.watch(storeLandingProvider(StoreType.household));
    final sections = buildHouseholdCategorySections(
      landing.value?.categories ?? const [],
    );
    final filtered = [
      for (final section in sections)
        HouseholdCategorySection(
          group: section.group,
          items: section.items.where((item) {
            final label = normalizeHouseholdCategoryName(
              '${item.category.name} ${item.category.canonicalName ?? ''}',
            );
            return _query.split(' ').every(label.contains);
          }).toList(),
        ),
    ].where((section) => section.items.isNotEmpty).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(onPressed: () => appBack(context)),
        title: Text(l10n.catalogCategoryFilter),
        actions: [
          IconButton(
            key: const ValueKey('household-categories-close'),
            tooltip: l10n.commonClose,
            onPressed: () => appBack(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              key: const ValueKey('household-category-search'),
              controller: _search,
              onChanged: _filter,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.householdCategorySearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.commonClose,
                        onPressed: () {
                          _search.clear();
                          _filter('');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: landing.value == null
                ? landing.hasError
                      ? StoreErrorView(
                          message: landing.error is ApiFailure
                              ? (landing.error! as ApiFailure).localize(l10n)
                              : l10n.errorUnknown,
                          onRetry: () => ref.invalidate(
                            storeLandingProvider(StoreType.household),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? l10n.catalogEmpty : l10n.searchEmpty,
                    ),
                  )
                : ListView.builder(
                    key: const PageStorageKey('household-category-index'),
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final section = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  householdCategoryGroupTitle(
                                    l10n,
                                    section.group,
                                  ),
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            for (final item in section.items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Material(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: Color(0xFFDDE1E5),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    key: ValueKey(
                                      'household-index-${item.category.id}',
                                    ),
                                    minTileHeight: 60,
                                    leading: Icon(
                                      householdCategoryIcon(item.category),
                                    ),
                                    title: Text(item.category.name),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      context.push(
                                        Routes.storeCategoryProducts(
                                          'household',
                                          item.category.id,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
