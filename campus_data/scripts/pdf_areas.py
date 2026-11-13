"""Trace the pale precinct background areas, lawns and the sports oval from the CDU PDF."""
import numpy as np
from osgeo import gdal, ogr, osr

from osm_buildings import MERC, WGS84, PdfSampler
from pdf_footprints import _close, _shift_or

# Background tints printed on the PDF (most common colours, quantised to 4)
AREA_COLOURS = {
    "Pink": (248, 208, 224),
    "Brown": (232, 184, 152),
    "Orange": (252, 212, 180),
    "Purple": (208, 204, 228),
    "Blue": (188, 212, 240),
    "Red": (244, 176, 172),
    "Yellow": (252, 232, 160),
    "Green": (184, 212, 172),
    "lawn": (212, 228, 216),
    "oval": (144, 192, 128),
}
TOLERANCE = 18


def _open(m, r):
    ero = ~_shift_or(~m, r)
    return _shift_or(ero, r)


def trace_areas(sampler: PdfSampler, min_area_m2=300.0):
    rgb = sampler.rgba[:, :, :3].astype(int)
    alpha = sampler.rgba[:, :, 3] > 0
    to_wgs = osr.CoordinateTransformation(MERC, WGS84)
    out = []
    for kind, colour in AREA_COLOURS.items():
        mask = (np.abs(rgb - np.array(colour)).sum(-1) <= TOLERANCE) & alpha
        mask = _close(mask, 6)   # bridge thin paths and printed text (~3 m)
        mask = _open(mask, 2)    # drop specks
        ds = gdal.GetDriverByName("MEM").Create("", sampler.w, sampler.h, 1, gdal.GDT_Byte)
        ds.SetGeoTransform(sampler.gt)
        ds.SetProjection(MERC.ExportToWkt())
        ds.GetRasterBand(1).WriteArray(mask.astype(np.uint8))
        mem = gdal.GetDriverByName("MEM").Create("", 0, 0, 0, gdal.GDT_Unknown)
        lyr = mem.CreateLayer("a", MERC, ogr.wkbPolygon)
        lyr.CreateField(ogr.FieldDefn("v", ogr.OFTInteger))
        band = ds.GetRasterBand(1)
        gdal.Polygonize(band, band, lyr, 0)
        for f in lyr:
            g = f.GetGeometryRef()
            if g.GetArea() < min_area_m2:
                continue
            # smooth the pixel staircase: round out, round in, simplify
            g = g.Buffer(2.0, 4).Buffer(-2.0, 4).SimplifyPreserveTopology(1.0)
            if g is None or g.IsEmpty():
                continue
            g = g.Clone()
            g.Transform(to_wgs)
            out.append((kind, g))
    return out


def pixel_to_lonlat(sampler: PdfSampler, col, row):
    gt = sampler.gt
    x, y = gt[0] + col * gt[1], gt[3] + row * gt[5]
    t = osr.CoordinateTransformation(MERC, WGS84)
    lon, lat, _ = t.TransformPoint(x, y)
    return lon, lat
