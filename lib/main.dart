import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config/app_info.dart';
import 'screens/campus_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerDataLicences();
  runApp(const CDUCampusApp());
}

/// Shown on the "Open-source licences" page next to the code packages.
void _registerDataLicences() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Campus map data (OpenStreetMap)'],
      'Building shapes and walking paths: © OpenStreetMap contributors.\n'
      'Available under the Open Database Licence (ODbL) 1.0: '
      'https://opendatacommons.org/licenses/odbl/1-0/\n'
      'See https://www.openstreetmap.org/copyright',
    );
    yield const LicenseEntryWithLineBreaks(
      ['CDU Casuarina Campus Map'],
      'Building names, precinct colours and place names follow the CDU '
      'Casuarina Campus Map, published August 2024. © Charles Darwin University.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['OpenFreeMap'],
      'Street map tiles and style by OpenFreeMap (openfreemap.org), '
      'using OpenStreetMap data.',
    );
  });
}

class CDUCampusApp extends StatelessWidget {
  const CDUCampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppInfo.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF251B5B),
        ),
      ),
      home: const CampusMapScreen(),
    );
  }
}
