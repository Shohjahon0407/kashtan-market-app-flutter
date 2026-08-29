import 'dart:async';

/// Oddiy debouncer — qidiruv kabi tez-tez o'zgaruvchi kiritmalar uchun.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => cancel();
}
