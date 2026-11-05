import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/storage/prefs_store.dart';
import '../data/notification_models.dart';
import '../data/notifications_api.dart';
import 'notifications_controller.dart';

const _ordersChannel = AndroidNotificationChannel(
  'orders',
  'Buyurtmalar',
  description: 'Buyurtma va kuryer holati bildirishnomalari',
  importance: Importance.high,
);

/// Muhim buyurtma hodisalari (`importance=high`) uchun alohida kanal. Backend
/// FCM `android.notification.channel_id` sifatida aynan shu ID'ni yuboradi.
/// Android kanal ovozi/vibratsiyasini yaratilgandan keyin o'zgartirib
/// bo'lmaydi — o'zgartirish kerak bo'lsa yangi `_v2` ID ochiladi.
const _importantOrdersChannelId = 'orders_important_v1';
const _importantOrdersChannelName = 'Muhim buyurtma holatlari';
const _importantOrdersChannelDescription =
    'Kuryer yo\'lda, buyurtma yetkazildi yoki bekor qilindi';
const _importantOrdersSound = RawResourceAndroidNotificationSound(
  'order_important',
);
final _importantOrdersVibration = Int64List.fromList([
  0,
  500,
  200,
  500,
  200,
  900,
]);

final _importantOrdersChannel = AndroidNotificationChannel(
  _importantOrdersChannelId,
  _importantOrdersChannelName,
  description: _importantOrdersChannelDescription,
  importance: Importance.max,
  sound: _importantOrdersSound,
  enableVibration: true,
  vibrationPattern: _importantOrdersVibration,
);

/// Registers the data-only FCM background callback.
///
/// Call once after `WidgetsFlutterBinding.ensureInitialized()` and before
/// `runApp`. It is safe when Firebase configuration is absent.
void registerCustomerPushBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(
    customerFirebaseMessagingBackgroundHandler,
  );
}

@pragma('vm:entry-point')
Future<void> customerFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (!await _ensureFirebaseInitialized()) return;
  // A notification payload is rendered by Android/iOS itself. Only data-only
  // lifecycle events need a local notification here.
  if (message.notification != null) return;
  final push = CustomerPushMessage.fromData(data: message.data);
  if (push.title.isEmpty && push.body.isEmpty) return;
  final local = CustomerLocalNotifications();
  await local.initialize();
  await local.show(push);
  await local.dispose();
}

final customerLocalNotificationsProvider = Provider<CustomerLocalNotifications>(
  (ref) {
    final service = CustomerLocalNotifications();
    ref.onDispose(service.dispose);
    return service;
  },
);

final customerPushServiceProvider = Provider<CustomerPushService>((ref) {
  final service = CustomerPushService(
    api: ref.watch(notificationsApiProvider),
    prefs: ref.watch(prefsStoreProvider),
    localNotifications: ref.watch(customerLocalNotificationsProvider),
    locale: () => ref.read(localeControllerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

class CustomerPushService {
  CustomerPushService({
    required this.api,
    required this.prefs,
    required this.localNotifications,
    required this.locale,
    Future<bool> Function()? firebaseInitializer,
    Future<void> Function()? firebaseTokenDeleter,
  }) : _firebaseInitializer = firebaseInitializer ?? _ensureFirebaseInitialized,
       _firebaseTokenDeleter =
           firebaseTokenDeleter ??
           (() => FirebaseMessaging.instance.deleteToken());

  final NotificationsApi api;
  final PrefsStore prefs;
  final CustomerLocalNotifications localNotifications;
  final AppLocale Function() locale;
  final Future<bool> Function() _firebaseInitializer;
  final Future<void> Function() _firebaseTokenDeleter;

  static const _deviceIdKey = 'push.customer.device_id';
  static const _backendDeviceIdKey = 'push.customer.backend_device_id';
  static const _lastTokenKey = 'push.customer.last_token';
  static const _pendingBackendDeviceIdKey =
      'push.customer.pending_backend_device_id';
  static const _pendingFirebaseDeleteKey =
      'push.customer.pending_firebase_delete';

  final _foregroundController =
      StreamController<CustomerPushMessage>.broadcast();
  final _navigationController =
      StreamController<CustomerPushMessage>.broadcast();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<String>? _localTapSubscription;
  bool _started = false;
  bool _enabled = false;
  bool _disposed = false;
  Future<void>? _unregistering;

  Stream<CustomerPushMessage> get foregroundMessages =>
      _foregroundController.stream;
  Stream<CustomerPushMessage> get navigationRequests =>
      _navigationController.stream;
  bool get isEnabled => _enabled;

  /// Starts FCM if real platform configuration exists. Missing config is a
  /// supported state: REST history and WebSocket reconciliation keep working.
  Future<bool> start() async {
    if (_disposed) return false;
    if (_started) return _enabled;
    _started = true;
    _enabled = await _firebaseInitializer();
    if (!_enabled) {
      // Missing config yoki vaqtinchalik native Firebase init xatosi keyingi
      // resume/start urinishini bloklab qo'ymasligi kerak.
      _started = false;
      return false;
    }

    try {
      await retryPendingUnregister(canUseBackend: true);
      await localNotifications.initialize();
      _localTapSubscription = localNotifications.taps.listen(_handleLocalTap);
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        // Buyurtma holati ovozli kelishi kerak — iOS "jim" provisional emas.
        provisional: false,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForeground,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpened,
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _registerToken(token),
      );
      await syncRegistration();
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleOpened(initial);
      return true;
    } on Object {
      // Never expose Firebase internals or tokens in logs. REST notifications
      // remain available when platform services are not configured.
      await stop();
      _enabled = false;
      debugPrint('Customer push is unavailable; REST fallback remains active.');
      return false;
    }
  }

  Future<void> syncRegistration() async {
    if (!_enabled || _disposed) return;
    try {
      final vapidKey = kIsWeb ? _CustomerFirebaseConfig.vapidKey : null;
      if (kIsWeb && (vapidKey == null || vapidKey.isEmpty)) return;
      // iOS: FCM token APNs tokenidan keyin paydo bo'ladi. Undan oldin
      // getToken() xato beradi — qisqa kutamiz, kelmasa keyingi resume'da.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        if (!await waitForApnsToken(FirebaseMessaging.instance.getAPNSToken)) {
          return;
        }
      }
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: vapidKey,
      );
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } on Object {
      debugPrint('Customer push registration will be retried later.');
    }
  }

  Future<void> _registerToken(String token) async {
    if (_disposed || token.isEmpty) return;
    // Backend commit bo'lib, response yo'qolsa ham logout ushbu FCM tokenni
    // bekor qila olishi uchun token API chaqiruvidan OLDIN saqlanadi.
    await prefs.setString(_lastTokenKey, token);
    final deviceId = await _stableDeviceId();
    var appVersion = '';
    try {
      final package = await PackageInfo.fromPlatform();
      appVersion = '${package.version}+${package.buildNumber}';
    } on Object {
      // App version is optional in the backend contract.
    }
    try {
      final device = await api.registerDevice(
        token: token,
        platform: _platformWire,
        deviceId: deviceId,
        appVersion: appVersion,
        locale: locale().code,
      );
      if (device.id.isNotEmpty) {
        await prefs.setString(_backendDeviceIdKey, device.id);
        final pendingIds = _pendingBackendIds()..remove(device.id);
        await _savePendingBackendIds(pendingIds);
      }
    } on Object {
      debugPrint('Customer push token sync failed; it will be retried.');
    }
  }

  @visibleForTesting
  Future<void> registerTokenForTest(String token) => _registerToken(token);

  Set<String> _pendingBackendIds() => {
    for (final id in (prefs.getString(_pendingBackendDeviceIdKey) ?? '').split(
      ',',
    ))
      if (id.trim().isNotEmpty) id.trim(),
  };

  Future<void> _savePendingBackendIds(Set<String> ids) async {
    if (ids.isEmpty) {
      await prefs.remove(_pendingBackendDeviceIdKey);
    } else {
      await prefs.setString(_pendingBackendDeviceIdKey, ids.join(','));
    }
  }

  Future<Set<String>> _deleteBackendIds(Iterable<String> ids) async {
    final failed = <String>{};
    for (final id in ids.toSet()) {
      if (id.isEmpty) continue;
      try {
        await api.deleteDevice(id);
      } on Object {
        failed.add(id);
      }
    }
    return failed;
  }

  /// Deactivates the backend device before auth tokens are cleared and asks
  /// Firebase to invalidate the local token.
  Future<void> unregister() {
    final active = _unregistering;
    if (active != null) return active;
    final operation = _performUnregister();
    _unregistering = operation;
    return operation.whenComplete(() {
      if (identical(_unregistering, operation)) _unregistering = null;
    });
  }

  Future<void> _performUnregister() async {
    final backendId = prefs.getString(_backendDeviceIdKey);
    final pendingBackendIds = _pendingBackendIds();
    final rememberedToken = prefs.getString(_lastTokenKey);
    if ((backendId == null || backendId.isEmpty) &&
        pendingBackendIds.isEmpty &&
        (rememberedToken == null || rememberedToken.isEmpty) &&
        prefs.getString(_pendingFirebaseDeleteKey) != '1' &&
        !_started) {
      await stop();
      _enabled = false;
      return;
    }
    final backendTargets = {
      ...pendingBackendIds,
      if (backendId != null && backendId.isNotEmpty) backendId,
    };
    final failedBackendIds = await _deleteBackendIds(backendTargets);
    // Logout offline bo'lsa revocation yo'qolib ketmasin. Keyingi
    // authenticated startup/resume bu tombstonelarni qayta yuboradi.
    await _savePendingBackendIds(failedBackendIds);
    await prefs.remove(_backendDeviceIdKey);

    final firebaseDeletionRequired =
        _enabled ||
        (rememberedToken != null && rememberedToken.isNotEmpty) ||
        prefs.getString(_pendingFirebaseDeleteKey) == '1';
    var firebaseDeleted = !firebaseDeletionRequired;
    final firebaseReady =
        firebaseDeletionRequired && (_enabled || await _firebaseInitializer());
    if (firebaseDeletionRequired && firebaseReady) {
      try {
        await _firebaseTokenDeleter();
        firebaseDeleted = true;
      } on Object {
        // Tombstone saqlanadi; keyingi unauth resume ham qayta urinadi.
      }
    }
    if (firebaseDeleted) {
      await prefs.remove(_lastTokenKey);
      await prefs.remove(_pendingFirebaseDeleteKey);
    } else if (firebaseDeletionRequired) {
      // Hatto backend device ID pref yo'q bo'lsa ham enabled Firebase delete
      // xatosi revocationni unutishga sabab bo'lmasin.
      await prefs.setString(_pendingFirebaseDeleteKey, '1');
    }
    await stop();
    _enabled = false;
  }

  /// Offline logout/session expiryda saqlangan revocation tombstonelarini
  /// keyingi startup yoki resume'da qayta bajaradi.
  Future<void> retryPendingUnregister({required bool canUseBackend}) async {
    if (_disposed) return;
    final pendingBackendIds = _pendingBackendIds();
    if (canUseBackend && pendingBackendIds.isNotEmpty) {
      final failed = await _deleteBackendIds(pendingBackendIds);
      await _savePendingBackendIds(failed);
    }

    if (prefs.getString(_pendingFirebaseDeleteKey) != '1') return;
    final firebaseReady = _enabled || await _firebaseInitializer();
    if (!firebaseReady) return;
    try {
      await _firebaseTokenDeleter();
      await prefs.remove(_lastTokenKey);
      await prefs.remove(_pendingFirebaseDeleteKey);
    } on Object {
      // Keyingi resume yana urinadi.
    }
  }

  Future<void> stop() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _localTapSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _tokenSubscription = null;
    _localTapSubscription = null;
    _started = false;
  }

  void _handleForeground(RemoteMessage message) {
    final push = CustomerPushMessage.fromData(
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
    // Ilova ochiq bo'lsa Android FCM notification'ni o'zi ko'rsatmaydi. Muhim
    // holatlarda foydalanuvchi baribir heads-up + maxsus ovozni eshitishi
    // kerak; oddiy pushlar avvalgidek faqat ilova ichida (SnackBar) chiqadi.
    if (push.isImportant && (push.title.isNotEmpty || push.body.isNotEmpty)) {
      unawaited(localNotifications.show(push));
    }
    _foregroundController.add(push);
  }

  void _handleOpened(RemoteMessage message) {
    _navigationController.add(
      CustomerPushMessage.fromData(
        data: message.data,
        title: message.notification?.title,
        body: message.notification?.body,
      ),
    );
  }

  void _handleLocalTap(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _navigationController.add(CustomerPushMessage.fromData(data: decoded));
      }
    } on FormatException {
      // Ignore malformed payload instead of navigating to a guessed route.
    }
  }

  Future<String> _stableDeviceId() async {
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = [
      'customer',
      DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      random.nextInt(0x7fffffff).toRadixString(36),
      random.nextInt(0x7fffffff).toRadixString(36),
    ].join('-');
    await prefs.setString(_deviceIdKey, value);
    return value;
  }

  String get _platformWire {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
      _ => 'android',
    };
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _foregroundController.close();
    await _navigationController.close();
  }
}

class CustomerLocalNotifications {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tapController =
      StreamController<String>.broadcast();
  bool _initialized = false;
  bool _disposed = false;

  Stream<String> get taps => _tapController.stream;

  Future<void> initialize() async {
    if (_initialized || _disposed || !_supportsLocalNotifications) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ruxsatni bu yerda emas, FirebaseMessaging.requestPermission so'raydi
        // (bitta dialog, to'g'ri paytda).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty && !_disposed) {
            _tapController.add(payload);
          }
        },
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_ordersChannel);
      await android?.createNotificationChannel(_importantOrdersChannel);
      _initialized = true;
    } on Object {
      debugPrint('Local notifications are unavailable on this platform.');
    }
  }

  Future<void> show(CustomerPushMessage message) async {
    if (!_initialized || _disposed || !_supportsLocalNotifications) return;
    // iOS uchun maxsus ovoz bundle'ga (.caf) qo'shilmagan — default ovoz.
    final details = message.isImportant
        ? NotificationDetails(
            android: AndroidNotificationDetails(
              _importantOrdersChannelId,
              _importantOrdersChannelName,
              channelDescription: _importantOrdersChannelDescription,
              importance: Importance.max,
              priority: Priority.max,
              // Android 8.0 dan oldingi qurilmalarda kanal yo'q — ovoz va
              // vibratsiya bevosita notification'ga beriladi.
              sound: _importantOrdersSound,
              enableVibration: true,
              vibrationPattern: _importantOrdersVibration,
            ),
            iOS: const DarwinNotificationDetails(),
          )
        : const NotificationDetails(
            android: AndroidNotificationDetails(
              'orders',
              'Buyurtmalar',
              channelDescription: 'Buyurtma va kuryer holati bildirishnomalari',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          );
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: message.title,
      body: message.body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  bool get _supportsLocalNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _tapController.close();
  }
}

Future<bool> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return true;
  try {
    if (kIsWeb) {
      final options = _CustomerFirebaseConfig.webOptions;
      if (options == null) return false;
      await Firebase.initializeApp(options: options);
    } else {
      await Firebase.initializeApp();
    }
    return true;
  } on Object {
    debugPrint('Firebase config is absent; push is safely disabled.');
    return false;
  }
}

abstract final class _CustomerFirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const vapidKeyValue = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static String? get vapidKey => vapidKeyValue.isEmpty ? null : vapidKeyValue;

  static FirebaseOptions? get webOptions {
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
    );
  }
}

/// iOS APNs tokenini [attempts] marta × [delay] kutadi. Token kelsa `true`.
@visibleForTesting
Future<bool> waitForApnsToken(
  Future<String?> Function() read, {
  int attempts = 10,
  Duration delay = const Duration(milliseconds: 500),
}) async {
  for (var i = 0; i < attempts; i++) {
    try {
      final token = await read();
      if (token != null && token.isNotEmpty) return true;
    } on Object {
      // Plagin hali tayyor emas — keyingi urinish.
    }
    if (i < attempts - 1) await Future<void>.delayed(delay);
  }
  return false;
}
