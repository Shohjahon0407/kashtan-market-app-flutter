import 'dart:async';

import 'package:flutter/material.dart';

/// Cold start paytida router ustida bir marta ko'rinadigan brend intro.
///
/// App kontenti uning ostida parallel quriladi. Minimal intro vaqti tugagach
/// ham session hali tekshirilayotgan bo'lsa, yozuv markazda kutib turadi.
class StartupIntro extends StatefulWidget {
  const StartupIntro({
    required this.isAppReady,
    required this.child,
    super.key,
  });

  static const entryDuration = Duration(milliseconds: 650);
  static const holdDuration = Duration(milliseconds: 900);
  static const exitDuration = Duration(milliseconds: 950);
  static const brandColor = Color(0xFF24C93B);

  final bool isAppReady;
  final Widget child;

  @override
  State<StartupIntro> createState() => _StartupIntroState();
}

class _StartupIntroState extends State<StartupIntro>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _exitController;
  bool _started = false;
  bool _minimumElapsed = false;
  bool _exitStarted = false;
  bool _finished = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: StartupIntro.entryDuration + StartupIntro.holdDuration,
    );
    _exitController = AnimationController(
      vsync: this,
      duration: StartupIntro.exitDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    unawaited(_runIntroTimeline());
  }

  @override
  void didUpdateWidget(covariant StartupIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isAppReady && widget.isAppReady) _tryStartExit();
  }

  void _tryStartExit() {
    if (!mounted || !_minimumElapsed || !widget.isAppReady || _exitStarted) {
      return;
    }
    _exitStarted = true;
    unawaited(_runExit());
  }

  Future<void> _runIntroTimeline() async {
    await _entryController.forward();
    if (!mounted) return;
    _minimumElapsed = true;
    _tryStartExit();
  }

  Future<void> _runExit() async {
    await _exitController.forward();
    if (!mounted) return;
    setState(() => _finished = true);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  double get _entryProgress {
    final totalMilliseconds =
        (StartupIntro.entryDuration + StartupIntro.holdDuration).inMilliseconds;
    final entryFraction =
        StartupIntro.entryDuration.inMilliseconds / totalMilliseconds;
    return (_entryController.value / entryFraction).clamp(0, 1);
  }

  double get _entryOpacity => Curves.easeOut.transform(_entryProgress);

  double get _entryScale => _reduceMotion
      ? 1
      : 0.82 + (0.18 * Curves.easeOutCubic.transform(_entryProgress));

  double get _exitScale => _reduceMotion
      ? 1
      : 1 + (11 * Curves.easeInCubic.transform(_exitController.value));

  double get _revealOpacity {
    final progress = _exitController.value;
    if (progress <= 0.56) return 1;
    return 1 - Curves.easeIn.transform(((progress - 0.56) / 0.44).clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_finished)
          Positioned.fill(
            key: const ValueKey('startup-intro-overlay'),
            child: AbsorbPointer(
              absorbing: true,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _entryController,
                  _exitController,
                ]),
                builder: (context, child) => Opacity(
                  opacity: _revealOpacity,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: Opacity(
                        opacity: _entryOpacity,
                        child: Transform.scale(
                          key: const ValueKey('startup-intro-wordmark-scale'),
                          scale: _entryScale * _exitScale,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fontSize = (constraints.maxWidth * 0.09).clamp(
                      30.0,
                      40.0,
                    );
                    return Text(
                      'BESHKASHTAN',
                      key: const ValueKey('startup-intro-wordmark'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        inherit: false,
                        color: StartupIntro.brandColor,
                        fontFamily: 'Inter',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        height: 1,
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
