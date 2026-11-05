import 'dart:async';

import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('downloaded image has no white crossfade after its first frame', (
    tester,
  ) async {
    const url = 'https://image.test/delayed-food.jpg';
    final pending = Completer<ImageInfo>();
    final provider = ProductImageView.decodedProvider(url, persistent: true);
    final key = await provider.obtainKey(ImageConfiguration.empty);
    final cache = PaintingBinding.instance.imageCache;
    cache.putIfAbsent(key, () => OneFrameImageStreamCompleter(pending.future));
    addTearDown(() {
      cache.clear();
      cache.clearLiveImages();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 200,
            child: ProductImageView(imageUrl: url, persistent: true),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    final image = await tester.runAsync(() => createTestImage());
    pending.complete(ImageInfo(image: image!));
    await tester.pump();
    await tester.pump();
    // No 500/1000ms wait: the placeholder must disappear as soon as the
    // decoded image arrives, even when disk loading was asynchronous.
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changing a photo of the same dish keeps it visible until ready',
    (tester) async {
      const firstUrl = 'https://image.test/main-food.jpg';
      const nextUrl = 'https://image.test/extra-food.jpg';
      final cache = PaintingBinding.instance.imageCache;
      final firstImage = await tester.runAsync(
        () => createTestImage(width: 21),
      );
      final next = Completer<ImageInfo>();
      for (final url in [firstUrl, nextUrl]) {
        final key = await ProductImageView.decodedProvider(
          url,
          persistent: true,
        ).obtainKey(ImageConfiguration.empty);
        cache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
            url == firstUrl
                ? Future.value(ImageInfo(image: firstImage!))
                : next.future,
          ),
        );
      }
      addTearDown(() {
        cache.clear();
        cache.clearLiveImages();
      });
      Future<void> show(String url) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.square(
              dimension: 200,
              child: ProductImageView(
                key: const ValueKey('one-dish-photo'),
                imageUrl: url,
                persistent: true,
                keepPreviousImage: true,
              ),
            ),
          ),
        ),
      );
      await show(firstUrl);
      await tester.pump();
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      await show(nextUrl);
      await tester.pump();
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      final oldPhoto = tester.widget<RawImage>(find.byType(RawImage));
      expect(oldPhoto.image?.width, 21);
      final nextImage = await tester.runAsync(() => createTestImage(width: 22));
      next.complete(ImageInfo(image: nextImage!));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image?.width, 22);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'persistent and explicit carousel photos skip fades; other stores keep defaults',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              SizedBox.square(
                dimension: 80,
                child: ProductImageView(
                  imageUrl: 'https://image.test/food.jpg',
                  persistent: true,
                  keepPreviousImage: true,
                ),
              ),
              SizedBox.square(
                dimension: 80,
                child: ProductImageView(
                  imageUrl: 'https://image.test/shashlik.jpg',
                  disableFade: true,
                ),
              ),
              SizedBox.square(
                dimension: 80,
                child: ProductImageView(
                  imageUrl: 'https://image.test/tool.jpg',
                ),
              ),
            ],
          ),
        ),
      );
      final images = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .toList();
      expect(images.first.fadeInDuration, Duration.zero);
      expect(images.first.fadeOutDuration, Duration.zero);
      expect(images.first.placeholderFadeInDuration, Duration.zero);
      expect(images.first.useOldImageOnUrlChange, isTrue);
      expect(images[1].fadeInDuration, Duration.zero);
      expect(images[1].fadeOutDuration, Duration.zero);
      expect(images[1].cacheManager, isNull);
      expect(images.last.fadeInDuration, const Duration(milliseconds: 500));
      expect(images.last.fadeOutDuration, const Duration(milliseconds: 1000));
      expect(images.last.useOldImageOnUrlChange, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
