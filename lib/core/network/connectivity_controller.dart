import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/locale_controller.dart';
import 'connectivity_probe.dart';

const staleDataThreshold = Duration(days: 1);

class ConnectivityState {
  const ConnectivityState({
    this.isOffline = false,
    this.isServerUnavailable = false,
    this.isChecking = false,
    this.recoveryRevision = 0,
    this.lastSyncAt,
    this.isForeground = true,
  });

  /// Only confirmed loss of interfaces AND failed reachability blocks requests.
  final bool isOffline;
  final bool isServerUnavailable;
  final bool isChecking;
  final int recoveryRevision;
  final DateTime? lastSyncAt;

  /// Ilova ekranda (resumed) turibdimi. Fon rejimida davriy so'rovlar
  /// (tracking poll va h.k.) qurilmaydi.
  final bool isForeground;

  bool get needsRecovery => isOffline || isServerUnavailable;
  bool get isStale =>
      needsRecovery &&
      (lastSyncAt == null ||
          DateTime.now().difference(lastSyncAt!) > staleDataThreshold);

  ConnectivityState copyWith({
    bool? isOffline,
    bool? isServerUnavailable,
    bool? isChecking,
    int? recoveryRevision,
    DateTime? lastSyncAt,
    bool? isForeground,
  }) => ConnectivityState(
    isOffline: isOffline ?? this.isOffline,
    isServerUnavailable: isServerUnavailable ?? this.isServerUnavailable,
    isChecking: isChecking ?? this.isChecking,
    recoveryRevision: recoveryRevision ?? this.recoveryRevision,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    isForeground: isForeground ?? this.isForeground,
  );
}

final connectivityControllerProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
    );

final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(
    connectivityControllerProvider.select((state) => state.isOffline),
  ),
);

final connectivityRecoveryProvider = Provider<int>(
  (ref) => ref.watch(
    connectivityControllerProvider.select((state) => state.recoveryRevision),
  ),
);

/// Refresh active controllers without resetting navigation, queries or scroll.
void listenForConnectionRecovery(Ref ref, FutureOr<void> Function() refresh) {
  ref.listen(connectivityRecoveryProvider, (previous, next) {
    if (previous == null || previous == next) return;
    scheduleMicrotask(() async {
      if (!ref.mounted) return;
      try {
        await refresh();
      } on Object {
        // Existing controller error/cache behavior owns the result.
      }
    });
  });
}

class ConnectivityController extends Notifier<ConnectivityState> {
  static const _kLastSync = 'net.last_sync_at';
  static const _retrySeconds = [5, 10, 20, 30];

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Connectivity? _plugin;
  ConnectivityProbe? _probe;
  Timer? _debounce;
  Timer? _retry;
  Future<void>? _inFlight;
  final _reconnectListeners = <void Function()>[];
  bool _started = false;
  bool _foreground = true;
  bool? _hasInterface;
  Set<ConnectivityResult> _interfaces = {};
  bool _noneConfirmed = false;
  bool _checkAgain = false;
  int _platformRevision = 0;
  int _evidenceRevision = 0;
  int _attempt = 0;

  /// A delayed failed request must not override newer HTTP/probe success.
  int get evidenceRevision => _evidenceRevision;

  @override
  ConnectivityState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _debounce?.cancel();
      _retry?.cancel();
      _probe?.cancel();
      _reconnectListeners.clear();
    });
    DateTime? lastSync;
    try {
      final raw = ref.read(prefsStoreProvider).getString(_kLastSync);
      lastSync = raw == null ? null : DateTime.tryParse(raw);
    } on Object {
      // Preferences are optional for connectivity.
    }
    return ConnectivityState(lastSyncAt: lastSync);
  }

  Future<void> start({Connectivity? connectivity}) async {
    if (_started) return;
    _started = true;
    _probe = ref.read(connectivityProbeProvider);
    _plugin = connectivity ?? Connectivity();
    try {
      // Subscribe before the async snapshot to avoid a lost transition.
      _subscription = _plugin!.onConnectivityChanged.listen(
        _applyPlatformResult,
        onError: (_) {},
      );
    } on Object {
      // A missing plugin never proves that Internet is unavailable.
    }
    await recheck();
  }

  Future<void> recheck() async {
    if (!_started || !ref.mounted || !_foreground) return;
    final revision = _platformRevision;
    try {
      final results = await _plugin!.checkConnectivity();
      if (!ref.mounted || !_foreground) return;
      if (revision == _platformRevision) _applyPlatformResult(results);
    } on Object {
      // Proceed using HTTP evidence if interface discovery is unavailable.
    }
    if (!ref.mounted || !_foreground) return;
    await _check();
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _platformRevision++;
    _debounce?.cancel();
    _retry?.cancel();
    if (foreground) {
      state = state.copyWith(isForeground: true);
      // A cancelled background probe may still be unwinding. Its stale result
      // must be followed by a fresh check, not reused as the resume check.
      if (_inFlight != null) _checkAgain = true;
      unawaited(recheck());
    } else {
      _checkAgain = false;
      _probe?.cancel();
      state = state.copyWith(isChecking: false, isForeground: false);
    }
  }

  void _applyPlatformResult(List<ConnectivityResult> results) {
    if (!ref.mounted || !_foreground) return;
    final hasInterface = results.any(
      (value) => value != ConnectivityResult.none,
    );
    final interfaces = results.toSet();
    final unchanged =
        interfaces.length == _interfaces.length &&
        interfaces.containsAll(_interfaces);
    if (unchanged &&
        _hasInterface == hasInterface &&
        (hasInterface || _noneConfirmed || _debounce?.isActive == true)) {
      return;
    }
    _platformRevision++;
    _interfaces = interfaces;
    _hasInterface = hasInterface;
    _noneConfirmed = false;
    _debounce?.cancel();
    _retry?.cancel();
    _attempt = 0;
    if (hasInterface) {
      // Release the hard gate immediately; interface != backend health.
      if (state.isOffline) {
        state = state.copyWith(isOffline: false, isServerUnavailable: true);
      }
      _requestFreshCheck();
    } else {
      _debounce = Timer(const Duration(seconds: 1), () {
        if (!ref.mounted || !_foreground || _hasInterface != false) return;
        _noneConfirmed = true;
        _platformRevision++;
        _requestFreshCheck();
      });
    }
  }

  void _requestFreshCheck() {
    if (_inFlight != null) _checkAgain = true;
    unawaited(_check());
  }

  Future<void> _check() {
    if (!_started || !ref.mounted || !_foreground) return Future.value();
    if (_inFlight != null) return _inFlight!;
    _retry?.cancel();
    final completer = Completer<void>();
    _inFlight = completer.future;
    unawaited(() async {
      try {
        final platform = _platformRevision;
        final evidence = _evidenceRevision;
        state = state.copyWith(isChecking: true);
        ProbeResult result;
        try {
          result = await _probe!.check();
        } on Object {
          result = ProbeResult.unreachable;
        }
        if (!ref.mounted ||
            !_foreground ||
            platform != _platformRevision ||
            evidence != _evidenceRevision) {
          return;
        }
        if (result == ProbeResult.healthy) {
          _markHealthy(); // Probe does not update cached-data freshness.
        } else {
          state = state.copyWith(
            isOffline: result == ProbeResult.unreachable && _noneConfirmed,
            isServerUnavailable:
                result != ProbeResult.unreachable || !_noneConfirmed,
          );
        }
      } finally {
        _inFlight = null;
        if (ref.mounted) {
          state = state.copyWith(isChecking: false);
          if (_foreground && _checkAgain) {
            _checkAgain = false;
            _requestFreshCheck();
          } else if (_foreground && state.needsRecovery) {
            _scheduleRetry();
          }
        }
        completer.complete();
      }
    }());
    return completer.future;
  }

  void _scheduleRetry() {
    if (_retry?.isActive == true) return;
    final index = _attempt.clamp(0, _retrySeconds.length - 1);
    _attempt++;
    _retry = Timer(Duration(seconds: _retrySeconds[index]), () {
      unawaited(recheck());
    });
  }

  void reportSuccess() {
    if (!ref.mounted) return;
    final now = DateTime.now();
    try {
      unawaited(
        ref
            .read(prefsStoreProvider)
            .setString(_kLastSync, now.toIso8601String())
            .catchError((_) {}),
      );
    } on Object {
      // Preference errors cannot turn a successful API call offline.
    }
    _markHealthy(lastSyncAt: now);
  }

  /// An HTTP error proves connectivity; 5xx describes the server, not Wi-Fi.
  void reportHttpResponse(int statusCode) {
    if (!ref.mounted) return;
    if (statusCode < 500) {
      _markHealthy();
    } else {
      _evidenceRevision++;
      _debounce?.cancel();
      _noneConfirmed = false;
      state = state.copyWith(isOffline: false, isServerUnavailable: true);
      if (_started && _foreground) _scheduleRetry();
    }
  }

  void _markHealthy({DateTime? lastSyncAt}) {
    final recovered = state.needsRecovery;
    _evidenceRevision++;
    _debounce?.cancel();
    _noneConfirmed = false;
    _retry?.cancel();
    _attempt = 0;
    state = state.copyWith(
      isOffline: false,
      isServerUnavailable: false,
      lastSyncAt: lastSyncAt,
      recoveryRevision: state.recoveryRevision + (recovered ? 1 : 0),
    );
    if (recovered) {
      for (final listener in List.of(_reconnectListeners)) {
        try {
          listener();
        } on Object {
          /* Keep other listeners running. */
        }
      }
    }
  }

  /// No state change from one timeout; the independent probe decides.
  void reportNetworkFailure() {
    if (_started && ref.mounted && _foreground && _retry?.isActive != true) {
      unawaited(_check());
    }
  }

  void addReconnectListener(void Function() listener) =>
      _reconnectListeners.add(listener);
}
