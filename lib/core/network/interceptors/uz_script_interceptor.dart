import 'package:dio/dio.dart';

import '../../localization/uzbek_transliterator.dart';

/// Kirill yozuvida kiritilgan matnni serverga LOTIN holida yuboradi.
///
/// Nega majburiy: `api/user/catalog/filters.py` qidiruvi xom
/// `name_uz__icontains` — bazadagi hamma narsa lotinda. Kirill so'rov
/// hech qachon mos kelmaydi va foydalanuvchi "hech narsa topilmadi" ko'radi.
///
/// Javob transliteratori matnni yana kirillga qaytargani uchun bu almashuv
/// foydalanuvchiga umuman ko'rinmaydi, baza esa bir yozuvda qoladi.
class UzScriptRequestInterceptor extends Interceptor {
  UzScriptRequestInterceptor(this._script);

  final UzScript Function() _script;

  /// Body ichida transliteratsiya qilinadigan maydonlar.
  ///
  /// Ataylab TOR ro'yxat: faqat foydalanuvchi o'zi yozadigan erkin matn.
  /// `phone_number`, `otp_code`, barcha `*_id` va enum'lar tegilmaydi.
  static const Set<String> writableTextFields = {
    // Manzil
    'title',
    'district',
    'neighborhood',
    'street',
    'house',
    'apartment',
    'landmark',
    'address',
    // Profil / onboarding
    'full_name',
    'first_name',
    'last_name',
    // Buyurtma va savat izohlari
    'customer_note',
    'note',
    'comment',
    // Yordam
    'subject',
    'message',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_script() != UzScript.cyrillic) {
      handler.next(options);
      return;
    }

    // Qidiruv so'rovi
    final q = options.queryParameters['q'];
    if (q is String && q.isNotEmpty) {
      options.queryParameters['q'] = UzbekTransliterator.toLatin(q);
    }

    // Yoziladigan body maydonlari
    final data = options.data;
    if (data is Map<String, dynamic>) {
      for (final key in writableTextFields) {
        final value = data[key];
        if (value is String && value.isNotEmpty) {
          data[key] = UzbekTransliterator.toLatin(value);
        }
      }
    } else if (data is FormData) {
      for (var index = 0; index < data.fields.length; index++) {
        final field = data.fields[index];
        if (writableTextFields.contains(field.key) && field.value.isNotEmpty) {
          data.fields[index] = MapEntry(
            field.key,
            UzbekTransliterator.toLatin(field.value),
          );
        }
      }
    }

    handler.next(options);
  }
}
