// Image is already supplied by the pinned flutter_launcher_icons dev tool.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Mechanical export of the imagegen cutout: PNG sizes, platform padding,
/// white compositing, and alpha-only themed-icon silhouette. No redesign.
void main(List<String> args) {
  final sourceFile = File('tool/launcher_icon_logo.png');
  final source = img.decodePng(sourceFile.readAsBytesSync())!;
  if (source.getPixel(0, 0).a != 0) {
    throw StateError('Launcher foreground must have a transparent background.');
  }
  var left = source.width;
  var top = source.height;
  var right = 0;
  var bottom = 0;
  for (final pixel in source) {
    if (pixel.a > 8) {
      left = math.min(left, pixel.x);
      top = math.min(top, pixel.y);
      right = math.max(right, pixel.x);
      bottom = math.max(bottom, pixel.y);
    }
  }
  final logo = img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
  var radius = 0.0;
  for (final pixel in logo) {
    if (pixel.a > 8) {
      final dx = pixel.x - (logo.width - 1) / 2;
      final dy = pixel.y - (logo.height - 1) / 2;
      radius = math.max(radius, math.sqrt(dx * dx + dy * dy));
    }
  }

  img.Image canvas(int size, {required bool opaque, double? radiusFraction}) {
    final target = img.Image(
      width: size,
      height: size,
      numChannels: opaque ? 3 : 4,
    );
    if (opaque) img.fill(target, color: img.ColorRgb8(255, 255, 255));
    final scale = radiusFraction == null
        ? size * .80 / math.max(logo.width, logo.height)
        : size * radiusFraction / radius;
    final resized = img.copyResize(
      logo,
      width: (logo.width * scale).round(),
      height: (logo.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
    img.compositeImage(
      target,
      resized,
      dstX: (size - resized.width) ~/ 2,
      dstY: (size - resized.height) ~/ 2,
    );
    return target;
  }

  void save(String path, img.Image image) =>
      File(path).writeAsBytesSync(img.encodePng(image));
  if (!args.contains('--maskable-only')) {
    save('tool/launcher_icon.png', canvas(1024, opaque: true));
    final foreground = canvas(1024, opaque: false, radiusFraction: .30);
    save('tool/launcher_icon_adaptive_fg.png', foreground);
    final monochrome = img.Image.from(foreground);
    for (final pixel in monochrome) {
      pixel
        ..r = 255
        ..g = 255
        ..b = 255;
    }
    save('tool/launcher_icon_monochrome.png', monochrome);
    save('docs/play-store/assets/app-icon-512.png', canvas(512, opaque: true));
  }
  // Maskable PWA images keep every visible pixel in the central safe circle.
  save(
    'web/icons/Icon-maskable-192.png',
    canvas(192, opaque: true, radiusFraction: .38),
  );
  save(
    'web/icons/Icon-maskable-512.png',
    canvas(512, opaque: true, radiusFraction: .38),
  );
  stdout.writeln(
    'Launcher assets exported on white; transparent adaptive/themed foregrounds preserved.',
  );
}
