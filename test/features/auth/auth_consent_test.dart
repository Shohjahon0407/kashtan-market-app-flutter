import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/auth/presentation/screens/phone_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

/// Play/huquqiy talab: kirish ekranida foydalanish shartlari va maxfiylik
/// siyosatiga rozilik matni ko'rinishi shart.
void main() {
  testWidgets('kirish ekranida rozilik matni va havolalar bor', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith(_FakeAuthController.new),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          supportedLocales: [Locale('uz')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: PhoneScreen(isModalPrompt: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final consent = find.byKey(const ValueKey('auth-consent-text'));
    expect(consent, findsOneWidget);

    final rich = tester.widget<Text>(consent);
    final plain = rich.textSpan!.toPlainText();
    expect(plain, contains('Foydalanish shartlari'));
    expect(plain, contains('Maxfiylik siyosati'));
    expect(plain, contains('rozilik bildirasiz'));
  });
}
