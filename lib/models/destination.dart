import 'package:maplibre_gl/maplibre_gl.dart';

import 'campus_building.dart';
import 'campus_place.dart';
import 'place_category.dart';

/// Something the user can select and get directions to: a building or a place.
class Destination {
  const Destination._({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.point,
    this.building,
    this.place,
  });

  factory Destination.building(CampusBuilding b) => Destination._(
    id: b.id,
    title: b.title,
    subtitle: [
      ...b.aliases,
      if (b.precinct.isNotEmpty) '${b.precinct} precinct',
      if (b.underConstruction) 'Under construction (Aug 2024 map)',
      if (!b.hasLabel) 'No number on the CDU map',
    ].join(' · '),
    point: b.centre,
    building: b,
  );

  /// [inBuilding] is the building the place is in, if any.
  factory Destination.place(CampusPlace p, {CampusBuilding? inBuilding}) =>
      Destination._(
        id: p.id,
        title: p.name,
        subtitle: [
          PlaceCategory.of(p.category).label,
          if (inBuilding != null && !p.name.contains(inBuilding.label))
            'in ${inBuilding.label}',
        ].join(' · '),
        point: p.point,
        building: inBuilding,
        place: p,
      );

  final String id;
  final String title;
  final String subtitle;
  final LatLng point;

  /// The building itself, or the building a place is inside.
  final CampusBuilding? building;
  final CampusPlace? place;

  bool get isPlace => place != null;

  /// Building to outline on the map and to route to (its entrances).
  String? get buildingId => building?.id;
}
