import 'package:cdu_campus_navigation/data/campus_map_bounds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  test('map corners form a north-up rectangle', () {
    const q = CampusMapBounds.quad;
    expect(q.topLeft.latitude, q.topRight.latitude);
    expect(q.bottomLeft.latitude, q.bottomRight.latitude);
    expect(q.topLeft.longitude, q.bottomLeft.longitude);
    expect(q.topRight.longitude, q.bottomRight.longitude);
    expect(q.topLeft.latitude, greaterThan(q.bottomLeft.latitude));
    expect(q.topRight.longitude, greaterThan(q.topLeft.longitude));
  });

  test('QGIS control points lie on the campus map', () {
    // From campus_data/source/cdu_campus_map.png.points
    const controlPoints = [
      LatLng(-12.3710197, 130.8727860), // Hospital roundabout
      LatLng(-12.3745259, 130.8745764), // roundabout east of sports oval
      LatLng(-12.3745334, 130.8683243), // Vocation Place x University Dr South
      LatLng(-12.3699162, 130.8660458), // Technology Place
      LatLng(-12.3695056, 130.8679082), // Yellow C car park road
    ];
    for (final p in controlPoints) {
      expect(CampusMapBounds.contains(p), isTrue, reason: '$p');
    }
    expect(CampusMapBounds.contains(CampusMapBounds.centre), isTrue);
  });

  test('places off campus are not on the map', () {
    const darwinCbd = LatLng(-12.4634, 130.8456);
    const nakaraOval = LatLng(-12.3712, 130.8790);
    expect(CampusMapBounds.contains(darwinCbd), isFalse);
    expect(CampusMapBounds.contains(nakaraOval), isFalse);
  });
}
