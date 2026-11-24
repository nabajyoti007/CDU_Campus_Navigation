import 'package:maplibre_gl/maplibre_gl.dart';

/// A place on campus from assets/campus/places.geojson: toilets, food, the
/// library, a theatre, a garden, a car park, a bus stop ...
class CampusPlace {
  const CampusPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryName,
    required this.point,
    this.building = '',
    this.buildingId = '',
    this.aliases = const [],
    this.source = '',
  });

  final String id;
  final String name;

  /// Machine name, e.g. 'toilets', 'food', 'library' (see PlaceCategory).
  final String category;

  /// Display name, e.g. 'Toilets', 'Food & café'.
  final String categoryName;
  final LatLng point;

  /// Building label it is in ("Red 6"), or empty when outdoors.
  final String building;
  final String buildingId;
  final List<String> aliases;
  final String source;

  bool get inBuilding => buildingId.isNotEmpty;

  /// How well [query] fits: 0 = in the name, 1 = in its keywords,
  /// 2 = only via the category or building. Lower is better.
  int matchRank(String query) {
    final q = query.trim().toLowerCase();
    if (name.toLowerCase().contains(q)) return 0;
    if (aliases.any((a) => a.toLowerCase().contains(q))) return 1;
    return 2;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    final words = [
      name,
      categoryName,
      building,
      ...aliases,
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(words.contains);
  }

  factory CampusPlace.fromFeature(Map<String, dynamic> f) {
    final p = f['properties'] as Map<String, dynamic>;
    final c = (f['geometry']['coordinates'] as List).cast<num>();
    return CampusPlace(
      id: p['id'] as String,
      name: p['name'] as String,
      category: p['category'] as String,
      categoryName: p['categoryName'] as String? ?? '',
      point: LatLng(c[1].toDouble(), c[0].toDouble()),
      building: p['building'] as String? ?? '',
      buildingId: p['buildingId'] as String? ?? '',
      aliases: [for (final a in p['aliases'] as List? ?? const []) a as String],
      source: p['source'] as String? ?? '',
    );
  }
}
