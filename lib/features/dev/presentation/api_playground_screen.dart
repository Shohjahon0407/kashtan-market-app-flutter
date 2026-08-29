import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/ui/theme/app_colors.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';

/// 1-bosqichning "ishlaydigan natijasi".
///
/// Bu ekran core qatlamining uchma-uch ishlashini ISBOTLAYDI:
///   - Dio + interceptorlar haqiqiy `GET /home/` ni chaqiradi;
///   - til almashtirilganda `?lang=` o'zgaradi;
///   - kirill tanlansa server matni transliteratsiya qilinadi, lekin
///     UUID / URL / enum / rang kodlari TEGILMAYDI.
///
/// 2-bosqichda haqiqiy ekranlar qo'shilgach bu ekran `/dev` route'ida qoladi.
class ApiPlaygroundScreen extends ConsumerStatefulWidget {
  const ApiPlaygroundScreen({super.key});

  @override
  ConsumerState<ApiPlaygroundScreen> createState() =>
      _ApiPlaygroundScreenState();
}

class _ApiPlaygroundScreenState extends ConsumerState<ApiPlaygroundScreen> {
  Object? _response;
  ApiFailure? _failure;
  bool _loading = false;
  int _bytes = 0;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final data = await ref.read(apiClientProvider).get(Api.home);
      if (!mounted) return;
      setState(() {
        _response = data;
        _bytes = jsonEncode(data).length;
        _loading = false;
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e;
        _response = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devPlaygroundTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          Text(l10n.devPlaygroundSubtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),

          _LanguagePicker(
            current: locale,
            onChanged: (value) =>
                ref.read(localeControllerProvider.notifier).set(value),
          ),
          const SizedBox(height: AppSpacing.lg),

          _InfoCard(
            rows: [
              ('Origin', AppConfig.backendOrigin),
              ('Flavor', AppConfig.flavor.name),
              (l10n.devApiLang, locale.apiLang),
              (l10n.devScript, locale.script.name),
              if (_bytes > 0) (l10n.devResponseSize, '$_bytes B'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          FilledButton(
            onPressed: _loading ? null : _fetch,
            child: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('${l10n.devFetch}  ·  GET ${Api.home}'),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_failure != null) _FailureCard(failure: _failure!),
          if (_response != null) _ResponseView(response: _response!),
        ],
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.current, required this.onChanged});

  final AppLocale current;
  final ValueChanged<AppLocale> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppLocale>(
      segments: [
        for (final locale in AppLocale.values)
          ButtonSegment(value: locale, label: Text(locale.nativeName)),
      ],
      selected: {current},
      showSelectedIcon: false,
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(label, style: theme.textTheme.bodySmall),
                    ),
                    Expanded(
                      child: Text(value, style: theme.textTheme.titleSmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure});

  final ApiFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failure.runtimeType.toString(),
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.danger,
            ),
          ),
          if (failure.message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(failure.message, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Javobning muhim qismlarini ko'rsatadi: transliteratsiya ISHLAGANINI
/// (kategoriya nomlari) va ISHLAMAGANINI (UUID, URL, enum) bir ekranda.
class _ResponseView extends StatelessWidget {
  const _ResponseView({required this.response});

  final Object response;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (response is! Map<String, dynamic>) {
      return Text(jsonEncode(response));
    }
    final map = response as Map<String, dynamic>;

    final sections = <(String, int)>[
      for (final entry in map.entries)
        if (entry.value is List) (entry.key, (entry.value as List).length),
    ];

    final hub = (map['store_hub'] as List?) ?? const [];
    final categories = (map['categories'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seksiyalar', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (name, count) in sections)
              Chip(label: Text('$name · $count')),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        if (hub.isNotEmpty) ...[
          Text('store_hub', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final raw in hub.whereType<Map<String, dynamic>>())
            _KeyValueBlock(
              title: '${raw['label']}',
              // Transliteratsiya QILINADI: label, subtitle, badge
              // TEGILMAYDI: store_type, icon_key, style/layout enum'lari
              entries: [
                ('label ✎', '${raw['label']}'),
                ('subtitle ✎', '${raw['subtitle']}'),
                ('store_type ✗', '${raw['store_type']}'),
                (
                  'layout.card_variant ✗',
                  '${(raw['layout'] as Map?)?['card_variant']}',
                ),
                (
                  'style.background_start ✗',
                  '${(raw['style'] as Map?)?['background_start']}',
                ),
                ('background_image ✗', '${raw['background_image']}'),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
        ],

        if (categories.isNotEmpty) ...[
          Text('categories', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final raw in categories.whereType<Map<String, dynamic>>().take(
            6,
          ))
            _KeyValueBlock(
              title: '${raw['name']}',
              entries: [
                ('name ✎', '${raw['name']}'),
                ('id ✗', '${raw['id']}'),
                ('store_type ✗', '${raw['store_type']}'),
              ],
            ),
        ],

        const SizedBox(height: AppSpacing.xl),
        Text(
          '✎ = transliteratsiya qilinadi   ✗ = tegilmaydi',
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _KeyValueBlock extends StatelessWidget {
  const _KeyValueBlock({required this.title, required this.entries});

  final String title;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final (key, value) in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 170,
                        child: Text(key, style: theme.textTheme.labelSmall),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
