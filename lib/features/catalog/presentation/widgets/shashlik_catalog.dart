import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/localization/uzbek_transliterator.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/routing/store_navigation.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../core/ui/widgets/smooth_press.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../cart/data/cart_models.dart';
import '../../../cart/domain/cart_controller.dart';
import '../../data/catalog_product_images.dart';
import '../../data/product_models.dart';
import 'product_card.dart';
import 'product_image.dart';

enum ShashlikSection { kebabs, charcoal, other }

enum ShashlikMeasure { piece, kilogram }

enum ShashlikFamilyKey {
  beefJazz('beef-jazz'),
  lambJazz('lamb-jazz'),
  chicken('chicken'),
  liver('liver'),
  mince('mince');

  const ShashlikFamilyKey(this.wire);

  final String wire;

  static ShashlikFamilyKey? fromWire(String value) {
    for (final key in values) {
      if (key.wire == value) return key;
    }
    return null;
  }
}

class ShashlikFamily {
  const ShashlikFamily({required this.key, required this.products});

  final ShashlikFamilyKey key;
  final List<ProductSummary> products;

  ShashlikMeasure measureOf(ProductSummary product) {
    final normalized = normalizeShashlikProductName(product.name);
    if (normalized.contains('kilo') || product.unitCode == 'kg') {
      return ShashlikMeasure.kilogram;
    }
    if (key == ShashlikFamilyKey.liver) {
      final index = products.indexWhere((item) => item.id == product.id);
      return index > 0 ? ShashlikMeasure.kilogram : ShashlikMeasure.piece;
    }
    return ShashlikMeasure.piece;
  }

  ProductSummary? productForMeasure(ShashlikMeasure measure) {
    for (final product in products) {
      if (measureOf(product) == measure) return product;
    }
    return null;
  }

  String? get imageUrl {
    for (final product in products) {
      final image = product.imageUrl;
      if (image != null && image.trim().isNotEmpty) return image;
    }
    return null;
  }
}

class ShashlikCatalogGroups {
  const ShashlikCatalogGroups({
    required this.families,
    required this.charcoal,
    required this.other,
  });

  factory ShashlikCatalogGroups.fromProducts(Iterable<ProductSummary> source) {
    final unique = <String, ProductSummary>{};
    for (final product in source) {
      unique.putIfAbsent(product.id, () => product);
    }

    final familyBuckets = <ShashlikFamilyKey, List<ProductSummary>>{
      for (final key in ShashlikFamilyKey.values) key: [],
    };
    final charcoal = <ProductSummary>[];
    final other = <ProductSummary>[];

    for (final product in unique.values) {
      final normalized = normalizeShashlikProductName(product.name);
      final family = _familyForName(normalized);
      if (family != null) {
        familyBuckets[family]!.add(product);
      } else if (normalized.contains('komir')) {
        charcoal.add(product);
      } else {
        other.add(product);
      }
    }

    final families = <ShashlikFamily>[
      for (final key in ShashlikFamilyKey.values)
        if (familyBuckets[key]!.isNotEmpty)
          ShashlikFamily(
            key: key,
            products: _sortFamilyProducts(key, familyBuckets[key]!),
          ),
    ];
    charcoal.sort(
      (a, b) =>
          _priority(normalizeShashlikProductName(a.name), const [
            'tez yonar',
            'tosh',
          ]).compareTo(
            _priority(normalizeShashlikProductName(b.name), const [
              'tez yonar',
              'tosh',
            ]),
          ),
    );
    other.sort(
      (a, b) =>
          _priority(normalizeShashlikProductName(a.name), const [
            'mol ragu',
            'bez',
            'mol ilik',
            'dumba',
            'qoy suyak',
            'zix',
            'mol charvi',
            'qoy charvi',
          ]).compareTo(
            _priority(normalizeShashlikProductName(b.name), const [
              'mol ragu',
              'bez',
              'mol ilik',
              'dumba',
              'qoy suyak',
              'zix',
              'mol charvi',
              'qoy charvi',
            ]),
          ),
    );
    return ShashlikCatalogGroups(
      families: families,
      charcoal: charcoal,
      other: other,
    );
  }

  final List<ShashlikFamily> families;
  final List<ProductSummary> charcoal;
  final List<ProductSummary> other;

  bool hasImageless(ShashlikSection section) => switch (section) {
    ShashlikSection.kebabs => families.any((family) => family.imageUrl == null),
    ShashlikSection.charcoal => charcoal.any((p) => !catalogProductHasImage(p)),
    ShashlikSection.other => other.any((p) => !catalogProductHasImage(p)),
  };
}

String normalizeShashlikProductName(String value) =>
    UzbekTransliterator.toLatin(value)
        .toLowerCase()
        .replaceAll('ö', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ı', 'i')
        .replaceAll(RegExp("['‘’`ʻʼ´]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();

ShashlikFamilyKey? _familyForName(String name) {
  if (name.contains('mol jazz')) return ShashlikFamilyKey.beefJazz;
  if (name.contains('qoy jazz')) return ShashlikFamilyKey.lambJazz;
  if (name.contains('qanot')) return ShashlikFamilyKey.chicken;
  if (name == 'jigar') return ShashlikFamilyKey.liver;
  if (name.contains('qiyma')) return ShashlikFamilyKey.mince;
  return null;
}

List<ProductSummary> _sortFamilyProducts(
  ShashlikFamilyKey key,
  List<ProductSummary> products,
) {
  final sorted = [...products];
  sorted.sort((a, b) {
    if (key == ShashlikFamilyKey.liver) {
      return _priceValue(a.price).compareTo(_priceValue(b.price));
    }
    final aName = normalizeShashlikProductName(a.name);
    final bName = normalizeShashlikProductName(b.name);
    final order = key == ShashlikFamilyKey.mince
        ? const ['qiyma', 'non qiyma', 'kilolik qiyma']
        : const ['base', 'kilolik'];
    int rank(String name) {
      if (key != ShashlikFamilyKey.mince) {
        return name.contains('kilo') ? 1 : 0;
      }
      return _priority(name, order);
    }

    final byRank = rank(aName).compareTo(rank(bName));
    return byRank != 0 ? byRank : aName.compareTo(bName);
  });
  return sorted;
}

int _priority(String name, List<String> orderedPatterns) {
  for (var index = 0; index < orderedPatterns.length; index++) {
    if (name == orderedPatterns[index]) return index;
  }
  for (var index = 0; index < orderedPatterns.length; index++) {
    if (name.contains(orderedPatterns[index])) return index;
  }
  return orderedPatterns.length + name.hashCode.abs() % 1000;
}

num _priceValue(String value) => num.tryParse(value) ?? 0;

String shashlikFamilyTitle(AppLocalizations l10n, ShashlikFamilyKey key) =>
    switch (key) {
      ShashlikFamilyKey.beefJazz => l10n.shashlikFamilyBeefJazz,
      ShashlikFamilyKey.lambJazz => l10n.shashlikFamilyLambJazz,
      ShashlikFamilyKey.chicken => l10n.shashlikFamilyChicken,
      ShashlikFamilyKey.liver => l10n.shashlikFamilyLiver,
      ShashlikFamilyKey.mince => l10n.shashlikFamilyMince,
    };

String shashlikOptionTitle(
  AppLocalizations l10n,
  ShashlikFamily family,
  ProductSummary product,
) {
  final index = family.products.indexWhere((item) => item.id == product.id);
  if (family.key == ShashlikFamilyKey.mince) {
    final name = normalizeShashlikProductName(product.name);
    if (name.contains('kilolik')) return l10n.shashlikOptionKiloMince;
    if (name.contains('non qiyma')) return l10n.shashlikOptionBreadMince;
    return l10n.shashlikOptionMince;
  }
  return index <= 0 ? l10n.shashlikOptionSkewered : l10n.shashlikOptionByKilo;
}

String shashlikQuantityLabel(
  AppLocalizations l10n,
  ShashlikMeasure measure,
  int quantity,
) => switch (measure) {
  ShashlikMeasure.piece => l10n.shashlikPieceQuantity(quantity),
  ShashlikMeasure.kilogram => l10n.shashlikKilogramQuantity(quantity),
};

class ShashlikSectionSelector extends StatelessWidget {
  const ShashlikSectionSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ShashlikSection selected;
  final ValueChanged<ShashlikSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = <(ShashlikSection, IconData, String)>[
      (ShashlikSection.kebabs, Icons.outdoor_grill, l10n.shashlikSectionKebabs),
      (
        ShashlikSection.charcoal,
        Icons.local_fire_department_outlined,
        l10n.shashlikSectionCharcoal,
      ),
      (
        ShashlikSection.other,
        Icons.inventory_2_outlined,
        l10n.shashlikSectionOther,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SectionButton(
                entry: entries[index],
                selected: selected == entries[index].$1,
                onTap: () => onSelected(entries[index].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final (ShashlikSection, IconData, String) entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('shashlik-section-${entry.$1.name}'),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  entry.$2,
                  size: 19,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(height: 3),
                Text(
                  entry.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShashlikCatalogList extends StatelessWidget {
  const ShashlikCatalogList({
    required this.groups,
    required this.section,
    this.includeImageless = true,
    this.controller,
    this.footer,
    super.key,
  });

  final ShashlikCatalogGroups groups;
  final ShashlikSection section;
  final bool includeImageless;
  final ScrollController? controller;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final families = section == ShashlikSection.kebabs
        ? groups.families
              .where((family) => includeImageless || family.imageUrl != null)
              .toList()
        : const <ShashlikFamily>[];
    final allProducts = switch (section) {
      ShashlikSection.kebabs => const <ProductSummary>[],
      ShashlikSection.charcoal => groups.charcoal,
      ShashlikSection.other => groups.other,
    };
    final products = [
      ...allProducts.where(catalogProductHasImage),
      if (includeImageless)
        ...allProducts.where((p) => !catalogProductHasImage(p)),
    ];
    final sortedFamilies = [
      ...families.where((family) => family.imageUrl != null),
      if (includeImageless)
        ...families.where((family) => family.imageUrl == null),
    ];
    final count = sortedFamilies.length + products.length;
    if (count == 0 && footer == null) {
      return Center(child: Text(AppLocalizations.of(context).catalogEmpty));
    }
    return ListView.separated(
      controller: controller,
      key: ValueKey('shashlik-list-${section.name}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.xxl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: count + (footer == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => index == count
          ? footer!
          : sortedFamilies.isNotEmpty
          ? ShashlikFamilyCard(family: sortedFamilies[index])
          : ShashlikProductRow(product: products[index]),
    );
  }
}

class ShashlikFamilyCard extends ConsumerWidget {
  const ShashlikFamilyCard({required this.family, super.key});

  final ShashlikFamily family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final measuresByProductId = {
      for (final product in family.products)
        product.id: family.measureOf(product),
    };
    final quantities = ref.watch(
      cartControllerProvider(StoreType.shashlik).select((state) {
        var pieces = 0;
        var kilograms = 0;
        for (final item in state.value?.cart.items ?? const <CartItem>[]) {
          switch (measuresByProductId[item.product.id]) {
            case ShashlikMeasure.piece:
              pieces += item.quantity;
            case ShashlikMeasure.kilogram:
              kilograms += item.quantity;
            case null:
              break;
          }
        }
        return (pieces: pieces, kilograms: kilograms);
      }),
    );
    final pieceProduct = family.productForMeasure(ShashlikMeasure.piece);
    final kilogramProduct = family.productForMeasure(ShashlikMeasure.kilogram);
    final primaryProduct = pieceProduct ?? kilogramProduct!;
    final price = pieceProduct == null
        ? Uzs.format(primaryProduct.price)
        : l10n.shashlikPriceFrom(Uzs.format(primaryProduct.price));
    final cartParts = <String>[
      if (quantities.pieces > 0)
        shashlikQuantityLabel(l10n, ShashlikMeasure.piece, quantities.pieces),
      if (quantities.kilograms > 0)
        shashlikQuantityLabel(
          l10n,
          ShashlikMeasure.kilogram,
          quantities.kilograms,
        ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('shashlik-family-${family.key.wire}'),
        onTap: () => context.push(Routes.shashlikFamily(family.key.wire)),
        child: SizedBox(
          height: 124,
          child: Row(
            children: [
              SizedBox(
                width: 132,
                child: ProductImageView(imageUrl: family.imageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shashlikFamilyTitle(l10n, family.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        price,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (kilogramProduct != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.shashlikKilogramPrice(
                            Uzs.format(kilogramProduct.price),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          if (cartParts.isNotEmpty)
                            Expanded(
                              child: Text(
                                cartParts.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            )
                          else
                            const Spacer(),
                          SizedBox.square(
                            dimension: 36,
                            child: SmoothPress(
                              child: FilledButton(
                                key: ValueKey(
                                  'shashlik-family-add-${family.key.wire}',
                                ),
                                onPressed: () async {
                                  final added =
                                      await showShashlikFamilySelector(
                                        context,
                                        family,
                                      );
                                  if (added == true && context.mounted) {
                                    showProductAddedSnackBar(context);
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                  ),
                                ),
                                child: const Icon(Icons.add, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShashlikProductRow extends StatelessWidget {
  const ShashlikProductRow({required this.product, this.family, super.key});

  final ProductSummary product;
  final ShashlikFamily? family;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final measure = family?.measureOf(product);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('shashlik-product-${product.id}'),
        onTap: () => openStoreProduct(context, StoreType.shashlik, product.id),
        child: SizedBox(
          height: measure == null ? 104 : 124,
          child: Row(
            children: [
              SizedBox(
                width: 122,
                child: ProductImageView(imageUrl: product.imageUrl),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Uzs.format(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ProductCartControl(
                          product: product,
                          storeType: StoreType.shashlik,
                          inlineCompact: true,
                          iconOnlyWhenEmpty: true,
                          quantityLabelBuilder: measure == null
                              ? null
                              : (quantity) => shashlikQuantityLabel(
                                  l10n,
                                  measure,
                                  quantity,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showShashlikFamilySelector(
  BuildContext context,
  ShashlikFamily family,
) => showGeneralDialog<bool>(
  context: context,
  barrierDismissible: false,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black.withValues(alpha: 0.18),
  transitionDuration: const Duration(milliseconds: 200),
  pageBuilder: (dialogContext, _, _) => BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
    child: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _FamilySelectorDialog(family: family),
        ),
      ),
    ),
  ),
  transitionBuilder: (_, animation, _, child) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(
        begin: 0.96,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
);

class _FamilySelectorDialog extends ConsumerStatefulWidget {
  const _FamilySelectorDialog({required this.family});

  final ShashlikFamily family;

  @override
  ConsumerState<_FamilySelectorDialog> createState() =>
      _FamilySelectorDialogState();
}

class _FamilySelectorDialogState extends ConsumerState<_FamilySelectorDialog> {
  late String _selectedId;
  var _quantity = 1;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.family.products.first.id;
  }

  ProductSummary get _selected =>
      widget.family.products.firstWhere((product) => product.id == _selectedId);

  Future<void> _add() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await ref
        .read(cartControllerProvider(StoreType.shashlik).notifier)
        .addProduct(_selected, quantity: _quantity);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    final failure = ref
        .read(cartControllerProvider(StoreType.shashlik))
        .value
        ?.mutationFailure;
    setState(() {
      _busy = false;
      _error =
          failure?.localize(AppLocalizations.of(context)) ??
          AppLocalizations.of(context).errorUnknown;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shashlikFamilyTitle(l10n, widget.family.key),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                l10n.shashlikChooseProduct,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final product in widget.family.products) ...[
                        _SelectorProductRow(
                          family: widget.family,
                          product: product,
                          selected: product.id == _selectedId,
                          onSelected: _busy
                              ? null
                              : () => setState(() => _selectedId = product.id),
                        ),
                        if (product != widget.family.products.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    l10n.shashlikQuantity,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  SmoothPress(
                    enabled: !_busy && _quantity > 1,
                    child: IconButton.filledTonal(
                      key: const ValueKey('shashlik-selector-minus'),
                      onPressed: _busy || _quantity <= 1
                          ? null
                          : () => setState(() => _quantity--),
                      icon: const Icon(Icons.remove),
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        shashlikQuantityLabel(
                          l10n,
                          widget.family.measureOf(_selected),
                          _quantity,
                        ),
                        key: const ValueKey('shashlik-selector-quantity'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  SmoothPress(
                    enabled: !_busy,
                    child: IconButton.filledTonal(
                      key: const ValueKey('shashlik-selector-plus'),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _quantity++),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  key: const ValueKey('shashlik-selector-error'),
                  style: TextStyle(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const ValueKey('shashlik-selector-submit'),
                onPressed: _busy ? null : _add,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_shopping_cart),
                label: Text(l10n.shashlikAddToCart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorProductRow extends StatelessWidget {
  const _SelectorProductRow({
    required this.family,
    required this.product,
    required this.selected,
    required this.onSelected,
  });

  final ShashlikFamily family;
  final ProductSummary product;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: ValueKey('shashlik-selector-product-${product.id}'),
        onTap: onSelected,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.md),
                ),
                child: SizedBox(
                  width: 82,
                  height: double.infinity,
                  child: ProductImageView(imageUrl: product.imageUrl),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shashlikOptionTitle(l10n, family, product),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Uzs.format(product.price),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? colors.primary : colors.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
