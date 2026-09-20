import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../data/video_cache.dart';
import '../data/video_models.dart';
import '../domain/reel_gesture_math.dart';

/// Reels uchun player oynasi: faol video ± 1 ta controller tirik, qolgani
/// bo'shatiladi. Home lentasi va Videolar tabi bitta mantiqni ishlatadi.
///
/// UI'ga bog'liq emas: `onChanged` — controller tayyor/xato bo'lganda
/// `setState`, `onActiveReady` — markazdagi video initialize bo'lganda
/// (chaqiruvchi o'z shartlari bilan `play` qiladi).
class ReelPlayerPool {
  ReelPlayerPool({
    required this.cache,
    required this.soundOn,
    required this.onChanged,
    required this.onActiveReady,
  });

  final VideoCache cache;
  final bool Function() soundOn;
  final VoidCallback onChanged;
  final VoidCallback onActiveReady;

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, String> _urls = {};
  final Set<String> _errors = {};
  final Set<String> _initializing = {};
  List<StoreVideo> _items = const [];
  int _center = 0;
  bool _disposed = false;

  /// Sekin tarmoqda initialize cheksiz osilib qolmasin.
  static const initializeTimeout = Duration(seconds: 20);

  VideoPlayerController? controllerFor(String id) => _controllers[id];
  bool hasError(String id) => _errors.contains(id);
  Iterable<VideoPlayerController> get controllers => _controllers.values;

  /// Oyna markazini [center]ga ko'chiradi: keraksiz controller'lar
  /// bo'shatiladi, yetishmayotganlari (avval AKTIV, keyin keyingisi, oxirida
  /// oldingisi — `calculateReelPlayerWindow`) yaratiladi.
  Future<void> syncWindow(List<StoreVideo> items, int center) async {
    if (_disposed || items.isEmpty) return;
    _items = items;
    _center = center.clamp(0, items.length - 1);
    final orderedIndexes = calculateReelPlayerWindow(
      center: _center,
      itemCount: items.length,
    );
    final desired = <String>{
      for (final index in orderedIndexes) items[index].id,
    };
    final obsolete = _controllers.keys
        .where((id) => !desired.contains(id))
        .toList();
    for (final id in obsolete) {
      final controller = _controllers.remove(id);
      _urls.remove(id);
      if (controller != null) {
        await controller.pause();
        await controller.dispose();
      }
    }

    for (final index in orderedIndexes) {
      final video = items[index];
      final existing = _controllers[video.id];
      if (existing != null && _urls[video.id] != video.videoUrl) {
        _controllers.remove(video.id);
        _urls.remove(video.id);
        _errors.remove(video.id);
        await existing.pause();
        await existing.dispose();
      }
      if (_controllers.containsKey(video.id) ||
          _initializing.contains(video.id) ||
          _errors.contains(video.id)) {
        continue;
      }
      _initializing.add(video.id);
      VideoPlayerController? controller;
      try {
        final cachedFile = await cache.cachedFile(video.videoUrl);
        if (_disposed || !_isDesired(video.id)) continue;
        controller = cachedFile != null
            ? VideoPlayerController.file(cachedFile)
            : VideoPlayerController.networkUrl(Uri.parse(video.videoUrl));
        _controllers[video.id] = controller;
        _urls[video.id] = video.videoUrl;
        await controller.initialize().timeout(initializeTimeout);
        if (_disposed || _controllers[video.id] != controller) {
          await controller.dispose();
          continue;
        }
        // Ko'rilgan video diskda qoladi: orqaga scroll va oflaynda fayldan
        // o'ynaydi. Faqat haqiqatan initialize bo'lgan (ko'rilayotgan) video —
        // butun lenta oldindan yuklanmaydi.
        if (cachedFile == null) cache.storeInBackground(video.videoUrl);
        await controller.setLooping(true);
        await controller.setVolume(soundOn() ? 1 : 0);
        // Yuqoridagi ikki await paytida ham ekran yopilgan bo'lishi mumkin.
        if (_disposed || _controllers[video.id] != controller) continue;
        onChanged();
        // Aktiv video tayyor bo'lishi bilan darhol o'ynaydi. Keyingi/oldingi
        // controllerlar tayyor bo'lishini kutmaydi.
        if (index == _center) onActiveReady();
      } on Object {
        if (_controllers.remove(video.id) == controller) {
          _urls.remove(video.id);
          await controller?.dispose();
        }
        _errors.add(video.id);
        if (!_disposed) onChanged();
      } finally {
        _initializing.remove(video.id);
      }
    }
    if (!_disposed) onActiveReady();
  }

  bool _isDesired(String videoId) {
    for (var index = _center - 1; index <= _center + 1; index++) {
      if (index >= 0 && index < _items.length && _items[index].id == videoId) {
        return true;
      }
    }
    return false;
  }

  /// Initialize bo'lgan bo'lsa o'ynatadi; aks holda tayyor bo'lganda
  /// `onActiveReady` chaqiriladi.
  void play(String id) {
    final controller = _controllers[id];
    if (controller?.value.isInitialized ?? false) unawaited(controller!.play());
  }

  void pauseAll({String? exceptId}) {
    for (final entry in _controllers.entries) {
      if (entry.key != exceptId && entry.value.value.isPlaying) {
        unawaited(entry.value.pause());
      }
    }
  }

  Future<void> setVolume(bool on) async {
    for (final controller in _controllers.values) {
      await controller.setVolume(on ? 1 : 0);
    }
  }

  /// Xato bo'lgan videoni qayta yuklaydi (oyna o'zgarmaydi).
  Future<void> retry(String id) async {
    _errors.remove(id);
    final old = _controllers.remove(id);
    _urls.remove(id);
    if (old != null) await old.dispose();
    if (_disposed) return;
    onChanged();
    await syncWindow(_items, _center);
  }

  void dispose() {
    _disposed = true;
    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
    _urls.clear();
    _initializing.clear();
  }
}
