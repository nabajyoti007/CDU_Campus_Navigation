import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'walk_graph.dart';

/// Average walking speed used for time estimates (4.5 km/h).
const double walkingSpeedMps = 1.25;

class RouteException implements Exception {
  RouteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One walking route along campus paths.
class WalkRoute {
  WalkRoute({
    required this.points,
    required this.pathDistance,
    required this.edgeIds,
    required this.startGap,
    required this.door,
    required this.access,
  });

  /// Route along the path network, from the snapped start to the access point.
  final List<LatLng> points;

  /// Metres walked along paths.
  final double pathDistance;

  /// Edges used (for comparing alternatives).
  final Set<int> edgeIds;

  /// Metres from the start position to the nearest path (drawn dotted).
  final double startGap;

  /// Closest point on the building wall (drawn dotted; not a surveyed entrance).
  final LatLng door;
  final AccessPoint access;

  double get distance => pathDistance + startGap + access.gap;
  Duration get duration =>
      Duration(seconds: math.max(30, (distance / walkingSpeedMps).round()));
}

/// Where the walker is along a route.
class RouteProgress {
  RouteProgress(this.offRoute, this.remaining);

  /// Metres between the walker and the route line.
  final double offRoute;

  /// Metres still to walk, measured along the route.
  final double remaining;
}

/// Finds walking routes on the campus path network (Dijkstra), plus alternatives.
class CampusRouter {
  CampusRouter(this.graph);

  final WalkGraph graph;

  /// Starting further than this from any campus path is refused.
  static const double maxStartGap = 300;

  /// Routes from [from] to building [buildingId], best first (up to [maxRoutes]).
  List<WalkRoute> routes(LatLng from, String buildingId, {int maxRoutes = 3}) {
    final targets = graph.access[buildingId];
    if (targets == null || targets.isEmpty) {
      throw RouteException('No campus path reaches this building.');
    }
    final snap = graph.snap(from);
    if (snap.distance > maxStartGap) {
      throw RouteException(
        'You are ${snap.distance.round()} m from the nearest campus path. '
        'Walking directions start on campus.',
      );
    }

    final penalty = List<double>.filled(graph.edges.length, 1.0);
    final found = <WalkRoute>[];
    for (var attempt = 0; attempt < 8 && found.length < maxRoutes; attempt++) {
      final r = _shortest(snap, targets, penalty);
      if (r == null) break;
      if (found.isEmpty) {
        found.add(r);
      } else {
        final best = found.first.distance;
        final tooLong = r.distance > best * 1.5 + 40;
        final tooSimilar = found.any((f) => _overlap(r, f) > 0.7);
        if (tooLong) break;
        if (!tooSimilar) found.add(r);
      }
      for (final e in r.edgeIds) {
        penalty[e] *= 2.2;
      }
    }
    if (found.isEmpty) throw RouteException('No walking route found.');
    return found;
  }

  WalkRoute? _shortest(SnapResult snap, List<AccessPoint> targets, List<double> penalty) {
    final n = graph.nodes.length;
    final cost = List<double>.filled(n, double.infinity);
    final prevEdge = List<int>.filled(n, -1);
    final done = List<bool>.filled(n, false);
    final heap = _MinHeap();

    final startEdge = graph.edges[snap.edge];
    final w = startEdge.factor * penalty[snap.edge];
    cost[startEdge.a] = startEdge.length * snap.t * w;
    cost[startEdge.b] = startEdge.length * (1 - snap.t) * w;
    heap.push(startEdge.a, cost[startEdge.a]);
    heap.push(startEdge.b, cost[startEdge.b]);

    final targetNodes = {for (final t in targets) t.node: t};
    int? reached;
    while (heap.isNotEmpty) {
      final u = heap.pop();
      if (done[u]) continue;
      done[u] = true;
      if (targetNodes.containsKey(u)) {
        reached = u;
        break;
      }
      for (final ei in graph.adjacency[u]) {
        final e = graph.edges[ei];
        final v = e.other(u);
        final c = cost[u] + e.length * e.factor * penalty[ei];
        if (c < cost[v]) {
          cost[v] = c;
          prevEdge[v] = ei;
          heap.push(v, c);
        }
      }
    }
    if (reached == null) return null;

    // Walk back to the start edge.
    final nodePath = <int>[reached];
    final edgeIds = <int>{};
    var cur = reached;
    double along = 0;
    while (prevEdge[cur] != -1) {
      final e = graph.edges[prevEdge[cur]];
      edgeIds.add(prevEdge[cur]);
      along += e.length;
      cur = e.other(cur);
      nodePath.add(cur);
    }
    // cur is startEdge.a or .b: add the partial start edge
    along += cur == startEdge.a
        ? startEdge.length * snap.t
        : startEdge.length * (1 - snap.t);
    edgeIds.add(snap.edge);

    final points = <LatLng>[
      snap.latLng,
      for (final i in nodePath.reversed) graph.nodes[i],
    ];
    final access = targetNodes[reached]!;
    return WalkRoute(
      points: points,
      pathDistance: along,
      edgeIds: edgeIds,
      startGap: snap.distance,
      door: access.door,
      access: access,
    );
  }

  double _overlap(WalkRoute a, WalkRoute b) {
    double shared = 0, total = 0;
    for (final e in a.edgeIds) {
      final l = graph.edges[e].length;
      total += l;
      if (b.edgeIds.contains(e)) shared += l;
    }
    return total == 0 ? 1 : shared / total;
  }

  /// Distance from [p] to [route] and metres left to walk.
  static RouteProgress progress(WalkRoute route, LatLng p) {
    final m = LocalProjection.toMetres(p);
    final pts = route.points.map(LocalProjection.toMetres).toList();
    var bestD = double.infinity;
    var bestRemaining = route.pathDistance;
    var cumulative = 0.0;
    final segLengths = <double>[
      for (var i = 0; i + 1 < pts.length; i++) pts[i].distanceTo(pts[i + 1]),
    ];
    final total = segLengths.fold<double>(0, (s, l) => s + l);
    for (var i = 0; i + 1 < pts.length; i++) {
      final pr = projectOnSegment(m, pts[i], pts[i + 1]);
      final d = pr.point.distanceTo(m);
      if (d < bestD) {
        bestD = d;
        bestRemaining = total - (cumulative + segLengths[i] * pr.t);
      }
      cumulative += segLengths[i];
    }
    return RouteProgress(bestD, bestRemaining + route.access.gap);
  }
}

/// Small binary min-heap of (node, cost).
class _MinHeap {
  final _nodes = <int>[];
  final _costs = <double>[];

  bool get isNotEmpty => _nodes.isNotEmpty;

  void push(int node, double cost) {
    _nodes.add(node);
    _costs.add(cost);
    var i = _nodes.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_costs[p] <= _costs[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  int pop() {
    final top = _nodes.first;
    final lastN = _nodes.removeLast();
    final lastC = _costs.removeLast();
    if (_nodes.isNotEmpty) {
      _nodes[0] = lastN;
      _costs[0] = lastC;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _nodes.length && _costs[l] < _costs[m]) m = l;
        if (r < _nodes.length && _costs[r] < _costs[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int i, int j) {
    final n = _nodes[i];
    _nodes[i] = _nodes[j];
    _nodes[j] = n;
    final c = _costs[i];
    _costs[i] = _costs[j];
    _costs[j] = c;
  }
}
