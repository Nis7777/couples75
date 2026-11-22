# Layered avatar: art still needed

The avatar is now built from independent layers (`Shared/AvatarParts.swift`, `Shared/LayeredAvatarView.swift`).
Every part already works with a flat vector placeholder drawn in code. Drop real art into
`Shared/Assets.xcassets` with the names below and the app uses it automatically, part by part (no code change).
To add a brand-new part: add the art and one line to the catalogue in `AvatarParts.swift`.

## How it switches on

Until `avatar_head_head` and `avatar_body_neutral_stand` are in the asset catalogue, the app keeps the 12
illustrated characters and the original builder (the code-drawn placeholders never show). As soon as both
exist, the layered avatar and the new builder turn on by themselves. Parts without art yet fall back to the
placeholder, so a first batch can be tested on its own.

Fallbacks for small batches: a part drawn only for `stand` is used in every pose; the neutral body is used for
the other body shapes until they exist.

Template and style references: `docs/avatar-art/canvas_template.png` (the anchor guides below, drawn on the
canvas) and `docs/avatar-art/reference_*_stand.png` (the current art, for the style).

## Canvas (all layers)

- **600 × 1200 px** transparent PNG (or PDF with "Preserve Vector Data"), i.e. a 200 × 400 pt canvas at @3x.
- Every layer is drawn on the **full canvas**, never cropped, so layers line up at every size.
- Anchor points (px, origin top-left):
  - Head centre **(300, 240)**, head about 198 px wide × 228 px tall (ellipse radii 99 × 114). Eyes on y 240 at x 264 / 336; mouth y ≈ 291.
  - Neck 270–330 x, y 318–396. Shoulders at **y 384**; shoulder half-width 117 (straight) / 138 (broad) / 117 (curvy).
  - Waist **y 696**; hips y 708; ankles **y 1080**; floor/soles **y 1146**. Body centred on x = 300.
  - Bust / head-only crop: the region **x 0–600, y 42–642** (used for circles, thumbnails, widgets).
- Style: the current flat 2D illustration style with soft shading and the dark brown line #2A1814.

## Two files per part

1. `avatar_<layer>_<id>`: the **shape**, white/light grey, set to **Render As: Template Image**. The app tints it
   with the chosen colour (skin, hair, top, bottoms).
2. `avatar_<layer>_<id>_shade` (optional): **line art and soft shading only**, Render As: Original. Drawn on top,
   untinted, so the shading survives any colour.

Parts that aren't recoloured (eyes, mouth, shoes) are a single `avatar_<layer>_<id>` set to Original.

Poses: parts that change with the pose use `avatar_<layer>_<id>_<pose>`; the app tries that first, then the
plain name. Poses: `stand` (hands on hips), `cheer` (right fist up), `crossed` (arms crossed), `stretch` (both arms
up). The bust uses the `stand` art.

## Layers, in drawing order, and the files

| Order | Layer | Names | Tinted with | Per pose? |
|---|---|---|---|---|
| 1 | hairBack | `avatar_hairBack_<hairId>` (+ `_shade`) | hair colour | no |
| 2 | body (skin: legs, arms) | `avatar_body_<feminine/masculine/neutral>_<pose>` | skin | **yes** |
| 3 | bottoms | `avatar_bottoms_<id>` | bottoms colour | no |
| 4 | shoes | `avatar_shoes_<id>` | (original colours) | no |
| 5 | top (incl. sleeves) | `avatar_top_<id>_<pose>` | top colour | **yes** |
| 6 | hands in front of the top | `avatar_hands_skin_<pose>` | skin | yes (stand, crossed) |
| 7 | head (neck, ears, face shape, nose) | `avatar_head_head` | skin | no |
| 8 | brows | `avatar_brows_<id>` | hair colour | no |
| 9 | eyes | `avatar_eyes_<id>` | (original) | no |
| 10 | mouth | `avatar_mouth_<id>` | (original) | no |
| 11 | facialHair | `avatar_facialHair_<id>` | hair colour | no |
| 12 | hairFront | `avatar_hairFront_<hairId>` | hair colour | no |
| 13 | accessory | `avatar_accessory_<id>` | top colour (cap, beanie) / original | no |

Body shapes change the shoulder and hip widths, so bottoms and tops ideally come in the 3 widths too:
`avatar_top_<id>_<body>_<pose>` is not looked up yet. Either draw tops/bottoms that fit all three, or tell me
and I'll add the body to the lookup.

## Part ids (catalogue)

- **Hair (28)**: bald, buzz, short, fade, sidePart, fringe, pixie, curly, wavyShort, mohawk, afro, coily, wavy, bob,
  longStraight, longFringe, curlyLong, ponytail, highPonytail, bun, curlyBun, spaceBuns, manBun, braids, sideBraid,
  locs, mullet, hijab. Each needs `hairBack` and/or `hairFront` (most need both: back = volume behind the head,
  front = hairline and fringe over the forehead).
- **Eyes**: dot, almond, wide, smile, sleepy, lashes. **Brows**: soft, straight, thick, arched, none.
- **Mouth**: smile, grin, small, neutral, laugh. **Facial hair**: none, stubble, moustache, goatee, shortBeard, fullBeard.
- **Tops**: zip (the current high-collar zip jacket), tee, tank, hoodie, jacket (open), sweater, dress (covers the bottoms).
- **Bottoms**: jeans, trousers, leggings, shorts, skirt. **Shoes**: sneakers, boots, flats, sandals.
- **Extras**: none, glasses, sunglasses, earrings, cap, beanie.

## First test batch (suggested)

`avatar_head_head`, `avatar_body_neutral_stand`, and 4 hairstyles as `avatar_hairBack_<id>` + `avatar_hairFront_<id>`
(e.g. short, wavy, curly, ponytail). Put them in a folder with exactly these names; I'll drop them into
`Shared/Assets.xcassets` (template rendering for the tinted ones) and check the alignment.

## Minimum set to replace the placeholders well

1. `avatar_body_*_<pose>` (3 bodies × 4 poses) and `avatar_head_head`.
2. Hair: back + front for the 28 styles.
3. `avatar_top_zip_<pose>` (the default top) for 4 poses, then the other tops.
4. Eyes, brows, mouths, facial hair (one file each).
5. Bottoms, shoes, accessories.
