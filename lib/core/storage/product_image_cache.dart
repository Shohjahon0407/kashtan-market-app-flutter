import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'product_image_files.dart';

class ProductImageCache {
  ProductImageCache({CacheManager? manager}) : manager = manager ?? _manager;
  static final _manager = CacheManager(
    Config(
      'restaurant_images_v1',
      stalePeriod: const Duration(days: 3650),
      maxNrOfCacheObjects: 5000,
      fileSystem: ProductImageFiles(),
    ),
  );
  final CacheManager manager;
  static CacheManager? get persistentManager =>
      kIsWeb || Platform.environment['FLUTTER_TEST'] == 'true'
      ? null
      : _manager;

  Future<bool> save(String url) async {
    try {
      // Use an existing full image without downloading it again on each sync.
      final saved = await manager.getFileFromCache(url);
      if (saved != null && saved.file.existsSync()) return true;
      await manager.downloadFile(url).timeout(const Duration(seconds: 30));
      return true;
    } on Object {
      return false;
    }
  }
}

final productImageCacheProvider = Provider<ProductImageCache>(
  (ref) => ProductImageCache(),
);
