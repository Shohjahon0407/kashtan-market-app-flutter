import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../generated/l10n/app_localizations.dart';
import '../../config/app_config.dart';

/// Shared, cached map tiles with optional neutral colors.
///
/// Tile manbasi o'zgarmaydi: filtr faqat clientda ranglarni neytrallashtiradi.
class NeutralMapTiles extends StatelessWidget {
  const NeutralMapTiles({
    required this.urlTemplate,
    required this.userAgentPackageName,
    this.maxZoom = 20,
    this.onTileError,
    this.neutralize = false,
    super.key,
  });

  final String urlTemplate;
  final String userAgentPackageName;
  final double maxZoom;
  final VoidCallback? onTileError;

  /// Keep provider colors by default so roads and parks remain legible.
  final bool neutralize;

  static const _neutralFilter = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    18,
    0.2126,
    0.7152,
    0.0722,
    0,
    18,
    0.2126,
    0.7152,
    0.0722,
    0,
    18,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    // Mapbox's 512px tiles cover four 256px tiles. Match the projection with
    // a zoom offset; native retina tiles keep labels sharp without fetching
    // four extra tiles. NetworkTileProvider preserves its built-in HTTP cache.
    final largeTiles =
        Uri.tryParse(urlTemplate)?.host == 'api.mapbox.com' &&
        urlTemplate.contains('/tiles/512/');
    final tiles = TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: userAgentPackageName,
      tileDimension: largeTiles ? 512 : 256,
      zoomOffset: largeTiles ? -1 : 0,
      retinaMode: largeTiles && RetinaMode.isHighDensity(context),
      maxZoom: maxZoom,
      errorTileCallback: (_, _, _) => onTileError?.call(),
    );
    return neutralize
        ? ColorFiltered(colorFilter: _neutralFilter, child: tiles)
        : tiles;
  }
}

/// Keep the provider logo visible; long credits open from the adjacent info
/// control instead of covering the mini-map. OSM-only maps retain a text link.
class MapTileAttribution extends StatelessWidget {
  const MapTileAttribution({this.useMapbox, super.key});

  final bool? useMapbox;

  static final _mapboxUrl = Uri.parse('https://www.mapbox.com/about/maps/');
  static final _osmUrl = Uri.parse('https://www.openstreetmap.org/copyright');
  static final _feedbackUrl = Uri.parse('https://apps.mapbox.com/feedback/');

  void _showSources(BuildContext context) {
    final title =
        Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        )?.mapAttributionTitle ??
        MaterialLocalizations.of(context).licensesPageTitle;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                for (final source in [
                  ('© Mapbox', _mapboxUrl),
                  ('© OpenStreetMap', _osmUrl),
                  ('Improve this map', _feedbackUrl),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _AttributionLink(
                      label: source.$1,
                      uri: source.$2,
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (useMapbox ?? AppConfig.usesMapboxTiles) {
      final title =
          Localizations.of<AppLocalizations>(
            context,
            AppLocalizations,
          )?.mapAttributionTitle ??
          MaterialLocalizations.of(context).licensesPageTitle;
      return Row(
        key: const ValueKey('map-attribution-compact'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              key: const ValueKey('map-attribution-logo'),
              onTap: () =>
                  launchUrl(_mapboxUrl, mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox(
                  width: 65,
                  height: 20,
                  child: SvgPicture.asset(
                    'assets/brand/mapbox-logo-black.svg',
                    fit: BoxFit.contain,
                    semanticsLabel: 'Mapbox',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: 36,
            child: Material(
              color: Colors.white.withValues(alpha: .94),
              shape: const CircleBorder(),
              child: IconButton(
                key: const ValueKey('map-attribution-info'),
                tooltip: title,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.info_outline,
                  size: 19,
                  color: Color(0xFF263238),
                ),
                onPressed: () => _showSources(context),
              ),
            ),
          ),
        ],
      );
    }
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: _AttributionLink(label: '© OpenStreetMap', uri: _osmUrl),
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.uri,
    this.fontSize = 10,
  });

  final String label;
  final Uri uri;
  final double fontSize;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
    child: Text(
      label,
      style: TextStyle(
        color: const Color(0xFF263238),
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}

class MapZoomControls extends StatelessWidget {
  const MapZoomControls({
    required this.controller,
    required this.zoomInTooltip,
    required this.zoomOutTooltip,
    this.minZoom = 3,
    this.maxZoom = 19,
    super.key,
  });

  final MapController controller;
  final String zoomInTooltip;
  final String zoomOutTooltip;
  final double minZoom;
  final double maxZoom;

  void _zoomBy(double delta) {
    final camera = controller.camera;
    final zoom = (camera.zoom + delta).clamp(minZoom, maxZoom).toDouble();
    controller.moveAndRotate(camera.center, zoom, 0);
  }

  @override
  Widget build(BuildContext context) => _MapControlSurface(
    children: [
      _MapIconButton(
        icon: Icons.add,
        tooltip: zoomInTooltip,
        onPressed: () => _zoomBy(1),
      ),
      const Divider(height: 1),
      _MapIconButton(
        icon: Icons.remove,
        tooltip: zoomOutTooltip,
        onPressed: () => _zoomBy(-1),
      ),
    ],
  );
}

class MapCurrentLocationButton extends StatelessWidget {
  const MapCurrentLocationButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 3,
    shadowColor: Colors.black26,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: loading ? null : onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: expanded
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.my_location_rounded, size: 20),
            const SizedBox(width: 8),
            // Katta shrift/kichik ekranda qator sinmasin — ellipsis.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapControlSurface extends StatelessWidget {
  const _MapControlSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 3,
    shadowColor: Colors.black26,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    icon: Icon(icon),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}
