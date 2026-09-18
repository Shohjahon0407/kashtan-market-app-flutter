import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SMS orqali kelgan OTP kodini avtomatik to'ldirish rejimi.
enum SmsAutofillMode {
  /// SMS User Consent: tizim oynasi chiqadi, foydalanuvchi bir marta
  /// "Ruxsat" bosadi. SMS matniga hech narsa qo'shilishi shart emas.
  consent,

  /// SMS Retriever: hech narsa bosilmaydi, ammo SMS oxirida 11 belgilik
  /// ilova hash'i bo'lishi SHART.
  retriever,

  /// Ikkalasi birga: hash mos kelsa 0 tap, aks holda tizim oynasi.
  /// Sideload qilingan (Play imzosi bo'lmagan) build'lar uchun zaxira.
  both,
}

/// Android'da SMS kodini avtomatik o'qish.
///
/// iOS'da kerak emas — `AutofillHints.oneTimeCode` klaviatura ustida kodni
/// o'zi taklif qiladi. Shuning uchun default implementatsiya no-op va
/// widget testlari hech qanday platforma kanaliga tegmaydi.
abstract interface class SmsAutofillService {
  /// Tinglashni boshlaydi. Qayta chaqirish XAVFSIZ (idempotent) — ilova
  /// fondan qaytganda shu xususiyatga tayaniladi.
  Future<void> start({required SmsAutofillMode mode});

  /// Tinglashni to'xtatadi (ekran yopilganda, kod qayta yuborilganda).
  Future<void> stop();

  /// SMS matnidan ajratilgan kodlar. Broadcast: login ekrani va hisob
  /// o'chirish oynasi bir vaqtda obuna bo'la oladi.
  Stream<String> get codes;
}

/// Platformada qo'llab-quvvatlanmaydi (iOS, web, testlar).
class NoopSmsAutofillService implements SmsAutofillService {
  const NoopSmsAutofillService();

  @override
  Stream<String> get codes => const Stream<String>.empty();

  @override
  Future<void> start({required SmsAutofillMode mode}) async {}

  @override
  Future<void> stop() async {}
}

/// Default — no-op. `main.dart` Android uchun haqiqiy implementatsiyani
/// beradi (`onAfterLoginProvider` bilan bir xil naqsh).
final smsAutofillServiceProvider = Provider<SmsAutofillService>(
  (ref) => const NoopSmsAutofillService(),
);

/// Qaysi rejim ishlatilishini SERVER hal qiladi.
///
/// `send-otp` javobidagi `sms_app_hash` bayrog'i SMS matnida Retriever
/// hash'i borligini bildiradi. Shu sababli 0-tap rejimiga o'tish uchun
/// ilovani yangilash shart emas — serverdagi bitta sozlama yetarli.
final smsAutofillModeProvider =
    NotifierProvider<SmsAutofillModeController, SmsAutofillMode>(
      SmsAutofillModeController.new,
    );

class SmsAutofillModeController extends Notifier<SmsAutofillMode> {
  @override
  SmsAutofillMode build() => SmsAutofillMode.consent;

  /// `send-otp` javobidan keyin chaqiriladi.
  void applyServerHint({required bool serverAppendsHash}) {
    state = serverAppendsHash ? SmsAutofillMode.both : SmsAutofillMode.consent;
  }
}
