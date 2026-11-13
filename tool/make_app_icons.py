"""Draw the CDU Campus Navigator app icon in every size the app needs.

Design: white map pin with a red centre and a blue dotted walking path,
on CDU navy (#211858).

Writes:
  android/app/src/main/res/mipmap-*/ic_launcher.png             classic icon (rounded square)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive icon foreground
  android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png  Android 13+ themed icon
  web/icons/*.png, web/favicon.png                               web app icons
  assets/branding/app_icon.png                                   shown on the About screen

Run from the project root with a Python that has Pillow (e.g. the QGIS Python):
    python tool/make_app_icons.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
NAVY = (33, 24, 88, 255)
WHITE = (255, 255, 255, 255)
BLUE = (76, 141, 246, 255)
RED = (228, 0, 64, 255)
CLEAR = (0, 0, 0, 0)


def draw_icon(size, style):
    """style: 'rounded' | 'full' | 'foreground' | 'mono'."""
    s = size * 4  # draw large, shrink at the end for smooth edges
    bg = NAVY if style == "full" else CLEAR
    img = Image.new("RGBA", (s, s), bg)
    d = ImageDraw.Draw(img)
    if style == "rounded":
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=NAVY)

    # How much of the canvas the artwork uses. Adaptive-icon foregrounds must
    # keep their content inside the central 66/108 "safe zone".
    k = {"rounded": 1.0, "full": 0.78, "foreground": 0.6, "mono": 0.6}[style]
    mono = style == "mono"
    path_colour = WHITE if mono else BLUE
    cx = cy = s / 2

    def P(x, y):
        return (cx + (x - 0.5) * s * k, cy + (y - 0.5) * s * k)

    # dotted walking path from the bottom-left up towards the pin
    pts = [P(0.18, 0.84), P(0.32, 0.74), P(0.42, 0.78), P(0.52, 0.70)]
    r = s * k * 0.022
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for i in range(7):
            t = i / 6
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            d.ellipse([x - r, y - r, x + r, y + r], fill=path_colour)
    sx, sy = P(0.18, 0.84)
    r2 = s * k * 0.045
    d.ellipse([sx - r2, sy - r2, sx + r2, sy + r2],
              fill=CLEAR if mono else WHITE, outline=path_colour, width=int(s * k * 0.02))

    # map pin
    px, top = P(0.58, 0.16)
    pr = s * k * 0.20
    head_cy = top + pr
    d.ellipse([px - pr, top, px + pr, top + 2 * pr], fill=WHITE)
    tip = P(0.58, 0.72)
    d.polygon([(px - pr * 0.82, head_cy + pr * 0.45), (px + pr * 0.82, head_cy + pr * 0.45), tip],
              fill=WHITE)
    ir = pr * 0.45
    d.ellipse([px - ir, head_cy - ir, px + ir, head_cy + ir], fill=CLEAR if mono else RED)

    return img.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main():
    res = ("android", "app", "src", "main", "res")
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, px in legacy.items():
        save(draw_icon(px, "rounded"), *res, f"mipmap-{density}", "ic_launcher.png")
        fg = int(px * 108 / 48)  # adaptive layers are 108dp
        save(draw_icon(fg, "foreground"), *res, f"mipmap-{density}", "ic_launcher_foreground.png")
        save(draw_icon(fg, "mono"), *res, f"mipmap-{density}", "ic_launcher_monochrome.png")

    save(draw_icon(192, "rounded"), "web", "icons", "Icon-192.png")
    save(draw_icon(512, "rounded"), "web", "icons", "Icon-512.png")
    save(draw_icon(192, "full"), "web", "icons", "Icon-maskable-192.png")
    save(draw_icon(512, "full"), "web", "icons", "Icon-maskable-512.png")
    save(draw_icon(32, "rounded"), "web", "favicon.png")

    save(draw_icon(512, "rounded"), "assets", "branding", "app_icon.png")
    print("icons written")


if __name__ == "__main__":
    main()
