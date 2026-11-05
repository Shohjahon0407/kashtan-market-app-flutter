import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_buttons.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/uzbek_phone.dart';
import '../data/support_models.dart';
import '../domain/support_controller.dart';

class MissingProductRequestScreen extends StatelessWidget {
  const MissingProductRequestScreen({this.initialStoreType, super.key});

  final String? initialStoreType;

  @override
  Widget build(BuildContext context) => SupportCenterScreen(
    initialKind: SupportKind.missingProduct.wire,
    initialStoreType: initialStoreType,
    dedicatedMissingProduct: true,
  );
}

class SupportCenterScreen extends ConsumerStatefulWidget {
  const SupportCenterScreen({
    this.initialKind,
    this.initialStoreType,
    this.dedicatedMissingProduct = false,
    super.key,
  });

  final String? initialKind;
  final String? initialStoreType;
  final bool dedicatedMissingProduct;

  @override
  ConsumerState<SupportCenterScreen> createState() =>
      _SupportCenterScreenState();
}

class _SupportCenterScreenState extends ConsumerState<SupportCenterScreen> {
  static const _maxImageBytes = 8 * 1024 * 1024;
  static const _maxVoiceBytes = 10 * 1024 * 1024;
  static const _maxRecording = Duration(seconds: 120);

  final _messageController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();

  late SupportKind _kind;
  StoreType? _storeType;
  SupportMedia? _media;
  bool _isSubmitting = false;
  bool _isRecording = false;
  double? _uploadProgress;
  Timer? _recordTimer;
  Duration _recordElapsed = Duration.zero;
  String _recordExtension = 'm4a';

  @override
  void initState() {
    super.initState();
    final requestedKind = SupportKind.fromWire(widget.initialKind);
    _kind = widget.dedicatedMissingProduct
        ? SupportKind.missingProduct
        : requestedKind == SupportKind.missingProduct
        ? SupportKind.support
        : requestedKind;
    _storeType = StoreType.fromWire(widget.initialStoreType ?? '');
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    if (_isRecording) unawaited(_recorder.cancel());
    _recorder.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _chooseImageSource() async {
    if (kIsWeb) {
      await _pickImage(ImageSource.gallery);
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(AppLocalizations.of(context).supportTakePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppLocalizations.of(context).supportChooseGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxImageBytes) {
        _snack(l10n.supportImageTooLarge);
        return;
      }
      setState(() {
        _media = SupportMedia(
          kind: SupportMediaKind.image,
          bytes: bytes,
          filename: file.name.isEmpty ? 'request.jpg' : file.name,
        );
      });
    } on Object {
      _snack(l10n.supportMediaReadFailed);
    }
  }

  Future<(AudioEncoder, String)> _voiceFormat() async {
    if (!kIsWeb && await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      return (AudioEncoder.aacLc, 'm4a');
    }
    if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
      return (AudioEncoder.opus, kIsWeb ? 'webm' : 'ogg');
    }
    if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      return (AudioEncoder.aacLc, 'm4a');
    }
    return (AudioEncoder.wav, 'wav');
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    try {
      if (!await _recorder.hasPermission()) {
        _snack(l10n.supportMicrophoneDenied);
        return;
      }
      final (encoder, extension) = await _voiceFormat();
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/support_${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordElapsed = Duration.zero;
        _recordExtension = extension;
        _media = null;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording) return;
        final next = _recordElapsed + const Duration(seconds: 1);
        setState(() => _recordElapsed = next);
        if (next >= _maxRecording) unawaited(_stopRecording());
      });
    } on Object {
      _snack(l10n.supportRecordingFailed);
    }
  }

  Future<void> _stopRecording({bool keep = true}) async {
    _recordTimer?.cancel();
    if (!_isRecording) return;
    final l10n = AppLocalizations.of(context);
    try {
      final output = keep ? await _recorder.stop() : null;
      if (!keep) await _recorder.cancel();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (!keep || output == null || output.isEmpty) return;
      final bytes = await XFile(output).readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxVoiceBytes) {
        _snack(l10n.supportVoiceTooLarge);
        return;
      }
      setState(() {
        _media = SupportMedia(
          kind: SupportMediaKind.voice,
          bytes: bytes,
          filename:
              'voice_${DateTime.now().millisecondsSinceEpoch}.$_recordExtension',
        );
      });
    } on Object {
      if (mounted) setState(() => _isRecording = false);
      _snack(l10n.supportRecordingFailed);
    }
  }

  Future<bool> _ensureContactName() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(authControllerProvider).user;
    if (current != null &&
        current.firstName.trim().isNotEmpty &&
        current.lastName.trim().isNotEmpty) {
      return true;
    }
    final result = await showDialog<(String, String)>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ContactNameDialog(),
    );
    if (result == null) return false;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateName(firstName: result.$1, lastName: result.$2);
      return true;
    } on ApiFailure catch (failure) {
      _snack(failure.localize(l10n));
      return false;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isRecording) return;
    final l10n = AppLocalizations.of(context);
    final message = _messageController.text.trim();
    if (message.isEmpty && _media == null) {
      _snack(l10n.supportAtLeastOne);
      return;
    }
    if (_kind == SupportKind.missingProduct && _storeType == null) {
      _snack(l10n.supportSelectStore);
      return;
    }
    if (!await _ensureContactName()) return;
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
    });
    try {
      final ticket = await ref
          .read(supportApiProvider)
          .createTicket(
            kind: _kind,
            message: message,
            storeType: _kind == SupportKind.missingProduct
                ? _storeType?.wire
                : null,
            media: _media,
            onSendProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _uploadProgress = sent / total);
              }
            },
          );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _media = null;
        _uploadProgress = null;
      });
      ref.invalidate(supportTicketsProvider);
      final shortId = _shortTicketId(ticket.id);
      _snack(
        widget.dedicatedMissingProduct || shortId.isEmpty
            ? l10n.supportSent
            : '${l10n.supportSent} #$shortId',
      );
    } on ApiFailure catch (failure) {
      _snack(failure.localize(l10n));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Widget _buildMissingProduct(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          onPressed: () => appBack(context),
          icon: const Icon(Icons.close),
        ),
        titleSpacing: 0,
        title: Text(
          l10n.supportMissingProductTitle.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.xxl,
                  ),
                  children: [
                    Text(
                      l10n.supportMissingProductSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _NumberedSection(
                      number: '01',
                      title: l10n.homeRequestText,
                      child: TextField(
                        key: const ValueKey('missing-product-message'),
                        controller: _messageController,
                        enabled: !_isSubmitting,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          hintText: l10n.supportMissingProductHint,
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: colors.surfaceContainerLow,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ),
                    _NumberedSection(
                      number: '02',
                      title: l10n.homeRequestImage,
                      trailing: Text(
                        l10n.supportOneAttachment,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                      child: _media?.kind == SupportMediaKind.image
                          ? _DedicatedAttachment(
                              media: _media!,
                              onRemove: () => setState(() => _media = null),
                              onReplace: _isSubmitting
                                  ? null
                                  : _chooseImageSource,
                            )
                          : _UploadTile(
                              label: l10n.supportAddImage,
                              enabled: !_isSubmitting && !_isRecording,
                              onTap: _chooseImageSource,
                            ),
                    ),
                    _NumberedSection(
                      number: '03',
                      title: l10n.homeRequestVoice,
                      child: _VoiceRequestPanel(
                        recording: _isRecording,
                        attached: _media?.kind == SupportMediaKind.voice,
                        elapsed: _recordElapsed,
                        enabled: !_isSubmitting,
                        onPressed: _isRecording
                            ? _stopRecording
                            : _startRecording,
                        onRemove: _media?.kind == SupportMediaKind.voice
                            ? () => setState(() => _media = null)
                            : null,
                      ),
                    ),
                    _NumberedSection(
                      number: '04',
                      title: l10n.supportChooseStoreQuestion,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final store in StoreType.values)
                            ChoiceChip(
                              key: ValueKey(
                                'missing-product-store-${store.wire}',
                              ),
                              label: Text(_storeLabel(l10n, store)),
                              selected: _storeType == store,
                              showCheckmark: false,
                              onSelected: _isSubmitting
                                  ? null
                                  : (_) => setState(() => _storeType = store),
                              selectedColor: colors.primary,
                              labelStyle: theme.textTheme.labelSmall?.copyWith(
                                color: _storeType == store
                                    ? colors.onPrimary
                                    : colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2),
                                side: BorderSide(
                                  color: _storeType == store
                                      ? colors.primary
                                      : colors.outlineVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_uploadProgress != null) ...[
                        LinearProgressIndicator(value: _uploadProgress),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          key: const ValueKey('missing-product-submit'),
                          onPressed: _isSubmitting || _isRecording
                              ? null
                              : _submit,
                          style: FilledButton.styleFrom(
                            shape: const RoundedRectangleBorder(),
                          ),
                          child: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  l10n.supportSend.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.supportResponseHint,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (widget.dedicatedMissingProduct) {
      return _buildMissingProduct(context, l10n, theme);
    }
    final user = ref.watch(authControllerProvider).user;
    final history = ref.watch(supportTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.supportCenterTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(supportTicketsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xxxl,
          ),
          children: [
            Text(l10n.supportFormIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final kind in const [
                  SupportKind.suggestion,
                  SupportKind.support,
                ])
                  ChoiceChip(
                    avatar: Icon(_kindIcon(kind), size: 18),
                    label: Text(_kindLabel(l10n, kind)),
                    selected: _kind == kind,
                    onSelected: _isSubmitting
                        ? null
                        : (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
            if (_kind == SupportKind.missingProduct) ...[
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<StoreType>(
                key: ValueKey(_storeType),
                initialValue: _storeType,
                decoration: InputDecoration(labelText: l10n.supportStoreLabel),
                items: [
                  for (final store in StoreType.values)
                    DropdownMenuItem(
                      value: store,
                      child: Text(_storeLabel(l10n, store)),
                    ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _storeType = value),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName
                                : l10n.supportContactMissing,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (user != null)
                            Text(
                              UzbekPhone.formatFull(user.phoneNumber),
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _messageController,
              enabled: !_isSubmitting,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.supportMessageLabel,
                hintText: _kindHint(l10n, _kind),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_media != null)
              _MediaPreview(
                media: _media!,
                onRemove: () => setState(() => _media = null),
              ),
            if (_isRecording)
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(l10n.supportRecording),
                  subtitle: Text(_durationText(_recordElapsed)),
                  trailing: IconButton(
                    tooltip: l10n.supportStopRecording,
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop_circle_outlined),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting || _isRecording
                        ? null
                        : _chooseImageSource,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l10n.supportAddImage),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : _isRecording
                        ? _stopRecording
                        : _startRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic_none),
                    label: Text(
                      _isRecording
                          ? l10n.supportStopRecording
                          : l10n.supportRecordVoice,
                    ),
                  ),
                ),
              ],
            ),
            if (_uploadProgress != null) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: _uploadProgress),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _isSubmitting || _isRecording ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _isSubmitting ? l10n.supportSending : l10n.supportSend,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              l10n.supportHistory,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            switch (history) {
              AsyncData(:final value) when value.isEmpty => _HistoryEmpty(
                text: l10n.supportHistoryEmpty,
              ),
              AsyncData(:final value) => Column(
                children: [
                  for (final ticket in value) ...[
                    _TicketCard(ticket: ticket),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
              AsyncError(:final error) => _HistoryEmpty(
                text: error is ApiFailure
                    ? error.localize(l10n)
                    : l10n.errorUnknown,
                action: TextButton(
                  onPressed: () => ref.invalidate(supportTicketsProvider),
                  child: Text(l10n.commonRetry),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ],
        ),
      ),
    );
  }
}

class _NumberedSection extends StatelessWidget {
  const _NumberedSection({
    required this.number,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String number;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '$number · ${title.toUpperCase()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Divider(color: colors.outlineVariant)),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('missing-product-add-image'),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 104,
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: colors.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
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

class _DedicatedAttachment extends StatelessWidget {
  const _DedicatedAttachment({
    required this.media,
    required this.onRemove,
    required this.onReplace,
  });

  final SupportMedia media;
  final VoidCallback onRemove;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.memory(
              media.bytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.supportImageAttached,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.supportAddImage,
            onPressed: onReplace,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.supportRemoveAttachment,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _VoiceRequestPanel extends StatelessWidget {
  const _VoiceRequestPanel({
    required this.recording,
    required this.attached,
    required this.elapsed,
    required this.enabled,
    required this.onPressed,
    required this.onRemove,
  });

  final bool recording;
  final bool attached;
  final Duration elapsed;
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: double.infinity,
            child: FilledButton(
              key: const ValueKey('missing-product-voice'),
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(),
              ),
              child: Icon(recording ? Icons.stop : Icons.mic_none),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: attached || recording
                ? Row(
                    children: [
                      for (final height in const [
                        8.0,
                        18.0,
                        12.0,
                        25.0,
                        16.0,
                        22.0,
                        10.0,
                        19.0,
                        14.0,
                        24.0,
                        11.0,
                        18.0,
                      ])
                        Expanded(
                          child: Center(
                            child: Container(
                              height: height,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              color: colors.primary.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                    ],
                  )
                : Text(
                    l10n.supportRecordVoice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            recording
                ? _durationText(elapsed)
                : attached
                ? l10n.commonDone
                : '',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: l10n.supportRemoveAttachment,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            )
          else
            const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media, required this.onRemove});
  final SupportMedia media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (media.kind == SupportMediaKind.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.memory(
                  media.bytes,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              )
            else
              const SizedBox.square(
                dimension: 64,
                child: Icon(Icons.graphic_eq, size: 36),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                media.kind == SupportMediaKind.image
                    ? l10n.supportImageAttached
                    : l10n.supportVoiceAttached,
              ),
            ),
            IconButton(
              tooltip: l10n.supportRemoveAttachment,
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final date = ticket.createdAt == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm').format(ticket.createdAt!);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_kindIcon(ticket.kind), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _kindLabel(l10n, ticket.kind),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(status: ticket.status),
              ],
            ),
            if (ticket.message.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                ticket.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(date, style: theme.textTheme.bodySmall),
                const Spacer(),
                if (ticket.attachment != null)
                  Icon(
                    ticket.attachment!.kind == SupportMediaKind.image
                        ? Icons.image_outlined
                        : Icons.mic_none,
                    size: 18,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final SupportStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      SupportStatus.open => (l10n.supportStatusOpen, colors.primary),
      SupportStatus.inProgress => (
        l10n.supportStatusInProgress,
        colors.tertiary,
      ),
      SupportStatus.closed => (l10n.supportStatusClosed, colors.outline),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
    child: Column(
      children: [
        Icon(
          Icons.forum_outlined,
          size: 42,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(text, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}

class _ContactNameDialog extends StatefulWidget {
  const _ContactNameDialog();

  @override
  State<_ContactNameDialog> createState() => _ContactNameDialogState();
}

class _ContactNameDialogState extends State<_ContactNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      // Klaviatura ochilganda kontent siqilmasin — o'zi skroll bo'ladi.
      scrollable: true,
      title: Text(l10n.supportContactNeededTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.supportContactNeededSubtitle),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.supportFirstName),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.commonFieldRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.supportLastName),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.commonFieldRequired
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: AppButtons.dialogAction,
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, (
              _firstName.text.trim(),
              _lastName.text.trim(),
            ));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

IconData _kindIcon(SupportKind kind) => switch (kind) {
  SupportKind.missingProduct => Icons.add_shopping_cart,
  SupportKind.suggestion => Icons.lightbulb_outline,
  SupportKind.support => Icons.support_agent,
};

String _kindLabel(AppLocalizations l10n, SupportKind kind) => switch (kind) {
  SupportKind.missingProduct => l10n.supportMissingProductTitle,
  SupportKind.suggestion => l10n.supportSuggestionTitle,
  SupportKind.support => l10n.supportHelpTitle,
};

String _kindHint(AppLocalizations l10n, SupportKind kind) => switch (kind) {
  SupportKind.missingProduct => l10n.supportMissingProductHint,
  SupportKind.suggestion => l10n.supportSuggestionHint,
  SupportKind.support => l10n.supportHelpHint,
};

String _storeLabel(AppLocalizations l10n, StoreType store) => switch (store) {
  StoreType.grocery => l10n.storeGrocery,
  StoreType.household => l10n.storeHousehold,
  StoreType.restaurant => l10n.storeRestaurant,
  StoreType.shashlik => l10n.storeShashlik,
  StoreType.meat => l10n.storeMeat,
};

/// Ticket id'ning qisqa ko'rinishi. Id 8 belgidan qisqa bo'lsa (bo'sh yoki
/// butun son) `substring` RangeError bermasligi uchun to'liq qaytariladi.
String _shortTicketId(String id) => id.length <= 8 ? id : id.substring(0, 8);

String _durationText(Duration value) {
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds / 02:00';
}
