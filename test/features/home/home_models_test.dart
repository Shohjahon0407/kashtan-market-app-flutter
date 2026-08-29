import 'dart:ui' show Color;

import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jonli `GET /home/` javobidan olingan fragment (maydonlar aynan).
const Map<String, dynamic> _livePayload = {
  'banners': <dynamic>[],
  'store_hub': [
    {
      'store_type': 'shashlik',
      'label': 'Shashlik marenovka',
      'subtitle': "Qo'y/Mol Jazz, Qiyma, Tovuq",
      'icon': '',
      'icon_key': '',
      'image': null,
      'background_image':
          'https://api.beshkashtan.uz/media/stores/home/backgrounds/x.png',
      'active_store_count': 0,
      'sort_order': 0,
      'is_enabled': true,
      'style': {'background_start': '#F59E0B', 'accent_color': '#334155'},
      'layout': {'card_variant': 'wide'},
    },
    {
      'store_type': 'grocery',
      'label': 'Oziq ovqatlar',
      'subtitle': '',
      'image': null,
      'background_image': null,
      'sort_order': 2,
      'is_enabled': true,
      'style': <String, dynamic>{'accent_color': 'buzuq-rang'},
      'layout': <String, dynamic>{},
    },
    {'store_type': 'yangi_tur_2030', 'label': 'Yangi bo‘lim', 'sort_order': 1},
  ],
};

void main() {
  group('HomeData.fromJson', () {
    test('jonli payload o‘qiladi, sort_order bo‘yicha tartiblanadi', () {
      final data = HomeData.fromJson(_livePayload);

      expect(data.banners, isEmpty);
      expect(data.storeHub.length, 3);
      // sort_order: 0(shashlik), 1(yangi), 2(grocery)
      expect(data.storeHub[0].storeType, StoreType.shashlik);
      expect(data.storeHub[1].storeTypeWire, 'yangi_tur_2030');
      expect(data.storeHub[2].storeType, StoreType.grocery);
    });

    test('accent_color parse, buzug‘i null', () {
      final data = HomeData.fromJson(_livePayload);
      expect(data.storeHub[0].accentColor, const Color(0xFF334155));
      expect(data.storeHub[2].accentColor, isNull, reason: 'buzuq-rang');
    });

    test('background_image karta rasmi sifatida OLINMAYDI', () {
      // Regressiya: prod'da shashlik'ning background_image'ida tasodifiy
      // test rasmi (kosmosdan Yer surati) turibdi. U kartaga chiqmasligi
      // kerak — UI lokal assetga tushishi kerak.
      final data = HomeData.fromJson(_livePayload);
      expect(data.storeHub[0].imageUrl, isNull);
      expect(data.storeHub[2].imageUrl, isNull);
    });

    test('server `image` bergan bo‘lsa o‘sha olinadi', () {
      final data = HomeData.fromJson(const {
        'banners': <dynamic>[],
        'store_hub': [
          {
            'store_type': 'grocery',
            'label': 'x',
            'image':
                'https://api.beshkashtan.uz/media/stores/home/images/a.png',
            'background_image': 'https://api.beshkashtan.uz/media/other.png',
          },
        ],
      });
      expect(
        data.storeHub.single.imageUrl,
        'https://api.beshkashtan.uz/media/stores/home/images/a.png',
      );
    });

    test('noma’lum store_type yiqitmaydi — karta baribir chiziladi', () {
      final data = HomeData.fromJson(_livePayload);
      final unknown = data.storeHub[1];
      expect(unknown.storeType, isNull);
      expect(unknown.label, 'Yangi bo‘lim');
    });

    test('tuzilma buzuq bo‘lsa bo‘sh ro‘yxat (crash yo‘q)', () {
      final data = HomeData.fromJson(const {
        'banners': 'massiv emas',
        'store_hub': null,
      });
      expect(data.banners, isEmpty);
      expect(data.storeHub, isEmpty);
    });
  });

  group('HomeBanner layout chegaralari', () {
    HomeBanner banner(Map<String, dynamic> layout) => HomeBanner.fromJson({
      'id': 'b1',
      'title': 'Ventelyatorlar',
      'image': 'https://x/y.png',
      'layout': layout,
    });

    test('admin balandligi ishlatiladi', () {
      expect(banner({'mobile_height_px': 180}).heightPx, 180);
      expect(banner({'display_height_px': 200}).heightPx, 200);
    });

    test('chegaradan tashqarisi qisiladi, yo‘g‘i default', () {
      expect(banner({'mobile_height_px': 900}).heightPx, 260);
      expect(banner({'mobile_height_px': 10}).heightPx, 80);
      expect(banner(const {}).heightPx, 140);
      expect(banner(const {}).radius, 16);
    });
  });
}
