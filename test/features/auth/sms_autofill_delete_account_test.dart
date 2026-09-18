import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/platform/sms_autofill_service.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/delete_account_sheet.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  int requestedCodes = 0;
  final deletedWith = <String>[];

  @override
  AuthState build() => const AuthState.authenticated(
    AuthUser(
      id: 'user-1',
      phoneNumber: '+998901234567',
      firstName: 'Sardor',
      lastName: 'Rahimov',
      role: UserRole.customer,
      isPhoneVerified: true,
      requiresOnboarding: false,
      missingFields: [],
    ),
  );

  @override
  Future<void> requestDeleteAccountCode() async {
    requestedCodes++;
  }

  @override
  Future<void> deleteAccount(String otpCode) async {
    deletedWith.add(otpCode);
    state = const AuthState.unauthenticated();
  }
}

class _FakeSmsAutofillService implements SmsAutofillService {
  final _controller = StreamController<String>.broadcast();
  int startCount = 0;
  int stopCount = 0;

  @override
  Stream<String> get codes => _controller.stream;

  @override
  Future<void> start({required SmsAutofillMode mode}) async => startCount++;

  @override
  Future<void> stop() async => stopCount++;

  void emit(String code) => _controller.add(code);

  Future<void> close() => _controller.close();
}

/// Hisobni o'chirishda SMS kodi FAQAT to'ldiriladi — avtomatik tasdiqlash
/// ataylab yo'q, chunki amal qaytarib bo'lmaydi.
void main() {
  testWidgets('kod to\'ladi, lekin hisob avtomatik o\'chirilMAYDI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final autofill = _FakeSmsAutofillService();
    addTearDown(autofill.close);
    final auth = _FakeAuthController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(() => auth),
          smsAutofillServiceProvider.overrideWithValue(autofill),
        ],
        child: MaterialApp(
          locale: const Locale('uz'),
          theme: AppTheme.light(),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open-sheet'),
                  onPressed: () => showDeleteAccountSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pumpAndSettle();

    // Kod hali so'ralmagan — tinglash ham boshlanmaydi.
    expect(autofill.startCount, 0);

    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(auth.requestedCodes, 1);
    expect(autofill.startCount, 1);

    autofill.emit('112233');
    await tester.pumpAndSettle();

    // Maydon to'ldi...
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(OtpCodeField),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      '112233',
    );
    expect(find.byKey(const ValueKey('otp-box-5')), findsOneWidget);
    // ...lekin hisob O'CHIRILMADI.
    expect(auth.deletedWith, isEmpty);
    expect(
      find.byKey(const ValueKey('delete-account-confirm')),
      findsOneWidget,
    );

    // Faqat foydalanuvchi tugmani bosgach o'chadi.
    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(auth.deletedWith, ['112233']);
  });
}
