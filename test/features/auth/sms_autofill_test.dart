import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/platform/sms_autofill_service.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/presentation/screens/phone_screen.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/phone_field.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthApi extends Mock implements AuthApi {}

/// Platforma kanaliga tegmaydigan soxta servis: test kodni o'zi "yuboradi".
class FakeSmsAutofillService implements SmsAutofillService {
  final _controller = StreamController<String>.broadcast();
  final startedModes = <SmsAutofillMode>[];
  int stopCount = 0;

  @override
  Stream<String> get codes => _controller.stream;

  @override
  Future<void> start({required SmsAutofillMode mode}) async {
    startedModes.add(mode);
  }

  @override
  Future<void> stop() async => stopCount++;

  void emit(String code) => _controller.add(code);

  Future<void> close() => _controller.close();
}

const _user = AuthUser(
  id: 'u-1',
  phoneNumber: '+998901234567',
  firstName: '',
  lastName: '',
  role: UserRole.customer,
  isPhoneVerified: true,
  requiresOnboarding: false,
  missingFields: [],
);

void main() {
  late _MockAuthApi api;
  late FakeSmsAutofillService autofill;
  late ProviderContainer container;

  Future<void> pumpLogin(WidgetTester tester, {bool smsAppHash = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    api = _MockAuthApi();
    autofill = FakeSmsAutofillService();
    addTearDown(autofill.close);
    when(
      () => api.sendOtp(any()),
    ).thenAnswer((_) async => SendOtpResult(smsAppHash: smsAppHash));
    when(
      () => api.verifyOtp(
        normalizedPhone: any(named: 'normalizedPhone'),
        code: any(named: 'code'),
      ),
    ).thenAnswer(
      (_) async => const VerifyOtpResult(
        access: 'a',
        refresh: 'r',
        user: _user,
        isNewUser: false,
      ),
    );
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authApiProvider.overrideWithValue(api),
        smsAutofillServiceProvider.overrideWithValue(autofill),
      ],
    );
    addTearDown(container.dispose);

    // Login muvaffaqiyatida ekran `context.go(Routes.home)` qiladi —
    // shuning uchun minimal router kerak.
    final router = GoRouter(
      initialLocation: Routes.authPhone,
      routes: [
        GoRoute(path: Routes.authPhone, builder: (_, _) => const PhoneScreen()),
        GoRoute(
          path: Routes.home,
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('uz'),
          supportedLocales: const [Locale('uz')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterPhoneAndSend(WidgetTester tester) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(PhoneField),
        matching: find.byType(TextField),
      ),
      '90 123 45 67',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auth-prompt-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(OtpCodeField), findsOneWidget);
  }

  testWidgets('SMS kodi maydonga yoziladi va BIR marta tasdiqlanadi', (
    tester,
  ) async {
    await pumpLogin(tester);
    await enterPhoneAndSend(tester);
    expect(autofill.startedModes, [SmsAutofillMode.consent]);

    autofill.emit('482913');
    await tester.pumpAndSettle();

    verify(
      () => api.verifyOtp(normalizedPhone: '+998901234567', code: '482913'),
    ).called(1);
    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
  });

  testWidgets('bir xil kod ikki marta kelsa ham bir marta yuboriladi', (
    tester,
  ) async {
    await pumpLogin(tester);
    await enterPhoneAndSend(tester);

    autofill
      ..emit('482913')
      ..emit('482913');
    await tester.pumpAndSettle();

    verify(
      () => api.verifyOtp(normalizedPhone: '+998901234567', code: '482913'),
    ).called(1);
  });

  testWidgets('server hash beradi → 0-tap (both) rejimi yoqiladi', (
    tester,
  ) async {
    await pumpLogin(tester, smsAppHash: true);
    await enterPhoneAndSend(tester);

    expect(autofill.startedModes, [SmsAutofillMode.both]);
  });

  testWidgets('OTP bosqichidan chiqqach kelgan kod e\'tiborsiz qoladi', (
    tester,
  ) async {
    await pumpLogin(tester);
    await enterPhoneAndSend(tester);
    await tester.tap(find.byKey(const ValueKey('auth-change-number')));
    await tester.pumpAndSettle();

    // Kechikib kelgan SMS (masalan telefon o'zgartirilgandan keyin).
    autofill.emit('482913');
    await tester.pumpAndSettle();

    verifyNever(
      () => api.verifyOtp(
        normalizedPhone: any(named: 'normalizedPhone'),
        code: any(named: 'code'),
      ),
    );
  });

  testWidgets('telefonni o\'zgartirishda tinglash to\'xtaydi', (tester) async {
    await pumpLogin(tester);
    await enterPhoneAndSend(tester);
    final before = autofill.stopCount;

    await tester.tap(find.byKey(const ValueKey('auth-change-number')));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneField), findsOneWidget);
    expect(autofill.stopCount, greaterThan(before));
  });

  testWidgets('ekran yopilganda tinglash to\'xtaydi', (tester) async {
    await pumpLogin(tester);
    await enterPhoneAndSend(tester);
    final before = autofill.stopCount;

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(autofill.stopCount, greaterThan(before));
  });
}
