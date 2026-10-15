import 'package:flutter/material.dart';

import '../../../../core/ui/theme/app_colors.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/order_models.dart';

/// 4 bosqichli yetkazish stepper'i: tasdiq → tayyorlanmoqda → yo'lda →
/// yetkazildi. Joriy bosqich pulsatsiya qiladi, o'tilgan chiziqlar
/// animatsiya bilan to'ladi. Bekor qilingan/pickup holatlari uchun
/// chizilmaydi — chaqiruvchi badge ko'rsatadi.
class OrderStageStepper extends StatefulWidget {
  const OrderStageStepper({required this.stage, super.key});

  final CustomerOrderStage stage;

  static const steps = [
    CustomerOrderStage.searching,
    CustomerOrderStage.accepted,
    CustomerOrderStage.onWay,
    CustomerOrderStage.delivered,
  ];

  static IconData iconOf(CustomerOrderStage stage) => switch (stage) {
    CustomerOrderStage.searching => Icons.schedule_rounded,
    CustomerOrderStage.accepted => Icons.soup_kitchen_rounded,
    CustomerOrderStage.onWay => Icons.directions_run_rounded,
    CustomerOrderStage.delivered => Icons.check_rounded,
    CustomerOrderStage.cancelled => Icons.cancel_rounded,
    CustomerOrderStage.other => Icons.schedule_rounded,
  };

  @override
  State<OrderStageStepper> createState() => _OrderStageStepperState();

  /// Bosqich sarlavhasi (stepper ostidagi matn va semantika uchun).
  static String stageTitle(AppLocalizations l10n, CustomerOrderStage stage) =>
      switch (stage) {
        CustomerOrderStage.searching => l10n.orderStageAwaiting,
        CustomerOrderStage.accepted => l10n.orderStagePreparing,
        CustomerOrderStage.onWay => l10n.orderStageOnWay,
        CustomerOrderStage.delivered => l10n.orderStageDelivered,
        CustomerOrderStage.cancelled => l10n.orderStatusCancelled,
        CustomerOrderStage.other => l10n.orderStatusProcessing,
      };

  /// Bosqich izohi (ixtiyoriy, kichik matn).
  static String? stageHint(AppLocalizations l10n, CustomerOrderStage stage) =>
      switch (stage) {
        CustomerOrderStage.searching => l10n.orderStageAwaitingHint,
        CustomerOrderStage.accepted => l10n.orderStagePreparingHint,
        CustomerOrderStage.onWay => l10n.orderStageOnWayHint,
        CustomerOrderStage.delivered => l10n.orderStageDeliveredHint,
        _ => null,
      };
}

class _OrderStageStepperState extends State<OrderStageStepper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool? _animationsDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled != disabled) {
      _animationsDisabled = disabled;
      _syncPulse();
    }
  }

  @override
  void didUpdateWidget(covariant OrderStageStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) _syncPulse();
  }

  void _syncPulse() {
    final current = widget.stage.stepIndex;
    // Yakuniy bosqichda pulsatsiya yo'q — tinch yashil belgi.
    final animate =
        current != null &&
        widget.stage != CustomerOrderStage.delivered &&
        _animationsDisabled != true;
    if (animate) {
      _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.stage.stepIndex;
    if (current == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final children = <Widget>[];
    for (var index = 0; index < OrderStageStepper.steps.length; index++) {
      final step = OrderStageStepper.steps[index];
      if (index > 0) {
        children.add(Expanded(child: _StageLine(filled: index <= current)));
      }
      children.add(
        _StageDot(
          stage: step,
          state: index < current
              ? _DotState.completed
              : index == current
              ? _DotState.current
              : _DotState.pending,
          pulse: _pulse,
          animated: _animationsDisabled != true,
          label: OrderStageStepper.stageTitle(l10n, step),
        ),
      );
    }
    return Semantics(
      label: OrderStageStepper.stageTitle(l10n, widget.stage),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(children: children),
      ),
    );
  }
}

enum _DotState { completed, current, pending }

class _StageDot extends StatelessWidget {
  const _StageDot({
    required this.stage,
    required this.state,
    required this.pulse,
    required this.animated,
    required this.label,
  });

  final CustomerOrderStage stage;
  final _DotState state;
  final Animation<double> pulse;
  final bool animated;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = OrderStageStepper.iconOf(stage);
    final Widget dot = switch (state) {
      _DotState.completed => _Circle(
        size: 44,
        color: AppColors.primarySoft,
        child: Icon(icon, size: 22, color: AppColors.primary),
      ),
      _DotState.current => _Circle(
        size: 50,
        color: AppColors.primary,
        shadow: true,
        child: Icon(icon, size: 26, color: AppColors.onPrimary),
      ),
      _DotState.pending => _Circle(
        size: 44,
        color: scheme.surfaceContainerHighest,
        child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
      ),
    };
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (animated &&
                state == _DotState.current &&
                stage != CustomerOrderStage.delivered)
              AnimatedBuilder(
                animation: pulse,
                builder: (context, _) {
                  final t = pulse.value;
                  return Container(
                    key: const ValueKey('order-stage-pulse'),
                    width: 50 + 14 * t,
                    height: 50 + 14 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(
                        alpha: 0.28 * (1 - t),
                      ),
                    ),
                  );
                },
              ),
            KeyedSubtree(
              key: ValueKey(
                state == _DotState.current
                    ? 'order-stage-current-${stage.name}'
                    : 'order-stage-${stage.name}',
              ),
              child: dot,
            ),
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    required this.size,
    required this.color,
    required this.child,
    this.shadow = false,
  });

  final double size;
  final Color color;
  final Widget child;
  final bool shadow;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutBack,
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: shadow
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    child: Center(child: child),
  );
}

class _StageLine extends StatelessWidget {
  const _StageLine({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: filled ? 1 : 0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
