import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/locale_controller.dart';

/// Ma'lumot qancha vaqtdan keyin "eski" hisoblanadi (egasining qarori: 1 kun).
const staleDataThreshold = Duration(days: 1);

/// Ilovaning ulanish holati.
///
/// FAQAT platforma signaliga tayanmaydi: "Wi-Fi bor, lekin internet yo'q"
/// juda keng tarqalgan (mehmonxona portali, tugagan trafik). Shuning uchun
/// holat ikki manbadan yig'iladi:
///   1. `connectivity_plus` — interfeys bor/yo'q (tez, lekin ishonchsiz);
///   2. haqiqiy so'rov natijalari — `NetworkFailure` kelsa offline, muvaffaqiyat
///      kelsa online.
class ConnectivityState {
  const ConnectivityState({this.isOffline = false, this.lastSyncAt});

  final bool isOffline;

  /// Oxirgi muvaffaqiyatli server javobi vaqti.
  final DateTime? lastSyncAt;

  /// Offline va ma'lumot 1 kundan eski — UI "eski ma'lumotlar" deb belgilaydi.
  bool get isStale {
    if (!isOffline) return false;
    final synced = lastSyncAt;
    if (synced == null) return true;
    return DateTime.now().difference(synced) > staleDataThreshold;
  }

  ConnectivityState copyWith({bool? isOffline, DateTime? lastSyncAt}) =>
      ConnectivityState(
        isOffline: isOffline ?? this.isOffline,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}

final connectivityControllerProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
    );

/// Qulaylik uchun: faqat offline bayrog'ini kuzatish.
final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(
    connectivityControllerProvider.select((state) => state.isOffline),
  ),
);

class ConnectivityController extends Notifier<ConnectivityState> {
  static const _kLastSync = 'net.last_sync_at';

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _reconnectListeners = <void Function()>[];

  @override
  ConnectivityState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _reconnectListeners.clear();
    });
    // Prefs mavjud bo'lmasa (ba'zi testlar) ham ilova yiqilmasligi kerak.
    DateTime? lastSync;
    try {
      final raw = ref.read(prefsStoreProvider).getString(_kLastSync);
      lastSync = raw == null ? null : DateTime.tryParse(raw);
    } on Object {
      lastSync = null;
    }
    return ConnectivityState(lastSyncAt: lastSync);
  }

  /// Platforma signalini kuzatishni boshlaydi (ilova ishga tushganda bir marta).
  Future<void> start({Connectivity? connectivity}) async {
    final plugin = connectivity ?? Connectivity();
    try {
      _applyPlatformResult(await plugin.checkConnectivity());
    } on Object {
      // Plagin ishlamasa haqiqiy so'rov natijalariga tayanamiz.
    }
    _subscription ??= plugin.onConnectivityChanged.listen(
      _applyPlatformResult,
      onError: (_) {},
    );
  }

  void _applyPlatformResult(List<ConnectivityResult> results) {
    final hasInterface =
        results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);
    if (!hasInterface) {
      _setOffline(true);
      return;
    }
    // Interfeys bor — lekin internet borligini faqat haqiqiy so'rov tasdiqlaydi.
    // Shuning uchun bu yerda online deb belgilaymiz va birinchi muvaffaqiyatsiz
    // so'rov bizni yana offline'ga qaytaradi.
    _setOffline(false);
  }

  /// Har muvaffaqiyatli server javobidan keyin chaqiriladi.
  void reportSuccess() {
    final now = DateTime.now();
    try {
      unawaited(
        ref
            .read(prefsStoreProvider)
            .setString(_kLastSync, now.toIso8601String()),
      );
    } on Object {
      // Prefs yozilmasa ham holat yangilanadi.
    }
    final wasOffline = state.isOffline;
    state = state.copyWith(isOffline: false, lastSyncAt: now);
    if (wasOffline) _notifyReconnect();
  }

  /// Tarmoq xatosidan keyin chaqiriladi (`NetworkFailure`).
  void reportNetworkFailure() => _setOffline(true);

  void _setOffline(bool offline) {
    if (state.isOffline == offline) return;
    state = state.copyWith(isOffline: offline);
    if (!offline) _notifyReconnect();
  }

  /// Internet qaytganda bajariladigan ish (savat navbati va h.k.).
  void addReconnectListener(void Function() listener) =>
      _reconnectListeners.add(listener);

  void _notifyReconnect() {
    for (final listener in List.of(_reconnectListeners)) {
      try {
        listener();
      } on Object {
        // Bitta tinglovchi yiqilsa qolganlari ishlashda davom etadi.
      }
    }
  }
}
