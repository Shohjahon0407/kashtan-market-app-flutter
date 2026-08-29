import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:beshkashtan_customer/features/notifications/domain/customer_push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNotificationsApi extends Mock implements NotificationsApi {}

void main() {
  test('muvaffaqiyatsiz Firebase init keyingi startni bloklamaydi', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    var initializationAttempts = 0;
    final service = CustomerPushService(
      api: _MockNotificationsApi(),
      prefs: prefs,
      localNotifications: CustomerLocalNotifications(),
      locale: () => AppLocale.uz,
      firebaseInitializer: () async {
        initializationAttempts++;
        return false;
      },
    );
    addTearDown(service.dispose);

    expect(await service.start(), isFalse);
    expect(await service.start(), isFalse);
    expect(initializationAttempts, 2, reason: '_started falsega qaytmadi');
  });

  test(
    'offline logout revocation tombstonelarini saqlab qayta urinadi',
    () async {
      SharedPreferences.setMockInitialValues({
        'push.customer.backend_device_id': 'backend-device-1',
        'push.customer.last_token': 'fcm-token',
      });
      final prefs = await PrefsStore.load();
      final api = _MockNotificationsApi();
      when(
        () => api.deleteDevice('backend-device-1'),
      ).thenThrow(const NetworkFailure());
      final service = CustomerPushService(
        api: api,
        prefs: prefs,
        localNotifications: CustomerLocalNotifications(),
        locale: () => AppLocale.uz,
        firebaseInitializer: () async => false,
      );
      addTearDown(service.dispose);

      await service.unregister();

      expect(prefs.getString('push.customer.backend_device_id'), isNull);
      expect(
        prefs.getString('push.customer.pending_backend_device_id'),
        'backend-device-1',
      );
      expect(prefs.getString('push.customer.pending_firebase_delete'), '1');
      expect(prefs.getString('push.customer.last_token'), 'fcm-token');

      when(() => api.deleteDevice('backend-device-1')).thenAnswer((_) async {});
      await service.retryPendingUnregister(canUseBackend: true);

      expect(
        prefs.getString('push.customer.pending_backend_device_id'),
        isNull,
      );
      expect(
        prefs.getString('push.customer.pending_firebase_delete'),
        '1',
        reason: 'Firebase hali offline, tombstone yo‘qolmasligi kerak',
      );
    },
  );

  test(
    'register response yo‘qolsa token oldindan saqlanib revoke tombstone qoladi',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final api = _MockNotificationsApi();
      when(
        () => api.registerDevice(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          deviceId: any(named: 'deviceId'),
          appVersion: any(named: 'appVersion'),
          locale: any(named: 'locale'),
        ),
      ).thenThrow(const NetworkFailure('commitdan keyin response yo‘qoldi'));
      var deleteAttempts = 0;
      final service = CustomerPushService(
        api: api,
        prefs: prefs,
        localNotifications: CustomerLocalNotifications(),
        locale: () => AppLocale.uz,
        firebaseInitializer: () async => true,
        firebaseTokenDeleter: () async {
          deleteAttempts++;
          throw const NetworkFailure('logout offline');
        },
      );
      addTearDown(service.dispose);

      await service.registerTokenForTest('fcm-commit-token');
      expect(
        prefs.getString('push.customer.last_token'),
        'fcm-commit-token',
        reason: 'registerDevice xatosi tokenni unutmasligi kerak',
      );

      await service.unregister();

      expect(deleteAttempts, 1);
      expect(prefs.getString('push.customer.pending_firebase_delete'), '1');
      expect(prefs.getString('push.customer.last_token'), 'fcm-commit-token');
    },
  );
}
