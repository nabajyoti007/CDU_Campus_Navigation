# CDU Campus Navigator

A Flutter app that helps students, staff and visitors find buildings on **Charles Darwin
University's Casuarina campus** and walk there.

Search for a building (or tap it on the map), press **Directions**, and the app shows walking
routes along the campus paths from where you are, like Google Maps. Press **Start** and it
follows you as you walk, counts down the distance and re-routes if you go the wrong way.

> Independent student project. Not an official app of, or endorsed by, Charles Darwin University.

## Use it on any device (web app)

Open **https://nabajyoti007.github.io/CDU_Campus_Navigation/** in your phone's browser.
Works on iPhone, Android and computers. To use it like an app: in Safari tap
**Share → Add to Home Screen**; in Chrome tap **⋮ → Install app / Add to Home screen**.
Allow location when the browser asks. Keep the page open while navigating.

## Download (Android)

Get the latest version from the
[**Releases page**](https://github.com/nabajyoti007/CDU_Campus_Navigation/releases/latest):

| File | For |
|---|---|
| `CDU-Campus-Navigator-vX.Y.Z-arm64.apk` | Almost all Android phones from 2017 onwards (**start here**) |
| `CDU-Campus-Navigator-vX.Y.Z-older-phones.apk` | Older 32-bit Android phones |
| `CDU-Campus-Navigator-vX.Y.Z-universal.apk` | Works on any Android phone (larger download) |

To install: open the downloaded file on your phone and allow **"Install unknown apps"** when
Android asks. Android 7.0 or newer. The app needs internet (for the street map) and location
permission. iPhone is not supported yet.

## Features

- **Campus map in the style of the official CDU map:** buildings in their precinct colours,
  building numbers printed on each building, precinct banners and place names
  (Boab Court, The Mall, The Strand, ...), on top of a real street map.
- **Live GPS location**, with clear messages when location is off, blocked or weak.
- **Search** by building (`Red 6`, `blue 2`) or facility (`Library`, `Mal Nairn Auditorium`).
- **Walking directions** along real campus footpaths (never a straight line), with up to
  3 alternative routes, distance and walking time.
- **Live navigation** with off-route detection and automatic re-routing.
- Start from **your location or any building** (e.g. Red 6 → Blue 8).
- **About** screen with credits, privacy note and licences.

## Tech stack

| Part | Used |
|---|---|
| App | Flutter / Dart |
| Map display | [maplibre_gl](https://pub.dev/packages/maplibre_gl) |
| Street map | [OpenFreeMap](https://openfreemap.org) "Liberty" style (OpenStreetMap data, no API key) |
| Location | [geolocator](https://pub.dev/packages/geolocator) |
| Routing | Own Dijkstra router over a campus walking network (`lib/services/campus_router.dart`) |
| Campus data | QGIS, GDAL and Python scripts in `campus_data/scripts/` |

## Project structure

```
lib/
  main.dart                    app entry, licence notices
  config/app_info.dart         app name, developer details, About text
  screens/                     map screen, About screen
  map/campus_layers.dart       map styling and layers
  services/                    location, walking network, router
  widgets/                     search, building card, route and navigation panels
  data/                        loads the campus data files
assets/campus/                 buildings, labels, paths, areas, walking network
campus_data/                   how the campus data is made (see campus_data/README.md)
test/                          unit and widget tests
```

## Run it

Requirements: Flutter (stable), Android SDK, an Android phone or emulator.

```bash
flutter pub get
flutter run
```

The app needs location permission and an internet connection (for the street map).

Run the tests:

```bash
flutter analyze
flutter test
```

## How the campus data is made

1. The CDU Casuarina Campus Map PDF (August 2024) was georeferenced in QGIS with
   10 control points (Polynomial 2, about 1–4 m error).
2. Building shapes and footpaths come from OpenStreetMap. Each building's label and
   colour is checked against the PDF; buildings missing from OpenStreetMap are traced from it.
3. A walking network is built from the paths; routes prefer footpaths and avoid cutting
   through buildings.

Details and rebuild steps: [campus_data/README.md](campus_data/README.md).

## Known limits

- Building entrances are not mapped yet: routes end at the path nearest the building.
- Building names follow the August 2024 map; some buildings were under construction then.
- GPS is usually accurate to 3–10 m outdoors and is weaker next to tall buildings.

## Credits

- Building names, precinct colours and place names: CDU Casuarina Campus Map,
  August 2024. © Charles Darwin University.
- Building shapes and walking paths: © [OpenStreetMap](https://www.openstreetmap.org/copyright)
  contributors, Open Database Licence (ODbL).
- Street map tiles: [OpenFreeMap](https://openfreemap.org).
- Map rendering: [MapLibre](https://maplibre.org).

## Author

**Nabajyoti Sharma**, Student ID S399970, Charles Darwin University
Contact: s399970@students.cdu.edu.au

© 2026 Nabajyoti Sharma. All rights reserved. Map data remains the property of its
owners listed above.
