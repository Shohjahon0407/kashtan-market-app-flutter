// Image is supplied by the pinned launcher-icons dev dependency.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  img.Image read(String path) => img.decodePng(File(path).readAsBytesSync())!;

  test('white opaque launcher and store exports have expected dimensions', () {
    for (final entry in {
      'tool/launcher_icon.png': 1024,
      'docs/play-store/assets/app-icon-512.png': 512,
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
    }.entries) {
      final image = read(entry.key);
      expect(image.width, entry.value);
      expect(image.height, entry.value);
      expect(image.getPixel(0, 0).r, 255);
      expect(image.getPixel(0, 0).g, 255);
      expect(image.getPixel(0, 0).b, 255);
      expect(image.every((pixel) => pixel.a == 255), isTrue);
    }
    expect(
      File('docs/play-store/assets/app-icon-512.png').lengthSync(),
      lessThan(1024 * 1024),
    );
  });

  test('adaptive foreground remains inside the Android circular safe area', () {
    final image = read('tool/launcher_icon_adaptive_fg.png');
    final mono = read('tool/launcher_icon_monochrome.png');
    expect(image.getPixel(0, 0).a, 0);
    expect(mono.width, image.width);
    var occupied = 0;
    for (final pixel in image) {
      if (pixel.a <= 8) continue;
      occupied++;
      final dx = pixel.x - image.width / 2;
      final dy = pixel.y - image.height / 2;
      expect(math.sqrt(dx * dx + dy * dy), lessThan(image.width * .306));
      final themed = mono.getPixel(pixel.x, pixel.y);
      expect(themed.a, pixel.a);
      expect([themed.r, themed.g, themed.b], [255, 255, 255]);
    }
    expect(occupied, greaterThan(0));
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains('#FFFFFF'),
    );
  });

  test('maskable Web icons keep the logo within the central safe circle', () {
    for (final size in [192, 512]) {
      final image = read('web/icons/Icon-maskable-$size.png');
      expect(image.width, size);
      expect(image.height, size);
      for (final pixel in image) {
        expect(pixel.a, 255);
        if (pixel.r >= 250 && pixel.g >= 250 && pixel.b >= 250) continue;
        final dx = pixel.x - size / 2;
        final dy = pixel.y - size / 2;
        expect(math.sqrt(dx * dx + dy * dy), lessThan(size * .4));
      }
    }
  });
}
