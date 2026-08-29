import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';

/// Barcha xaritalar uchun bir xil, chalg'itmaydigan oq-kulrang tile ko'rinishi.
///
/// Tile manbasi o'zgarmaydi: filtr faqat clientda ranglarni neytrallashtiradi.
class NeutralMapTiles extends StatelessWidget {
  const NeutralMapTiles({
    required this.urlTemplate,
    required this.userAgentPackageName,
    this.maxZoom = 20,
    super.key,
  });

  final String urlTemplate;
  final String userAgentPackageName;
  final double maxZoom;

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
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: _neutralFilter,
    child: TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: userAgentPackageName,
      maxZoom: maxZoom,
    ),
  );
}

/// Tile provayderining litsenziya attribution'i har doim xarita ustida
/// ko'rinadi. Mapbox OSM ma'lumotlaridan foydalangani uchun ikkala manba ham
/// ko'rsatiladi; debug OSM fallbackda faqat OpenStreetMap chiqadi.
class MapTileAttribution extends StatelessWidget {
  const MapTileAttribution({super.key});

  static final _mapboxUrl = Uri.parse('https://www.mapbox.com/about/maps/');
  static final _osmUrl = Uri.parse('https://www.openstreetmap.org/copyright');

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.88),
    borderRadius: BorderRadius.circular(4),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (AppConfig.usesMapboxTiles) ...[
            _AttributionLink(label: '© Mapbox', uri: _mapboxUrl),
            const Text(' · ', style: TextStyle(fontSize: 10)),
          ],
          _AttributionLink(label: '© OpenStreetMap', uri: _osmUrl),
        ],
      ),
    ),
  );
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF263238),
        fontSize: 10,
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
