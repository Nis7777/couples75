# Pact brand: colour

Locked palette. Use it for every screen, icon and new illustration.

| Colour | Hex | Use |
|---|---|---|
| Warm cream | `#F7F1E8` | backgrounds |
| Espresso | `#382A22` | text, outlines (every illustration), primary buttons |
| Caramel | `#C2804C` | everyday habits (main illustration colour), progress, ring |
| Tan | `#D2AE7E` | everyday habits, light (people, moons, heads) |
| Sage | `#909C78` | everyday habits (secondary illustration colour) |
| Deep sage | `#7F8864` | big sage shapes; sage as text or behind white text in the UI |
| Sand | `#E6C28E` | badges, coins, trophies, neutral details |
| Light sand | `#F2E6D4` / `#F0E6D6` | icon circles, soft panels |
| Coral | `#E2704C` | **only** achievements, progress milestones and special moments |

## The rule

**Coral means achievement, progress or something special.** The streak flame, rank badges, The 75, earned badges,
celebrations, the seal on the Pact Card. Nothing else.

**Sage and caramel are everyday habits.** Spread them evenly: no screen or icon set should lean all one way.
Body icons lead with sage, looks with caramel, mind and money with tan/caramel.

**Espresso ties it together:** every outline and all text.

## Code

- UI colours: `Shared/Theme.swift` (`Color.ivory`, `.coral` = espresso, `.gold` = caramel, `.sage`, `.sand`,
  `.highlight` = coral for achievements).
- Illustrations: new Grok art in any palette can be converted with `scripts/recolor_art.py` (pick its scheme in
  `PLAN`: A caramel-led, B sage-led, C tan-led, D achievement).

## Logo

Two interlocking links: espresso and sage, on warm cream. It's the app icon (iPhone and Watch), the splash logo,
the seal on the Pact Card (`pact_seal`) and the website icon.
