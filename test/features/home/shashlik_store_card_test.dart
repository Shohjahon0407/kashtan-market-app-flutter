import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/presentation/widgets/store_grid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StoreHubItem _store(String? url, {StoreType type = StoreType.shashlik}) =>
    StoreHubItem(
      storeType: type,
      storeTypeWire: type.wire,
      label: 'Shashlik marenovka',
      subtitle: 'Mol, qo‘y, tovuq',
      imageUrl: url,
      accentColor: null,
      sortOrder: 3,
    );

Future<void> _pump(
  WidgetTester tester,
  StoreHubItem item,
  ValueChanged<StoreHubItem> onTap,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StoreGrid(items: [item], onTap: onTap),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final type in [
    StoreType.shashlik,
    StoreType.restaurant,
    StoreType.meat,
  ]) {
    for (final url in [null, 'https://example.com/old-shashlik.webp']) {
      testWidgets(
        'chosen ${type.wire} photo has priority with server image $url',
        (tester) async {
          final item = _store(url, type: type);
          StoreHubItem? tapped;
          await _pump(tester, item, (value) => tapped = value);
          final image = tester.widget<Image>(find.byType(Image));
          final resized = image.image as ResizeImage;
          expect(
            (resized.imageProvider as AssetImage).assetName,
            'assets/stores/${type.wire}.webp',
          );
          expect(image.fit, BoxFit.cover);
          expect(
            image.alignment,
            type == StoreType.shashlik ? Alignment.center : Alignment.topCenter,
          );
          expect(find.byType(CachedNetworkImage), findsNothing);
          await tester.tap(find.byKey(ValueKey('home-store-${type.wire}')));
          expect(tapped, same(item));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('other store cards still prioritize the server image', (
    tester,
  ) async {
    await _pump(
      tester,
      _store('https://example.com/grocery.webp', type: StoreType.grocery),
      (_) {},
    );
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('local photo failure can still use the server image', (
    tester,
  ) async {
    const url = 'https://example.com/old-shashlik.webp';
    await _pump(tester, _store(url), (_) {});
    final image = tester.widget<Image>(find.byType(Image));
    final context = tester.element(find.byType(Image));
    final fallback = image.errorBuilder!(
      context,
      StateError('asset missing'),
      StackTrace.empty,
    );
    expect(fallback, isA<CachedNetworkImage>());
    expect((fallback as CachedNetworkImage).imageUrl, url);
  });
}
