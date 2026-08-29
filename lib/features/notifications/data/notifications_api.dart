import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'notification_models.dart';

class NotificationsApi {
  const NotificationsApi(this._client, {this.cache, this.cacheKeySuffix});

  final ApiClient _client;

  /// Oxirgi bildirishnomalar — oflaynda ham ochiladi.
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  Future<OffsetPage<CustomerNotification>> fetch({String? nextUrl}) async {
    final data = nextUrl == null
        ? await _client.get(Api.notifications, query: {'page_size': 20})
        : await _client.getUrl(nextUrl);
    if (nextUrl == null && data is Map<String, dynamic>) {
      try {
        final suffix = cacheKeySuffix?.call();
        if (cache != null && suffix != null) {
          unawaited(cache!.writeJson(notificationsCacheKey(suffix), data));
        }
      } on Object {
        // Kesh majburiy emas.
      }
    }
    return PageDecoder.offset(data, CustomerNotification.fromJson);
  }

  Future<OffsetPage<CustomerNotification>?> cachedNotifications() async {
    try {
      final suffix = cacheKeySuffix?.call();
      if (cache == null || suffix == null) return null;
      final raw = await cache!.read(notificationsCacheKey(suffix));
      if (raw == null) return null;
      return PageDecoder.offset(raw, CustomerNotification.fromJson);
    } on Object {
      return null;
    }
  }

  Future<int> unreadCount() async {
    final data = await _client.get(Api.notificationsUnreadCount);
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure('unread-count javobi obyekt emas');
    }
    return JsonRead.integer(map['unread_count'] ?? map['count']);
  }

  Future<CustomerNotification> markRead(
    String id, {
    required String lang,
  }) async {
    final data = await _client.post(
      Api.notificationRead(id),
      query: {'lang': lang},
    );
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure('notification read javobi obyekt emas');
    }
    return CustomerNotification.fromJson(map);
  }

  Future<int> markAllRead() async {
    final data = await _client.post(Api.notificationsReadAll);
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure('notification read-all javobi obyekt emas');
    }
    return JsonRead.integer(map['updated_count']);
  }

  Future<NotificationDevice> registerDevice({
    required String token,
    required String platform,
    required String deviceId,
    required String appVersion,
    required String locale,
  }) async {
    final data = await _client.post(
      Api.notificationDevices,
      body: {
        'token': token,
        'platform': platform,
        'device_id': deviceId,
        'app_version': appVersion,
        'locale': locale,
      },
    );
    final map = JsonRead.map(data);
    if (map == null) {
      throw const UnknownFailure('notification device javobi obyekt emas');
    }
    return NotificationDevice.fromJson(map);
  }

  Future<void> deleteDevice(String id) =>
      _client.delete(Api.notificationDevice(id));
}
