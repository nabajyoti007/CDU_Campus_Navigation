# Campus map data

How the CDU map in the app is produced.

## Source

- `source/cas-open-day-map_2024-08.pdf`: CDU Casuarina Campus Map, published August 2024 (UniPrint 78976).
  Some buildings are marked *Under Construction* (Blue 8, Pink 10). Check these on campus.
- `source/cdu_campus_map.png`: the campus area of the PDF rendered at 400 dpi
  (`gdal_translate --config GDAL_PDF_DPI 400`, then crop `-srcwin 280 530 3027 1990`).
- `source/cdu_campus_map.png.points`: 10 control points made in the QGIS Georeferencer,
  matching road junctions/roundabouts on the PDF to OpenStreetMap (EPSG:4326).
  Polynomial 2 fit: about 1.2 m error at the points and about 3.7 m between them (leave-one-out).

## Build steps

Run from the project root in the QGIS OSGeo4W shell (`C:\Program Files\QGIS 3.44.15\OSGeo4W.bat`):

```
python campus_data/scripts/clean_map.py campus_data/source/cdu_campus_map.png campus_data/source/cdu_campus_map_clean.png
python campus_data/scripts/build_app_map.py
```

1. `clean_map.py` removes print-only artwork: the white Open Day inset outline and its
   leader lines, the Key box and the scale bar. The pixel grid is unchanged, so the
   control points still apply.
2. `build_app_map.py` warps the cleaned image with the control points to Web Mercator
   and writes:
   - `assets/campus/cdu_campus_map.png`: image shown in the app
   - `lib/data/campus_map_bounds.dart`: its corner coordinates (generated, don't edit)
   - `output/cdu_campus_map_3857.tif`: georeferenced copy for checking in QGIS

If you move or add control points in QGIS, save them over the `.points` file and re-run step 2.

## 3D map and walking directions

`python campus_data/scripts/build_campus_data.py` (QGIS Python) builds everything the app loads
from `assets/campus/`:

- `buildings.geojson`: OSM footprints labelled and coloured from the PDF. Buildings missing from OSM
  are traced from the PDF. Heights are display-only, not surveyed.
- `labels.geojson`: building labels and PDF place names (Boab Court, The Mall, ...).
- `areas.geojson`: precinct ground tints, lawns and the oval, traced from the PDF.
- `paths.geojson`: campus footpaths for drawing.
- `walk_graph.json`: walking network from OSM paths and roads (shared OSM nodes = real junctions).
  Roads cost 1.2–1.6× a footpath; segments crossing a building footprint cost 3×. Each building
  has up to 3 access points on the nearest paths. **Entrances are not surveyed**: routes end at
  the closest path and the last metres to the wall are drawn dotted.
- `campus_data/output/building_report.csv`: where every label and shape came from.

OSM data (`osm/campus_osm.json`) was downloaded from the Overpass API on 4 Nov 2026 and is © OpenStreetMap
contributors, ODbL. The street base map in the app is OpenFreeMap "Liberty" (needs internet).

## Places (toilets, food, library, theatre, gardens …)

`python campus_data/scripts/build_places.py` builds `assets/campus/places.geojson` from:

- **PDF icons**: `pdf_icons.py` finds every facility icon on the PDF (toilets, food, ATM, post
  office, security, parents & carers rooms, taxi, information, car parks) by matching them
  against the icons in the PDF's key, then places them with the georeferencing control points.
- **PDF inset**: names the Open Day inset points at a building: Library (Red 8),
  Mal Nairn Auditorium (Red 7), CDU Services and Gulwa – The Austin Asche Hall (Red 2),
  Nan Giese Gallery (Orange 10), Northern Editions Gallery (Orange 9),
  Northern Institute Savanna Room (Yellow 1, level 2). Open Day-only items (marquees,
  food vendors, Welcome Hub) are left out.
- **PDF labels**: Boab Court, The Mall, The Strand, Chinese Garden, Student Square, Sports Oval.
- **OpenStreetMap**: bus stops with their names, car park names (`osm/campus_pois_osm.json`).
- **You**: `campus_data/manual_places.json` for places neither source has, e.g. the
  **bookshop** or named cafés. Add them there and re-run the script.

## Known differences between the PDF and OpenStreetMap

The PDF is the source for names and layout. OSM was used only for alignment.

- Blue 8 (Under Construction) is drawn where OSM has Blue 3 and Blue 4.
- Pink 10 (Under Construction) is drawn over an OSM car park.
- The two Pink 2 buildings are on the PDF but not in OSM.
