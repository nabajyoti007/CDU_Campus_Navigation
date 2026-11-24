/// ============================================================================
///  YOUR APP AND DEVELOPER DETAILS
///  Edit this one file to change what the About screen and copyright show.
///  Leave a field as '' (empty) to hide it.
/// ============================================================================
class AppInfo {
  AppInfo._();

  // --- App ------------------------------------------------------------------
  static const String appName = 'CDU Campus Navigator';
  static const String tagline =
      'Find any building on Casuarina campus and walk there.';

  /// Keep in step with `version:` in pubspec.yaml.
  static const String version = '1.0.2';

  // --- You (the developer) --------------------------------------------------
  static const String developerName = 'Nabajyoti Sharma';
  static const String studentId = 'S399970';
  static const String developerRole = 'Student Developer';
  static const String course = ''; // e.g. 'Bachelor of Information Technology'
  static const String university = 'Charles Darwin University';
  static const String email =
      's399970@students.cdu.edu.au'; // shown on the About screen
  static const String website = ''; // e.g. GitHub or LinkedIn URL

  // --- Where to get the app -------------------------------------------------
  static const String webAppUrl =
      'https://nabajyoti007.github.io/CDU_Campus_Navigation/';
  static const String sourceUrl =
      'https://github.com/nabajyoti007/CDU_Campus_Navigation';

  // --- Copyright ------------------------------------------------------------
  static const int copyrightYear = 2026;

  static String get copyright =>
      '© $copyrightYear $developerName. All rights reserved.';

  // --- About text -----------------------------------------------------------
  static const String description =
      'CDU Campus Navigator helps students, staff and visitors find buildings '
      'on Charles Darwin University\'s Casuarina campus. Search for a building '
      'or tap it on the map, then get walking directions along the campus '
      'paths from where you are, with live updates as you walk.';

  /// Required: this is an independent project, not an official CDU product.
  static const String disclaimer =
      'This app is an independent project and is not an official app of, or '
      'endorsed by, Charles Darwin University. Building names and colours '
      'follow the CDU Casuarina Campus Map (August 2024); buildings may have '
      'changed since then. Entrances are not yet mapped: routes end at the '
      'path nearest the building. Always follow on-site signs.';

  static const String privacy =
      'Your location is used only on this phone to show where you are and to '
      'plan walking routes. It is not stored or sent anywhere by this app. '
      'The street map is loaded from OpenFreeMap over the internet.';
}
