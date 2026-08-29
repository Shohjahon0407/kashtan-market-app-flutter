import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../data/ugc_api.dart';
import '../data/ugc_models.dart';

/// Birinchi public izoh yoki sharhdan oldin amaldagi qoidalarni qabul qildiradi.
/// Cancel qilinganda kontent serverga yuborilmaydi.
Future<bool> ensureUgcPolicyAccepted(
  BuildContext context,
  WidgetRef ref,
) async {
  UgcPolicy policy;
  try {
    policy = await ref.read(ugcPolicyProvider.future);
  } on Object catch (error) {
    if (context.mounted) _showFailure(context, error);
    return false;
  }
  if (policy.accepted) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UgcPolicyDialog(policy: policy),
  );
  if (accepted != true || !context.mounted) return false;

  try {
    await ref.read(ugcApiProvider).acceptPolicy(policy.version);
    ref.invalidate(ugcPolicyProvider);
    return true;
  } on Object catch (error) {
    if (context.mounted) _showFailure(context, error);
    return false;
  }
}

Future<bool> reportUgcContent(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  if (!await requireAuthentication(context, ref) || !context.mounted) {
    return false;
  }
  final draft = await showModalBottomSheet<_ReportDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ReportSheet(),
  );
  if (draft == null || !context.mounted) return false;
  try {
    await ref
        .read(ugcApiProvider)
        .report(
          targetType: targetType,
          targetId: targetId,
          reason: draft.reason,
          details: draft.details,
        );
    if (!context.mounted) return true;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.ugcReportSent)));
    return true;
  } on Object catch (error) {
    if (context.mounted) _showFailure(context, error);
    return false;
  }
}

Future<bool> blockUgcUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  if (!await requireAuthentication(context, ref) || !context.mounted) {
    return false;
  }
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.ugcBlockUser),
      content: Text(l10n.ugcBlockConfirmation(displayName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.ugcBlock),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await ref.read(ugcApiProvider).blockUser(userId);
    ref.invalidate(blockedUsersProvider);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.ugcUserBlocked)));
    return true;
  } on Object catch (error) {
    if (context.mounted) _showFailure(context, error);
    return false;
  }
}

void _showFailure(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  final message = error is ApiFailure
      ? error.localize(l10n)
      : l10n.errorUnknown;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _UgcPolicyDialog extends StatefulWidget {
  const _UgcPolicyDialog({required this.policy});

  final UgcPolicy policy;

  @override
  State<_UgcPolicyDialog> createState() => _UgcPolicyDialogState();
}

class _UgcPolicyDialogState extends State<_UgcPolicyDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final policy = widget.policy;
    final termsUrl = policy.termsUrl.isEmpty
        ? AppConfig.termsUrl
        : policy.termsUrl;
    final communityUrl = policy.communityGuidelinesUrl.isEmpty
        ? AppConfig.communityGuidelinesUrl
        : policy.communityGuidelinesUrl;
    return PopScope(
      canPop: true,
      child: AlertDialog(
        title: Text(policy.title.isEmpty ? l10n.ugcPolicyTitle : policy.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                policy.summary.isEmpty ? l10n.ugcPolicySummary : policy.summary,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(termsUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(l10n.ugcTerms),
                  ),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(communityUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(l10n.ugcCommunityGuidelines),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked,
                onChanged: (value) => setState(() => _checked = value == true),
                title: Text(l10n.ugcPolicyConsent),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: _checked ? () => Navigator.pop(context, true) : null,
            child: Text(l10n.ugcAccept),
          ),
        ],
      ),
    );
  }
}

class _ReportDraft {
  const _ReportDraft(this.reason, this.details);
  final UgcReportReason reason;
  final String details;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  UgcReportReason _reason = UgcReportReason.spam;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    String label(UgcReportReason reason) => switch (reason) {
      UgcReportReason.spam => l10n.ugcReasonSpam,
      UgcReportReason.abuse => l10n.ugcReasonAbuse,
      UgcReportReason.inappropriate => l10n.ugcReasonInappropriate,
      UgcReportReason.other => l10n.ugcReasonOther,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.ugcReportTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final reason in UgcReportReason.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _reason == reason
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _reason == reason
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(label(reason)),
                onTap: () => setState(() => _reason = reason),
              ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(hintText: l10n.ugcReportDetails),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _ReportDraft(_reason, _details.text.trim()),
              ),
              child: Text(l10n.ugcReportSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
