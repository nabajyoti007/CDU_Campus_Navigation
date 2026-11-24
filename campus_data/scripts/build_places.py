"""Build assets/campus/places.geojson: toilets, food, library, theatre, gardens, parking ...

Sources (all recorded per place in the 'source' property):
  * PDF icons      - facility icons printed on the CDU PDF map (pdf_icons.py)
  * PDF inset      - names the PDF's Open Day inset points at a building
                     (Library -> Red 8, Mal Nairn Auditorium -> Red 7, ...)
  * PDF labels     - place names printed on the map (Boab Court, The Mall, ...)
  * OSM            - bus stops, Chinese Garden, car park names (OpenStreetMap, ODbL)
  * manual         - campus_data/manual_places.json, for places neither source has
                     (e.g. the bookshop or named cafes); empty until filled in

Run with the QGIS Python from the project root:
    python campus_data/scripts/build_places.py
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from osm_buildings import ROOT  # noqa: E402
from pdf_icons import CLEAN, find_icons, load_rgb  # noqa: E402

ASSETS = os.path.join(ROOT, "assets", "campus")
OSM_POIS = os.path.join(ROOT, "campus_data", "osm", "campus_pois_osm.json")
MANUAL = os.path.join(ROOT, "campus_data", "manual_places.json")

# category -> (display name for lists, icon key used by the app)
CATEGORIES = {
    "toilets": "Toilets",
    "food": "Food & café",
    "library": "Library",
    "venue": "Theatre & venue",
    "gallery": "Gallery",
    "services": "Student services",
    "info": "Information",
    "atm": "ATM",
    "post": "Post office",
    "security": "Security",
    "parents": "Parents & carers room",
    "bus": "Bus stop",
    "taxi": "Taxi drop-off",
    "parking": "Car park",
    "outdoor": "Garden & outdoor",
    "bookshop": "Bookshop",
}

# Names the PDF's Open Day inset points at a numbered building (leader lines checked by eye).
INSET_PLACES = [
    ("Library", "library", "Red 8", ["books", "study", "borrow", "computers"]),
    ("Mal Nairn Auditorium", "venue", "Red 7", ["theatre", "theater", "lecture", "hall", "events"]),
    ("CDU Services", "services", "Red 2", ["student services", "help", "enrolment", "id card"]),
    ("Gulwa – The Austin Asche Hall", "venue", "Red 2", ["hall", "austin asche", "events"]),
    ("Nan Giese Gallery", "gallery", "Orange 10", ["art", "exhibition"]),
    ("Northern Editions Gallery", "gallery", "Orange 9", ["art", "printmaking", "exhibition"]),
    ("Northern Institute – Savanna Room", "venue", "Yellow 1", ["level 2", "meeting room"]),
]

# Outdoor places printed on the PDF (ids match the area labels in labels.geojson).
OUTDOOR = {
    "area-boab-court": ["courtyard", "lawn", "eat", "sit"],
    "area-the-mall": ["walkway"],
    "area-the-strand": ["lawn", "green"],
    "area-chinese-garden": ["garden", "pond", "pagoda", "quiet"],
    "area-student-square": ["square", "meet"],
    "area-sports-oval": ["oval", "sport", "football", "cricket", "pirates oval", "gym"],
}

PRECINCT_RGB = {
    "Purple": (110, 93, 165), "Orange": (243, 144, 62), "Red": (228, 0, 64),
    "Yellow": (255, 218, 0), "Blue": (0, 131, 202), "Green": (40, 155, 56),
    "Brown": (194, 88, 18), "Pink": (239, 133, 173),
}

KX = 111_320 * math.cos(math.radians(-12.372))
KY = 110_574


def metres(a, b):
    return math.hypot((a[0] - b[0]) * KX, (a[1] - b[1]) * KY)


def point_in_polygon(pt, geom):
    polys = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
    for poly in polys:
        inside = False
        for ring in poly:
            for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
                if (y1 > pt[1]) != (y2 > pt[1]):
                    if x1 + (pt[1] - y1) * (x2 - x1) / (y2 - y1) > pt[0]:
                        inside = not inside
        if inside:
            return True
    return False


def main():
    buildings = json.load(open(os.path.join(ASSETS, "buildings.geojson"), encoding="utf-8"))["features"]
    labels = json.load(open(os.path.join(ASSETS, "labels.geojson"), encoding="utf-8"))["features"]
    by_label = {f["properties"]["label"]: f for f in buildings if f["properties"]["label"]}
    label_point = {f["properties"]["id"]: f["geometry"]["coordinates"] for f in labels}
    osm = json.load(open(OSM_POIS, encoding="utf-8"))["elements"]

    def building_at(pt):
        for f in buildings:
            if point_in_polygon(pt, f["geometry"]):
                return f
        # icons are often printed just beside the building: take the nearest within 15 m
        best, bd = None, 15.0
        for f in buildings:
            c = label_point.get(f["properties"]["id"])
            if c and metres(pt, c) < bd:
                best, bd = f, metres(pt, c)
        return best

    places = []

    def add(name, category, pt, source, building=None, aliases=(), note=""):
        props = {
            "id": f"place-{len(places)}",
            "name": name,
            "category": category,
            "categoryName": CATEGORIES[category],
            "building": building["properties"]["label"] if building else "",
            "buildingId": building["properties"]["id"] if building else "",
            "aliases": list(aliases),
            "source": source,
        }
        if note:
            props["note"] = note
        places.append({"type": "Feature", "id": props["id"], "properties": props,
                       "geometry": {"type": "Point", "coordinates": [round(pt[0], 7), round(pt[1], 7)]}})

    # 1. Named places from the PDF inset, placed at their building
    for name, cat, label, aliases in INSET_PLACES:
        b = by_label[label]
        add(name, cat, label_point[b["properties"]["id"]], "PDF inset", b, aliases)

    # 2. Outdoor places printed on the PDF
    for f in labels:
        aid = f["properties"]["id"]
        if aid in OUTDOOR:
            add(f["properties"]["label"], "outdoor", f["geometry"]["coordinates"], "PDF label",
                aliases=OUTDOOR[aid])

    # 3. Facility icons printed on the PDF
    icons, _, _ = find_icons()
    rgb = load_rgb(CLEAN)
    osm_parking = [(e["tags"]["name"], (e["center"]["lon"], e["center"]["lat"]))
                   for e in osm if e.get("tags", {}).get("amenity") == "parking"
                   and e["tags"].get("name") and e.get("center")]
    osm_bus = [(e["tags"].get("name", "Bus stop"), (e["lon"], e["lat"]))
               for e in osm if e.get("tags", {}).get("highway") == "bus_stop" and "lon" in e]
    seen = []
    for kind, lon, lat, score, px, py in icons:
        pt = (lon, lat)
        # the "i" information kiosk at Orange 1 looks like the parents-room icon to the matcher
        if kind == "parents" and abs(px - 1756) < 15 and abs(py - 1096) < 15:
            kind = "info"
        if any(k == kind and metres(pt, p) < 12 for k, p in seen):
            continue  # same icon twice (e.g. a split blob)
        seen.append((kind, pt))
        if kind == "bus" and any(metres(pt, p) < 60 for _, p in osm_bus):
            continue  # OSM has this stop with its real name
        # Security's shield is printed where Orange 7 and 8 meet, so no building is named.
        b = building_at(pt) if kind not in ("parking", "bus", "taxi", "security") else None
        where = f" – {b['properties']['label']}" if b and b["properties"]["label"] else ""
        if kind == "toilets":
            add(f"Toilets{where}", "toilets", pt, "PDF icon", b,
                ["toilet", "wc", "bathroom", "restroom", "accessible toilet"])
        elif kind == "food":
            add(f"Food & café{where}", "food", pt, "PDF icon", b,
                ["cafe", "coffee", "eat", "lunch", "canteen", "food"])
        elif kind == "atm":
            add(f"ATM{where}", "atm", pt, "PDF icon", b, ["cash", "bank", "money"])
        elif kind == "post":
            add(f"Post office{where}", "post", pt, "PDF icon", b, ["mail", "letters", "parcel"])
        elif kind == "security":
            add(f"Campus Security{where}", "security", pt, "PDF icon", b,
                ["help", "emergency", "lost", "found", "safety"])
        elif kind == "parents":
            add(f"Parents & carers room{where}", "parents", pt, "PDF icon", b,
                ["baby", "change", "parent", "feeding"])
        elif kind == "info":
            add(f"Information{where}", "info", pt, "PDF icon", b, ["help", "information", "welcome"])
        elif kind == "taxi":
            add("Accessible taxi drop-off", "taxi", pt, "PDF icon", None, ["taxi", "drop off", "uber"])
        elif kind == "parking":
            near = sorted((metres(pt, p), n) for n, p in osm_parking)
            if near and near[0][0] < 70:
                name = near[0][1].replace("Carpark", "car park").replace("Pink car park A", "Pink A car park")
            else:
                # precinct from the coloured letter box printed beside the P
                sx, sy = min(px + 40, rgb.shape[1] - 1), py
                c = rgb[sy, sx].astype(int)
                prec = min(PRECINCT_RGB, key=lambda k: sum(abs(c - PRECINCT_RGB[k])))
                close = sum(abs(c - PRECINCT_RGB[prec])) < 90
                name = f"{prec} car park" if close else "Car park"
            add(name, "parking", pt, "PDF icon", None, ["parking", "car park", "car"])

    # 4. OSM bus stops on or next to campus
    for name, pt in osm_bus:
        add(f"Bus stop – {name}", "bus", pt, "OSM", None, ["bus", "stop", "public transport"])

    # 5. Places you add yourself
    if os.path.exists(MANUAL):
        for m in json.load(open(MANUAL, encoding="utf-8")).get("places", []):
            b = by_label.get(m.get("building", ""))
            pt = m.get("lonlat") or (label_point[b["properties"]["id"]] if b else None)
            if pt:
                add(m["name"], m["category"], pt, "manual", b, m.get("aliases", []), m.get("note", ""))

    with open(os.path.join(ASSETS, "places.geojson"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"type": "FeatureCollection",
                   "attribution": "Places: CDU Casuarina Campus Map (Aug 2024) icons and labels; "
                                  "bus stops and some names (c) OpenStreetMap contributors (ODbL).",
                   "features": places}, f, ensure_ascii=False, separators=(",", ":"))

    from collections import Counter
    print(len(places), "places:", dict(Counter(p["properties"]["category"] for p in places)))
    for p in places:
        pr = p["properties"]
        if pr["category"] not in ("toilets",):
            print(f'  {pr["category"]:9s} {pr["name"]:42s} [{pr["source"]}]')


if __name__ == "__main__":
    main()
