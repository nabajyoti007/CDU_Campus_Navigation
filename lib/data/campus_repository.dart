import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/campus_building.dart';
import '../services/walk_graph.dart';

/// Loads the campus files built by campus_data/scripts/build_campus_data.py.
class CampusRepository {
  CampusRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const buildingsAsset = 'assets/campus/buildings.geojson';
  static const labelsAsset = 'assets/campus/labels.geojson';
  static const pathsAsset = 'assets/campus/paths.geojson';
  static const areasAsset = 'assets/campus/areas.geojson';
  static const walkGraphAsset = 'assets/campus/walk_graph.json';

  final AssetBundle _bundle;

  Map<String, dynamic>? buildingsGeoJson;
  Map<String, dynamic>? labelsGeoJson;
  Map<String, dynamic>? pathsGeoJson;
  Map<String, dynamic>? areasGeoJson;
  WalkGraph? walkGraph;
  final Map<String, CampusBuilding> buildings = {};

  Future<void> load() async {
    buildingsGeoJson = await _loadJson(buildingsAsset);
    labelsGeoJson = await _loadJson(labelsAsset);
    pathsGeoJson = await _loadJson(pathsAsset);
    areasGeoJson = await _loadJson(areasAsset);
    walkGraph = WalkGraph.fromJson(await _loadJson(walkGraphAsset));

    // Label points are placed inside each footprint, so reuse them as building centres.
    final centres = <String, LatLng>{};
    for (final f in labelsGeoJson!['features'] as List) {
      final coords = (f['geometry']['coordinates'] as List).cast<num>();
      centres[f['properties']['id'] as String] =
          LatLng(coords[1].toDouble(), coords[0].toDouble());
    }

    buildings.clear();
    for (final f in buildingsGeoJson!['features'] as List) {
      final feature = f as Map<String, dynamic>;
      final id = feature['properties']['id'] as String;
      final centre = centres[id] ?? _firstPoint(feature['geometry']);
      buildings[id] = CampusBuilding.fromFeature(feature, centre);
    }
  }

  /// Buildings that carry a PDF label, sorted by precinct then number.
  List<CampusBuilding> get labelledBuildings {
    final list = buildings.values.where((b) => b.hasLabel).toList();
    list.sort(_byLabel);
    return list;
  }

  List<CampusBuilding> search(String query) =>
      labelledBuildings.where((b) => b.matches(query)).toList();

  static int _byLabel(CampusBuilding a, CampusBuilding b) {
    final pa = a.label.split(' '), pb = b.label.split(' ');
    final c = pa.first.compareTo(pb.first);
    if (c != 0) return c;
    final na = int.tryParse(pa.length > 1 ? pa[1] : '') ?? 999;
    final nb = int.tryParse(pb.length > 1 ? pb[1] : '') ?? 999;
    return na != nb ? na.compareTo(nb) : a.label.compareTo(b.label);
  }

  Future<Map<String, dynamic>> _loadJson(String asset) async =>
      jsonDecode(await _bundle.loadString(asset)) as Map<String, dynamic>;

  static LatLng _firstPoint(dynamic geometry) {
    dynamic c = geometry['coordinates'];
    while (c is List && c.isNotEmpty && c.first is List) {
      c = c.first;
    }
    final p = (c as List).cast<num>();
    return LatLng(p[1].toDouble(), p[0].toDouble());
  }
}
