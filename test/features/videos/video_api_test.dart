import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _VideoAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path.endsWith('/videos/video-1/products/')) {
      return _json({
        'category': {
          'id': 'category-1',
          'name': 'Maishiy texnikalar',
          'store_type': 'household',
        },
        'results': [
          {
            'id': 'rail-product-1',
            'name': 'Dazmol',
            'description': '',
            'price': '220000.00',
            'unit_display': 'dona',
            'store_type': 'household',
            'main_image': null,
            'is_purchasable': true,
            'variants': <Object>[],
            'addon_groups': <Object>[],
          },
        ],
        'see_all': {'store_type': 'household', 'category_id': 'category-1'},
      });
    }
    if (options.path.endsWith('/like/')) {
      return _json({'is_liked': options.method == 'PUT', 'likes_count': 4});
    }
    if (options.path.endsWith('/comments/')) {
      if (options.method == 'POST') {
        return _json({
          'id': 'comment-2',
          'user': {'id': 'me', 'name': 'Ali'},
          'text': 'Zo‘r',
          'is_owner': true,
          'created_at': '2026-08-01T12:00:00Z',
        }, 201);
      }
      return _json({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [
          {
            'id': 'comment-1',
            'user': {'id': 'u-1', 'name': 'Vali'},
            'text': 'Yaxshi',
            'is_owner': false,
            'created_at': '2026-08-01T11:00:00Z',
          },
        ],
      });
    }
    return _json({
      'next': 'https://api.beshkashtan.uz/api/user/videos/?cursor=next',
      'previous': null,
      'results': [
        {
          'id': 'video-1',
          'video_url': 'https://cdn.example/video.mp4',
          'poster_url': '/media/videos/poster.jpg',
          'title': 'Choynak videosi',
          'store': {
            'id': 'store-1',
            'name': 'Xozmak',
            'store_type': 'household',
          },
          'product': {
            'id': 'product-1',
            'name': 'Choynak',
            'store_type': 'household',
            'price': '120000.00',
            'image': null,
            'is_purchasable': true,
          },
          'duration': '12.500',
          'likes_count': 3,
          'comments_count': 1,
          'is_liked': false,
          'published_at': '2026-08-01T10:00:00Z',
        },
      ],
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late _VideoAdapter adapter;
  late VideoApi api;

  setUp(() {
    adapter = _VideoAdapter();
    api = VideoApi(
      ApiClient.create(
        tokenStore: InMemoryTokenStore(access: 'access', refresh: 'refresh'),
        apiLang: () => 'uz',
        script: () => UzScript.none,
        refresh: (_) async => null,
        onSessionExpired: () async {},
        adapter: adapter,
      ),
    );
  });

  test('cursor feed product CTA va media URLlarini o‘qiydi', () async {
    final page = await api.fetchFeed();
    final video = page.items.single;

    expect(video.store.name, 'Xozmak');
    expect(video.product?.id, 'product-1');
    expect(
      video.posterUrl,
      'https://api.beshkashtan.uz/media/videos/poster.jpg',
    );
    expect(page.hasMore, isTrue);
    expect(adapter.requests.single.queryParameters['page_size'], 10);
  });

  test('like PUT/DELETE va offset comment kontrakti ishlaydi', () async {
    final liked = await api.setLike('video-1', true);
    final unliked = await api.setLike('video-1', false);
    final comments = await api.fetchComments('video-1');
    final created = await api.createComment('video-1', 'Zo‘r');

    expect(liked.isLiked, isTrue);
    expect(unliked.isLiked, isFalse);
    expect(comments.count, 1);
    expect(comments.items.single.user.name, 'Vali');
    expect(created.isOwner, isTrue);
    expect(
      adapter.requests.map((request) => request.method),
      containsAll(['PUT', 'DELETE', 'GET', 'POST']),
    );
  });

  test('video products rail va category see-all kontraktini o‘qiydi', () async {
    final rail = await api.fetchProducts('video-1');

    expect(rail.category, 'Maishiy texnikalar');
    expect(rail.categoryId, 'category-1');
    expect(rail.storeType, 'household');
    expect(rail.products.single.name, 'Dazmol');
    expect(rail.products.single.imageUrl, isNull);
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, endsWith('/videos/video-1/products/'));
  });
}
