import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/features/notifications/data/notification_models.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:beshkashtan_customer/features/notifications/domain/notifications_controller.dart';
import 'package:beshkashtan_customer/features/notifications/presentation/notifications_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsApi extends Mock implements NotificationsApi {}

const _notification = CustomerNotification(
  id: 'notification-1',
  title: 'Kuryer buyurtmani qabul qildi',
  body: '20 daqiqada yetib boradi',
  type: 'order_update',
  eventKey: 'order_accepted',
  isRead: false,
  createdAt: null,
  data: {},
);

void main() {
  testWidgets('notification list unread holatni ko‘rsatadi va tapda o‘qiydi', (
    tester,
  ) async {
    final api = _MockNotificationsApi();
    when(() => api.fetch()).thenAnswer(
      (_) async =>
          const OffsetPage(items: [_notification], count: 1, nextUrl: null),
    );
    when(() => api.unreadCount()).thenAnswer((_) async => 1);
    when(
      () => api.markRead('notification-1', lang: 'uz'),
    ).thenAnswer((_) async => _notification.copyWith(isRead: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          notificationsApiProvider.overrideWithValue(api),
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
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bildirishnomalar'), findsOneWidget);
    expect(find.text('Kuryer buyurtmani qabul qildi'), findsOneWidget);
    expect(find.text('20 daqiqada yetib boradi'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await tester.tap(find.text('Kuryer buyurtmani qabul qildi'));
    await tester.pumpAndSettle();

    verify(() => api.markRead('notification-1', lang: 'uz')).called(1);
  });

  testWidgets('empty state lokalizatsiya bilan chiqadi', (tester) async {
    final api = _MockNotificationsApi();
    when(() => api.fetch()).thenAnswer(
      (_) async => const OffsetPage(items: [], count: 0, nextUrl: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiLangProvider.overrideWithValue('uz'),
          notificationsApiProvider.overrideWithValue(api),
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
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Hozircha bildirishnoma yo'q"), findsOneWidget);
  });
}
