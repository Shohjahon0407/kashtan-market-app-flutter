@Tags(['live'])
library;

import 'dart:io';

import 'package:beshkashtan_customer/core/config/api_endpoints.dart';
import 'package:beshkashtan_customer/core/config/app_config.dart';
import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// HAQIQIY serverga so'rov yuboradigan diagnostika testi.
///
/// Odatdagi `flutter test` da o'tkazib yuboriladi (`--tags live` bilan
/// ishga tushiriladi), chunki tarmoqqa bog'liq.
///
/// Maqsad: "Internet aloqasi yo'q" xatosining sababi URL/TLS/interceptor
/// zanjirida emasligini ISBOTLASH — shunda muammo qurilma/plagin tomonida
/// ekani aniq bo'ladi.
void main() {
  setUpAll(() {
    // flutter_test barcha HttpClient so'rovlarini 400 qaytaradigan qilib
    // almashtiradi — haqiqiy tarmoq uchun uni o'chiramiz.
    HttpOverrides.global = null;
  });

  test('URL to‘g‘ri yig‘iladi', () {
    expect(AppConfig.apiBaseUrl, 'https://api.beshkashtan.uz/api/user');
    expect(
      '${AppConfig.apiBaseUrl}${Api.sendOtp}',
      'https://api.beshkashtan.uz/api/user/auth/send-otp/',
    );
  });

  test(
    'haqiqiy GET /home/ butun interceptor zanjiri orqali ishlaydi',
    () async {
      final client = ApiClient.create(
        tokenStore: InMemoryTokenStore(),
        apiLang: () => 'uz',
        script: () => UzScript.none,
        refresh: (_) async => null,
        onSessionExpired: () async {},
      );

      final data = await client.get(Api.home);
      expect(data, isA<Map<dynamic, dynamic>>());
      expect((data as Map).containsKey('store_hub'), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'TOKEN OMBORI XATO BERSA qanday xato chiqadi',
    () async {
      final client = ApiClient.create(
        tokenStore: _ThrowingTokenStore(),
        apiLang: () => 'uz',
        script: () => UzScript.none,
        refresh: (_) async => null,
        onSessionExpired: () async {},
      );

      try {
        await client.get(Api.home);
        fail('xato kutilgan edi');
      } on ApiFailure catch (failure) {
        // Bu yerda NetworkFailure chiqsa — "Internet aloqasi yo'q" xabari
        // aslida LOKAL xatoni yashirayotgan bo'ladi.
        // ignore: avoid_print
        print(
          '>>> token ombori xato berganda: ${failure.runtimeType} '
          '/ ${failure.message}',
        );
        expect(
          failure,
          isNot(isA<NetworkFailure>()),
          reason: 'lokal xato "internet yo‘q" deb ko‘rsatilmasligi kerak',
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );
}

class _ThrowingTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccess() async =>
      throw Exception('PlatformException: keystore mavjud emas');

  @override
  Future<String?> readRefresh() async => null;

  @override
  Future<void> save({required String access, required String refresh}) async {}

  @override
  Future<void> saveAccess(String access) async {}
}
