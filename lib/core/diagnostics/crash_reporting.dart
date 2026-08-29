import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production crash diagnostikasi.
///
/// Faqat release Android/iOS buildda yoqiladi. User identity, telefon, token,
/// request payload yoki boshqa PII Crashlytics'ga biriktirilmaydi.
abstract final class CrashReporting {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || !kReleaseMode || kIsWeb) return;
    _initialized = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(true);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    } on Object {
      // Diagnostika bootstrap xatosi ilovaning asosiy oqimini bloklamaydi.
      // Bu yerda xato matni loglanmaydi: config/secrets tasodifan chiqmasin.
    }
  }
}
