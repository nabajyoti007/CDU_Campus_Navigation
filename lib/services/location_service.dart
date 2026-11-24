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

/// Accuracy (metres) above which the app suggests going outdoors.
/// Browsers indoors typically report 15–50 m, which is still usable.
const double lowAccuracyMetres = 50;

/// Whether a new GPS reading should replace the current one.
///
/// Phones (and especially browsers) mix precise GPS fixes with rough Wi-Fi or
/// cell estimates. A reading that is much less accurate than a recent good one
/// is ignored, so the dot doesn't jump around; once the good reading is more
/// than [staleAfter] old, any reading is accepted so the dot never freezes.
bool shouldUsePosition(
  Position? current,
  Position next, {
  Duration staleAfter = const Duration(seconds: 20),
}) {
  if (current == null) return true;
  final muchWorse = next.accuracy > 30 && next.accuracy > current.accuracy * 2;
  final currentIsRecent =
      next.timestamp.difference(current.timestamp) < staleAfter;
  return !(muchWorse && currentIsRecent);
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
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  /// A fresh GPS fix right now, or null if the phone can't get one within [timeLimit].
  Future<Position?> freshPosition({
    Duration timeLimit = const Duration(seconds: 6),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: timeLimit,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Stream<Position> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 2,
    );

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
