import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/order_models.dart';
import 'order_live_map.dart';
import 'order_status_badge.dart';

/// Delivery orderning customer-facing yuqori qismi. Pickup orderlar uchun
/// hech narsa chizmaydi.
class OrderDeliveryStatus extends StatelessWidget {
  const OrderDeliveryStatus({required this.order, this.location, super.key});

  final OrderData order;
  final CourierLocation? location;

  @override
  Widget build(BuildContext context) {
    final current = location;
    final canShowMap =
        current != null &&
        current.hasValidCoordinates &&
        order.address?.latitude != null &&
        order.address?.longitude != null;
    if (!order.isDelivery) return const SizedBox.shrink();
    if (order.isDelivered) {
      return const DeliveryDeliveredPanel();
    }
    if (order.customerStage == CustomerOrderStage.cancelled) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OrderStatusBadge(stage: order.customerStage),
      );
    }
    if (order.isSearchingCourier) {
      return DeliveryWaitingPanel(createdAt: order.createdDateTime);
    }
    if (order.isCourierOnWay) {
      return Column(
        children: [
          _CourierHero(order: order, isOnWay: true),
          if (canShowMap) ...[
            const SizedBox(height: AppSpacing.lg),
            if (current.isCurrentlyUnavailable)
              _LocationNotice(location: current)
            else
              OrderLiveMap(
                location: current,
                destinationLatitude: order.address!.latitude!,
                destinationLongitude: order.address!.longitude!,
                serverDeadline: order.deliveryDeadlineAt,
              ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            const _LocationNotice(),
          ],
        ],
      );
    }
    if (order.hasAcceptedCourier) {
      return _CourierHero(order: order, isOnWay: false);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OrderStatusBadge(stage: order.customerStage),
    );
  }
}

class DeliveryDeliveredPanel extends StatelessWidget {
  const DeliveryDeliveredPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    const green = Color(0xFF16A765);
    const darkGreen = Color(0xFF064E32);
    return Container(
      key: const ValueKey('order-delivered-hero'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: green,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: disableAnimations ? 1 : 0.2, end: 1),
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: const CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: Icon(Icons.check_rounded, color: darkGreen, size: 46),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.orderStatusDelivered,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: darkGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.orderDeliveredSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: darkGreen),
          ),
        ],
      ),
    );
  }
}

class DeliveryWaitingPanel extends StatefulWidget {
  const DeliveryWaitingPanel({this.createdAt, super.key});

  final DateTime? createdAt;

  @override
  State<DeliveryWaitingPanel> createState() => _DeliveryWaitingPanelState();
}

class _DeliveryWaitingPanelState extends State<DeliveryWaitingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;
  Timer? _clock;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _radar
        ..stop()
        ..value = 0;
    } else {
      _radar.repeat();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('order-searching-courier'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 152,
            child: AnimatedBuilder(
              animation: _radar,
              builder: (context, child) => CustomPaint(
                painter: _RadarPainter(
                  progress: _radar.value,
                  color: colors.primary,
                ),
                child: child,
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: const Icon(Icons.delivery_dining_rounded, size: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.orderSearchingCourier,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.orderSearchingSubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                l10n.orderWaitingElapsed(_elapsed(widget.createdAt)),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierHero extends StatelessWidget {
  const _CourierHero({required this.order, required this.isOnWay});

  final OrderData order;
  final bool isOnWay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    const green = Color(0xFF18B66A);
    const darkGreen = Color(0xFF064E32);
    return Container(
      key: ValueKey(
        isOnWay ? 'order-courier-on-way' : 'order-courier-accepted',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: green,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3318B66A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: disableAnimations ? 1 : 0.2, end: 1),
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: Icon(
                isOnWay ? Icons.delivery_dining_rounded : Icons.check_rounded,
                color: darkGreen,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isOnWay ? l10n.orderCourierOnWay : l10n.orderCourierAccepted,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: darkGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isOnWay
                ? l10n.orderCourierOnWaySubtitle
                : l10n.orderCourierAcceptedSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: darkGreen),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CourierDetails(order: order),
        ],
      ),
    );
  }
}

class _CourierDetails extends StatelessWidget {
  const _CourierDetails({required this.order});

  final OrderData order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const darkGreen = Color(0xFF064E32);
    final arrival = _arrivalText(context, order);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE8F8EF),
                foregroundColor: darkGreen,
                child: Icon(Icons.person_rounded),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.courierName,
                      style: const TextStyle(
                        color: darkGreen,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (order.courierPhone.isNotEmpty)
                      SelectableText(
                        order.courierPhone,
                        style: const TextStyle(color: darkGreen),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (arrival.isNotEmpty) ...[
            const Divider(height: AppSpacing.xxl),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: l10n.orderEstimatedArrival,
              value: arrival,
            ),
          ],
          if (order.courierVehicleType.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: Icons.two_wheeler_rounded,
              label: l10n.orderVehicle,
              value: order.courierVehicleType,
            ),
          ],
          if (order.courierComment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: l10n.orderCourierNote,
              value: order.courierComment,
            ),
          ],
          if (order.courierPhone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: darkGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _callPhone(context, order.courierPhone),
                    icon: const Icon(Icons.call),
                    label: Text(l10n.orderCallCourier),
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyPhone(context, order.courierPhone),
                      icon: const Icon(Icons.content_copy),
                      label: Text(l10n.orderCopyPhone),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFF0A7A4E), size: 21),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF064E32),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({this.location});

  final CourierLocation? location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(l10n.orderLocationUnavailable)),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2;
    for (var i = 0; i < 3; i++) {
      final value = (progress + i / 3) % 1;
      canvas.drawCircle(
        center,
        30 + (maxRadius - 30) * value,
        Paint()
          ..color = color.withValues(alpha: (1 - value) * 0.22)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

String _elapsed(DateTime? createdAt) {
  if (createdAt == null) return '00:00';
  final seconds = math.max(0, DateTime.now().difference(createdAt).inSeconds);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '${two(hours)}:${two(minutes)}:${two(remainingSeconds)}'
      : '${two(minutes)}:${two(remainingSeconds)}';
}

String _arrivalText(BuildContext context, OrderData order) {
  final l10n = AppLocalizations.of(context);
  if (order.deliveryOption == 'one_day') {
    return l10n.orderDeliveryWithinOneDay;
  }
  if (order.deliveryOption == 'two_days') {
    return l10n.orderDeliveryWithinTwoDays;
  }
  final deadline = order.deliveryDeadlineAt;
  if (deadline != null) {
    final minutes = deadline
        .difference(DateTime.now())
        .inMinutes
        .clamp(0, 1440);
    final clock = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(deadline));
    return '${l10n.orderArrivesInMinutes(minutes)} · $clock';
  }
  if (order.courierEtaMinutes > 0) {
    return l10n.orderArrivesInMinutes(order.courierEtaMinutes);
  }
  return '';
}

Future<void> _callPhone(BuildContext context, String phone) async {
  final clean = phone.replaceAll(RegExp(r'[^+\d]'), '');
  if (clean.isNotEmpty) {
    final launched = await launchUrl(Uri(scheme: 'tel', path: clean));
    if (launched) return;
  }
  if (!context.mounted) return;
  await _copyPhone(context, phone);
}

Future<void> _copyPhone(BuildContext context, String phone) async {
  await Clipboard.setData(ClipboardData(text: phone));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).orderPhoneCopied)),
    );
}
