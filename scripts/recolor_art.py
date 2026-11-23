# Recolours the flat art into the neutral palette (coral -> terracotta, gold -> khaki, peach -> sand, green -> olive).
# Usage: python3 scripts/recolor_art.py in.png out.png
import sys, colorsys, glob, os
from PIL import Image
import numpy as np

def recolor(img):
    a = np.asarray(img.convert('RGBA')).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn
    v = mx; s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.maximum(d, 1e-6), 0); gc = np.where(m, (mx - g) / np.maximum(d, 1e-6), 0); bc = np.where(m, (mx - b) / np.maximum(d, 1e-6), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2 + rc - bc, 4 + gc - rc))
    h = (h / 6) % 1.0
    deg = h * 360
    H, S, V = h.copy(), s.copy(), v.copy()
    # coral / red family (strong): -> espresso browns
    coral = ((deg < 22) | (deg > 340)) & (s > 0.45)
    H = np.where(coral, 27 / 360, H); S = np.where(coral, np.clip(s * 0.78, 0, 0.72), S); V = np.where(coral, v * 0.68, V)
    # gold / amber family: -> khaki
    gold = (deg >= 22) & (deg < 60) & (s > 0.35)
    H = np.where(gold, 37 / 360, H); S = np.where(gold, s * 0.45, S); V = np.where(gold, v * 0.86, V)
    # peach / pale warm (low saturation, light): -> sand
    peach = ((deg < 60) | (deg > 330)) & (s <= 0.45) & (s > 0.06) & (v > 0.7) & ~coral & ~gold
    H = np.where(peach, 37 / 360, H); S = np.where(peach, s * 0.35, S)
    # greens: -> olive
    green = (deg >= 60) & (deg < 180) & (s > 0.12)
    H = np.where(green, 75 / 360, H); S = np.where(green, s * 0.75, S); V = np.where(green, v * 0.92, V)
    # back to RGB
    i = np.floor(H * 6).astype(int) % 6; f = H * 6 - np.floor(H * 6)
    p = V * (1 - S); q = V * (1 - f * S); t = V * (1 - (1 - f) * S)
    out = np.zeros_like(rgb)
    for k, (R, G, B) in enumerate([(V, t, p), (q, V, p), (p, V, t), (p, q, V), (t, p, V), (V, p, q)]):
        sel = i == k
        out[..., 0] = np.where(sel, R, out[..., 0]); out[..., 1] = np.where(sel, G, out[..., 1]); out[..., 2] = np.where(sel, B, out[..., 2])
    res = np.concatenate([out, al], -1)
    return Image.fromarray((np.clip(res, 0, 1) * 255).astype(np.uint8), 'RGBA')

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    recolor(Image.open(src)).save(dst, optimize=True)
