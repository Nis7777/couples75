#!/usr/bin/env python3
"""Build recolouring masks and shading layers for every character image (run once, offline).

For each ArtSource/char_{id}_{pose}.png this writes three files to ArtSource/masks/:

    mask_{id}_{pose}_skin.png    face, ears, neck and both hands
    mask_{id}_{pose}_hair.png    hair (+ beard; for w5 the hijab)
    mask_{id}_{pose}_jacket.png  chest, both sleeves, collar

Each file is a grey + alpha PNG ("shading layer"): alpha is the region mask, grey is the region's original
brightness normalised so its brightest pixels are white. The app draws the original image, then each layer
multiplied by the chosen colour, so the new colour keeps the original shadows.

Outlines, eyes, mouth, trousers and shoes are never part of a mask.

How it works: every character has hand-picked anchor colours (base fill + shadow shades) for skin, hair and
jacket, plus "other" anchors (outline, trousers, shoes, eye whites). Each pixel is assigned to the nearest
anchor in Lab colour space. Regions are cleaned up with outline-bounded connected components (majority vote),
small specks are dropped, and dark hair (which is close in colour to outlines and trousers) is found as thick
dark blobs attached to the head.

Also writes ArtSource/masks/check/{id}.png: all five poses with skin = green, hair = blue, jacket = red,
for checking every result by eye, and copies the layers into the asset catalogs (stand + bust poses into
Shared/Assets.xcassets for the app and the widget; the other poses into App/Masks.xcassets).

Requires: Python 3, Pillow, numpy, scipy.   Run from the repo root:  python3 scripts/make_masks.py [ids...]
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "ArtSource")
OUT = os.path.join(SRC, "masks")
CHECK = os.path.join(OUT, "check")
CAT_SHARED = os.path.join(ROOT, "Shared", "Assets.xcassets")   # app + widget (stand, bust)
CAT_APP = os.path.join(ROOT, "App", "Masks.xcassets")          # app only (other poses)
POSES = ["stand", "crossed", "cheer", "stretch", "bust"]

# Anchor colours per character (RGB). "hair_dark" = hair is close to the outline colour and is found as dark blobs.
CHARS = {
    "w1": dict(skin=[(237, 144, 87), (235, 150, 97), (215, 128, 80)], hair=[(60, 41, 31)], hair_dark=True,
               jacket=[(246, 124, 102), (241, 130, 108), (223, 105, 84), (181, 77, 49)]),
    "w2": dict(skin=[(156, 88, 46), (124, 63, 28), (140, 76, 38)], hair=[(44, 33, 25)], hair_dark=True,
               jacket=[(226, 150, 55), (229, 159, 58), (205, 134, 46), (176, 111, 30)]),
    "w3": dict(skin=[(251, 186, 138), (230, 183, 149), (232, 160, 115)], hair=[(50, 41, 36)], hair_dark=True,
               jacket=[(192, 167, 206), (165, 144, 181), (116, 99, 127)]),
    "w4": dict(skin=[(223, 139, 85), (200, 120, 72), (150, 85, 47)], hair=[(51, 36, 28)], hair_dark=True,
               jacket=[(47, 110, 110), (38, 91, 92), (23, 68, 68)]),
    "w5": dict(skin=[(250, 173, 119), (228, 150, 100), (131, 82, 59)], hair=[(226, 138, 118), (225, 141, 120), (173, 93, 68)],
               hair_dark=False, jacket=[(117, 129, 108), (102, 113, 91), (76, 86, 68)]),
    "w6": dict(skin=[(252, 181, 128), (221, 142, 91)], hair=[(146, 76, 34), (128, 64, 26), (110, 55, 23)], hair_dark=False,
               jacket=[(48, 59, 87), (37, 47, 71), (23, 32, 51)]),
    "m1": dict(skin=[(253, 187, 138), (223, 144, 94)], hair=[(57, 40, 30)], hair_dark=True,
               jacket=[(114, 128, 104), (101, 112, 92), (86, 96, 76), (70, 79, 62)]),
    "m2": dict(skin=[(152, 87, 48), (130, 72, 38), (87, 49, 27)], hair=[(39, 36, 33)], hair_dark=True,
               jacket=[(40, 50, 75), (31, 39, 59), (20, 26, 42)]),
    "m3": dict(skin=[(253, 189, 139), (251, 191, 146), (227, 148, 100)], hair=[(48, 41, 35)], hair_dark=True,
               jacket=[(212, 109, 78), (189, 94, 62), (152, 70, 39)]),
    "m4": dict(skin=[(226, 146, 84), (205, 130, 72), (136, 90, 46)], hair=[(43, 36, 30)], hair_dark=True,
               jacket=[(231, 157, 57), (208, 137, 45), (172, 102, 31)]),
    "m5": dict(skin=[(251, 175, 120), (226, 140, 87), (201, 148, 112)], hair=[(56, 40, 30)], hair_dark=True,
               jacket=[(243, 123, 102), (223, 105, 84), (181, 78, 51)]),
    "m6": dict(skin=[(253, 191, 143), (232, 165, 120)], hair=[(229, 168, 107), (210, 150, 90), (157, 99, 52)],
               hair_dark=False, jacket=[(189, 165, 202), (167, 143, 180), (134, 115, 146), (103, 84, 115)]),
}
# Colours that are never recoloured.
OTHER = [(40, 33, 28), (50, 45, 42), (28, 23, 19), (248, 238, 228), (215, 205, 195), (176, 162, 150),
         (115, 70, 58), (90, 40, 35), (200, 90, 80)]


def rgb2lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def disk(r):
    y, x = np.ogrid[-r:r + 1, -r:r + 1]
    return x * x + y * y <= r * r


def classify(rgb, alpha, cfg):
    """Nearest-anchor labels: 0 other, 1 skin, 2 hair (light hair only), 3 jacket."""
    lab = rgb2lab(rgb.astype(float))
    anchors, labels = [], []
    for cls, key in ((1, "skin"), (3, "jacket")):
        for c in cfg[key]:
            anchors.append(c); labels.append(cls)
    if not cfg["hair_dark"]:
        for c in cfg["hair"]:
            anchors.append(c); labels.append(2)
    for c in OTHER:
        anchors.append(c); labels.append(0)
    alab = rgb2lab(np.array(anchors, float))
    w = np.array([0.6, 1.0, 1.0])  # lightness matters less than hue (shadows)
    best = np.full(lab.shape[:2], np.inf)
    near = np.zeros(lab.shape[:2], int)
    for i, al in enumerate(alab):
        di = (((lab - al) * w) ** 2).sum(-1)
        better = di < best
        best[better] = di[better]
        near[better] = i
    lbl = np.array(labels)[near]
    dist = np.sqrt(best)
    lbl[(dist > 26) & (lbl != 0)] = 0
    lbl[~alpha] = 0
    return lbl, lab


def majority_smooth(lbl, lab, alpha, speck):
    """Clean labels inside each outline-bounded fill region: small specks of another class and unclassified
    pixels adopt the region's dominant class. Large blobs keep their own class (a hand over a jacket stays skin)."""
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    chroma = np.hypot(a, b)
    barrier = (~alpha) | ((L < 30) & (chroma < 14))
    comp, n = ndi.label(~barrier)
    out = lbl.copy()
    if n == 0:
        return out
    counts = np.zeros((n + 1, 4), int)
    for cls in range(1, 4):
        counts[:, cls] = np.bincount(comp[lbl == cls].ravel(), minlength=n + 1)
    totals = np.bincount(comp.ravel(), minlength=n + 1)
    dom = counts.argmax(1)
    dom_frac = counts.max(1) / np.maximum(totals, 1)
    dom[0] = 0
    region_dom = dom[comp]
    # specks of a class that disagree with their region
    for cls in range(1, 4):
        blobs, m = ndi.label(lbl == cls, structure=np.ones((3, 3)))
        if m == 0:
            continue
        sizes = np.bincount(blobs.ravel())
        small = (sizes < speck)
        small[0] = False
        sel = small[blobs] & (region_dom != cls) & (region_dom != 0) & (dom_frac[comp] >= 0.6)
        out[sel] = region_dom[sel]
    # unclassified pixels (shading lines, anti-aliasing) inside a clearly dominated region
    sel = (lbl == 0) & (~barrier) & (region_dom != 0) & (dom_frac[comp] >= 0.7)
    out[sel] = region_dom[sel]
    return out


def drop_small(mask, min_area):
    comp, n = ndi.label(mask, structure=np.ones((3, 3)))
    if n == 0:
        return mask
    sizes = np.bincount(comp.ravel())
    keep = sizes >= min_area
    keep[0] = False
    return keep[comp]


def head_zone(skin, h, w, pose):
    """Face component: the largest skin blob whose centre is in the upper part of the figure."""
    comp, n = ndi.label(skin, structure=np.ones((3, 3)))
    best, best_area = None, 0
    for i in range(1, n + 1):
        ys, xs = np.nonzero(comp == i)
        if len(ys) < 200:
            continue
        cy = ys.mean() / h
        limit = 0.9 if pose == "bust" else 0.32
        if cy < limit and len(ys) > best_area:
            best, best_area = (ys.min(), ys.max(), xs.min(), xs.max()), len(ys)
    return best, best_area


def dark_hair(rgb, lab, alpha, skin, jacket, h, w, pose):
    L = lab[..., 0]
    chroma = np.hypot(lab[..., 1], lab[..., 2])
    dark = alpha & (L < 36) & ~jacket & ~skin
    r = 4 if pose == "bust" else 3
    opened = ndi.binary_opening(dark, structure=disk(r))
    face, face_area = head_zone(skin, h, w, pose)
    if face is None:
        return np.zeros_like(dark)
    fy0, fy1, fx0, fx1 = face
    fh, fw = fy1 - fy0, fx1 - fx0
    comp, n = ndi.label(opened, structure=np.ones((3, 3)))
    keep = np.zeros(n + 1, bool)
    chin = fy1
    below_limit = fy1 + (0.5 if pose == "bust" else 1.6) * fh
    skin_ring = ndi.binary_dilation(skin, structure=disk(3))
    for i in range(1, n + 1):
        blob = comp == i
        ys, xs = np.nonzero(blob)
        if len(ys) < 40:
            continue
        near_x = xs.max() >= fx0 - 1.3 * fw and xs.min() <= fx1 + 1.3 * fw
        if not near_x:
            continue
        if ys.min() > below_limit:
            continue
        # blobs entirely below the chin must be small hair ends near the head, not clothing
        if ys.min() > chin and len(ys) > 0.8 * face_area:
            continue
        # eyes / pupils: small blobs inside the face, surrounded by skin
        inside = ys.min() > fy0 and ys.max() < fy1 and xs.min() > fx0 and xs.max() < fx1
        if inside and len(ys) < 0.03 * face_area:
            ring = ndi.binary_dilation(blob, structure=disk(3)) & ~blob
            if ring.sum() and (skin_ring & ring).sum() / ring.sum() > 0.7:
                continue
        keep[i] = True
    blobs = keep[comp]
    # recover edges lost by the opening, but never outlines far from the blobs
    grown = ndi.binary_dilation(blobs, structure=disk(r + 1)) & dark
    # moustache: thin dark strokes connected to a beard, inside the lower face
    band = np.zeros_like(dark)
    band[int(fy0 + 0.62 * fh):fy1 + 1, fx0:fx1 + 1] = True
    beard_seed = grown & band
    if beard_seed.sum() > 0.01 * face_area:
        reach = dark & band
        lbl_r, nr = ndi.label(reach, structure=np.ones((3, 3)))
        ids = np.unique(lbl_r[beard_seed])
        ids = ids[ids > 0]
        grown |= np.isin(lbl_r, ids)
    grown |= eyebrows(lab, alpha, skin, face)
    return grown


def eyebrows(lab, alpha, skin, face):
    """Wide dark strokes in the upper face that sit above the pupils."""
    fy0, fy1, fx0, fx1 = face
    fh = fy1 - fy0
    dark = alpha & (lab[..., 0] < 40) & ~skin
    band = np.zeros_like(dark)
    band[int(fy0 + 0.12 * fh):int(fy0 + 0.62 * fh), fx0:fx1 + 1] = True
    comp, n = ndi.label(dark & band, structure=np.ones((3, 3)))
    box_area = max((fy1 - fy0) * (fx1 - fx0), 1)
    pupils_top, cands = None, []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(comp == i)
        if len(ys) < 20:
            continue
        if xs.min() <= fx0 + 1 or xs.max() >= fx1 - 1:
            continue  # touches the side of the face box: hair or outline
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        frac = len(ys) / box_area
        if 0.45 <= bw / bh <= 1.3 and 0.0012 < frac < 0.012:
            pupils_top = ys.min() if pupils_top is None else min(pupils_top, ys.min())
        elif bw / bh > 2.2 and frac < 0.02:
            cands.append((i, ys.max()))
    out = np.zeros_like(dark)
    if pupils_top is None:
        return out
    for i, bottom in cands:
        if bottom < pupils_top - 0.02 * fh:
            out |= comp == i
    return out


def light_hair(lbl, skin, h, w, pose):
    hair = ndi.binary_opening(lbl == 2, structure=disk(3 if pose == "bust" else 2))
    hair = drop_small(hair, 80)
    face, _ = head_zone(skin, h, w, pose)
    if face is None:
        return hair
    fy0, fy1, fx0, fx1 = face
    comp, n = ndi.label(hair, structure=np.ones((3, 3)))
    keep = np.zeros(n + 1, bool)
    for i in range(1, n + 1):
        ys, xs = np.nonzero(comp == i)
        # hair/hijab must touch the head area (allows ponytails and hijab drape below)
        if ys.min() <= fy1 + 0.1 * (fy1 - fy0) and xs.max() >= fx0 - (fx1 - fx0) and xs.min() <= fx1 + (fx1 - fx0):
            keep[i] = True
    return keep[comp]


def shading(rgb, mask, dark_region=False):
    y = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255.0
    core = ndi.binary_erosion(mask, structure=disk(2))
    vals = y[core] if core.any() else y[mask]
    if len(vals) == 0:
        return np.zeros_like(y)
    top = np.percentile(vals, 99)
    s = np.clip(y / max(top, 1e-3), 0, 1)
    med = np.median(np.clip(vals / max(top, 1e-3), 0, 1))
    # very dark regions (black hair): lift the mid-tones so light colours don't turn muddy
    if med < 0.78 and med > 0.05:
        gamma = np.log(0.85) / np.log(med)
        s = s ** gamma
    return s


def save_layer(name, shade, mask):
    soft = ndi.gaussian_filter(mask.astype(float), 0.6)
    soft = np.clip(soft * 1.2, 0, 1) * mask.any()
    grey = (np.round(shade * 63) * (255 / 63)).astype(np.uint8)  # 64 levels: smaller files, no visible banding
    img = np.dstack([grey * mask, (soft * 255).astype(np.uint8)])
    Image.fromarray(img, "LA").save(os.path.join(OUT, name + ".png"), optimize=True)


def process(cid):
    cfg = CHARS[cid]
    check_tiles = []
    for pose in POSES:
        path = os.path.join(SRC, f"char_{cid}_{pose}.png")
        im = np.array(Image.open(path).convert("RGBA"))
        rgb, alpha = im[..., :3].astype(float), im[..., 3] > 200
        h, w = alpha.shape
        lbl, lab = classify(rgb, alpha, cfg)
        min_area = 120 if pose == "bust" else 60
        lbl = majority_smooth(lbl, lab, alpha, speck=min_area * 4)
        skin = drop_small(lbl == 1, min_area)
        # light holes inside skin (palm highlights) belong to the skin; dark holes (eyes) don't
        holes = ndi.binary_fill_holes(skin) & ~skin & (lab[..., 0] > 55) & (lbl != 3)
        skin |= holes & ~drop_small(holes, 2000)
        jacket = ndi.binary_opening(lbl == 3, structure=disk(3 if pose == "bust" else 2))
        jacket = drop_small(jacket, min_area * 3)
        if pose != "bust":
            comp, n = ndi.label(jacket, structure=np.ones((3, 3)))
            for i in range(1, n + 1):
                ys, _ = np.nonzero(comp == i)
                if ys.min() > 0.6 * h:
                    jacket[comp == i] = False
        if cfg["hair_dark"]:
            hair = dark_hair(rgb, lab, alpha, skin, jacket, h, w, pose)
        else:
            hair = light_hair(lbl, skin, h, w, pose)
        hair &= ~skin
        jacket &= ~hair
        # jacket-coloured blobs inside the face (an open mouth) are not jacket
        face, _ = head_zone(skin, h, w, pose)
        if face is not None:
            fy0, fy1, fx0, fx1 = face
            comp, n = ndi.label(jacket, structure=np.ones((3, 3)))
            for i in range(1, n + 1):
                ys, xs = np.nonzero(comp == i)
                if ys.min() >= fy0 and ys.max() <= fy1 and xs.min() >= fx0 and xs.max() <= fx1:
                    jacket[comp == i] = False
        # cover anti-aliased edges with a 1px ring (outline pixels stay dark under multiply)
        ring = disk(1)
        masks = {
            "skin": ndi.binary_dilation(skin, structure=ring) & alpha & ~hair & ~jacket,
            "hair": ndi.binary_dilation(hair, structure=ring) & alpha & ~skin & ~jacket,
            "jacket": ndi.binary_dilation(jacket, structure=ring) & alpha & ~skin & ~hair,
        }
        for part, m in masks.items():
            save_layer(f"mask_{cid}_{pose}_{part}", shading(rgb, m, part == "hair" and cfg["hair_dark"]), m)
        # check render
        vis = im.copy()
        for m, col in ((masks["skin"], (40, 220, 60)), (masks["hair"], (40, 90, 255)), (masks["jacket"], (235, 30, 30))):
            vis[m, :3] = col
        tile = Image.fromarray(vis, "RGBA")
        tile = tile.resize((int(tile.width * 520 / tile.height), 520))
        check_tiles.append(tile)
    width = sum(t.width for t in check_tiles) + 10 * len(check_tiles)
    sheet = Image.new("RGB", (width, 520), (255, 255, 255))
    x = 0
    for t in check_tiles:
        sheet.paste(t, (x, 0), t)
        x += t.width + 10
    sheet.save(os.path.join(CHECK, f"{cid}.png"))


def add_to_catalog():
    info = {"author": "xcode", "version": 1}
    os.makedirs(CAT_APP, exist_ok=True)
    with open(os.path.join(CAT_APP, "Contents.json"), "w") as f:
        json.dump({"info": info}, f, indent=2)
        f.write("\n")
    n = 0
    for fn in sorted(os.listdir(OUT)):
        if not fn.endswith(".png"):
            continue
        name = fn[:-4]
        shared = "_stand_" in name or "_bust_" in name
        cat = CAT_SHARED if shared else CAT_APP
        other = CAT_APP if shared else CAT_SHARED
        stale = os.path.join(other, name + ".imageset")
        if os.path.isdir(stale):
            for f in os.listdir(stale):
                os.remove(os.path.join(stale, f))
            os.rmdir(stale)
        d = os.path.join(cat, name + ".imageset")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(OUT, fn), "rb") as s, open(os.path.join(d, fn), "wb") as t:
            t.write(s.read())
        with open(os.path.join(d, "Contents.json"), "w") as f:
            json.dump({"images": [{"filename": fn, "idiom": "universal"}], "info": info}, f, indent=2)
            f.write("\n")
        n += 1
    print(f"{n} layers in the asset catalog")


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(CHECK, exist_ok=True)
    ids = sys.argv[1:] or list(CHARS)
    for cid in ids:
        process(cid)
        print("done", cid)
    add_to_catalog()


if __name__ == "__main__":
    main()
