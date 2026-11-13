"""Remove print-only artwork from the CDU campus map image.

Input : campus_data/source/cdu_campus_map.png  (crop of the Aug 2024 PDF, 400 dpi)
Output: campus_data/source/cdu_campus_map_clean.png

Removes:
  * the white outline of the "Open Day" inset rectangle and its two leader lines
  * the Key box (bottom left) and the scale bar (the scale is wrong once zoomed in the app)

Nothing else is changed, so the pixel grid still matches cdu_campus_map.png.points.
Run with the QGIS Python (OSGeo4W shell):  python clean_map.py <in.png> <out.png>
"""
import sys

import numpy as np
from osgeo import gdal

gdal.UseExceptions()

NAVY = (33, 24, 88)  # background colour of the PDF


def read_rgb(path):
    ds = gdal.Open(path)
    return np.stack([ds.GetRasterBand(i + 1).ReadAsArray() for i in range(3)], -1).astype(float)


def fill_vertical(img, x0, x1, y0, y1, pad=2):
    """Replace columns x0..x1 (plus pad) by blending the pixels just left and right of them."""
    xl, xr = x0 - pad - 1, x1 + pad + 1
    for x in range(x0 - pad, x1 + pad + 1):
        t = (x - xl) / (xr - xl)
        img[y0:y1 + 1, x] = (1 - t) * img[y0:y1 + 1, xl] + t * img[y0:y1 + 1, xr]


def fill_horizontal(img, y0, y1, x0, x1, pad=2):
    """Replace rows y0..y1 (plus pad) by blending the pixels just above and below them."""
    ya, yb = y0 - pad - 1, y1 + pad + 1
    for y in range(y0 - pad, y1 + pad + 1):
        t = (y - ya) / (yb - ya)
        img[y, x0:x1 + 1] = (1 - t) * img[ya, x0:x1 + 1] + t * img[yb, x0:x1 + 1]


def fill_diagonal(img, y0, y1, centre_x, half=4):
    """Line that is mostly vertical: per row, blend across [c-half, c+half]."""
    for y in range(y0, y1 + 1):
        c = int(round(centre_x(y)))
        xl, xr = c - half - 1, c + half + 1
        for x in range(c - half, c + half + 1):
            t = (x - xl) / (xr - xl)
            img[y, x] = (1 - t) * img[y, xl] + t * img[y, xr]


def main(src, dst):
    img = read_rgb(src)
    h, w, _ = img.shape
    bottom = h - 1

    # Inset rectangle (measured white runs: x 805-809 / 1780-1784, y 481-485 / 1361-1365)
    fill_vertical(img, 805, 809, 479, 1367)
    fill_vertical(img, 1780, 1784, 479, 1367)
    fill_horizontal(img, 481, 485, 803, 1786)
    fill_horizontal(img, 1361, 1365, 803, 1786)

    # Leader lines from the rectangle down to the inset (off the bottom of the crop)
    fill_vertical(img, 1201, 1205, 1361, bottom)
    fill_diagonal(img, 1361, bottom, lambda y: 1412 - 0.3 * (y - 1370))

    # Key box and scale bar sit on plain navy background
    img[1560:1946, 135:1181] = NAVY
    img[1860:1941, 1340:1566] = NAVY

    out = np.clip(np.round(img), 0, 255).astype(np.uint8)
    drv = gdal.GetDriverByName("MEM").Create("", w, h, 3, gdal.GDT_Byte)
    for i in range(3):
        drv.GetRasterBand(i + 1).WriteArray(out[:, :, i])
    gdal.GetDriverByName("PNG").CreateCopy(dst, drv)
    print("written", dst, w, "x", h)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
