import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';
import 'shashlik_catalog.dart';

/// Tepadan tushadigan "Ko'mir ham kerakmi?" tavsiyasi.
///
/// Ildiz overlay'ga qo'yiladi: shashlik oila sahifasida qo'shilganda ham
/// ko'rinadi. Taymer emas, bitta [AnimationController] boshqaradi (kirish →
/// kutish → chiqish), oxirida o'zini olib tashlaydi.
class ShashlikCharcoalNudge {
  ShashlikCharcoalNudge._(this._entry);

  final OverlayEntry _entry;
  bool _removed = false;

  bool get isActive => !_removed;

  static ShashlikCharcoalNudge show(
    BuildContext context, {
    required VoidCallback onAction,
  }) {
    late final ShashlikCharcoalNudge nudge;
    final entry = OverlayEntry(
      builder: (_) =>
          _NudgeBanner(onAction: onAction, onFinished: () => nudge.remove()),
    );
    nudge = ShashlikCharcoalNudge._(entry);
    Overlay.of(context, rootOverlay: true).insert(entry);
    return nudge;
  }

  void remove() {
    if (_removed) return;
    _removed = true;
    _entry.remove();
  }
}

class _NudgeBanner extends StatefulWidget {
  const _NudgeBanner({required this.onAction, required this.onFinished});

  final VoidCallback onAction;
  final VoidCallback onFinished;

  @override
  State<_NudgeBanner> createState() => _NudgeBannerState();
}

class _NudgeBannerState extends State<_NudgeBanner>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 6500);

  // Dastlabki qisqa pauza: savatga qo'shish oynasi yopilib ulgursin.
  static const _enterStart = .05, _enterEnd = .12, _exitStart = .9;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  )..addStatusListener(_onStatus);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    // Qayerda bo'lmasin — chiqish bosqichidan tez yuqoriga ketadi.
    if (_controller.value < _exitStart) _controller.value = _exitStart;
    _controller.animateTo(1, duration: const Duration(milliseconds: 240));
  }

  double get _offset {
    final t = _controller.value;
    if (t < _enterStart) return 0;
    if (t < _enterEnd) {
      return Curves.easeOutBack.transform(
        (t - _enterStart) / (_enterEnd - _enterStart),
      );
    }
    if (t < _exitStart) return 1;
    return 1 - Curves.easeIn.transform((t - _exitStart) / (1 - _exitStart));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = _offset;
              if (offset <= 0) return const SizedBox.shrink();
              return FractionalTranslation(
                translation: Offset(0, offset - 1.3),
                child: Opacity(opacity: offset.clamp(0, 1), child: child),
              );
            },
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < 0) _close();
              },
              child: Material(
                key: const ValueKey('shashlik-charcoal-nudge'),
                color: Colors.white,
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFEFE5),
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          color: shashlikCharcoalAccent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.shashlikCharcoalNudgeTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.shashlikCharcoalNudgeBody,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              key: const ValueKey(
                                'shashlik-charcoal-nudge-action',
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _close();
                                widget.onAction();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: shashlikCharcoalAccent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.local_fire_department,
                                size: 18,
                              ),
                              label: Text(l10n.shashlikCharcoalNudgeAction),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.commonClose,
                        onPressed: _close,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
