import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../domain/notifications_controller.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authenticated = ref.watch(
      authControllerProvider.select((auth) => auth.isAuthenticated),
    );
    final count = authenticated
        ? ref.watch(notificationUnreadCountProvider).value ?? 0
        : 0;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).notificationsTitle,
      // Vizual 40 dp, bosish maydoni 48 dp (minimal tap target).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Material(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.none,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onPressed,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications_none,
                          size: 22,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: -4,
                          top: -5,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 19),
                            height: 19,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onError,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
