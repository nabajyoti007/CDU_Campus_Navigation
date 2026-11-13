import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Why the phone's location could not be used.
enum LocationProblem {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationException implements Exception {
  LocationException(this.problem);

  final LocationProblem problem;

  String get message {
    if (kIsWeb) {
      switch (problem) {
        case LocationProblem.serviceDisabled:
          return 'Location is not available in this browser.';
        case LocationProblem.permissionDenied:
        case LocationProblem.permissionDeniedForever:
          return 'Location is blocked. Allow location for this site in your browser.';
      }
    }
    switch (problem) {
      case LocationProblem.serviceDisabled:
        return 'Location is turned off on this phone.';
      case LocationProblem.permissionDenied:
        return 'Location permission was denied.';
      case LocationProblem.permissionDeniedForever:
        return 'Location permission is blocked. Allow it in app settings.';
    }
  }

  /// Phones can open the settings screen; a website can only ask again.
  bool get canOpenSettings =>
      !kIsWeb && problem != LocationProblem.permissionDenied;

  @override
  String toString() => message;
}

class LocationService {
  /// Checks the location service and permission, asking the user if needed.
  /// Throws [LocationException] if location cannot be used.
  Future<Position> determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw LocationException(LocationProblem.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationException(LocationProblem.permissionDenied);
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(LocationProblem.permissionDeniedForever);
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );
  }

  Stream<Position> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 2,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
