"""Shared helpers: read OSM buildings and sample the georeferenced CDU PDF under them."""
import json
import os

import numpy as np
from osgeo import gdal, ogr, osr

gdal.UseExceptions()
ogr.UseExceptions()

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OSM_JSON = os.path.join(ROOT, "campus_data", "osm", "campus_osm.json")
PDF_3857 = os.path.join(ROOT, "campus_data", "output", "cdu_campus_map_3857.tif")

WGS84 = osr.SpatialReference()
WGS84.ImportFromEPSG(4326)
WGS84.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
MERC = osr.SpatialReference()
MERC.ImportFromEPSG(3857)
TO_MERC = osr.CoordinateTransformation(WGS84, MERC)


def load_osm():
    with open(OSM_JSON, encoding="utf-8") as f:
        return json.load(f)["elements"]


def ring(coords):
    r = ogr.Geometry(ogr.wkbLinearRing)
    for lon, lat in coords:
        r.AddPoint_2D(lon, lat)
    r.CloseRings()
    return r


def element_polygon(e):
    """OGR polygon (lon/lat) for a closed way or a multipolygon relation (outer rings only)."""
    if e["type"] == "way":
        pts = [(p["lon"], p["lat"]) for p in e.get("geometry", [])]
        if len(pts) < 4 or pts[0] != pts[-1]:
            return None
        poly = ogr.Geometry(ogr.wkbPolygon)
        poly.AddGeometry(ring(pts))
        return poly
    if e["type"] == "relation":
        outers = join_ways(m for m in e.get("members", []) if m.get("role") == "outer")
        inners = join_ways(m for m in e.get("members", []) if m.get("role") == "inner")
        multi = ogr.Geometry(ogr.wkbMultiPolygon)
        for o in outers:
            poly = ogr.Geometry(ogr.wkbPolygon)
            poly.AddGeometry(ring(o))
            outer_poly = poly.Clone()
            for i in inners:
                hole = ogr.Geometry(ogr.wkbPolygon)
                hole.AddGeometry(ring(i))
                if outer_poly.Contains(hole):
                    poly.AddGeometry(ring(i))
            multi.AddGeometry(poly)
        if not multi.GetGeometryCount():
            return None
        return multi.GetGeometryRef(0).Clone() if multi.GetGeometryCount() == 1 else multi
    return None


def join_ways(members):
    """Join relation member ways that share end points into closed rings."""
    parts = [[(p["lon"], p["lat"]) for p in m["geometry"]] for m in members if m.get("geometry")]
    rings = []
    while parts:
        cur = parts.pop(0)
        changed = True
        while cur[0] != cur[-1] and changed:
            changed = False
            for i, p in enumerate(parts):
                if p[0] == cur[-1]:
                    cur += p[1:]
                elif p[-1] == cur[-1]:
                    cur += p[::-1][1:]
                elif p[-1] == cur[0]:
                    cur = p[:-1] + cur
                elif p[0] == cur[0]:
                    cur = p[::-1][:-1] + cur
                else:
                    continue
                parts.pop(i)
                changed = True
                break
        if len(cur) >= 4 and cur[0] == cur[-1]:
            rings.append(cur)
    return rings


class PdfSampler:
    """Reads colours from the georeferenced PDF (EPSG:3857 GeoTIFF with alpha)."""

    def __init__(self, path=PDF_3857):
        ds = gdal.Open(path)
        self.gt = ds.GetGeoTransform()
        self.rgba = np.stack([ds.GetRasterBand(i + 1).ReadAsArray() for i in range(4)], -1)
        self.h, self.w = self.rgba.shape[:2]

    def pixel(self, lon, lat):
        x, y, _ = TO_MERC.TransformPoint(lon, lat)
        col = int((x - self.gt[0]) / self.gt[1])
        row = int((y - self.gt[3]) / self.gt[5])
        return col, row

    def colours_inside(self, poly, step_m=1.5):
        """RGB of PDF pixels on a grid inside the polygon (shrunk 1 m to avoid outlines)."""
        minx, maxx, miny, maxy = poly.GetEnvelope()
        dlon = step_m / 108_700.0
        dlat = step_m / 110_600.0
        inner = poly.Buffer(-1.0 / 108_700.0)
        if inner is None or inner.IsEmpty():
            inner = poly
        out = []
        lat = miny + dlat / 2
        while lat < maxy:
            lon = minx + dlon / 2
            while lon < maxx:
                p = ogr.Geometry(ogr.wkbPoint)
                p.AddPoint_2D(lon, lat)
                if inner.Contains(p):
                    c, r = self.pixel(lon, lat)
                    if 0 <= c < self.w and 0 <= r < self.h and self.rgba[r, c, 3] > 0:
                        out.append(self.rgba[r, c, :3])
                lon += dlon
            lat += dlat
        return np.array(out, dtype=float).reshape(-1, 3)
