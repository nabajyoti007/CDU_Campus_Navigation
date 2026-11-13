import 'package:maplibre_gl/maplibre_gl.dart';

/// A CDU building from assets/campus/buildings.geojson.
class CampusBuilding {
  const CampusBuilding({
    required this.id,
    required this.label,
    required this.precinct,
    required this.colourHex,
    required this.source,
    required this.underConstruction,
    required this.centre,
    this.aliases = const [],
  });

  /// Facility names the PDF's Open Day inset points at this building, e.g. "Library".
  final List<String> aliases;

  final String id;

  /// Label as printed on the CDU PDF map, e.g. "Red 6". Empty if the PDF has no number.
  final String label;

  /// "Red", "Blue", ... or empty.
  final String precinct;
  final String colourHex;

  /// "osm", "pdf" or "osm+pdf" - where the shape came from.
  final String source;
  final bool underConstruction;

  /// A point inside the footprint (used for the camera and, later, routing).
  final LatLng centre;

  bool get hasLabel => label.isNotEmpty;

  String get title => hasLabel ? label : 'Unnumbered building';

  /// True if [query] matches the label, a facility name or "building N".
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return hasLabel;
    if (!hasLabel) return false;
    final words = [label, ...aliases].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every((w) => words.contains(w));
  }

  factory CampusBuilding.fromFeature(
    Map<String, dynamic> feature,
    LatLng centre,
  ) {
    final p = feature['properties'] as Map<String, dynamic>;
    return CampusBuilding(
      id: p['id'] as String,
      label: p['label'] as String? ?? '',
      precinct: p['precinct'] as String? ?? '',
      colourHex: p['colour'] as String? ?? '#B9B4C7',
      source: p['source'] as String? ?? '',
      underConstruction: p['underConstruction'] as bool? ?? false,
      centre: centre,
      aliases: [for (final a in p['aliases'] as List? ?? const []) a as String],
    );
  }
}
