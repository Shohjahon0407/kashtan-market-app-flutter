import 'package:flutter/material.dart';

import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/order_models.dart';

class OrderStatusBadge extends StatefulWidget {
  const OrderStatusBadge({
    required this.stage,
    this.compact = false,
    super.key,
  });

  final CustomerOrderStage stage;
  final bool compact;

  @override
  State<OrderStatusBadge> createState() => _OrderStatusBadgeState();
}

class _OrderStatusBadgeState extends State<OrderStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled != disabled) {
      _animationsDisabled = disabled;
      _configureMotion();
    }
  }

  @override
  void didUpdateWidget(covariant OrderStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) _configureMotion();
  }

  void _configureMotion() {
    final animated =
        widget.stage == CustomerOrderStage.searching ||
        widget.stage == CustomerOrderStage.onWay;
    if (animated && _animationsDisabled != true) {
      _motion.repeat(reverse: true);
    } else {
      _motion
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = _OrderStatusVisual.of(context, widget.stage);
    return Semantics(
      label: visual.label,
      child: DecoratedBox(
        key: ValueKey('order-status-${widget.stage.name}'),
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? AppSpacing.sm : AppSpacing.md,
            vertical: widget.compact ? AppSpacing.xs : AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusIcon(
                stage: widget.stage,
                color: visual.foreground,
                motion: _motion,
                animated: _animationsDisabled != true,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  visual.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: visual.foreground,
                    fontSize: widget.compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.stage,
    required this.color,
    required this.motion,
    required this.animated,
  });

  final CustomerOrderStage stage;
  final Color color;
  final Animation<double> motion;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final icon = switch (stage) {
      CustomerOrderStage.searching => Icons.hourglass_top_rounded,
      CustomerOrderStage.accepted => Icons.soup_kitchen_rounded,
      CustomerOrderStage.onWay => Icons.delivery_dining_rounded,
      CustomerOrderStage.delivered => Icons.check_circle_rounded,
      CustomerOrderStage.cancelled => Icons.cancel_rounded,
      CustomerOrderStage.other => Icons.schedule_rounded,
    };
    final child = Icon(icon, size: 18, color: color);
    if (!animated) return child;
    if (stage == CustomerOrderStage.searching) {
      return ScaleTransition(
        key: const ValueKey('order-searching-animation'),
        scale: Tween(
          begin: 0.82,
          end: 1.08,
        ).animate(CurvedAnimation(parent: motion, curve: Curves.easeInOut)),
        child: child,
      );
    }
    if (stage == CustomerOrderStage.onWay) {
      return SlideTransition(
        key: const ValueKey('order-on-way-animation'),
        position: Tween(
          begin: const Offset(-0.14, 0),
          end: const Offset(0.14, 0),
        ).animate(CurvedAnimation(parent: motion, curve: Curves.easeInOut)),
        child: child,
      );
    }
    return child;
  }
}

class _OrderStatusVisual {
  const _OrderStatusVisual({
    required this.label,
    required this.background,
    required this.foreground,
  });

  factory _OrderStatusVisual.of(
    BuildContext context,
    CustomerOrderStage stage,
  ) {
    final l10n = AppLocalizations.of(context);
    return switch (stage) {
      CustomerOrderStage.searching => _OrderStatusVisual(
        label: l10n.orderStatusAwaiting,
        background: const Color(0xFFFFF3D0),
        foreground: const Color(0xFF8A5A00),
      ),
      CustomerOrderStage.accepted => _OrderStatusVisual(
        label: l10n.orderStatusPreparing,
        background: const Color(0xFFE5F0FF),
        foreground: const Color(0xFF175EA8),
      ),
      CustomerOrderStage.onWay => _OrderStatusVisual(
        label: l10n.orderStatusDelivering,
        background: const Color(0xFFF0E8FF),
        foreground: const Color(0xFF6A3FA0),
      ),
      CustomerOrderStage.delivered => _OrderStatusVisual(
        label: l10n.orderStatusDelivered,
        background: const Color(0xFFE2F7EB),
        foreground: const Color(0xFF087847),
      ),
      CustomerOrderStage.cancelled => _OrderStatusVisual(
        label: l10n.orderStatusCancelled,
        background: const Color(0xFFFFE7E4),
        foreground: const Color(0xFFB3261E),
      ),
      CustomerOrderStage.other => _OrderStatusVisual(
        label: l10n.orderStatusProcessing,
        background: Theme.of(context).colorScheme.surfaceContainerHighest,
        foreground: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
  }

  final String label;
  final Color background;
  final Color foreground;
}
