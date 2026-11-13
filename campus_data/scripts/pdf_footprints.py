"""Trace building shapes from the georeferenced CDU PDF by their precinct colour.

Used only for buildings that are on the PDF but missing from OpenStreetMap.
Returns polygons in lon/lat with the precinct each one was coloured as.
"""
import numpy as np
from osgeo import gdal, ogr, osr

from osm_buildings import MERC, WGS84, PdfSampler

# Building fill colours on the PDF (measured under OSM-named buildings)
BUILDING_COLOURS = {
    "Purple": (110, 93, 165),
    "Orange": (243, 144, 62),
    "Red": (228, 0, 64),
    "Yellow": (255, 218, 0),
    "Blue": (0, 131, 202),
    "BlueUC": (157, 199, 238),  # light blue = Blue 8 (Under Construction)
    "Green": (40, 155, 56),
    "Brown": (194, 88, 18),
    "Pink": (239, 133, 173),
}
TOLERANCE = 40  # sum of absolute RGB differences


def _shift_or(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def _close(m, r=3):
    """Morphological closing: fills white numbers/icons printed on top of buildings."""
    dil = _shift_or(m, r)
    return ~_shift_or(~dil, r)


def trace(sampler: PdfSampler, min_area_m2=25.0, simplify_m=0.6):
    rgb = sampler.rgba[:, :, :3].astype(int)
    alpha = sampler.rgba[:, :, 3] > 0
    to_wgs = osr.CoordinateTransformation(MERC, WGS84)
    results = []
    for precinct, colour in BUILDING_COLOURS.items():
        mask = (np.abs(rgb - np.array(colour)).sum(-1) <= TOLERANCE) & alpha
        mask = _close(mask)
        drv = gdal.GetDriverByName("MEM")
        ds = drv.Create("", sampler.w, sampler.h, 1, gdal.GDT_Byte)
        ds.SetGeoTransform(sampler.gt)
        ds.SetProjection(MERC.ExportToWkt())
        ds.GetRasterBand(1).WriteArray(mask.astype(np.uint8))
        mem = gdal.GetDriverByName("MEM").Create("", 0, 0, 0, gdal.GDT_Unknown)
        lyr = mem.CreateLayer("p", MERC, ogr.wkbPolygon)
        lyr.CreateField(ogr.FieldDefn("v", ogr.OFTInteger))
        band = ds.GetRasterBand(1)
        gdal.Polygonize(band, band, lyr, 0)
        for f in lyr:
            g = f.GetGeometryRef()
            if g.GetArea() < min_area_m2:
                continue
            g = g.SimplifyPreserveTopology(simplify_m)
            g = g.Clone()
            g.Transform(to_wgs)
            results.append((precinct, g))
    return results
