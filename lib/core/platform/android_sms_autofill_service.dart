import 'dart:async';

import 'package:flutter/services.dart';

import 'otp_sms_parser.dart';
import 'sms_autofill_service.dart';

/// Android implementatsiyasi: `MainActivity` dagi SMS Retriever +
/// SMS User Consent kanallari.
///
/// Hech qanday SMS ruxsati (`RECEIVE_SMS`/`READ_SMS`) talab qilinmaydi —
/// xabarni Google Play Services beradi, shuning uchun Play'da SMS
/// deklaratsiyasi ham kerak emas.
class AndroidSmsAutofillService implements SmsAutofillService {
  static const _method = MethodChannel('uz.beshkashtan.customer/sms_autofill');
  static const _events = EventChannel(
    'uz.beshkashtan.customer/sms_autofill_events',
  );

  final _codes = StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _native;
  bool _active = false;

  @override
  Stream<String> get codes => _codes.stream;

  @override
  Future<void> start({required SmsAutofillMode mode}) async {
    // Obuna native `onListen` ni chaqiradi — Dart ulangunicha kelgan xabar
    // o'sha yerda buferlangan bo'lsa, aynan shu paytda oqib chiqadi.
    _native ??= _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object _) {},
    );
    if (_active) return;
    _active = true;
    try {
      await _method.invokeMethod<bool>('start', {'mode': mode.name});
    } on PlatformException {
      // Play Services yo'q/eskirgan qurilma — foydalanuvchi kodni qo'lda
      // kiritadi, bu xato ekranga chiqarilmaydi.
      _active = false;
    } on MissingPluginException {
      _active = false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_active) return;
    _active = false;
    try {
      await _method.invokeMethod<void>('stop');
    } on PlatformException {
      // Sessiya allaqachon yopilgan bo'lishi mumkin.
    } on MissingPluginException {
      // Kanal yo'q — to'xtatadigan narsa ham yo'q.
    }
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'message':
        final code = OtpSmsParser.extract(event['message'] as String?);
        if (code != null && !_codes.isClosed) _codes.add(code);
        _active = false;
      case 'timeout': // GMS listener'i 5 daqiqadan keyin o'ladi
      case 'denied': // foydalanuvchi tizim oynasida rad etdi
      case 'error':
        _active = false;
    }
  }

  /// Provider dispose bo'lganda chaqiriladi.
  void dispose() {
    unawaited(stop());
    unawaited(_native?.cancel());
    unawaited(_codes.close());
  }
}
