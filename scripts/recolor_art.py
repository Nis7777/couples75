# Recolours Pact's flat art into the hybrid palette with a per-icon colour scheme and espresso outlines.
# Usage: python3 scripts/recolor_art.py original.png out.png (the scheme is picked from the file name, see PLAN).
# Always recolour from the ORIGINAL Grok art, never from an already recoloured file.
import sys, os
import numpy as np
from PIL import Image

def hexrgb(h): return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255
ESPRESSO, CARAMEL, SAGE, CORAL, SAND = map(hexrgb, ['382A22', 'B58A63', 'A9B39A', 'E98268', 'D8C49E'])
SAGE_DEEP, LIGHT = hexrgb('8E9A7E'), hexrgb('F1E6D3')
SCHEMES = {
    'A': dict(coral=CARAMEL, gold=SAND, green=SAGE),     # caramel-led
    'B': dict(coral=SAGE, gold=CARAMEL, green=SAGE_DEEP),  # sage-led
    'C': dict(coral=SAND, gold=CARAMEL, green=SAGE),     # sand-led
    'D': dict(coral=CORAL, gold=SAND, green=SAGE),       # achievements: muted coral accent
}

def hsv(rgb):
    mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dd = np.maximum(d, 1e-6)
    h = np.where(r == mx, (g - b) / dd, np.where(g == mx, 2 + (b - r) / dd, 4 + (r - g) / dd))
    h = np.where(d > 1e-6, (h / 6) % 1.0, 0)
    return h * 360, s, mx

def shade(target, k):
    k = k[..., None]
    dark = target * np.minimum(k, 1)
    light = target + (1 - target) * np.clip((k - 1) * 1.6, 0, 1)
    return np.where(k <= 1, dark, light)

def recolor(img, scheme):
    a = np.asarray(img.convert('RGBA')).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:]
    deg, s, v = hsv(rgb)
    vis = al[..., 0] > 0.3
    out = rgb.copy()
    fam = {
        'coral': (((deg < 22) | (deg > 330)) & (s > 0.45)),
        'gold': ((deg >= 22) & (deg < 60) & (s > 0.35)),
        'green': ((deg >= 60) & (deg < 180) & (s > 0.12)),
    }
    peach = ((deg < 60) | (deg > 330)) & (s > 0.06) & (s <= 0.45) & (v > 0.7)
    outline = (v < 0.36) & ~fam['green']
    fam = {k: m & ~outline for k, m in fam.items()}
    for name, m in fam.items():
        if not (m & vis).any(): continue
        ref = np.percentile(v[m & vis], 70)
        out = np.where(m[..., None], shade(SCHEMES[scheme][name], v / max(ref, 1e-3)), out)
    if (peach & vis).any():
        ref = np.percentile(v[peach & vis], 70)
        out = np.where(peach[..., None], shade(LIGHT, v / max(ref, 1e-3)), out)
    out = np.where(outline[..., None], np.clip(ESPRESSO * (v / 0.17)[..., None], 0, 1), out)
    res = np.concatenate([np.clip(out, 0, 1), al], -1)
    return Image.fromarray((res * 255).astype(np.uint8), 'RGBA')

PLAN = {
    'area_body': 'B', 'area_looks': 'A', 'area_mind': 'C',
    'challenge_the75': 'D', 'challenge_shred21': 'B', 'challenge_steps14': 'B', 'challenge_dry30': 'C',
    'challenge_sleep14': 'C', 'challenge_protein21': 'B', 'challenge_glow30': 'A', 'challenge_skin14': 'A',
    'challenge_posture21': 'C', 'challenge_nospend7': 'C', 'challenge_save30': 'A', 'challenge_read30': 'A',
    'challenge_detox7': 'B', 'challenge_skill30': 'C',
    'goal_fitness': 'B', 'goal_diet': 'B', 'goal_sleep': 'C', 'goal_steps': 'A', 'goal_skin': 'A',
    'goal_glowUp': 'A', 'goal_posture': 'C', 'goal_money': 'C', 'goal_phoneTime': 'A', 'goal_discipline': 'B',
    'goal_skills': 'A',
    'icon_flame': 'D', 'icon_challenge': 'D', 'trophy': 'D',
    'empty_proof': 'A', 'empty_challenges': 'B', 'empty_badges': 'C',
}

def scheme_for(name):
    if name.startswith('rank_'): return 'D'
    return PLAN.get(name, 'A')   # tabs, app icon, splash logo: caramel-led

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    name = os.path.basename(src)[:-4].split('@')[0]
    img = Image.open(src)
    rgb_only = img.mode == 'RGB'
    out = recolor(img, scheme_for(name))
    (out.convert('RGB') if rgb_only else out).save(dst, optimize=True)
