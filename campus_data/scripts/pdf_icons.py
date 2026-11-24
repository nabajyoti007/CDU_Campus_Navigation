"""Find the facility icons printed on the CDU PDF map (toilets, food, ATM, ...).

Each icon is a ~40 px blue square (at 400 dpi) with a white symbol. The script
finds every blue square on the map, compares it with the icons in the PDF's key,
and converts its position to latitude/longitude with the QGIS control points.

Input : campus_data/source/cdu_campus_map.png (+ .points), the uncleaned crop
        that still contains the key.
Output: list of (kind, lon, lat, score, px, py) from find_icons().
"""
import os

import numpy as np
from osgeo import gdal

gdal.UseExceptions()

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "campus_data", "source", "cdu_campus_map.png")
POINTS = SRC + ".points"

ICON_BLUE = np.array([0, 98, 158])
BLUE_TOL = 60

# Key area in the crop, and the column x-ranges of the two icon columns.
KEY_BOX = (130, 1555, 1190, 1955)  # x0, y0, x1, y1
KEY_ORDER = {  # (column, row) -> kind, as printed in the key
    (0, 0): "parking", (0, 1): "atm", (0, 2): "food", (0, 3): "taxi",
    (1, 0): "bus", (1, 1): "security", (1, 2): "toilets", (1, 3): "post", (1, 4): "parents",
}
TEMPLATE = 24  # icons are compared at 24 x 24 px


def load_rgb(path):
    ds = gdal.Open(path)
    return np.stack([ds.GetRasterBand(i + 1).ReadAsArray() for i in range(3)], -1).astype(np.int16)


def blue_mask(rgb):
    return np.abs(rgb - ICON_BLUE).sum(-1) <= BLUE_TOL


def components(mask, min_px=150):
    """Bounding boxes of 8-connected blobs (pure Python flood fill; masks are sparse)."""
    seen = np.zeros_like(mask, dtype=bool)
    ys, xs = np.nonzero(mask)
    h, w = mask.shape
    boxes = []
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        n, minx, maxx, miny, maxy = 0, x0, x0, y0, y0
        while stack:
            y, x = stack.pop()
            n += 1
            minx, maxx, miny, maxy = min(minx, x), max(maxx, x), min(miny, y), max(maxy, y)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True
                        stack.append((yy, xx))
        if n >= min_px:
            boxes.append((minx, miny, maxx + 1, maxy + 1))
    return boxes


def squares(box, size):
    """Split a blob that is several icons side by side into single squares."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    nx = max(1, round(w / size))
    ny = max(1, round(h / size))
    out = []
    for i in range(nx):
        for j in range(ny):
            out.append((x0 + i * w / nx, y0 + j * h / ny, x0 + (i + 1) * w / nx, y0 + (j + 1) * h / ny))
    return out


def tile(rgb, box):
    """Icon crop resized to TEMPLATE x TEMPLATE, as 'white symbol' mask (float)."""
    x0, y0, x1, y1 = (int(round(v)) for v in box)
    crop = rgb[y0:y1, x0:x1]
    if crop.size == 0:
        return None
    white = (crop.min(-1) > 170).astype(np.float32)
    ys = (np.arange(TEMPLATE) * crop.shape[0] / TEMPLATE).astype(int)
    xs = (np.arange(TEMPLATE) * crop.shape[1] / TEMPLATE).astype(int)
    return white[ys][:, xs]


def key_templates(rgb):
    x0, y0, x1, y1 = KEY_BOX
    key = rgb[y0:y1, x0:x1]
    boxes = [b for b in components(blue_mask(key), 300) if 25 <= b[2] - b[0] <= 60]
    left = sorted([b for b in boxes if b[0] < 300], key=lambda b: b[1])
    right = sorted([b for b in boxes if b[0] >= 300], key=lambda b: b[1])
    temps, size = {}, []
    for col, column in enumerate((left, right)):
        for row, b in enumerate(column):
            kind = KEY_ORDER.get((col, row))
            if kind is None:
                continue
            bb = (b[0] + x0, b[1] + y0, b[2] + x0, b[3] + y0)
            if kind == "parking":  # the key's P has a 'FREE' strip below; use the square part
                bb = (bb[0], bb[1], bb[2], bb[1] + (bb[2] - bb[0]))
            temps[kind] = tile(rgb, bb)
            size.append(bb[2] - bb[0])
    return temps, float(np.median(size))


def gcp_transformer():
    gcps = []
    with open(POINTS, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or line.startswith("mapX"):
                continue
            mx, my, sx, sy, en = line.strip().split(",")[:5]
            if en.strip() == "1":
                gcps.append(gdal.GCP(float(mx), float(my), 0, float(sx), -float(sy)))
    ds = gdal.Translate("/vsimem/icons_gcp.tif", SRC, format="GTiff", GCPs=gcps, outputSRS="EPSG:4326")
    return gdal.Transformer(ds, None, ["METHOD=GCP_POLYNOMIAL", "MAX_GCP_ORDER=2"]), ds


CLEAN = os.path.join(ROOT, "campus_data", "source", "cdu_campus_map_clean.png")


def find_icons(min_score=0.80):
    # Templates come from the key (only in the original crop); icons are searched
    # in the cleaned crop, where the white Open Day inset lines no longer cross them.
    temps, size = key_templates(load_rgb(SRC))
    rgb = load_rgb(CLEAN)
    x0k, y0k, x1k, y1k = KEY_BOX
    mask = blue_mask(rgb)
    mask[y0k:y1k, x0k:x1k] = False  # not the key area
    tr, _ds = gcp_transformer()
    found = []
    for box in components(mask, int(size * size * 0.3)):
        w, h = box[2] - box[0], box[3] - box[1]
        if not (0.6 * size <= min(w, h) <= 1.5 * size) or max(w, h) > 4.5 * size:
            continue  # not icon-sized (banners, buildings)
        for sq in squares(box, size):
            t = tile(rgb, sq)
            if t is None:
                continue
            best, score = None, -1.0
            for kind, tp in temps.items():
                # similarity of the white symbol shapes (1 = identical)
                s = 1.0 - np.abs(t - tp).mean()
                if s > score:
                    best, score = kind, s
            if score >= min_score:
                cx, cy = (sq[0] + sq[2]) / 2, (sq[1] + sq[3]) / 2
                ok, (lon, lat, _z) = tr.TransformPoint(0, cx, cy)
                found.append((best, lon, lat, round(score, 3), int(cx), int(cy)))
    return found, temps, size


if __name__ == "__main__":
    found, temps, size = find_icons()
    print("templates:", sorted(temps), "icon size", size)
    from collections import Counter
    print(Counter(k for k, *_ in found))
    for f in sorted(found):
        print(f)
