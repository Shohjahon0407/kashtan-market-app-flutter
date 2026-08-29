import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test uchun eng sodda model.
class _Item {
  const _Item(this.id);

  factory _Item.fromJson(Map<String, dynamic> json) =>
      _Item(json['id'] as String);

  final String id;
}

void main() {
  _Item map(Map<String, dynamic> j) => _Item.fromJson(j);

  group('PageDecoder.cursor', () {
    test('/catalog/products/ javobini o‘qiydi', () {
      final page = PageDecoder.cursor<_Item>({
        'next':
            'https://api.beshkashtan.uz/api/user/catalog/products/'
            '?cursor=cD0yMDI2&page_size=2',
        'previous': null,
        'results': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      }, map);

      expect(page.items.length, 2);
      expect(page.items.first.id, 'a');
      expect(page.hasMore, isTrue);
      expect(page.previousUrl, isNull);
    });

    test('next null bo‘lsa hasMore false', () {
      final page = PageDecoder.cursor<_Item>({
        'next': null,
        'previous': null,
        'results': <Map<String, dynamic>>[],
      }, map);
      expect(page.hasMore, isFalse);
      expect(page.isEmpty, isTrue);
    });
  });

  group('PageDecoder.offset', () {
    test('/catalog/categories/ javobini o‘qiydi', () {
      final page = PageDecoder.offset<_Item>({
        'count': 18,
        'next':
            'https://api.beshkashtan.uz/api/user/catalog/categories/?page=2',
        'previous': null,
        'results': [
          {'id': 'x'},
        ],
      }, map);

      expect(page.count, 18);
      expect(page.items.single.id, 'x');
      expect(page.hasMore, isTrue);
    });

    test('count yo‘q bo‘lsa BALAND yiqiladi (cursor javobi berilgan)', () {
      expect(
        () => PageDecoder.offset<_Item>({
          'next': null,
          'previous': null,
          'results': <Map<String, dynamic>>[],
        }, map),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('PageDecoder.bare', () {
    test('yalang‘och massiv — /addresses/, /favorites/', () {
      final page = PageDecoder.bare<_Item>([
        {'id': '1'},
        {'id': '2'},
      ], map);
      expect(page.items.length, 2);
      expect(page.hasMore, isFalse);
    });

    test('{"results": [...]} — /home/news/', () {
      final page = PageDecoder.bare<_Item>({
        'results': [
          {'id': 'n1'},
        ],
      }, map);
      expect(page.items.single.id, 'n1');
    });

    test('kutilmagan shakl xato beradi', () {
      expect(
        () => PageDecoder.bare<_Item>('salom', map),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  test('results ichida obyekt bo‘lmasa xato beradi', () {
    expect(
      () => PageDecoder.cursor<_Item>({
        'next': null,
        'results': ['salom'],
      }, map),
      throwsA(isA<UnknownFailure>()),
    );
  });
}
