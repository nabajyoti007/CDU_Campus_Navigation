import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

/// Local flat-earth projection around the campus (metres). Accurate to
/// well under 0.1% over the ~1.5 km campus.
class LocalProjection {
  static const double lat0 = -12.372;
  static const double lon0 = 130.869;
  static final double kx = 111320 * math.cos(lat0 * math.pi / 180);
  static const double ky = 110574;

  static math.Point<double> toMetres(LatLng p) =>
      math.Point((p.longitude - lon0) * kx, (p.latitude - lat0) * ky);

  static LatLng toLatLng(math.Point<double> m) =>
      LatLng(m.y / ky + lat0, m.x / kx + lon0);
}

class WalkEdge {
  WalkEdge(this.a, this.b, this.length, this.factor, this.kind);

  final int a;
  final int b;

  /// Real length in metres.
  final double length;

  /// Cost multiplier (footpath 1.0, road 1.2-1.6, through a building x3).
  final double factor;
  final String kind;

  int other(int n) => n == a ? b : a;
}

/// Where a route can end for a building: a node on the path network and the
/// closest point on the building's wall ("door" - not a surveyed entrance).
class AccessPoint {
  AccessPoint(this.node, this.door, this.gap);

  final int node;
  final LatLng door;

  /// Metres between the path and the wall.
  final double gap;
}

/// Walking network from assets/campus/walk_graph.json
/// (built by campus_data/scripts/walk_graph.py from OpenStreetMap paths).
class WalkGraph {
  WalkGraph._(this.nodes, this.metres, this.edges, this.adjacency, this.access);

  factory WalkGraph.fromJson(Map<String, dynamic> json) {
    final nodes = <LatLng>[
      for (final n in json['nodes'] as List)
        LatLng((n[1] as num).toDouble(), (n[0] as num).toDouble()),
    ];
    final metres = nodes.map(LocalProjection.toMetres).toList();
    final edges = <WalkEdge>[
      for (final e in json['edges'] as List)
        WalkEdge(
          e[0] as int,
          e[1] as int,
          (e[2] as num).toDouble(),
          (e[3] as num).toDouble(),
          e[4] as String,
        ),
    ];
    final adjacency = List.generate(nodes.length, (_) => <int>[]);
    for (var i = 0; i < edges.length; i++) {
      adjacency[edges[i].a].add(i);
      adjacency[edges[i].b].add(i);
    }
    final access = <String, List<AccessPoint>>{};
    (json['access'] as Map<String, dynamic>).forEach((id, list) {
      access[id] = [
        for (final a in list as List)
          AccessPoint(
            a['node'] as int,
            LatLng(
              (a['door'][1] as num).toDouble(),
              (a['door'][0] as num).toDouble(),
            ),
            (a['gap'] as num).toDouble(),
          ),
      ];
    });
    return WalkGraph._(nodes, metres, edges, adjacency, access);
  }

  final List<LatLng> nodes;
  final List<math.Point<double>> metres;
  final List<WalkEdge> edges;
  final List<List<int>> adjacency;
  final Map<String, List<AccessPoint>> access;

  /// Nearest point on any path segment to [p].
  SnapResult snap(LatLng p) {
    final m = LocalProjection.toMetres(p);
    SnapResult? best;
    for (var i = 0; i < edges.length; i++) {
      final e = edges[i];
      final r = projectOnSegment(m, metres[e.a], metres[e.b]);
      final d = r.point.distanceTo(m);
      if (best == null || d < best.distance) {
        best = SnapResult(i, r.t, r.point, d);
      }
    }
    return best!;
  }
}

class SnapResult {
  SnapResult(this.edge, this.t, this.point, this.distance);

  final int edge;

  /// 0 at edge.a, 1 at edge.b.
  final double t;
  final math.Point<double> point;

  /// Metres from the query point to the path.
  final double distance;

  LatLng get latLng => LocalProjection.toLatLng(point);
}

class SegmentProjection {
  SegmentProjection(this.point, this.t);
  final math.Point<double> point;
  final double t;
}

SegmentProjection projectOnSegment(
  math.Point<double> p,
  math.Point<double> a,
  math.Point<double> b,
) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final l2 = dx * dx + dy * dy;
  var t = l2 == 0 ? 0.0 : ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2;
  t = t.clamp(0.0, 1.0);
  return SegmentProjection(math.Point(a.x + t * dx, a.y + t * dy), t);
}
