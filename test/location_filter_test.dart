import 'package:cdu_campus_navigation/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position fix(double accuracy, int secondsAfterStart) => Position(
      latitude: -12.3694,
      longitude: 130.8693,
      timestamp: DateTime(2026, 11, 14, 2).add(Duration(seconds: secondsAfterStart)),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  test('first reading is always used', () {
    expect(shouldUsePosition(null, fix(300, 0)), isTrue);
  });

  test('a much rougher reading right after a good one is ignored', () {
    expect(shouldUsePosition(fix(8, 0), fix(65, 3)), isFalse);
  });

  test('similar or better readings are used', () {
    expect(shouldUsePosition(fix(8, 0), fix(12, 1)), isTrue);
    expect(shouldUsePosition(fix(40, 0), fix(9, 1)), isTrue);
  });

  test('small accuracy changes are not treated as rough', () {
    // 25 m is more than double 10 m, but still a usable outdoor reading.
    expect(shouldUsePosition(fix(10, 0), fix(25, 1)), isTrue);
  });

  test('a rough reading is accepted once the good one is old, so the dot never freezes', () {
    expect(shouldUsePosition(fix(8, 0), fix(65, 25)), isTrue);
  });
}
