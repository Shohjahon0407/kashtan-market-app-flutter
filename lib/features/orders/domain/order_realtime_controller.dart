import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/store_scope/store_type.dart';
import '../../notifications/domain/notifications_controller.dart';
import 'order_socket_connector_io.dart'
    if (dart.library.js_interop) 'order_socket_connector_web.dart'
    as socket_transport;
import 'orders_controller.dart';

typedef OrderSocketConnector =
    WebSocketChannel Function(Uri uri, Map<String, dynamic> headers);

final orderSocketConnectorProvider = Provider<OrderSocketConnector>(
  (ref) => socket_transport.connectOrderSocket,
);

enum OrderSocketStatus { connecting, connected, reconnecting, disconnected }

class OrderRealtimeState {
  const OrderRealtimeState({
    this.status = OrderSocketStatus.connecting,
    this.revision = 0,
    this.lastOrderId,
    this.lastEventType,
    this.lastMessageAt,
  });

  final OrderSocketStatus status;
  final int revision;
  final String? lastOrderId;
  final String? lastEventType;
  final DateTime? lastMessageAt;
}

final orderRealtimeProvider =
    NotifierProvider.autoDispose<OrderRealtimeController, OrderRealtimeState>(
      OrderRealtimeController.new,
    );

class OrderRealtimeController extends Notifier<OrderRealtimeState> {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _reconnect;
  Timer? _restFallback;
  var _attempt = 0;
  var _disposed = false;
  var _connecting = false;
  var _paused = false;
  var _connectionGeneration = 0;
  DateTime? _lastServerMessageAt;
  final _random = Random();

  /// Testlar uchun: `pause()` dan keyin hech qanday timer qolmaganini va
  /// `resume()` ularni qayta tiklaganini tekshirish.
  @visibleForTesting
  bool get hasScheduledWork =>
      (_heartbeat?.isActive ?? false) ||
      (_watchdog?.isActive ?? false) ||
      (_restFallback?.isActive ?? false) ||
      (_reconnect?.isActive ?? false);

  @visibleForTesting
  bool get isPaused => _paused;

  @override
  OrderRealtimeState build() {
    listenForConnectionRecovery(ref, _onConnectionRecovered);
    ref.onDispose(_dispose);
    scheduleMicrotask(_connect);
    _startRestFallback();
    return const OrderRealtimeState();
  }

  /// Socket uzilib turganda ham ro'yxatlar 30 soniyada bir REST orqali
  /// yangilanadi. Fonda (`pause`) to'xtaydi, `resume` qayta yoqadi.
  void _startRestFallback() {
    _restFallback ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reconcileRestState(),
    );
  }

  Future<void> _connect() async {
    if (_disposed || _paused || _connecting || _channel != null) return;
    if (_isOffline()) {
      // Oflaynda socket ochishga urinish besamar — keyingi rejalashtirilgan
      // urinishda (yoki online qaytganda) qayta ko'riladi.
      _scheduleReconnect();
      return;
    }
    _connecting = true;
    final generation = ++_connectionGeneration;
    _reconnect?.cancel();
    _reconnect = null;
    state = OrderRealtimeState(
      status: _attempt == 0
          ? OrderSocketStatus.connecting
          : OrderSocketStatus.reconnecting,
      revision: state.revision,
      lastOrderId: state.lastOrderId,
      lastEventType: state.lastEventType,
      lastMessageAt: state.lastMessageAt,
    );
    String? token;
    try {
      token = await _socketAccessToken();
    } on Object {
      // Refresh server/offline xatosi auth expiry emas. Mavjud sessiyani
      // saqlab, backoff bilan qayta ulanamiz.
      _scheduleReconnect();
      if (generation == _connectionGeneration) _connecting = false;
      return;
    }
    if (_disposed || generation != _connectionGeneration) return;
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      _connecting = false;
      return;
    }
    try {
      final channel = ref.read(orderSocketConnectorProvider)(
        AppConfig.orderSocketUri,
        {'Authorization': 'Bearer $token'},
      );
      if (_disposed || generation != _connectionGeneration) {
        await channel.sink.close();
        return;
      }
      _lastServerMessageAt = DateTime.now();
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnected(),
        onDone: _onDisconnected,
        cancelOnError: true,
      );
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _channel?.sink.add(jsonEncode({'type': 'ping'})),
      );
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 10), (_) {
        final last = _lastServerMessageAt;
        if (last != null && DateTime.now().difference(last).inSeconds > 55) {
          _forceReconnect();
        }
      });
    } on Object {
      _onDisconnected();
    } finally {
      if (generation == _connectionGeneration) _connecting = false;
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    Map<String, dynamic>? event;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map<String, dynamic>) event = decoded;
    } on FormatException {
      return;
    }
    if (event == null) return;
    final type = event['type']?.toString();
    _lastServerMessageAt = DateTime.now();
    if (type == 'connection.ready') {
      _attempt = 0;
      state = OrderRealtimeState(
        status: OrderSocketStatus.connected,
        revision: state.revision,
        lastOrderId: state.lastOrderId,
        lastEventType: type,
        lastMessageAt: _lastServerMessageAt,
      );
      // WebSocket faqat tezkor signal. Har yangi/recovered connectionda REST
      // source of truth bilan darhol reconcile qilamiz; shu bilan socket uzilib
      // turganda o'tkazib yuborilgan accept/location/notification tiklanadi.
      _reconcileRestState();
      return;
    }
    if (type == 'pong') {
      state = OrderRealtimeState(
        status: OrderSocketStatus.connected,
        revision: state.revision,
        lastOrderId: state.lastOrderId,
        lastEventType: type,
        lastMessageAt: _lastServerMessageAt,
      );
      return;
    }
    final orderId = event['order_id']?.toString();
    state = OrderRealtimeState(
      status: OrderSocketStatus.connected,
      revision: state.revision + 1,
      lastOrderId: orderId,
      lastEventType: type,
      lastMessageAt: _lastServerMessageAt,
    );
    if (orderId != null && orderId.isNotEmpty) {
      ref.invalidate(orderDetailProvider(orderId));
    }
    if (type != 'user.order_courier_location' &&
        type != 'order_courier_viewed') {
      refreshCustomerNotifications(ref);
    }
    _refreshLists();
  }

  void _onDisconnected() {
    if (_disposed) return;
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    state = OrderRealtimeState(
      status: OrderSocketStatus.disconnected,
      revision: state.revision,
      lastOrderId: state.lastOrderId,
      lastEventType: state.lastEventType,
      lastMessageAt: state.lastMessageAt,
    );
    _refreshLists();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _paused || _reconnect?.isActive == true) return;
    _attempt++;
    final seconds = switch (_attempt) {
      <= 1 => 1,
      2 => 2,
      3 => 4,
      4 => 8,
      _ => 30,
    };
    final jitter = _attempt <= 1
        ? Duration.zero
        : Duration(milliseconds: _random.nextInt(500));
    _reconnect = Timer(Duration(seconds: seconds) + jitter, _connect);
  }

  /// Ilova foregroundga qaytganda socketni tekshiradi va REST source of
  /// truth bilan darhol reconcile qiladi. `pause()` dan keyin REST fallback,
  /// socket va heartbeat/watchdog'ni qayta tiklaydi. Idempotent.
  void resume() {
    if (_disposed) return;
    _paused = false;
    _startRestFallback();
    _reconcileRestState();
    if (_channel == null) {
      _reconnect?.cancel();
      _reconnect = null;
      scheduleMicrotask(_connect);
    } else {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    }
  }

  /// Ilova fonga tushganda (paused/hidden): heartbeat, watchdog va REST
  /// fallback to'xtaydi, socket yopiladi, qayta ulanish rejalashtirilMAYDI —
  /// fonda batareya/radio behuda ketmasin. `resume()` teskarisi. Idempotent.
  void pause() {
    if (_disposed || _paused) return;
    _paused = true;
    // Token kutayotgan uchayotgan _connect natijasi e'tiborsiz qoladi.
    _connectionGeneration++;
    _connecting = false;
    _reconnect?.cancel();
    _reconnect = null;
    _restFallback?.cancel();
    _restFallback = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    // Avval subscription bekor qilinadi — sink.close() onDone orqali
    // _onDisconnected/_scheduleReconnect'ni uyg'otmasin.
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    channel?.sink.close();
    state = OrderRealtimeState(
      status: OrderSocketStatus.disconnected,
      revision: state.revision,
      lastOrderId: state.lastOrderId,
      lastEventType: state.lastEventType,
      lastMessageAt: state.lastMessageAt,
    );
  }

  /// Internet qaytdi. Fonda bo'lsak hech narsa qilmaymiz — foregroundga
  /// qaytganda `resume()` o'zi tiklaydi.
  void _onConnectionRecovered() {
    if (_paused) return;
    resume();
  }

  void _forceReconnect() {
    if (_disposed) return;
    _channel?.sink.close();
    _onDisconnected();
  }

  void _refreshLists() {
    if (_disposed) return;
    for (final storeType in StoreType.values) {
      for (final query in orderQueriesForStore(storeType)) {
        ref.invalidate(ordersControllerProvider(query));
      }
    }
  }

  bool _isOffline() {
    try {
      return ref.read(isOfflineProvider);
    } on Object {
      return false; // holat o'qilmasa — online deb davom etamiz
    }
  }

  void _reconcileRestState() {
    if (_disposed) return;
    // OFLAYN: har 30 soniyada barcha buyurtma so'rovlarini otish — batareya va
    // radioni behuda yeyish. Internet qaytganda ConnectivityController'ning
    // reconnect oqimi baribir yangilanish beradi.
    if (_isOffline()) return;
    _refreshLists();
    ref.invalidate(orderDetailProvider);
    ref.invalidate(orderTrackingControllerProvider);
    refreshCustomerNotifications(ref);
  }

  Future<String?> _socketAccessToken() async {
    final store = ref.read(tokenStoreProvider);
    var access = await store.readAccess();
    if (_attempt == 0) return access;

    // A socket 401 cannot pass through Dio's AuthInterceptor. On reconnect we
    // therefore refresh access explicitly, but keep the old token on a mere
    // offline/transport failure; the normal REST reconciliation decides
    // whether the session is actually expired.
    final refreshToken = await store.readRefresh();
    if (refreshToken == null || refreshToken.isEmpty) return access;
    final refreshed = await ref
        .read(tokenRefreshClientProvider)
        .refresh(refreshToken);
    if (refreshed == null || refreshed.isEmpty) {
      await ref.read(onSessionExpiredProvider)();
      return null;
    }
    await store.saveAccess(refreshed);
    access = refreshed;
    return access;
  }

  void _dispose() {
    _disposed = true;
    _connectionGeneration++;
    _connecting = false;
    _heartbeat?.cancel();
    _watchdog?.cancel();
    _reconnect?.cancel();
    _restFallback?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
