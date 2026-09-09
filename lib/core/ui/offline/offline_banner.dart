import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/l10n/app_localizations.dart';
import '../../network/connectivity_controller.dart';

/// Butun ilova ustidagi bilinar-bilinmas offline belgisi.
///
/// `MaterialApp.router` ning `builder` ida turadi — BARCHA ekranlarni qamraydi,
/// hech bir ekranga tegilmaydi. `Stack` overlay bo'lgani uchun layout
/// siljimaydi. Online qaytganda o'zi animatsiya bilan yo'qoladi.
///
/// Internet talab qiladigan amal offline bosilganda [OfflineGate.notify]
/// chaqiriladi — belgi yorishib, yengil silkinadi (animatsiyali ogohlantirish).
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    OfflineGate.instance._attach(_onBlockedAction);
  }

  @override
  void dispose() {
    OfflineGate.instance._detach(_onBlockedAction);
    _pulse.dispose();
    super.dispose();
  }

  void _onBlockedAction() {
    if (!mounted) return;
    _pulse.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !connectivity.needsRecovery,
            child: AnimatedSlide(
              offset: connectivity.needsRecovery
                  ? Offset.zero
                  : const Offset(0, -1.2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: connectivity.needsRecovery ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: _BannerBody(
                  pulse: _pulse,
                  onRetry: () => unawaited(
                    ref.read(connectivityControllerProvider.notifier).recheck(),
                  ),
                  isChecking: connectivity.isChecking,
                  retryLabel: l10n.commonRetry,
                  text: connectivity.isServerUnavailable
                      ? l10n.connectionServerUnavailable
                      : connectivity.isStale
                      ? '${l10n.offlineBanner} · ${l10n.offlineStaleData}'
                      : l10n.offlineBanner,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({
    required this.pulse,
    required this.text,
    required this.onRetry,
    required this.isChecking,
    required this.retryLabel,
  });

  final AnimationController pulse;
  final String text;
  final VoidCallback onRetry;
  final bool isChecking;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            // Bosilganda: yorishish + yengil silkinish, so'ng asl xira holat.
            final t = pulse.value;
            final emphasis = t == 0 ? 0.0 : (1 - t);
            // Sinus asosidagi so'nayotgan silkinish.
            final shake = emphasis == 0
                ? 0.0
                : 6 *
                      emphasis *
                      (0.5 - ((t * 4) - (t * 4).floorToDouble())).sign;
            return Transform.translate(
              offset: Offset(shake, 0),
              child: Opacity(opacity: 0.72 + 0.28 * emphasis, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xCC1F2937),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: retryLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isChecking ? null : onRetry,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: isChecking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Internet talab qiladigan amallar uchun darvoza.
///
/// Ekranlar `OfflineGate.check(ref)` chaqiradi: online bo'lsa `true`,
/// offline bo'lsa `false` qaytadi va yuqoridagi belgi animatsiya bilan
/// e'tiborni tortadi — alohida dialog/snackbar shart emas.
class OfflineGate {
  OfflineGate._();

  static final instance = OfflineGate._();

  final _listeners = <void Function()>[];

  void _attach(void Function() listener) => _listeners.add(listener);

  void _detach(void Function() listener) => _listeners.remove(listener);

  /// Amalni bajarish mumkinmi? Offline bo'lsa belgini "silkitadi".
  static bool check(WidgetRef ref) {
    if (!ref.read(isOfflineProvider)) return true;
    unawaited(ref.read(connectivityControllerProvider.notifier).recheck());
    notify();
    return false;
  }

  /// Belgini qo'lda silkitish (masalan server NetworkFailure qaytarganda).
  static void notify() {
    for (final listener in List.of(instance._listeners)) {
      listener();
    }
  }
}
