/// Server javobida transliteratsiya qilinishi MUMKIN bo'lgan JSON kalitlari.
///
/// Bu allowlist — butun xavfsizlik shu yerda. Ro'yxatda YO'Q har qanday kalit
/// tegilmaydi, ya'ni backend yangi maydon qo'shsa u default'da **xavfsiz**.
///
/// Ataylab ro'yxatga KIRITILMAGAN (va hech qachon kiritilmasligi kerak):
///   status, user_status, courier_step, payment_method, payment_status,
///   fulfillment_type, store_type, product_type, action_type, target_type,
///   layout_style, card_variant, card_width_type, image_mode, image_position,
///   text_position, image_fit, selection_type, ordering, product_ordering,
///   search_query, custom_url, external_url, qr_token, qr_payload, sku,
///   icon_key, barcha `*_color`, `*_id`, `id`, `url`, `image`, `next`,
///   `previous`, `cursor`, narx/miqdor stringlari.
library;

/// Faqat foydalanuvchiga ko'rinadigan, tabiiy tilda yozilgan maydonlar.
const Set<String> kLocalizedKeys = {
  // Umumiy nom/sarlavha
  'name',
  'title',
  'subtitle',
  'description',
  'label',
  'badge',
  'badge_text',
  'cta',
  'text',
  'body',
  'message',
  'detail',

  // Katalog
  'product_name',
  'variant_name',
  'category_name',
  'store_name',
  'branch_name',
  'unit',
  'unit_display',
  'addon_name',
  'group_name',
  'option_name',
  'items_summary',
  'items_preview_text',

  // Buyurtma
  'status_label',
  'status_display',
  'user_status_display',
  'customer_note',
  'courier_note',
  'courier_name',
  'courier_comment',
  'comment',
  'note',
  'reason',

  // Manzil
  'address',
  'address_summary',
  'district',
  'neighborhood',
  'street',
  'house',
  'apartment',
  'landmark',
  'full_name',
  'first_name',
  'last_name',
  'user_name',
  'user_display_name',
  'user_first_name',
  'user_last_name',

  // Yordam
  'subject',

  // Xom `*_uz` juftliklari — app ularni fallback sifatida o'qishi mumkin.
  // `*_ru` ataylab yo'q: rus matnini kirillga o'girish mantiqsiz.
  'name_uz',
  'title_uz',
  'subtitle_uz',
  'description_uz',
  'badge_uz',
  'label_uz',
  'cta_uz',
  'badge_text_uz',
  'status_label_uz',
  'user_status_display_uz',
  'address_uz',
};
