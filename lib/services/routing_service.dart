import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/route_result.dart';

class RoutingService {
  static const _routeUrl = 'https://valhalla1.openstreetmap.de/route';

  Future<RouteResult> getWalkingRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final response = await http.post(
      Uri.parse(_routeUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'locations': [
          {'lat': start.latitude, 'lon': start.longitude},
          {'lat': destination.latitude, 'lon': destination.longitude},
        ],
        'costing': 'pedestrian',
        'format': 'osrm',
        'shape_format': 'geojson',
        'directions_type': 'instructions',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Routing server returned ${response.statusCode}.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;

    if (routes == null || routes.isEmpty) {
      throw Exception('No walking route was found.');
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;

    if (coordinates == null || coordinates.isEmpty) {
      throw Exception('The route did not contain map geometry.');
    }

    final points = coordinates.map((item) {
      final pair = item as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();

    return RouteResult(
      points: points,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  }
}
