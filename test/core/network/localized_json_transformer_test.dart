import 'package:beshkashtan_customer/core/network/localized_json_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Haqiqiy `GET /home/` javobidan olingan bo'lak.
/// Maydon nomlari va qiymatlar serverdan aynan ko'chirilgan.
const Map<String, dynamic> _realHomeFragment = {
  'store_hub': [
    {
      'store_type': 'shashlik',
      'label': 'Shashlik marenovka',
      'label_uz': 'Shashlik marenovka',
      'label_ru': 'Shashlik marenovka',
      'subtitle': "Qo'y/Mol Jazz, Qiyma, Tovuq",
      'badge': "Go'sht mahsulotlarimiz",
      'icon_key': 'grocery',
      'background_image':
          'https://api.beshkashtan.uz/media/stores/home/backgrounds/x.png',
      'active_store_count': 0,
      'is_enabled': true,
      'style': {
        'background_start': '#F59E0B',
        'background_end': '#FFFFFF',
        'text_color': '#0F172A',
        'background_overlay_opacity': 0.45,
      },
      'layout': {
        'card_variant': 'wide',
        'card_width_type': 'half',
        'image_mode': 'thumbnail',
        'image_position': 'right',
        'text_position': 'left',
        'card_radius': 16,
        'show_arrow': true,
      },
    },
  ],
  'categories': [
    {
      'id': 'e1b29aac-3b91-4693-9422-6d122e6ee947',
      'store_type': 'grocery',
      'parent': null,
      'name': 'Mevalar',
      'name_uz': 'Mevalar',
      'name_ru': 'Fruktы',
      'image_url': null,
      'sort_order': 0,
      'product_count': 12,
    },
  ],
  'popular_products': [
    {
      'id': 'd99e20ce-40bb-4217-8743-20fca14257c9',
      'name': 'Sut yog\'siz',
      'price': '15000.00',
      'old_price': null,
      'sku': '10103',
      'main_image':
          'https://api.beshkashtan.uz/media/products/thumbnails/a-3cd5.jpg',
      'store_type': 'household',
      'unit': 'dona',
      'unit_display': 'Dona',
      'is_purchasable': true,
      'available_stock': '0.000',
      'product_type': 'household',
    },
  ],
};

void main() {
  group('transliterateJsonTree', () {
    late Map<String, dynamic> out;

    setUp(() {
      out = transliterateJsonTree(_realHomeFragment)! as Map<String, dynamic>;
    });

    test('allowlist’dagi matn maydonlari kirillga o‘giriladi', () {
      final hub = (out['store_hub'] as List).first as Map<String, dynamic>;
      expect(hub['label'], 'Шашлик мареновка');
      expect(hub['subtitle'], 'Қўй/Мол Жазз, Қийма, Товуқ');
      expect(hub['badge'], 'Гўшт маҳсулотларимиз');

      final cat = (out['categories'] as List).first as Map<String, dynamic>;
      expect(cat['name'], 'Мевалар');
      expect(cat['name_uz'], 'Мевалар');

      final p = (out['popular_products'] as List).first as Map<String, dynamic>;
      expect(p['name'], 'Сут ёғсиз');
      expect(p['unit_display'], 'Дона');
    });

    test('ENUM va texnik maydonlar TEGILMAYDI', () {
      final hub = (out['store_hub'] as List).first as Map<String, dynamic>;
      expect(hub['store_type'], 'shashlik');
      expect(hub['icon_key'], 'grocery');

      final layout = hub['layout'] as Map;
      expect(layout['card_variant'], 'wide');
      expect(layout['card_width_type'], 'half');
      expect(layout['image_mode'], 'thumbnail');
      expect(layout['image_position'], 'right');
      expect(layout['text_position'], 'left');

      final p = (out['popular_products'] as List).first as Map<String, dynamic>;
      expect(p['product_type'], 'household');
      expect(p['sku'], '10103');
    });

    test('UUID, URL, rang, pul, son TEGILMAYDI', () {
      final cat = (out['categories'] as List).first as Map<String, dynamic>;
      expect(cat['id'], 'e1b29aac-3b91-4693-9422-6d122e6ee947');
      expect(cat['product_count'], 12);
      expect(cat['parent'], isNull);

      final hub = (out['store_hub'] as List).first as Map<String, dynamic>;
      expect(
        hub['background_image'],
        'https://api.beshkashtan.uz/media/stores/home/backgrounds/x.png',
      );
      final style = hub['style'] as Map;
      expect(style['background_start'], '#F59E0B');
      expect(style['text_color'], '#0F172A');
      expect(style['background_overlay_opacity'], 0.45);

      final p = (out['popular_products'] as List).first as Map<String, dynamic>;
      expect(p['price'], '15000.00');
      expect(p['available_stock'], '0.000');
      expect(p['main_image'], startsWith('https://'));
      expect(p['is_purchasable'], isTrue);
    });

    test('name_ru ataylab o‘girilmaydi (rus matni kirillda qolishi kerak)', () {
      final cat = (out['categories'] as List).first as Map<String, dynamic>;
      expect(cat['name_ru'], 'Fruktы', reason: 'name_ru allowlist da yo‘q');
    });

    test('daraxt tuzilishi saqlanadi', () {
      expect(out.keys, _realHomeFragment.keys);
      expect((out['store_hub'] as List).length, 1);
      expect((out['categories'] as List).length, 1);
    });

    test('idempotent — ikki marta qo‘llash natijani buzmaydi', () {
      final twice = transliterateJsonTree(out)! as Map<String, dynamic>;
      final a = (twice['categories'] as List).first as Map<String, dynamic>;
      final b = (out['categories'] as List).first as Map<String, dynamic>;
      expect(a['name'], b['name']);
    });
  });
}
