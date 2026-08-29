import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/home/presentation/profile_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
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
  Future<void> logout() async {
    state = const AuthState.unauthenticated();
  }

  int requestedCodes = 0;

  @override
  Future<void> requestDeleteAccountCode() async {
    requestedCodes++;
  }

  @override
  Future<void> deleteAccount(String otpCode) async {
    state = const AuthState.unauthenticated();
  }
}

void main() {
  _deleteAccountTests();
  testWidgets('profil faqat real menu qatorlari va store pickerni ko‘rsatadi', (
    tester,
  ) async {
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
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sardor Rahimov'), findsOneWidget);
    expect(find.text('+998 90 123 45 67'), findsOneWidget);
    expect(find.text('Manzillar'), findsOneWidget);
    expect(find.text('Buyurtmalar'), findsOneWidget);
    expect(find.text('Bildirishnomalar'), findsOneWidget);
    expect(find.text('Sevimlilar'), findsOneWidget);
    expect(find.text("Yo'q tovarlar uchun zakaz berish"), findsOneWidget);
    expect(find.text('Bonus'), findsNothing);
    expect(find.text("To'lov kartalari"), findsNothing);

    await tester.tap(find.text('Buyurtmalar'));
    await tester.pumpAndSettle();
    expect(find.text("Do'konni tanlang"), findsOneWidget);
    for (final type in StoreType.values) {
      expect(
        find.byKey(ValueKey('profile-store-${type.wire}')),
        findsOneWidget,
        reason: 'har do‘kon turi uchun tanlov bo‘lishi kerak: ${type.wire}',
      );
    }
  });
}

// ─── Hisobni o'chirish (Play Store talabi) ───────────────────────────────────

void _deleteAccountTests() {
  testWidgets("hisobni o'chirish oynasi ilova temasida xatosiz chiziladi", (
    tester,
  ) async {
    // Telefon o'lchami + HAQIQIY tema: temada FilledButton.minimumSize
    // `Size.fromHeight` (kengligi cheksiz), shuning uchun oyna tugmalari
    // chegaralangan kenglik beradigan konteynerda bo'lishi shart.
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
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('profile-delete-account'));
    expect(row, findsOneWidget);

    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    // 1-bosqich: ogohlantirish, kod maydoni hali yo'q.
    expect(find.text("Hisobni butunlay o'chirish"), findsOneWidget);
    expect(find.byKey(const ValueKey('otp-box-0')), findsNothing);
    expect(tester.takeException(), isNull);

    // 2-bosqich: kod so'raladi va kod maydoni chiqadi.
    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('otp-box-0')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Bekor qilish hech narsani o'chirmaydi.
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(find.text("Hisobni butunlay o'chirish"), findsNothing);
  });
}
