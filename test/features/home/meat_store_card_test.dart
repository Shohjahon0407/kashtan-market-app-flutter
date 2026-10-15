import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/presentation/widgets/store_grid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Go'sht do'koni kartasi boshqalari bilan BIR XIL dizayn va o'lchamda
/// chizilishini qulflaydi (egasining asosiy talabi).
const _meat = StoreHubItem(
  storeType: StoreType.meat,
  storeTypeWire: 'meat',
  label: "Go'sht mahsulotlari",
  subtitle: "Mol, qo'y, tovuq go'shti",
  imageUrl: null,
  accentColor: null,
  sortOrder: 1,
);

const _grocery = StoreHubItem(
  storeType: StoreType.grocery,
  storeTypeWire: 'grocery',
  label: 'Oziq-ovqat',
  subtitle: 'Bozorlik',
  imageUrl: null,
  accentColor: null,
  sortOrder: 2,
);

Future<void> _pump(WidgetTester tester, List<StoreHubItem> items) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StoreGrid(items: items, onTap: (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('go‘sht kartasi chiziladi va tanib olinadi', (tester) async {
    await _pump(tester, const [_meat, _grocery]);

    expect(find.byKey(const ValueKey('home-store-meat')), findsOneWidget);
    expect(find.text("Go'sht mahsulotlari"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('go‘sht kartasi boshqalari bilan bir xil o‘lchamda', (
    tester,
  ) async {
    await _pump(tester, const [_meat, _grocery]);

    final meatSize = tester.getSize(
      find.byKey(const ValueKey('home-store-meat')),
    );
    final grocerySize = tester.getSize(
      find.byKey(const ValueKey('home-store-grocery')),
    );
    expect(meatSize, grocerySize);
  });

  testWidgets('server rasmi bo‘lmasa lokal meat.webp ishlaydi', (tester) async {
    await _pump(tester, const [_meat]);

    expect(find.byKey(const ValueKey('home-store-meat')), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image).first);
    final resized = image.image as ResizeImage;
    expect(
      (resized.imageProvider as AssetImage).assetName,
      'assets/stores/meat.webp',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanlangan yangi meat fotosi server rasmidan ustun turadi', (
    tester,
  ) async {
    await _pump(tester, const [
      StoreHubItem(
        storeType: StoreType.meat,
        storeTypeWire: 'meat',
        label: "Go'sht mahsulotlari",
        subtitle: "Mol, qo'y, tovuq go'shti",
        imageUrl: 'https://example.com/meat.webp',
        accentColor: null,
        sortOrder: 1,
      ),
    ]);

    expect(find.byType(CachedNetworkImage), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.alignment, Alignment.topCenter);
    expect(
      ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
      'assets/stores/meat.webp',
    );
  });
}
