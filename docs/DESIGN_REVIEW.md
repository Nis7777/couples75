# Design review: mockups in `reference/` vs the SwiftUI screens

Each mockup was opened next to its view and every visual difference was fixed. Copy and rules follow
`CLAUDE_CODE_PROMPT.md` (name "Couples 75", no stars/rating, no trial, no "Prove it", saves, 3,99 € per person).

## Everywhere
| Mockup | Before | Now |
|---|---|---|
| Rounded geometric font | SF Pro | **Outfit** (bundled, OFL), titles bold 26–34 pt, body 15–17 pt; SF Pro Rounded fallback |
| Ivory with peach glow | flat ivory | ivory + two soft peach radial glows |
| Big illustrations on peach | small figures floating | hip-cropped couples on a peach panel or blob, 40–50% of the height |
| Gold 6 pt progress bar on peach track | thin bar | 6 pt gold capsule on a light peach track, "Step X of N" under it |
| Option cards | small radius | white, 1 pt #F1DDD2 border, radius 18, 64–72 pt; selected peach + 1.5 pt coral border + filled check |
| Coral button | lighter coral, rectangle | #C9452A capsule, 58 pt, white semibold 18 pt, " ›", 20 pt margins |
| Cards | flat | white, radius 20, black 5% shadow (r 12, y 4), faint border |
| Floating tab bar | system-like | white rounded bar, soft shadow, floats above the edge, coral active item, no top line; content fades out under it |

## Per screen
| Screen | Differences found | Fix |
|---|---|---|
| 01 Hook | headline small; couple small, no blob | 30 pt two-line headline at top; couple cut at the hips on a peach blob in the bottom half |
| 02 Avatar | character picker only | avatar builder: preview on a gold pedestal, tabs (Hairstyle, Skin, Hair colour, Outfit), round head grid / swatches, button inside a white card |
| 03 Names | small avatars, small names | 96 pt circle avatars (dashed circle for the partner), small "You"/"Partner" label, 28 pt bold name, tall white cards |
| 30 iPhone | full-body couple | the two busts over the title; partner = outline |
| 04 Together | short cards | tall cards sharing the free height |
| 05 Long distance | horizontal options | busts on top, two tall side-by-side cards, check in the top-right corner |
| 06 Goals | small chips | 2-column grid of big rounded cards, selected coral with white check and text |
| 07 Quit | system slider | slider in a card: beige track with ticks, coral thumb, coral label above |
| 08 Mirror | no panel | full-width peach panel, couple cut at the hips, bold line below |
| 09 Level | plain cards | "How hard should it be?", stretching couple above, Gentle / Couples 75 (gold pill) / Hard mode |
| 10 Building | small figures | big full-body stretching couple, card with sage checks and a gold spinner |
| 11 Plan reveal | ring and figures overlapping edges | peach panel, gold ring centred behind both figures with 20 pt margins, two-colour rules card, peach saves card with three gold squares, scrolling above the pinned button |
| 12 Stakes | big cards | compact cards; fingerprint inside concentric peach/white/coral rings |
| 13a Outcome | no ribbon/badge | cheering couple, trophy, gold ribbon, gold "Day 75" ring badge |
| 13c Paywall | option rows | big plan cards (26 pt title), yearly peach with a centred gold BEST VALUE pill, monthly white; no stars or rating |
| 13d Exit | plain | rounded sheet, 26 pt title, primary + secondary |
| 14 Invite | gap above the figures | A and the dashed outline start right under the title and fill down to the code card |
| 15 Today | small hero | peach hero: label, centred gold ring, both figures head to waist inside the panel, bubble, Done / x left chips; big week dots with streak; saves row; rule cards (15 pt, one line); big Check in; stakes card with trophy |
| 16 Progress | small grid | figures overlapping a 12-column gold dot grid card, rounded thumbnails in a card |
| 18 Profile | small character, clipped pill | big character on a peach disc, 40 pt name, fully visible sage pill, every row a white card |
| 19 Day 75 | small title | huge heavy title, cheering couple with trophy, gold confetti |
| 20 Widgets | plain | ring around both busts; big busts on the medium widget |
| 21 Camera | gradient overlays | solid dark bars, LIVE tag, stamp tag bottom left, big round shutter |
| 22 Partner check-in | navigation bar | × with centred header, 28 pt rule title, rounded photo, square reaction tiles, Sus + Approve side by side |
| 23 / 24 | small figures | crossed-arm couple at the top, info card (label over value), white bet card with gold trophy |
| 25 Invited | small bust | 150 pt bust circle with a soft peach ring, plan card with the bet box inside |
| 26 Code | small boxes | six 64 pt square boxes, active one coral, actions right under them |
| 27 Waiting | small figures | header + peach "Not started" pill, A next to the dashed outline, Remind + outlined Copy invite code |
| 28 Warm-up | separate screen | same layout as Today with the bordered peach banner, Warm-up pill, Practise check-in |
| 29 Pause | plain card | couple, "Life happens" card, Agree / Not now |
