import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_locale.dart';
import 'core/localization/locale_controller.dart';
import 'core/routing/app_router.dart';
import 'core/routing/back_navigation.dart';
import 'core/ui/offline/offline_banner.dart';
import 'core/ui/theme/app_theme.dart';
import 'features/app_update/presentation/app_update_bootstrap.dart';
import 'features/auth/domain/auth_controller.dart';
import 'features/notifications/presentation/customer_notification_bootstrap.dart';
import 'generated/l10n/app_localizations.dart';

/// Ilova ildizi.
class BeshKashtanApp extends ConsumerWidget {
  const BeshKashtanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(appRouterProvider);
    final isAppReady = ref.watch(
      authControllerProvider.select((state) => !state.isCheckingSession),
    );
    return MaterialApp.router(
      title: 'Besh Kashtan',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light(),
      themeMode: ThemeMode.light,

      builder: (context, child) => AppUpdateBootstrap(
        isAppReady: isAppReady,
        child: CustomerNotificationBootstrap(
          // Offline belgisi Navigator USTIDA — barcha ekranlarni qamraydi.
          child: OfflineBanner(child: child ?? const SizedBox.shrink()),
        ),
      ),

      locale: locale.locale,
      supportedLocales: AppLocale.supportedLocales,
      // Tur argumentlari ATAYLAB oshkora: `const [...]` ro'yxatining kontekst
      // turi `LocalizationsDelegate<dynamic>` bo'lgani uchun ularsiz Dart
      // `dynamic` ni chiqaradi (`ScriptFallbackDelegate.type` izohiga qarang).
      localizationsDelegates: const [
        AppLocalizations.delegate,
        // Material/Cupertino da `uz_Cyrl` yo'q — `uz` ga tushiriladi.
        ScriptFallbackDelegate<MaterialLocalizations>(
          GlobalMaterialLocalizations.delegate,
          Locale('uz'),
        ),
        ScriptFallbackDelegate<CupertinoLocalizations>(
          GlobalCupertinoLocalizations.delegate,
          Locale('uz'),
        ),
        ScriptFallbackDelegate<WidgetsLocalizations>(
          GlobalWidgetsLocalizations.delegate,
          Locale('uz'),
        ),
      ],

      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: AppBackButtonDispatcher(
        AppBackCoordinator.of(router),
      ),
    );
  }
}
