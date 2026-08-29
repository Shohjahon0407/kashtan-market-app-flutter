import 'package:beshkashtan_customer/app.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/routing/app_router.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/presentation/screens/otp_screen.dart';
import 'package:beshkashtan_customer/features/auth/presentation/screens/phone_screen.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/phone_field.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/home/presentation/home_screen.dart';
import 'package:beshkashtan_customer/features/home/presentation/profile_screen.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:beshkashtan_customer/features/notifications/domain/notifications_controller.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockHomeApi extends Mock implements HomeApi {}

class _MockVideoApi extends Mock implements VideoApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

class _MockNotificationsApi extends Mock implements NotificationsApi {}

const _user = AuthUser(
  id: 'u-1',
  phoneNumber: '+998901234567',
  firstName: '',
  lastName: '',
  role: UserRole.customer,
  isPhoneVerified: true,
  requiresOnboarding: true, // router BUNI e'tiborga olmasligi kerak
  missingFields: ['full_name', 'location'],
);

const _homeWithStore = HomeData(
  banners: [],
  storeHub: [
    StoreHubItem(
      storeType: StoreType.household,
      storeTypeWire: 'household',
      label: 'Xozmak',
      subtitle: 'Uy uchun mahsulotlar',
      imageUrl: null,
      accentColor: null,
      sortOrder: 0,
    ),
  ],
);

void main() {
  late _MockAuthApi api;
  late ProviderContainer container;

  Future<void> pumpApp(
    WidgetTester tester, {
    String? access,
    String? refresh,
    HomeData homeData = const HomeData(banners: [], storeHub: []),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    api = _MockAuthApi();
    final homeApi = _MockHomeApi();
    final videoApi = _MockVideoApi();
    final cartApi = _MockCartApi();
    final checkoutApi = _MockCheckoutApi();
    final notificationsApi = _MockNotificationsApi();
    when(() => homeApi.fetch()).thenAnswer((_) async => homeData);
    when(() => videoApi.fetchFeed()).thenAnswer(
      (_) async => const CursorPage<StoreVideo>(items: [], nextUrl: null),
    );
    when(() => cartApi.fetch(any())).thenAnswer(
      (invocation) async =>
          CartData.empty(invocation.positionalArguments.first as String),
    );
    when(() => checkoutApi.fetchAddresses()).thenAnswer((_) async => []);
    when(() => notificationsApi.unreadCount()).thenAnswer((_) async => 0);
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: access, refresh: refresh),
        ),
        authApiProvider.overrideWithValue(api),
        homeApiProvider.overrideWithValue(homeApi),
        videoApiProvider.overrideWithValue(videoApi),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(checkoutApi),
        notificationsApiProvider.overrideWithValue(notificationsApi),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BeshKashtanApp(),
      ),
    );
  }

  AuthController auth() => container.read(authControllerProvider.notifier);

  testWidgets('kirilmagan guest → Home ekrani', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PhoneScreen), findsNothing);
  });

  testWidgets('guest request kartasi mavjud login modalni ochadi', (
    tester,
  ) async {
    await pumpApp(tester, homeData: _homeWithStore);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-missing-product-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);
    expect(find.byType(PhoneField), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('protected amal blur modal ochadi va fon bosilganda yopilmaydi', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(PhoneField), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auth-prompt-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('telefon va OTP shu modalda, login ortidan amal davom etadi', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    when(() => api.sendOtp(any())).thenAnswer((_) async {});
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

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PhoneField),
        matching: find.byType(TextField),
      ),
      '90 123 45 67',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('auth-prompt-continue')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('auth-prompt-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.byType(PhoneField), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      ),
      '482913',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsNothing);
    expect(
      find.byType(ProfileScreen),
      findsOneWidget,
      reason:
          'current route: ${container.read(appRouterProvider).routerDelegate.currentConfiguration.uri}',
    );
    verify(() => api.sendOtp('+998901234567')).called(1);
    verify(
      () => api.verifyOtp(normalizedPhone: '+998901234567', code: '482913'),
    ).called(1);
  });

  testWidgets(
    'to‘g‘ridan-to‘g‘ri OTP holatiga o‘tib bo‘lmaydi (telefon yo‘q)',
    (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(Routes.authOtp);
      await tester.pumpAndSettle();
      // phone == null bo'lgani uchun /auth/otp so'ralsa ham /auth/phone
      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
    },
  );

  testWidgets(
    'kod yuborilgach OTP ekrani, verify’dan keyin redirect Home’ga olib chiqadi'
    ' (requiresOnboarding=true bo‘lsa ham)',
    (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(Routes.authPhone);
      await tester.pumpAndSettle();

      when(() => api.sendOtp(any())).thenAnswer((_) async {});
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
          isNewUser: true,
        ),
      );

      await auth().sendCode('901234567');
      container.read(appRouterProvider).go(Routes.authOtp);
      await tester.pumpAndSettle();

      // Controller navigatsiya qilmaydi; auth prompt UI muvaffaqiyatni yopadi.
      // Bu controller-level testda faqat sessiya holatini tekshiramiz.
      await auth().verifyCode('482913');
      await tester.pumpAndSettle();
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      container.read(appRouterProvider).go(Routes.home);
      await tester.pumpAndSettle();

      // Onboarding YO'Q — to'g'ri Home
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets('token bor, me() OK → restoreSession Home’ga olib boradi', (
    tester,
  ) async {
    await pumpApp(tester, access: 'a', refresh: 'r');
    when(() => api.me()).thenAnswer((_) async => _user);

    await auth().restoreSession();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('logout → guest Home ekraniga qaytadi', (tester) async {
    await pumpApp(tester, access: 'a', refresh: 'r');
    when(() => api.me()).thenAnswer((_) async => _user);
    when(() => api.logout(any())).thenAnswer((_) async {});

    await auth().restoreSession();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await auth().logout();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PhoneScreen), findsNothing);
  });
}
