import 'package:maplibre_gl/maplibre_gl.dart';

import '../data/campus_repository.dart';
import '../models/place_category.dart';
import '../services/campus_router.dart';
import 'place_icons.dart';

/// Map style and layers: a flat, real street map with the CDU campus drawn
/// in the style of the official CDU map (Aug 2024 PDF).
///
/// Base map: OpenFreeMap "Liberty" (OpenStreetMap data, no API key) with its
/// 3D buildings and generic place icons switched off.
/// On top, bottom to top: PDF precinct ground colours, footpaths, CDU buildings
/// (flat, precinct colour, dark edge, soft shadow), routes, then labels.
class CampusLayers {
  CampusLayers(this.controller, {this.iconScale = 1});

  final MapLibreMapController controller;

  /// Map icon images are drawn in physical pixels on Android/iOS but in
  /// screen (CSS) pixels on the web; pass the phone's pixel ratio on phones
  /// so icons are the same size everywhere.
  final double iconScale;

  /// Zoom from which place names and facility icons appear. Further out the
  /// map stays clean: building numbers and the main places' icons only.
  static const double namesFromZoom = 17.3;
  static const double facilitiesFromZoom = 16.8;

  static const baseStyle = 'https://tiles.openfreemap.org/styles/liberty';

  static const buildingsLayer = 'cdu-buildings-fill';
  static const routeAltLayer = 'cdu-route-alt';
  static const placeLayers = ['cdu-places-major', 'cdu-places-minor'];
  static const _selectedLayer = 'cdu-buildings-selected';

  static const _areas = 'cdu-areas';
  static const _paths = 'cdu-paths';
  static const _buildings = 'cdu-buildings';
  static const _labels = 'cdu-labels';
  static const _route = 'cdu-route';
  static const _routeEnds = 'cdu-route-ends';
  static const _me = 'cdu-me';
  static const _places = 'cdu-places';

  static const _emptyCollection = {'type': 'FeatureCollection', 'features': []};

  Future<void> addAll(CampusRepository campus) async {
    // Flat map: hide the base map's 3D buildings and generic POI icons.
    for (final id in ['building-3d', 'poi_r20', 'poi_r7', 'poi_r1']) {
      try {
        await controller.setLayerVisibility(id, false);
      } catch (_) {}
    }

    await controller.addGeoJsonSource(_areas, campus.areasGeoJson!);
    await controller.addGeoJsonSource(
      _paths,
      campus.pathsGeoJson!,
      promoteId: 'id',
    );
    await controller.addGeoJsonSource(
      _buildings,
      campus.buildingsGeoJson!,
      promoteId: 'id',
    );
    await controller.addGeoJsonSource(
      _labels,
      campus.labelsGeoJson!,
      promoteId: 'id',
    );
    await controller.addGeoJsonSource(_route, _emptyCollection);
    await controller.addGeoJsonSource(_routeEnds, _emptyCollection);
    await controller.addGeoJsonSource(_me, _emptyCollection);
    await controller.addGeoJsonSource(
      _places,
      campus.placesGeoJson!,
      promoteId: 'id',
    );
    for (final e in (await PlaceIcons.render()).entries) {
      await controller.addImage(e.key, e.value);
    }

    // 1. Precinct ground colours from the CDU map, under the roads.
    const areaProps = FillLayerProperties(
      fillColor: ['get', 'colour'],
      fillOpacity: [
        'interpolate',
        ['linear'],
        ['zoom'],
        14,
        0.5,
        17,
        0.85,
      ],
    );
    try {
      await controller.addFillLayer(
        _areas,
        'cdu-areas-fill',
        areaProps,
        belowLayerId: 'waterway_tunnel',
        enableInteraction: false,
      );
    } catch (_) {
      await controller.addFillLayer(
        _areas,
        'cdu-areas-fill',
        areaProps,
        enableInteraction: false,
      );
    }

    // 2. Footpaths: white with a soft edge, as on the printed map.
    await controller.addLineLayer(
      _paths,
      'cdu-paths-casing',
      const LineLayerProperties(
        lineColor: '#9F96BE',
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          14.5,
          2.0,
          16,
          4.0,
          19,
          13.0,
        ],
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _paths,
      'cdu-paths-line',
      const LineLayerProperties(
        lineColor: '#FFFFFF',
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          14.5,
          1.0,
          16,
          2.4,
          19,
          9.0,
        ],
        lineCap: 'round',
        lineJoin: 'round',
      ),
      enableInteraction: false,
    );

    // 3. CDU buildings, flat, like the PDF: soft shadow, precinct colour, darker edge.
    await controller.addFillLayer(
      _buildings,
      'cdu-buildings-shadow',
      const FillLayerProperties(
        fillColor: '#1B1640',
        fillOpacity: 0.28,
        fillTranslate: [2.5, 2.5],
      ),
      enableInteraction: false,
    );
    await controller.addFillLayer(
      _buildings,
      buildingsLayer,
      const FillLayerProperties(fillColor: ['get', 'colour'], fillOpacity: 1.0),
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _buildings,
      'cdu-buildings-edge',
      const LineLayerProperties(
        lineColor: ['get', 'outline'],
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          0.5,
          19,
          2.0,
        ],
      ),
      enableInteraction: false,
    );
    // Selected building: thick CDU-navy outline.
    await controller.addLineLayer(
      _buildings,
      _selectedLayer,
      const LineLayerProperties(
        lineColor: '#211858',
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          2.5,
          19,
          6.0,
        ],
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'id'],
        '',
      ],
      enableInteraction: false,
    );

    // 4. Routes: grey alternatives, blue chosen route, dotted last metres.
    await controller.addLineLayer(
      _route,
      routeAltLayer,
      const LineLayerProperties(
        lineColor: '#9AA6B4',
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          4.0,
          19,
          12.0,
        ],
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        'all',
        [
          '==',
          ['get', 'kind'],
          'route',
        ],
        [
          '==',
          ['get', 'selected'],
          false,
        ],
      ],
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _route,
      'cdu-route-casing',
      const LineLayerProperties(
        lineColor: '#1A56C7',
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          6.0,
          19,
          15.0,
        ],
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        'all',
        [
          '==',
          ['get', 'kind'],
          'route',
        ],
        [
          '==',
          ['get', 'selected'],
          true,
        ],
      ],
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _route,
      'cdu-route-line',
      const LineLayerProperties(
        lineColor: '#4C8DF6',
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          3.5,
          19,
          10.0,
        ],
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        'all',
        [
          '==',
          ['get', 'kind'],
          'route',
        ],
        [
          '==',
          ['get', 'selected'],
          true,
        ],
      ],
      enableInteraction: false,
    );
    await controller.addLineLayer(
      _route,
      'cdu-route-connector',
      const LineLayerProperties(
        lineColor: '#1A56C7',
        lineWidth: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          2.0,
          19,
          5.0,
        ],
        lineDasharray: [0.6, 1.8],
        lineCap: 'round',
      ),
      filter: [
        '==',
        ['get', 'kind'],
        'connector',
      ],
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _routeEnds,
      'cdu-route-ends',
      const CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          5.0,
          19,
          10.0,
        ],
        circleColor: [
          'match',
          ['get', 'kind'],
          'start',
          '#FFFFFF',
          '#EA4335',
        ],
        circleStrokeColor: [
          'match',
          ['get', 'kind'],
          'start',
          '#1A56C7',
          '#FFFFFF',
        ],
        circleStrokeWidth: 3,
      ),
      enableInteraction: false,
    );

    // 5. Labels.
    // Building numbers printed on the buildings, like the PDF; full name ("Red 6") when close.
    await controller.addSymbolLayer(
      _labels,
      'cdu-building-labels',
      const SymbolLayerProperties(
        textField: [
          'step',
          ['zoom'],
          ['get', 'number'],
          namesFromZoom,
          ['get', 'label'],
        ],
        textFont: ['Noto Sans Bold'],
        textSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15.5,
          10,
          17.5,
          15,
          19,
          16,
        ],
        textColor: [
          'match',
          ['get', 'precinct'],
          'Yellow',
          '#211858',
          '#FFFFFF',
        ],
        textHaloColor: 'rgba(0,0,0,0.35)',
        textHaloWidth: 0.8,
        textPadding: 1,
        symbolSortKey: [
          '-',
          0,
          ['get', 'area'],
        ],
      ),
      filter: [
        '==',
        ['get', 'kind'],
        'building',
      ],
      minzoom: 15.6,
      enableInteraction: false,
    );
    // Precinct banners ("RED PRECINCT"), white on the precinct colour like the PDF.
    await controller.addSymbolLayer(
      _labels,
      'cdu-precinct-labels',
      const SymbolLayerProperties(
        textField: ['get', 'label'],
        textFont: ['Noto Sans Bold'],
        textSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          14.5,
          10,
          17,
          14,
        ],
        textColor: [
          'match',
          ['get', 'precinct'],
          'Yellow',
          '#211858',
          '#FFFFFF',
        ],
        textHaloColor: ['get', 'colour'],
        textHaloWidth: 5,
        textAllowOverlap: false,
      ),
      filter: [
        '==',
        ['get', 'kind'],
        'precinct',
      ],
      maxzoom: 17.5,
      enableInteraction: false,
    );

    // Places (toilets, food, library, theatre, gardens ...).
    // Named destinations: from further out, with their name; the marker
    // stands just above the spot so the building number stays readable.
    final majorIds = [
      for (final c in PlaceCategory.all)
        if (c.major) c.id,
    ];
    final k = iconScale;
    // Main places (library, theatre, gardens ...): icon from further out,
    // the name only when zoomed in (tap for the name otherwise). The marker
    // stands just above the spot so the building number stays readable.
    await controller.addSymbolLayer(
      _places,
      placeLayers[0],
      SymbolLayerProperties(
        iconImage: const [
          'concat',
          'poi-',
          ['get', 'category'],
        ],
        iconSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          15,
          0.34 * k,
          17,
          0.46 * k,
          19,
          0.56 * k,
        ],
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
        textField: const [
          'step',
          ['zoom'],
          '',
          namesFromZoom,
          ['get', 'name'],
        ],
        textFont: const ['Noto Sans Bold'],
        textSize: 13,
        textAnchor: 'left',
        textOffset: const [1.4, -1.5],
        textMaxWidth: 9,
        textColor: '#211858',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.8,
        textOptional: true,
      ),
      filter: [
        'in',
        ['get', 'category'],
        ['literal', majorIds],
      ],
      minzoom: 15.2,
      enableInteraction: false,
    );
    // Facilities in the PDF's style (toilets, food, ATM, parking ...): only when
    // zoomed in; they never hide building numbers.
    await controller.addSymbolLayer(
      _places,
      placeLayers[1],
      SymbolLayerProperties(
        iconImage: const [
          'concat',
          'poi-',
          ['get', 'category'],
        ],
        iconSize: [
          'interpolate',
          ['linear'],
          ['zoom'],
          facilitiesFromZoom,
          0.3 * k,
          18,
          0.4 * k,
          19,
          0.48 * k,
        ],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        '!',
        [
          'in',
          ['get', 'category'],
          ['literal', majorIds],
        ],
      ],
      minzoom: facilitiesFromZoom,
      enableInteraction: false,
    );

    // "You are here" (used on the web, where the map has no built-in location dot):
    // pale circle sized to the GPS accuracy in metres, then a blue dot with a white ring.
    // Pixel radius = metres * 2^zoom / 152911 (metres per pixel at Darwin's latitude).
    await controller.addCircleLayer(
      _me,
      'cdu-me-accuracy',
      const CircleLayerProperties(
        circleRadius: [
          'interpolate',
          ['exponential', 2],
          ['zoom'],
          10,
          [
            '*',
            ['get', 'accuracy'],
            0.0066966,
          ],
          22,
          [
            '*',
            ['get', 'accuracy'],
            27.4297,
          ],
        ],
        circleColor: '#1A73E8',
        circleOpacity: 0.15,
        circleStrokeColor: '#1A73E8',
        circleStrokeOpacity: 0.35,
        circleStrokeWidth: 1,
      ),
      enableInteraction: false,
    );
    await controller.addCircleLayer(
      _me,
      'cdu-me-dot',
      const CircleLayerProperties(
        circleRadius: 8,
        circleColor: '#1A73E8',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
      enableInteraction: false,
    );
  }

  Future<void> highlight(String? buildingId) =>
      controller.setFilter(_selectedLayer, [
        '==',
        ['get', 'id'],
        buildingId ?? '',
      ]);

  Future<void> showRoutes(
    List<WalkRoute> routes,
    int selected, {
    LatLng? from,
  }) async {
    final features = <Map<String, dynamic>>[];
    // Alternatives first, chosen route last (drawn on top).
    final order = [
      for (var i = 0; i < routes.length; i++)
        if (i != selected) i,
      if (routes.isNotEmpty) selected,
    ];
    for (final i in order) {
      features.add(
        _line(routes[i].points, {
          'kind': 'route',
          'idx': i,
          'selected': i == selected,
        }),
      );
    }
    if (routes.isNotEmpty) {
      final r = routes[selected];
      features.add(_line([r.points.last, r.door], {'kind': 'connector'}));
      if (from != null && r.startGap > 2) {
        features.add(_line([from, r.points.first], {'kind': 'connector'}));
      }
    }
    await controller.setGeoJsonSource(_route, {
      'type': 'FeatureCollection',
      'features': features,
    });

    final ends = <Map<String, dynamic>>[
      if (routes.isNotEmpty) _point(routes[selected].door, {'kind': 'end'}),
      if (routes.isNotEmpty && from != null) _point(from, {'kind': 'start'}),
    ];
    await controller.setGeoJsonSource(_routeEnds, {
      'type': 'FeatureCollection',
      'features': ends,
    });
  }

  /// Draws (or moves) the "you are here" dot. Pass null to hide it.
  Future<void> showMyLocation(LatLng? here, double accuracyMetres) =>
      controller.setGeoJsonSource(_me, {
        'type': 'FeatureCollection',
        'features': [
          if (here != null)
            _point(here, {'accuracy': accuracyMetres.clamp(3, 200)}),
        ],
      });

  /// Red pin on a selected place (pass null to remove it).
  Future<void> showSelectedPoint(LatLng? p) =>
      controller.setGeoJsonSource(_routeEnds, {
        'type': 'FeatureCollection',
        'features': [
          if (p != null) _point(p, {'kind': 'end'}),
        ],
      });

  Future<void> clearRoutes() async {
    await controller.setGeoJsonSource(_route, _emptyCollection);
    await controller.setGeoJsonSource(_routeEnds, _emptyCollection);
  }

  static Map<String, dynamic> _line(
    List<LatLng> pts,
    Map<String, dynamic> props,
  ) => {
    'type': 'Feature',
    'properties': props,
    'geometry': {
      'type': 'LineString',
      'coordinates': [
        for (final p in pts) [p.longitude, p.latitude],
      ],
    },
  };

  static Map<String, dynamic> _point(LatLng p, Map<String, dynamic> props) => {
    'type': 'Feature',
    'properties': props,
    'geometry': {
      'type': 'Point',
      'coordinates': [p.longitude, p.latitude],
    },
  };
}
