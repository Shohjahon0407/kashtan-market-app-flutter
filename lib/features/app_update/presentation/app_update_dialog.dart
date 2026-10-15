import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/l10n/app_localizations.dart';
import '../domain/app_update_service.dart';

class AppUpdateDialog extends ConsumerStatefulWidget {
  const AppUpdateDialog({required this.release, super.key});
  final AndroidAppRelease release;
  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  bool _opening = false;
  bool _failed = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    final opened = await openAndroidUpdate(ref.read(updateUrlLauncherProvider));
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _opening = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Icon(Icons.system_update_rounded, color: color, size: 36),
      title: Text(l10n.appUpdateTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appUpdateBody(widget.release.version)),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.appUpdateOpenFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.appUpdateLater),
        ),
        FilledButton(
          onPressed: _opening ? null : _open,
          child: Text(_failed ? l10n.commonRetry : l10n.appUpdateDownload),
        ),
      ],
    );
  }
}
