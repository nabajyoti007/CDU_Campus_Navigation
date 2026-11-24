import 'package:cdu_campus_navigation/data/campus_repository.dart';
import 'package:cdu_campus_navigation/models/place_category.dart';
import 'package:cdu_campus_navigation/services/campus_router.dart';
import 'package:cdu_campus_navigation/services/walk_graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusRepository repo;
  late CampusRouter router;

  setUpAll(() async {
    repo = CampusRepository();
    await repo.load();
    router = CampusRouter(repo.walkGraph!);
  });

  test('places are loaded with known categories', () {
    expect(repo.places.length, greaterThan(60));
    for (final p in repo.places) {
      expect(PlaceCategory.byId.containsKey(p.category), isTrue, reason: p.category);
    }
    expect(repo.placesOf('toilets').length, greaterThan(20));
  });

  test('important places point at the right building (from the PDF inset)', () {
    String buildingOf(String name) =>
        repo.places.firstWhere((p) => p.name == name).building;
    expect(buildingOf('Library'), 'Red 8');
    expect(buildingOf('Mal Nairn Auditorium'), 'Red 7');
    expect(buildingOf('CDU Services'), 'Red 2');
    expect(buildingOf('Nan Giese Gallery'), 'Orange 10');
  });

  test('search finds places by everyday words', () {
    expect(repo.searchAll('library').first.title, 'Library');
    expect(repo.searchAll('theatre').first.title, 'Mal Nairn Auditorium');
    expect(repo.searchAll('toilet').where((d) => d.isPlace), isNotEmpty);
    expect(repo.searchAll('coffee').first.place?.category, 'food');
    expect(repo.searchAll('garden').map((d) => d.title), contains('Chinese Garden'));
    // buildings still work
    expect(repo.searchAll('red 6').map((d) => d.title), contains('Red 6'));
  });

  test('nearest toilets are sorted by distance', () {
    final here = repo.buildings.values.firstWhere((b) => b.label == 'Red 6').centre;
    final list = repo.placesOf('toilets', from: here);
    final m = LocalProjection.toMetres(here);
    double d(int i) => LocalProjection.toMetres(list[i].point).distanceTo(m);
    for (var i = 1; i < list.length; i++) {
      expect(d(i), greaterThanOrEqualTo(d(i - 1)));
    }
    expect(d(0), lessThan(60)); // Red 6 has toilets
  });

  test('directions to an outdoor place follow the paths to the spot', () {
    final garden = repo.places.firstWhere((p) => p.name == 'Chinese Garden');
    final from = repo.buildings.values.firstWhere((b) => b.label == 'Purple 1').centre;
    final routes = router.routesToPoint(from, garden.point);
    expect(routes, isNotEmpty);
    expect(routes.first.points.length, greaterThan(3));
    expect(routes.first.door, garden.point);
    expect(routes.first.distance, lessThan(1500));
  });

  test('the destination for a place inside a building is that building', () {
    final library = repo.places.firstWhere((p) => p.name == 'Library');
    final d = repo.destinationForPlace(library);
    expect(d.building?.label, 'Red 8');
    expect(d.buildingId, isNotNull);
  });
}
