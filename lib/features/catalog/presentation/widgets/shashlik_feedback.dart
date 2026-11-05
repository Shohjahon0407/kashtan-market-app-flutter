import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';

/// Page-owned banner: above content, never over the cart or navbar.
void showShashlikSaved(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentMaterialBanner()
    ..showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.white,
        leading: const Icon(Icons.check_circle, color: AppColors.primary),
        content: _SavedMessage(
          text: AppLocalizations.of(context).shashlikCartUpdated,
        ),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).commonClose,
            onPressed: messenger.hideCurrentMaterialBanner,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
}

class _SavedMessage extends StatefulWidget {
  const _SavedMessage({required this.text});
  final String text;
  @override
  State<_SavedMessage> createState() => _SavedMessageState();
}

class _SavedMessageState extends State<_SavedMessage> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Semantics(liveRegion: true, child: Text(widget.text));
}
