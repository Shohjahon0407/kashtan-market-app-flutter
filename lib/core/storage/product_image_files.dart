import 'package:file/file.dart' as files;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// CacheManager's default filesystem uses the OS temporary directory. These
/// explicitly downloaded product images must survive ordinary cache cleanup.
class ProductImageFiles implements FileSystem {
  ProductImageFiles({Future<files.Directory>? directory})
    : _directory = directory ?? _open();
  final Future<files.Directory> _directory;

  static Future<files.Directory> _open() async {
    final base = await getApplicationSupportDirectory();
    return const LocalFileSystem().directory(
      '${base.path}/restaurant_images_v1',
    )..createSync(recursive: true);
  }

  @override
  Future<files.File> createFile(String name) async {
    final dir = await _directory;
    await dir.create(recursive: true);
    return dir.childFile(name);
  }
}
