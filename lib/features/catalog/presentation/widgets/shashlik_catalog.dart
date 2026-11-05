import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/localization/uzbek_transliterator.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/routing/store_navigation.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../cart/data/cart_models.dart';
import '../../../cart/domain/cart_controller.dart';
import '../../data/catalog_product_images.dart';
import '../../data/product_models.dart';
import 'meat_product_image.dart';
import 'product_card.dart';
import 'product_image.dart';
import 'shashlik_quantity_picker.dart';
import 'shashlik_variant_ribbon.dart';

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
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Material(
      color: Colors.white,
      child: InkWell(
        key: ValueKey('shashlik-section-${entry.$1.name}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 3,
                color: selected ? AppColors.primary : Colors.transparent,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            entry.$3,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    ),
  );
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
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) => index == count
          ? footer!
          : sortedFamilies.isNotEmpty
          ? ShashlikFamilyCard(family: sortedFamilies[index])
          : ShashlikProductRow(product: products[index]),
    );
  }
}

class ShashlikFamilyCard extends StatelessWidget {
  const ShashlikFamilyCard({required this.family, super.key});
  final ShashlikFamily family;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void open([String? id]) =>
        context.push(Routes.shashlikFamily(family.key.wire, productId: id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: InkWell(
                key: ValueKey('shashlik-family-${family.key.wire}'),
                onTap: () => open(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    shashlikFamilyTitle(l10n, family.key),
                    style: const TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: TextButton(
                onPressed: () => open(),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F5F4),
                  foregroundColor: AppColors.lightTextPrimary,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('${l10n.commonAll} ›'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ShashlikVariantRibbon(family: family, onOpen: (p) => open(p.id)),
      ],
    );
  }
}

class ShashlikProductRow extends StatelessWidget {
  const ShashlikProductRow({required this.product, this.family, super.key});
  final ProductSummary product;
  final ShashlikFamily? family;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ShashlikRowCard(
      cardKey: ValueKey('shashlik-product-${product.id}'),
      imageUrl: product.imageUrl,
      title: family == null
          ? product.name
          : shashlikOptionTitle(l10n, family!, product),
      price: Uzs.format(product.price),
      onTap: () => openStoreProduct(context, StoreType.shashlik, product.id),
      action: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primaryContainer: Colors.white,
            onPrimaryContainer: AppColors.lightTextPrimary,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lightBorderStrong),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ProductCartControl(
            product: product,
            storeType: StoreType.shashlik,
            inlineCompact: true,
            iconOnlyWhenEmpty: true,
            large: true,
          ),
        ),
      ),
    );
  }
}

/// Natural text height keeps the same compact layout usable at 200% scale.
class _ShashlikRowCard extends StatelessWidget {
  const _ShashlikRowCard({
    required this.cardKey,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.onTap,
    required this.action,
  });
  final Key cardKey;
  final String? imageUrl;
  final String title, price;
  final VoidCallback onTap;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: cardKey,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = (constraints.maxWidth * .34).clamp(80.0, 124.0);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: imageWidth,
                    child: ProductImageView(
                      imageUrl: imageUrl,
                      memCacheWidth: 400,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: action,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<bool?> showShashlikFamilySelector(
  BuildContext context,
  ShashlikFamily family, {
  String? initialProductId,
  CartItem? exactItem,
  String? title,
  StoreType storeType = StoreType.shashlik,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: Colors.white,
  clipBehavior: Clip.antiAlias,
  constraints: const BoxConstraints(maxWidth: 560),
  barrierColor: Colors.black.withValues(alpha: .4),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _FamilySelectorDialog(
    family: family,
    initialProductId: initialProductId,
    exactItem: exactItem,
    title: title,
    storeType: storeType,
  ),
);

/// The same absolute-quantity editor, scoped to the meat cart. No shashlik
/// variant labels or piece presets are inferred for meat products.
Future<bool?> showMeatQuantityEditor(
  BuildContext context,
  ProductSummary product, {
  CartItem? exactItem,
}) => showShashlikFamilySelector(
  context,
  ShashlikFamily(key: ShashlikFamilyKey.beefJazz, products: [product]),
  initialProductId: product.id,
  exactItem: exactItem,
  title: product.name,
  storeType: StoreType.meat,
);

Future<bool?> showShashlikCartQuantityEditor(
  BuildContext context,
  CartItem item,
) {
  final groups = ShashlikCatalogGroups.fromProducts([item.product]);
  return showShashlikFamilySelector(
    context,
    groups.families.firstOrNull ??
        ShashlikFamily(
          key: ShashlikFamilyKey.beefJazz,
          products: [item.product],
        ),
    initialProductId: item.product.id,
    exactItem: item,
    title: item.product.name,
  );
}

class _FamilySelectorDialog extends ConsumerStatefulWidget {
  const _FamilySelectorDialog({
    required this.family,
    this.initialProductId,
    this.exactItem,
    this.title,
    this.storeType = StoreType.shashlik,
  });
  final ShashlikFamily family;
  final String? initialProductId;
  final CartItem? exactItem;
  final String? title;
  final StoreType storeType;
  @override
  ConsumerState<_FamilySelectorDialog> createState() =>
      _FamilySelectorDialogState();
}

class _FamilySelectorDialogState extends ConsumerState<_FamilySelectorDialog> {
  late String _selectedId;
  final _quantities = <String, int>{};
  int get _quantity => _quantities[_selectedId] ?? 1;
  bool _busy = false;
  bool _quantityValid = true;
  int _editEpoch = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId =
        widget.family.products.any((p) => p.id == widget.initialProductId)
        ? widget.initialProductId!
        : widget.family.products.first.id;
  }

  ProductSummary get _selected =>
      widget.family.products.firstWhere((p) => p.id == _selectedId);

  void _select(String id) {
    if (_busy || id == _selectedId) return;
    setState(() {
      _selectedId = id;
      _quantityValid = true;
      _error = null;
    });
  }

  void _quantityChanged(int value) {
    if (_busy) return;
    setState(() {
      _quantities[_selectedId] = value;
      _quantityValid = true;
      _error = null;
    });
  }

  CartItem? _lineFor(ProductSummary product, List<CartItem> items) {
    final exact = widget.exactItem;
    if (exact != null) {
      return items
          .where((i) => i.configurationIdentity == exact.configurationIdentity)
          .firstOrNull;
    }
    return items
        .where(
          (i) =>
              i.product.id == product.id &&
              i.variant == null &&
              i.selectedAddons.isEmpty &&
              i.note.isEmpty,
        )
        .firstOrNull;
  }

  Future<void> _add() async {
    final current = ref.read(cartControllerProvider(widget.storeType)).value;
    if (_busy ||
        !_quantityValid ||
        !_selected.isPurchasable ||
        _selected.inReview ||
        current == null ||
        current.hasPendingMutation ||
        current.unconfirmedKeys.isNotEmpty) {
      return;
    }
    final line = _lineFor(_selected, current.cart.items);
    if (line?.quantity == _quantity) {
      Navigator.of(context).pop(false);
      return;
    }
    if (widget.exactItem != null && line == null) {
      setState(() => _error = AppLocalizations.of(context).cartOrderChanged);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(
      cartControllerProvider(widget.storeType).notifier,
    );
    final success = line == null
        ? await controller.addProduct(_selected, quantity: _quantity)
        : await controller.setQuantity(line, _quantity);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    final failure = ref
        .read(cartControllerProvider(widget.storeType))
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
    final current = ref.watch(cartControllerProvider(widget.storeType)).value;
    if (current != null) {
      for (final product in widget.family.products) {
        _quantities.putIfAbsent(
          product.id,
          () => _lineFor(product, current.cart.items)?.quantity ?? 1,
        );
      }
    }
    final line = _lineFor(_selected, current?.cart.items ?? []);
    final total = _quantityValid
        ? Uzs.multiply(line?.unitPrice ?? _selected.price, _quantity)
        : null;
    final meat = widget.storeType == StoreType.meat;
    final measure = widget.family.measureOf(_selected);
    final presets = !meat && measure == ShashlikMeasure.piece
        ? const [10, 20, 50, 100, 150, 200]
        : const [1, 2, 3, 5];
    final label = meat
        ? '$_quantity ${_selected.unit}'
        : shashlikQuantityLabel(l10n, measure, _quantity);
    return PopScope(
      canPop: !_busy,
      child: Material(
        key: const ValueKey('shashlik-selector-dialog'),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * .9,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _ShashlikSheetLayout(
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: AppColors.lightBorderStrong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title ??
                                shashlikFamilyTitle(l10n, widget.family.key),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.commonClose,
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox.square(
                                  dimension: 88,
                                  child: meat
                                      ? MeatProductImage(product: _selected)
                                      : ProductImageView(
                                          imageUrl:
                                              _selected.imageUrl ??
                                              widget.family.imageUrl,
                                          memCacheWidth: 400,
                                          keepPreviousImage: true,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meat
                                          ? _selected.name
                                          : shashlikOptionTitle(
                                              l10n,
                                              widget.family,
                                              _selected,
                                            ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      Uzs.format(_selected.price),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (widget.exactItem == null && !meat)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final product in widget.family.products)
                                  ChoiceChip(
                                    key: ValueKey(
                                      'shashlik-selector-product-${product.id}',
                                    ),
                                    selected: product.id == _selectedId,
                                    onSelected: _busy
                                        ? null
                                        : (_) => _select(product.id),
                                    showCheckmark: true,
                                    checkmarkColor: Colors.white,
                                    selectedColor: AppColors.primary,
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    side: BorderSide(
                                      color: product.id == _selectedId
                                          ? AppColors.primary
                                          : AppColors.lightBorderStrong,
                                    ),
                                    labelStyle: TextStyle(
                                      color: product.id == _selectedId
                                          ? Colors.white
                                          : AppColors.lightTextPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.padded,
                                    label: Text(
                                      shashlikOptionTitle(
                                        l10n,
                                        widget.family,
                                        product,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.shashlikQuantity,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final value in presets)
                                ChoiceChip(
                                  key: ValueKey('shashlik-preset-$value'),
                                  label: Text('$value'),
                                  selected: _quantity == value,
                                  onSelected: _busy
                                      ? null
                                      : (_) {
                                          setState(() => _editEpoch++);
                                          _quantityChanged(value);
                                        },
                                  showCheckmark: false,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  surfaceTintColor: Colors.transparent,
                                  side: BorderSide(
                                    color: _quantity == value
                                        ? AppColors.primary
                                        : AppColors.lightBorderStrong,
                                  ),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _quantity == value
                                        ? Colors.white
                                        : AppColors.lightTextPrimary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ShashlikQuantityPicker(
                            key: ValueKey(
                              'shashlik-quantity-$_selectedId-$_editEpoch',
                            ),
                            quantity: _quantity,
                            quantityLabel: label,
                            enabled: !_busy,
                            horizontal: true,
                            unitLabel: meat
                                ? _selected.unit
                                : measure == ShashlikMeasure.piece
                                ? l10n.shashlikPieceUnit
                                : l10n.shashlikKilogramUnit,
                            onValidityChanged: (valid) =>
                                setState(() => _quantityValid = valid),
                            onChanged: _quantityChanged,
                            onScrollingChanged: (_) {},
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              key: const ValueKey('shashlik-selector-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.lightBorder),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_quantityValid ? label : l10n.shashlikQuantity} · ${total == null ? '—' : Uzs.formatWithFraction(total)}',
                          key: const ValueKey('shashlik-selector-total'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('shashlik-selector-submit'),
                          onPressed:
                              _busy ||
                                  !_quantityValid ||
                                  !_selected.isPurchasable ||
                                  _selected.inReview ||
                                  current == null ||
                                  current.hasPendingMutation ||
                                  current.unconfirmedKeys.isNotEmpty
                              ? null
                              : _add,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_shopping_cart_outlined),
                          label: Text(
                            line == null
                                ? l10n.shashlikAddToCart
                                : l10n.shashlikSaveQuantity,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keep the action pinned on phones; on short/landscape screens allow the
/// complete sheet to scroll instead of squeezing content or clipping actions.
class _ShashlikSheetLayout extends StatelessWidget {
  const _ShashlikSheetLayout({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final short =
          constraints.maxHeight < 480 ||
          MediaQuery.textScalerOf(context).scale(16) > 22;
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            if (short && child is Flexible) child.child else child,
        ],
      );
      return short ? SingleChildScrollView(child: column) : column;
    },
  );
}
