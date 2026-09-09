import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/features/notifications/data/notification_models.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:beshkashtan_customer/features/notifications/domain/notifications_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsApi extends Mock implements NotificationsApi {}

/// Badge provider keepAlive — testda auth'siz ham 5 dan boshlanadi.
class _UnreadStub extends NotificationUnreadCountController {
  @override
  Future<int> build() async => 5;
}

CustomerNotification _item(String id, {bool isRead = false}) =>
    CustomerNotification(
      id: id,
      title: 'Xabar $id',
      body: '',
      type: 'order_update',
      eventKey: 'order_accepted',
      isRead: isRead,
      createdAt: null,
      data: const {},
    );

void main() {
  late _MockNotificationsApi api;
  late ProviderContainer container;

  setUp(() {
    api = _MockNotificationsApi();
    when(() => api.unreadCount()).thenAnswer((_) async => 5);
    container = ProviderContainer(
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        notificationsApiProvider.overrideWithValue(api),
        notificationUnreadCountProvider.overrideWith(_UnreadStub.new),
      ],
    );
    addTearDown(container.dispose);
  });

  test('markRead kutish paytida yuklangan sahifani yo\'qotmaydi', () async {
    when(() => api.fetch()).thenAnswer(
      (_) async => OffsetPage(
        items: [_item('n1'), _item('n2')],
        count: 3,
        nextUrl: 'page-2',
      ),
    );
    when(() => api.fetch(nextUrl: 'page-2')).thenAnswer(
      (_) async => OffsetPage(items: [_item('n3')], count: 3, nextUrl: null),
    );
    final saved = Completer<CustomerNotification>();
    when(() => api.markRead('n1', lang: 'uz')).thenAnswer((_) => saved.future);

    final sub = container.listen(notificationsControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(notificationsControllerProvider.future);
    final notifier = container.read(notificationsControllerProvider.notifier);

    final marking = notifier.markRead('n1');
    await notifier.loadMore();
    expect(
      container.read(notificationsControllerProvider).value!.items,
      hasLength(3),
    );

    saved.complete(_item('n1', isRead: true));
    await marking;

    final state = container.read(notificationsControllerProvider).value!;
    expect(state.items.map((item) => item.id), ['n1', 'n2', 'n3']);
    expect(state.items.first.isRead, isTrue);
    expect(state.nextUrl, isNull, reason: 'ikkinchi sahifa kursori saqlanadi');
  });

  test(
    'markRead xatosi: ekran yopilgan bo\'lsa ham badge qaytariladi',
    () async {
      when(() => api.fetch()).thenAnswer(
        (_) async => OffsetPage(items: [_item('n1')], count: 1, nextUrl: null),
      );
      final failing = Completer<CustomerNotification>();
      when(
        () => api.markRead('n1', lang: 'uz'),
      ).thenAnswer((_) => failing.future);
      final unreadSub = container.listen(
        notificationUnreadCountProvider,
        (_, _) {},
      );
      addTearDown(unreadSub.close);
      await container.read(notificationUnreadCountProvider.future);

      final sub = container.listen(notificationsControllerProvider, (_, _) {});
      await container.read(notificationsControllerProvider.future);
      final notifier = container.read(notificationsControllerProvider.notifier);

      final marking = notifier.markRead('n1');
      expect(container.read(notificationUnreadCountProvider).value, 4);

      // Foydalanuvchi orqaga bosdi — autoDispose provider yo'q bo'ldi.
      sub.close();
      await Future<void>.delayed(Duration.zero);

      failing.completeError(const ServerFailure('', 500));
      await expectLater(marking, throwsA(isA<ServerFailure>()));
      expect(
        container.read(notificationUnreadCountProvider).value,
        5,
        reason: 'kompensatsiya dispose\'dan keyin ham bajarilishi shart',
      );
    },
  );

  test(
    'refresh mavjud ro\'yxatni bo\'shatmaydi, xatoda eski ro\'yxat qoladi',
    () async {
      var calls = 0;
      when(() => api.fetch()).thenAnswer((_) async {
        if (++calls > 1) throw const NetworkFailure();
        return OffsetPage(items: [_item('n1')], count: 1, nextUrl: null);
      });
      final sub = container.listen(notificationsControllerProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(notificationsControllerProvider.future);

      var sawLoading = false;
      final watch = container.listen(notificationsControllerProvider, (
        _,
        next,
      ) {
        if (next.isLoading && next.value == null) sawLoading = true;
      });
      addTearDown(watch.close);
      await container.read(notificationsControllerProvider.notifier).refresh();

      expect(sawLoading, isFalse);
      expect(
        container.read(notificationsControllerProvider).value!.items,
        hasLength(1),
      );
    },
  );
}
