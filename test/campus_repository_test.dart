import 'package:cdu_campus_navigation/data/campus_map_bounds.dart';
import 'package:cdu_campus_navigation/data/campus_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampusRepository repo;

  setUpAll(() async {
    repo = CampusRepository();
    await repo.load();
  });

  test('loads campus buildings and paths', () {
    expect(repo.buildings.length, greaterThan(80));
    expect(repo.labelledBuildings.length, greaterThan(70));
    expect((repo.pathsGeoJson!['features'] as List).length, greaterThan(100));
  });

  test('labels are unique', () {
    final labels = repo.labelledBuildings.map((b) => b.label).toList();
    expect(labels.toSet().length, labels.length);
  });

  test('test-case buildings exist with the right precinct', () {
    final byLabel = {for (final b in repo.labelledBuildings) b.label: b};
    expect(byLabel['Red 6']?.precinct, 'Red');
    expect(byLabel['Blue 8']?.precinct, 'Blue');
    expect(byLabel['Blue 8']?.underConstruction, isTrue);
    expect(byLabel['Purple 9'], isNotNull); // OSM spells it "Purple 09"
    expect(byLabel['Purple 09'], isNull);
  });

  test('every building is inside the campus map area', () {
    for (final b in repo.buildings.values) {
      expect(CampusMapBounds.contains(b.centre), isTrue, reason: b.id);
    }
  });

  test('buildings have a precinct colour and a display height', () {
    for (final f in repo.buildingsGeoJson!['features'] as List) {
      final p = f['properties'] as Map;
      expect(p['colour'], matches(RegExp(r'^#[0-9A-F]{6}$')), reason: p['id']);
      expect((p['height'] as num) > 0, isTrue, reason: p['id']);
      expect(f['id'], p['id']);
    }
  });

  test('labelled buildings are sorted by precinct then number', () {
    final reds = repo.labelledBuildings
        .where((b) => b.precinct == 'Red')
        .map((b) => b.label)
        .toList();
    expect(reds.first, 'Red 1');
    // numeric order, not text order ("Red 9" before "Purple 10"-style mistakes)
    expect(reds.indexOf('Red 2'), lessThan(reds.indexOf('Red 9')));
  });
}
