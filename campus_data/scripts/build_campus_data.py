"""Build the campus GeoJSON files used by the app's 3D map.

Inputs
  campus_data/osm/campus_osm.json             OpenStreetMap extract (buildings, paths) - ODbL
  campus_data/output/cdu_campus_map_3857.tif  georeferenced CDU PDF (Aug 2024)

Outputs (assets/campus/)
  buildings.geojson   building footprints with PDF label, precinct colour and display height
  labels.geojson      one label point per labelled building + PDF place names (kind=area)
  paths.geojson       campus footpaths (drawn on the map)
  areas.geojson       precinct background areas, lawns and the oval, traced from the PDF
  walk_graph.json     walking network for routing (see walk_graph.py)
  campus_data/output/building_report.csv  where every label/shape came from

Rules (see handoff):
  * Labels follow the PDF. An OSM name is kept only when the PDF shows the same building number
    in the same place, or (flagged) when the PDF shows nothing there.
  * A building is on campus when the PDF shows campus (not navy background) under it.
  * Shapes come from OSM. Buildings that are on the PDF but missing from OSM are traced
    from the PDF colours (accuracy ~3-5 m) and flagged source=pdf.
  * Heights are NOT surveyed. They are display heights for the 3D look only.

Run with the QGIS Python from the project root:
    python campus_data/scripts/build_campus_data.py
"""
import csv
import json
import os
import re
import sys

import numpy as np
from osgeo import ogr

sys.path.insert(0, os.path.dirname(__file__))
from osm_buildings import ROOT, PdfSampler, element_polygon, load_osm  # noqa: E402
from pdf_footprints import trace  # noqa: E402
from pdf_areas import pixel_to_lonlat, trace_areas  # noqa: E402
import walk_graph  # noqa: E402

ASSETS = os.path.join(ROOT, "assets", "campus")
REPORT = os.path.join(ROOT, "campus_data", "output", "building_report.csv")

NAVY = np.array([33, 24, 88])

# Precinct colours used in the app (from the PDF)
PRECINCT_COLOURS = {
    "Red": "#E40040",
    "Blue": "#0083CA",
    "Purple": "#6E5DA5",
    "Orange": "#F3903E",
    "Yellow": "#FFDA00",
    "Green": "#289B38",
    "Brown": "#C25812",
    "Pink": "#EF85AD",
    None: "#B9B4C7",  # campus building with no precinct colour on the PDF
}
UNDER_CONSTRUCTION_COLOUR = "#9DC7EE"

# Ground colours: the PDF's pale precinct tints, lawns and the oval
AREA_FILL = {
    "Pink": "#F8D0E0", "Brown": "#E8B898", "Orange": "#FCD4B4", "Purple": "#D0CCE4",
    "Blue": "#BCD4F0", "Red": "#F4B0AC", "Yellow": "#FCE8A0", "Green": "#B8D4AC",
    "lawn": "#D4E4D8", "oval": "#90C080",
}

# --- Decisions made by comparing OSM outlines with the PDF (see campus_data/README.md) -------

# OSM buildings that have no name in OSM, labelled from the PDF number printed on them.
OSM_LABEL_FROM_PDF = {
    545010154: "Pink 9",
    545010148: "Pink 6",
    1053518534: "Blue 7",
    545009973: "Orange 1 & 2",  # one OSM outline, PDF prints 1 and 2 on the same block
}
# OSM names written differently from the PDF.
OSM_NAME_FIX = {"Purple 09": "Purple 9"}
# OSM names for buildings the PDF does not number. Kept, but flagged in the report.
OSM_NAME_NOT_ON_PDF = {"Pink 1", "Red 5", "Goodstart Early Learning CDU"}
# OSM buildings replaced by a PDF building (PDF Aug 2024 is newer).
REPLACED_BY_BLUE_8 = {"Blue 3", "Blue 4"}
# OSM buildings that lie under a PDF label banner, not on campus.
EXCLUDE_OSM = {545482240, 1219103673}

# Buildings on the PDF but missing from OSM: (lat, lon inside the PDF shape, label, precinct)
PDF_ONLY = [
    (-12.371782, 130.865131, "Pink 2", "Pink"),
    (-12.372466, 130.866829, "Purple 15", "Purple"),
    (-12.371931, 130.867355, "Purple 16", "Purple"),
    (-12.370944, 130.870291, "Water Tank", "Blue"),
    (-12.370661, 130.864157, None, "Pink"),
    (-12.372554, 130.866973, None, "Purple"),
    (-12.373993, 130.867565, None, "Purple"),
    (-12.374256, 130.867989, None, "Purple"),
    (-12.373370, 130.869830, None, "Orange"),
    (-12.373381, 130.869543, None, "Orange"),
]

# Facility names from the PDF's Open Day inset, which points each one at a numbered building.
ALIASES = {
    "Red 8": ["Library"],
    "Red 7": ["Mal Nairn Auditorium"],
    "Red 2": ["Gulwa - The Austin Asche Hall", "CDU Services"],
    "Yellow 1": ["Northern Institute Savanna Room (Level 2)"],
}

# Precinct name banners, at their pixel position on the PDF (cdu_campus_map_3857.tif)
PRECINCT_BANNERS = [
    ("Yellow", 918, 400), ("Pink", 728, 591), ("Red", 1326, 822), ("Brown", 1661, 240),
    ("Blue", 1931, 530), ("Purple", 909, 1543), ("Orange", 1601, 1580), ("Green", 1849, 1790),
]


def darker(hex_colour, f=0.72):
    r, g, b = (int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02X%02X%02X" % (int(r * f), int(g * f), int(b * f))


def short_label(label):
    """What the PDF prints on the building itself: just the number ("Red 6" -> "6")."""
    m = PRECINCT_RE.match(label or "")
    return label.split(" ", 1)[1] if m else (label or "")


# Place names printed on the PDF, at their pixel position in cdu_campus_map_3857.tif
AREA_NAMES = [
    ("The Strand", 1213, 767),
    ("Boab Court", 1533, 930),
    ("The Mall", 1595, 1025),
    ("Chinese Garden", 1345, 610),
    ("Student Square", 1255, 935),
    ("Sports Oval", 2336, 1488),
]

PRECINCT_RE = re.compile(r"^(Red|Blue|Purple|Orange|Yellow|Green|Pink|Brown) (\d+[A-Z]?)")


def precinct_of(name):
    m = PRECINCT_RE.match(name or "")
    return m.group(1) if m else None


def display_height(area_m2, levels, precinct, name):
    """Height in metres for the 3D look. Not surveyed."""
    if levels:
        return round(float(levels) * 3.6, 1)
    if name == "Water Tank":
        return 10.0
    if area_m2 < 80:
        return 4.0
    if precinct == "Brown":  # student accommodation, low-rise
        return 7.0
    return 10.0


def area_m2(g):
    return g.GetArea() * 108_700 * 110_600


def to_geojson_geometry(g):
    return json.loads(g.ExportToJson())


def main():
    sampler = PdfSampler()
    buildings, report = [], []

    def add(geom, label, precinct, source, osm_id, note, levels=None, under_construction=False):
        a = area_m2(geom)
        colour = UNDER_CONSTRUCTION_COLOUR if under_construction else PRECINCT_COLOURS[precinct]
        props = {
            "id": f"osm-{osm_id}" if osm_id else f"pdf-{len(buildings)}",
            "label": label or "",
            "number": short_label(label),
            "precinct": precinct or "",
            "colour": colour,
            "outline": darker(colour),
            "height": display_height(a, levels, precinct, label),
            "source": source,
            "underConstruction": under_construction,
            "aliases": ALIASES.get(label, []),
        }
        buildings.append({"type": "Feature", "id": props["id"], "properties": props,
                          "geometry": to_geojson_geometry(geom)})
        report.append([props["id"], label or "", precinct or "", source, round(a), note])

    blue8_parts = []
    for e in load_osm():
        t = e.get("tags", {})
        if "building" not in t or e["id"] in EXCLUDE_OSM:
            continue
        geom = element_polygon(e)
        if geom is None:
            continue
        cols = sampler.colours_inside(geom, step_m=2.0)
        if len(cols) == 0 or np.abs(np.median(cols, 0) - NAVY).sum() < 30:
            continue  # not on the PDF campus

        name = OSM_NAME_FIX.get(t.get("name"), t.get("name"))
        if name in REPLACED_BY_BLUE_8:
            blue8_parts.append(geom)
            continue

        if e["id"] in OSM_LABEL_FROM_PDF:
            label = OSM_LABEL_FROM_PDF[e["id"]]
            note = "OSM shape, label read from PDF"
        elif name in OSM_NAME_NOT_ON_PDF:
            label = name
            note = "OSM name; PDF shows no number here - check on campus"
        elif name:
            label = name
            note = "OSM shape and name match PDF"
        else:
            label = None
            note = "OSM shape, no number on PDF"
        precinct = precinct_of(label)
        if precinct is None and label is None:
            # colour by the PDF only if a precinct building colour is printed under it
            med = np.median(cols, 0)
            best = min(PRECINCT_COLOURS_RGB, key=lambda k: np.abs(med - PRECINCT_COLOURS_RGB[k]).sum())
            if np.abs(med - PRECINCT_COLOURS_RGB[best]).sum() <= 45:
                precinct = best
        add(geom, label, precinct, "osm", e["id"], note, levels=t.get("building:levels"))

    if blue8_parts:
        u = blue8_parts[0]
        for g in blue8_parts[1:]:
            u = u.Union(g)
        add(u.ConvexHull(), "Blue 8", "Blue", "osm+pdf", None,
            "PDF Blue 8 (Under Construction) drawn over OSM Blue 3 + Blue 4 outlines",
            under_construction=True)

    traced = trace(sampler)
    for lat, lon, label, precinct in PDF_ONLY:
        p = ogr.Geometry(ogr.wkbPoint)
        p.AddPoint_2D(lon, lat)
        hits = [g for pr, g in traced if g.Contains(p)]
        if not hits:
            print("WARNING: no PDF shape at", lat, lon, label)
            continue
        add(hits[0], label, precinct, "pdf", None, "traced from PDF colours (+/- 3-5 m)")

    # Labels: one point per labelled building, placed inside its footprint
    labels = []
    for f in buildings:
        if not f["properties"]["label"]:
            continue
        g = ogr.CreateGeometryFromJson(json.dumps(f["geometry"]))
        c = g.PointOnSurface()
        text = f["properties"]["label"]
        if f["properties"]["underConstruction"]:
            text += "\n(Under Construction)"
        labels.append({
            "type": "Feature",
            "id": f["properties"]["id"],
            "properties": {"id": f["properties"]["id"], "label": text, "kind": "building",
                           "number": f["properties"]["number"],
                           "precinct": f["properties"]["precinct"], "height": f["properties"]["height"],
                           "area": area_m2(g)},
            "geometry": {"type": "Point", "coordinates": [round(c.GetX(), 7), round(c.GetY(), 7)]},
        })
    for precinct, col, row in PRECINCT_BANNERS:
        lon, lat = pixel_to_lonlat(sampler, col, row)
        labels.append({
            "type": "Feature",
            "id": "precinct-" + precinct.lower(),
            "properties": {"id": "precinct-" + precinct.lower(),
                           "label": f"{precinct.upper()} PRECINCT", "kind": "precinct",
                           "precinct": precinct, "colour": PRECINCT_COLOURS[precinct],
                           "height": 0, "area": 0},
            "geometry": {"type": "Point", "coordinates": [round(lon, 7), round(lat, 7)]},
        })
    for name, col, row in AREA_NAMES:
        lon, lat = pixel_to_lonlat(sampler, col, row)
        labels.append({
            "type": "Feature",
            "id": "area-" + name.lower().replace(" ", "-"),
            "properties": {"id": "area-" + name.lower().replace(" ", "-"), "label": name,
                           "kind": "area", "precinct": "", "height": 0, "area": 0},
            "geometry": {"type": "Point", "coordinates": [round(lon, 7), round(lat, 7)]},
        })

    # Precinct background areas, lawns and the oval
    area_features = []
    for kind, g in trace_areas(sampler):
        area_features.append({
            "type": "Feature",
            "properties": {"kind": kind,
                           "colour": AREA_FILL.get(kind, "#E8E6EE")},
            "geometry": json.loads(g.ExportToJson()),
        })

    # Walking network
    graph, graph_report = walk_graph.build(load_osm(), buildings)
    for line in graph_report:
        print(line)

    # Footpaths on campus
    path_types = {"footway", "path", "pedestrian", "steps", "cycleway"}
    paths = []
    for e in load_osm():
        t = e.get("tags", {})
        if e["type"] != "way" or t.get("highway") not in path_types:
            continue
        coords = [[round(p["lon"], 7), round(p["lat"], 7)] for p in e.get("geometry", [])]
        if len(coords) < 2:
            continue
        mid = coords[len(coords) // 2]
        c, r = sampler.pixel(*mid)
        if not (0 <= c < sampler.w and 0 <= r < sampler.h):
            continue
        px = sampler.rgba[r, c]
        if px[3] == 0 or np.abs(px[:3].astype(int) - NAVY).sum() < 30:
            continue
        paths.append({
            "type": "Feature",
            "id": f"osm-{e['id']}",
            "properties": {"id": f"osm-{e['id']}", "highway": t["highway"],
                           "covered": t.get("covered") == "yes"},
            "geometry": {"type": "LineString", "coordinates": coords},
        })

    os.makedirs(ASSETS, exist_ok=True)
    attribution = "Building shapes and paths: (c) OpenStreetMap contributors (ODbL). " \
                  "Labels and colours: CDU Casuarina Campus Map, August 2024."
    for name, feats in (("buildings", buildings), ("labels", labels), ("paths", paths),
                        ("areas", area_features)):
        with open(os.path.join(ASSETS, f"{name}.geojson"), "w", encoding="utf-8", newline="\n") as f:
            json.dump({"type": "FeatureCollection", "attribution": attribution, "features": feats},
                      f, separators=(",", ":"))
    with open(os.path.join(ASSETS, "walk_graph.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"attribution": attribution, **graph}, f, separators=(",", ":"))
    with open(REPORT, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "label", "precinct", "source", "area_m2", "note"])
        w.writerows(sorted(report, key=lambda r: (r[2], r[1])))

    print(f"{len(buildings)} buildings ({sum(1 for b in buildings if b['properties']['label'])} labelled), "
          f"{len(labels)} labels, {len(paths)} paths")


PRECINCT_COLOURS_RGB = {
    "Purple": np.array([110, 93, 165]), "Orange": np.array([243, 144, 62]),
    "Red": np.array([228, 0, 64]), "Yellow": np.array([255, 218, 0]),
    "Blue": np.array([0, 131, 202]), "Green": np.array([40, 155, 56]),
    "Brown": np.array([194, 88, 18]), "Pink": np.array([239, 133, 173]),
}

if __name__ == "__main__":
    main()
