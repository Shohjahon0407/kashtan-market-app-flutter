import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/json_read.dart';

final mapboxDirectionsProvider = Provider<MapboxDirections>(
  (ref) => MapboxDirections(),
);

class MapRouteData {
  const MapRouteData({
    required this.points,
    required this.duration,
    required this.distanceMeters,
    required this.fromMapbox,
  });

  factory MapRouteData.direct(LatLng from, LatLng to) {
    final meters = const Distance().distance(from, to);
    return MapRouteData(
      points: [from, to],
      duration: null,
      distanceMeters: meters,
      fromMapbox: false,
    );
  }

  final List<LatLng> points;
  final Duration? duration;
  final double distanceMeters;
  final bool fromMapbox;
}

/// Mapbox Directions faqat koordinatalarni oladi. Customer/order PII bu
/// klientga uzatilmaydi. Xato yoki token yo'qligida caller to'g'ri chiziq
/// fallbackini ishlatadi.
class MapboxDirections {
  MapboxDirections({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final Dio _dio;

  Future<MapRouteData?> route({
    required LatLng courier,
    required LatLng destination,
  }) async {
    final token = AppConfig.mapboxAccessToken.trim();
    if (token.isEmpty) return null;
    final coordinates =
        '${courier.longitude},${courier.latitude};'
        '${destination.longitude},${destination.latitude}';
    try {
      final response = await _dio.get<dynamic>(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates',
        queryParameters: {
          'access_token': token,
          'geometries': 'geojson',
          'overview': 'full',
          'steps': 'false',
        },
      );
      final body = JsonRead.map(response.data);
      final routes = body?['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final first = JsonRead.map(routes.first);
      final geometry = JsonRead.map(first?['geometry']);
      final rawCoordinates = geometry?['coordinates'];
      if (rawCoordinates is! List) return null;
      final points = <LatLng>[];
      for (final coordinate in rawCoordinates) {
        if (coordinate is! List || coordinate.length < 2) continue;
        final longitude = JsonRead.nullableDouble(coordinate[0]);
        final latitude = JsonRead.nullableDouble(coordinate[1]);
        if (latitude != null && longitude != null) {
          points.add(LatLng(latitude, longitude));
        }
      }
      if (points.length < 2) return null;
      final seconds = JsonRead.nullableDouble(first?['duration']);
      return MapRouteData(
        points: points,
        duration: seconds == null ? null : Duration(seconds: seconds.round()),
        distanceMeters:
            JsonRead.nullableDouble(first?['distance']) ??
            const Distance().distance(courier, destination),
        fromMapbox: true,
      );
    } on DioException {
      return null;
    }
  }
}
