import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/diagnostics/crash_reporting.dart';
import 'core/localization/locale_controller.dart';
import 'core/network/connectivity_controller.dart';
import 'core/network/network_providers.dart';
import 'core/platform/android_sms_autofill_service.dart';
import 'core/platform/sms_autofill_service.dart';
import 'core/storage/prefs_store.dart';
import 'features/auth/domain/auth_controller.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/cart/domain/cart_controller.dart';
import 'features/cart/domain/offline_cart_queue.dart';
import 'features/notifications/domain/customer_push_service.dart';
import 'features/orders/domain/order_realtime_controller.dart';
import 'features/recommendations/domain/interaction_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerCustomerPushBackgroundHandler();
  // Firebase/Crashlytics init birinchi kadrni ushlab turmasin: handlerlar
  // bir necha yuz ms keyin o'rnatiladi, bu davrdagi crash yo'qolishi mumkin —
  // bu sekin qurilmada oq ekranda kutishdan arzon.
  unawaited(CrashReporting.initialize());

  // Faqat portret — iOS Info.plist da ham shunday cheklangan.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Til va mavzu `runApp` dan OLDIN yuklanadi, shunda birinchi kadr allaqachon
  // to'g'ri chiziladi va oq ekran chaqnashi bo'lmaydi.
  final prefs = await PrefsStore.load();

  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      // Refresh ham o'lganda sessiyani auth holat mashinasi yopadi.
      // To'g'ridan-to'g'ri import network_providers ichida qilinmaydi —
      // aylanma bog'liqlik (auth → apiClient → onSessionExpired → auth)
      // faqat chaqiruv PAYTIDA o'qish bilan uziladi.
      onSessionExpiredProvider.overrideWith(
        (ref) =>
            () => ref.read(authControllerProvider.notifier).expireSession(),
      ),
      onBeforeLogoutProvider.overrideWith(
        (ref) =>
            () => ref.read(customerPushServiceProvider).unregister(),
      ),
      onAfterLoginProvider.overrideWith(
        (ref) =>
            () => ref.read(guestCartCoordinatorProvider).mergeIfNeeded(),
      ),
      // SMS kodini avtomatik to'ldirish faqat Android'da (iOS'da buni
      // `AutofillHints.oneTimeCode` o'zi qiladi). Provider LAZY — servis
      // birinchi marta OTP ekrani o'qiganda quriladi, boot'ga ta'sir qilmaydi.
      smsAutofillServiceProvider.overrideWith((ref) {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
          return const NoopSmsAutofillService();
        }
        final service = AndroidSmsAutofillService();
        ref.onDispose(service.dispose);
        return service;
      }),
    ],
  );
  // Ulanish holati birinchi kadrdan oldin boshlanadi — offline bo'lsa
  // so'rovlar bekorga yuborilmaydi.
  final connectivity = container.read(connectivityControllerProvider.notifier);
  unawaited(connectivity.start());
  // Internet qaytganda oflayn savat navbati serverga yuboriladi.
  connectivity.addReconnectListener(
    () => unawaited(container.read(offlineCartQueueProvider).flush()),
  );

  _AuthenticatedRuntimeServices(container).start();

  // Sessiya tiklash — kutmasdan boshlanadi: router `checkingSession` bo'lsa
  // splash ko'rsatadi, natija kelgach redirect o'zi yo'naltiradi.
  // (`Notifier.build` ichida side-effect qilish eski appning xatosi edi.)
  unawaited(container.read(authControllerProvider.notifier).restoreSession());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BeshKashtanApp(),
    ),
  );
}

/// UI route'idan tashqarida yashaydigan realtime subscription.
///
/// `main()`da yaratilgani sabab oddiy widget testlarda network/timer ochmaydi;
/// productionda esa Home, modal yoki store almashtirishdan qat'i nazar faol.
class _AuthenticatedRuntimeServices {
  _AuthenticatedRuntimeServices(this.container);

  final ProviderContainer container;
  ProviderSubscription<AuthState>? _auth;
  ProviderSubscription<OrderRealtimeState>? _orders;
  AppLifecycleListener? _lifecycle;

  void start() {
    if (_auth != null) return;
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) {
        container
            .read(connectivityControllerProvider.notifier)
            .setForeground(state == AppLifecycleState.resumed);
        // Fonda order socket heartbeat/watchdog/REST fallback batareya yeydi —
        // to'xtatamiz; `onResume` (pastda) qayta tiklaydi.
        final background =
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden;
        if (background && _orders != null) {
          container.read(orderRealtimeProvider.notifier).pause();
        }
        // Yig'ilgan ko'rish/qidiruv hodisalari ilova yopilguncha ketsin.
        if (background) {
          unawaited(container.read(interactionTrackerProvider).flush());
        }
      },
      onResume: () {
        unawaited(container.read(offlineCartQueueProvider).flush());
        if (_orders != null) {
          container.read(orderRealtimeProvider.notifier).resume();
        }
      },
    );
    _auth = container.listen<AuthState>(
      authControllerProvider,
      (_, next) => _sync(next),
      fireImmediately: true,
    );
  }

  void _sync(AuthState auth) {
    if (auth.isAuthenticated) {
      // Resume ONLY the signed-in account's persisted work, not the last
      // account's queue. This also works without an offline→online transition.
      unawaited(container.read(offlineCartQueueProvider).flush());
      _orders ??= container.listen<OrderRealtimeState>(
        orderRealtimeProvider,
        (_, _) {},
        fireImmediately: true,
      );
    } else {
      _orders?.close();
      _orders = null;
    }
  }
}
