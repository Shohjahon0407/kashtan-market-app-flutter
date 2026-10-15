import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/household_category_landing.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _names = [
  'Qurilish mollari',
  'Ustachilik asboblari',
  'Arra zapchastlari',
  'Plastmassa',
  'Maishiy texnika',
  'MP3 va elektronika',
  'Telefon zapchastlari',
  'Mashina aksessuarlari',
  'Velosiped zapchastlari',
  'Oshxona anjomlari',
  'Salafan va dasturxon',
  'Konstovar',
  'Kiyim-kechak',
  'Oyoq kiyim',
  'Parfyumeriya',
  'O‘yinchoqlar',
  'Ko‘k yashil to‘r',
  'Turli xil mahsulotlar',
];

List<ProductCategory> _categories({String? suffix}) => [
  for (var index = 0; index < _names.length; index++)
    ProductCategory(
      id: '$index',
      name: suffix == null ? _names[index] : '${_names[index]} $suffix',
      canonicalName: _names[index],
      storeTypeWire: 'household',
      productCount: 1,
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  List<ProductCategory>? categories,
  Locale locale = const Locale('uz'),
  double scale = 1,
  ValueChanged<ProductCategory>? onTap,
  AssetBundle? bundle,
  bool skeleton = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: DefaultAssetBundle(bundle: bundle ?? rootBundle, child: child!),
      ),
      home: Scaffold(
        body: CustomScrollView(
          key: UniqueKey(),
          slivers: [
            if (skeleton)
              const HouseholdCategoryLandingSkeleton()
            else
              HouseholdCategoryLandingSliver(
                categories: categories ?? _categories(),
                onCategoryTap: onTap ?? (_) {},
              ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MissingHouseholdAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('assets/categories/household/')) {
      throw FlutterError('Deliberately missing category asset');
    }
    return rootBundle.load(key);
  }
}

void main() {
  test('18 categories retain order and have distinct non-green palettes', () {
    final sections = buildHouseholdCategorySections([
      ..._categories().reversed,
      const ProductCategory(
        id: 'imported',
        name: 'YesPOS Imported',
        storeTypeWire: 'household',
        productCount: 9,
      ),
      const ProductCategory(
        id: 'empty',
        name: 'Empty',
        storeTypeWire: 'household',
      ),
    ]);
    expect(sections, hasLength(5));
    final items = sections.expand((section) => section.items).toList();
    expect(items.map((item) => item.category.name), _names);
    expect(items.every((item) => item.assetPath != null), isTrue);
    expect(items.map((item) => item.panelColor).toSet(), hasLength(18));
  });

  for (final locale in const [
    Locale('uz'),
    Locale('uz', 'Cyrl'),
    Locale('ru'),
  ]) {
    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 800),
      Size(430, 900),
      Size(800, 360),
    ]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('equal cards, full labels: $locale $size scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final suffix = locale.languageCode == 'ru'
              ? 'дополнительные принадлежности для домашнего использования'
              : locale.countryCode == 'Cyrl'
              ? 'уй учун қўшимча маҳсулотлар ва буюмлар'
              : 'uy uchun qo‘shimcha mahsulotlar va buyumlar';
          await _pump(
            tester,
            locale: locale,
            scale: scale,
            categories: _categories(suffix: suffix),
          );

          final left = tester.getRect(
            find.byKey(const ValueKey('household-category-card-0')),
          );
          final right = tester.getRect(
            find.byKey(const ValueKey('household-category-card-1')),
          );
          expect(left.width, right.width);
          expect(left.height, right.height);
          expect(left.top, right.top);
          expect(right.left - left.right, 12);
          expect(left.left, 16);
          final label = tester.widget<Text>(
            find.byKey(const ValueKey('household-category-label-0')),
          );
          expect(label.maxLines, isNull);
          expect(label.overflow, isNot(TextOverflow.ellipsis));
          expect(label.style?.fontSize, 15);
          expect(label.style?.height, 1.25);
          final image = find.descendant(
            of: find.byKey(const ValueKey('household-category-card-0')),
            matching: find.byType(AspectRatio),
          );
          expect(tester.widget<AspectRatio>(image).aspectRatio, 4 / 3);
          for (var index = 0; index < 15; index++) {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }

  testWidgets(
    'known category local image wins over server; card remains tappable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        ProductCategory? selected;
        await _pump(
          tester,
          categories: const [
            ProductCategory(
              id: 'tools',
              name: 'Ustachilik asboblari',
              storeTypeWire: 'household',
              productCount: 1,
              imageUrl: 'https://example.com/old.webp',
            ),
          ],
          onTap: (category) => selected = category,
        );
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.bySemanticsLabel('Ustachilik asboblari'), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isA<ResizeImage>());
        await tester.tap(
          find.byKey(const ValueKey('household-category-card-tools')),
        );
        expect(selected?.id, 'tools');
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('missing local image uses remote, unknown category is retained', (
    tester,
  ) async {
    await _pump(
      tester,
      bundle: _MissingHouseholdAssets(),
      categories: const [
        ProductCategory(
          id: 'known',
          name: 'Qurilish mollari',
          storeTypeWire: 'household',
          productCount: 1,
          imageUrl: 'https://example.com/category.webp',
        ),
        ProductCategory(
          id: 'unknown',
          name: 'Yangi kategoriya',
          storeTypeWire: 'household',
          productCount: 1,
        ),
      ],
    );
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.byIcon(Icons.category_outlined), findsWidgets);
    expect(
      buildHouseholdCategorySections(const [
        ProductCategory(
          id: 'unknown',
          name: 'Yangi kategoriya',
          storeTypeWire: 'household',
          productCount: 1,
        ),
      ]).last.items.single.assetPath,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('static skeleton uses matching two-column image ratio', (
    tester,
  ) async {
    await _pump(tester, skeleton: true);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final left = tester.getRect(
      find.byKey(const ValueKey('household-skeleton-0-0-0')),
    );
    final right = tester.getRect(
      find.byKey(const ValueKey('household-skeleton-0-0-1')),
    );
    expect(left.size, right.size);
    expect(right.left - left.right, 12);
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio).first).aspectRatio,
      4 / 3,
    );
  });
}
