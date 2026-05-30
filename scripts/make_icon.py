#!/usr/bin/env python3
"""Generate the OpenCan app icon: a dented tin can on a macOS squircle.

Draws a master image at high resolution with Pillow, then downsamples to all the
sizes a macOS AppIcon.appiconset needs. No SVG renderer required.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024          # final master size
SS = 4            # supersample factor for antialiasing
W = S * SS        # working canvas size

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "App", "Assets.xcassets", "AppIcon.appiconset")


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def vertical_gradient(size, top, bottom):
    w, h = size
    grad = Image.new("RGB", (1, h))
    for y in range(h):
        grad.putpixel((0, y), lerp(top, bottom, y / max(1, h - 1)))
    return grad.resize((w, h))


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def draw_background(img):
    """macOS squircle with a soft blue-steel gradient."""
    grad = vertical_gradient((W, W), (74, 144, 226), (28, 64, 122)).convert("RGBA")
    radius = int(W * 0.225)
    mask = rounded_mask((W, W), radius)
    img.paste(grad, (0, 0), mask)

    # subtle top sheen
    sheen = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    sd.ellipse([int(-W * 0.2), int(-W * 0.55), int(W * 1.2), int(W * 0.35)],
               fill=(255, 255, 255, 38))
    sheen.putalpha(Image.composite(sheen.getchannel("A"), Image.new("L", (W, W), 0), mask))
    img.alpha_composite(sheen)


def gauss(x, mu, sigma):
    return math.exp(-((x - mu) ** 2) / (2 * sigma ** 2))


def draw_can(img):
    cx = W * 0.5
    top = W * 0.250     # top of can body (below lid)
    bot = W * 0.795     # bottom of can body
    hw = W * 0.200      # half width
    lid_h = W * 0.082   # lid ellipse height
    body_l, body_r = cx - hw, cx + hw
    body_h = bot - top

    # ---- dented silhouette: right edge caves in, with a secondary left crush ----
    dy_r = top + body_h * 0.66      # main dent center (right)
    sig_r = body_h * 0.13
    depth_r = hw * 0.62
    dy_l = top + body_h * 0.50      # smaller crush (left)
    sig_l = body_h * 0.10
    depth_l = hw * 0.22

    def right_x(y):
        return body_r - depth_r * gauss(y, dy_r, sig_r)

    def left_x(y):
        return body_l + depth_l * gauss(y, dy_l, sig_l)

    ys = [top + i for i in range(int(body_h) + 1)]
    left_pts = [(left_x(y), y) for y in ys]
    right_pts = [(right_x(y), y) for y in ys]
    poly = left_pts + right_pts[::-1]

    body_mask = Image.new("L", (W, W), 0)
    ImageDraw.Draw(body_mask).polygon(poly, fill=255)

    # ---- body image: metallic vertical gradient + cylinder + label band ----
    body = vertical_gradient((W, W), (238, 240, 245), (158, 164, 174)).convert("RGBA")

    # cylinder horizontal shading + bright highlight (per column, relative to can center)
    col = Image.new("L", (W, 1), 0)
    hicol = Image.new("L", (W, 1), 0)
    for x in range(W):
        t = (x - body_l) / (2 * hw)
        t = min(1.0, max(0.0, t))
        edge = (abs(t - 0.5) * 2) ** 1.7
        col.putpixel((x, 0), int(max(0, min(255, 120 * edge))))
        hicol.putpixel((x, 0), int(210 * gauss(t, 0.33, 0.05)))
    col = col.resize((W, W))
    hicol = hicol.resize((W, W))
    dark = Image.new("RGBA", (W, W), (44, 48, 58, 255))
    white = Image.new("RGBA", (W, W), (255, 255, 255, 255))
    body = Image.composite(dark, body, col)
    body = Image.composite(white, body, hicol)

    # label band
    band_top = top + body_h * 0.36
    band_bot = top + body_h * 0.60
    band_grad = vertical_gradient((W, W), (230, 92, 76), (170, 44, 42)).convert("RGBA")
    band_grad = Image.composite(dark, band_grad, col)  # same cylinder shading
    band_region = Image.new("L", (W, W), 0)
    ImageDraw.Draw(band_region).rectangle([0, band_top, W, band_bot], fill=255)
    body = Image.composite(band_grad, body, band_region)

    # ---- dent shading: strong concave shadow + bright upper crease ----
    shadow_map = Image.new("L", (W, W), 0)
    sd = ImageDraw.Draw(shadow_map)
    for (ox, oy, rx, ry, val) in [
        (0.34, 0.00, 0.30, 0.22, 190),   # main right crush
        (0.20, 0.10, 0.22, 0.18, 150),
        (0.42, -0.10, 0.16, 0.12, 130),
        (-0.40, 0.0, 0.16, 0.14, 110),   # left crush
    ]:
        cxp, cyp = cx + ox * hw, dy_r + oy * hw
        sd.ellipse([cxp - rx * hw, cyp - ry * hw, cxp + rx * hw, cyp + ry * hw], fill=val)
    shadow_map = shadow_map.filter(ImageFilter.GaussianBlur(W * 0.016))
    deep = Image.new("RGBA", (W, W), (28, 30, 38, 255))
    body = Image.composite(deep, body, shadow_map)

    crease = Image.new("L", (W, W), 0)
    cr = ImageDraw.Draw(crease)
    for (cxo, cyo, rx, ry, a0, a1) in [
        (0.18, -0.20, 0.40, 0.20, 195, 345),
        (0.10, 0.26, 0.34, 0.12, 200, 340),
        (-0.34, -0.14, 0.18, 0.16, 200, 350),
    ]:
        cxp, cyp = cx + cxo * hw, dy_r + cyo * hw
        cr.arc([cxp - rx * hw, cyp - ry * hw, cxp + rx * hw, cyp + ry * hw],
               start=a0, end=a1, fill=235, width=int(W * 0.011))
    crease = crease.filter(ImageFilter.GaussianBlur(W * 0.005))
    body = Image.composite(white, body, crease)

    # apply the dented silhouette as the body's alpha
    body.putalpha(body_mask)

    # ---- drop shadow under the can ----
    ds = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(ds).ellipse([body_l, bot - lid_h * 0.5, body_r, bot + lid_h * 2.4],
                               fill=(0, 0, 0, 110))
    ds = ds.filter(ImageFilter.GaussianBlur(W * 0.022))
    img.alpha_composite(ds)

    # ---- bottom rim ----
    rim = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.ellipse([body_l, bot - lid_h, body_r, bot + lid_h], fill=(158, 164, 174, 255),
               outline=(112, 118, 128, 255), width=int(W * 0.006))
    img.alpha_composite(rim)

    img.alpha_composite(body)

    # ---- lid (drawn last, undented) ----
    lid = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lid)
    lid_top = top - lid_h
    ld.ellipse([body_l, lid_top, body_r, top + lid_h * 0.10], fill=(212, 216, 224, 255),
               outline=(120, 126, 136, 255), width=int(W * 0.007))
    ld.ellipse([body_l + hw * 0.16, lid_top + lid_h * 0.30,
                body_r - hw * 0.16, top - lid_h * 0.34], fill=(178, 184, 194, 255))
    tabx0, tabx1 = cx - hw * 0.34, cx + hw * 0.08
    taby = lid_top + lid_h * 0.52
    ld.ellipse([tabx0, taby, tabx1, taby + lid_h * 0.7],
               outline=(120, 126, 136, 255), width=int(W * 0.010))
    img.alpha_composite(lid)


def main():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw_background(img)
    draw_can(img)
    master = img.resize((S, S), Image.LANCZOS)

    os.makedirs(OUT_DIR, exist_ok=True)
    master_path = os.path.join(OUT_DIR, "icon_1024.png")
    master.save(master_path)

    sizes = {
        "icon_16.png": 16, "icon_32.png": 32, "icon_64.png": 64,
        "icon_128.png": 128, "icon_256.png": 256, "icon_512.png": 512,
        "icon_1024.png": 1024,
    }
    for name, px in sizes.items():
        master.resize((px, px), Image.LANCZOS).save(os.path.join(OUT_DIR, name))
        print(f"wrote {name} ({px}px)")

    contents = '''{
  "images" : [
    {"idiom":"mac","scale":"1x","size":"16x16","filename":"icon_16.png"},
    {"idiom":"mac","scale":"2x","size":"16x16","filename":"icon_32.png"},
    {"idiom":"mac","scale":"1x","size":"32x32","filename":"icon_32.png"},
    {"idiom":"mac","scale":"2x","size":"32x32","filename":"icon_64.png"},
    {"idiom":"mac","scale":"1x","size":"128x128","filename":"icon_128.png"},
    {"idiom":"mac","scale":"2x","size":"128x128","filename":"icon_256.png"},
    {"idiom":"mac","scale":"1x","size":"256x256","filename":"icon_256.png"},
    {"idiom":"mac","scale":"2x","size":"256x256","filename":"icon_512.png"},
    {"idiom":"mac","scale":"1x","size":"512x512","filename":"icon_512.png"},
    {"idiom":"mac","scale":"2x","size":"512x512","filename":"icon_1024.png"}
  ],
  "info" : {"author":"xcode","version":1}
}
'''
    with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
        f.write(contents)
    print("wrote Contents.json")


if __name__ == "__main__":
    main()
