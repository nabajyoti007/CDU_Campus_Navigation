import 'package:cdu_campus_navigation/data/campus_repository.dart';
import 'package:cdu_campus_navigation/models/campus_building.dart';
import 'package:cdu_campus_navigation/services/campus_router.dart';
import 'package:cdu_campus_navigation/services/walk_graph.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusRepository repo;
  late CampusRouter router;
  late Map<String, CampusBuilding> byLabel;

  setUpAll(() async {
    repo = CampusRepository();
    await repo.load();
    router = CampusRouter(repo.walkGraph!);
    byLabel = {for (final b in repo.labelledBuildings) b.label: b};
  });

  double metres(LatLng a, LatLng b) =>
      LocalProjection.toMetres(a).distanceTo(LocalProjection.toMetres(b));

  test('every labelled building can be reached', () {
    for (final b in repo.labelledBuildings) {
      expect(repo.walkGraph!.access[b.id], isNotEmpty, reason: b.label);
    }
  });

  test('Red 6 to Blue 8 follows the paths, not a straight line', () {
    final from = repo.walkGraph!.access[byLabel['Red 6']!.id]!.first.door;
    final routes = router.routes(from, byLabel['Blue 8']!.id);
    final best = routes.first;

    final straight = metres(from, best.door);
    expect(best.points.length, greaterThan(3));
    expect(best.distance, greaterThanOrEqualTo(straight));
    // Red 6 and Blue 8 are a few hundred metres apart.
    expect(best.distance, inInclusiveRange(100, 700));
    expect(best.duration.inMinutes, lessThan(12));
    // Route ends at Blue 8.
    expect(metres(best.points.last, best.door), lessThan(36));
  });

  test('alternatives are different and not much longer', () {
    final from = repo.walkGraph!.access[byLabel['Purple 1']!.id]!.first.door;
    final routes = router.routes(from, byLabel['Brown 18']!.id);
    expect(routes, isNotEmpty);
    for (final r in routes.skip(1)) {
      expect(r.distance, lessThanOrEqualTo(routes.first.distance * 1.5 + 40));
      expect(r.edgeIds.difference(routes.first.edgeIds), isNotEmpty);
    }
  });

  test('routes are found from anywhere on campus to the Library', () {
    final library = repo.search('library').single;
    expect(library.label, 'Red 8');
    for (final start in ['Brown 18', 'Green 4', 'Pink 9', 'Purple 14', 'Orange 12']) {
      final from = byLabel[start]!.centre;
      final r = router.routes(from, library.id, maxRoutes: 1).single;
      expect(r.distance, lessThan(2000), reason: start);
    }
  });

  test('starting far from campus is refused with a clear message', () {
    const darwinCbd = LatLng(-12.4634, 130.8456);
    expect(
      () => router.routes(darwinCbd, byLabel['Red 6']!.id),
      throwsA(isA<RouteException>()),
    );
  });

  test('progress: on the route at the start, nothing left at the end', () {
    final from = repo.walkGraph!.access[byLabel['Red 6']!.id]!.first.door;
    final route = router.routes(from, byLabel['Blue 8']!.id).first;
    final atStart = CampusRouter.progress(route, route.points.first);
    final atEnd = CampusRouter.progress(route, route.points.last);
    expect(atStart.offRoute, lessThan(1));
    expect(atStart.remaining, closeTo(route.pathDistance + route.access.gap, 1));
    expect(atEnd.remaining, lessThan(route.access.gap + 1));
  });

  test('search finds buildings by label, number and facility name', () {
    expect(repo.search('red 6').map((b) => b.label), contains('Red 6'));
    expect(repo.search('auditorium').single.label, 'Red 7');
    expect(repo.search('blue').length, greaterThan(4));
  });
}
