# Custom art prompts (ChatGPT image generation)

Every image below has a slot in the app already. Until a PNG is in the asset catalogue, the app shows an SF Symbol,
so you can add them one at a time.

**Status:** all 52 are in. The icons, badges and illustrations live in `App/Art.xcassets` (resized for their screen
size); the app icon and the splash logo are in `Shared/Assets.xcassets`. To replace one, overwrite its PNG.

## How to add one

1. Generate it with the prompt. Ask for a **transparent background, 1024 × 1024 PNG**.
2. In Xcode, drag the PNG into `App/Art.xcassets`.
3. Rename the image set to the exact **asset name** in the table, for example `rank_flame`.
4. Run the app. Nothing else to change: `CustomIcon` / `RankBadge` / the tab bar pick it up by name.

## Style block (paste at the start of every prompt)

> Flat, friendly vector illustration for a premium iOS app called Pact, for couples leveling up together.
> Soft rounded shapes, thick smooth outlines in deep brown #2A1814 at 6% of the width, no gradients except a soft
> highlight. Palette: coral #C9452A, warm gold #E8A54B, sage green #3F8F6B, peach #FDE4D8, ivory #FFF6F0. Centered,
> fills about 80% of the square, generous padding, transparent background, no text, no letters, no shadow on the
> background. Consistent with a set: same line weight, same corner roundness, same lighting from the top left.

Keep the same chat for a whole set (all 7 ranks in one chat, all tab icons in one chat), so the style stays consistent.
If a result drifts, say: "Same style as the previous image, only change the subject."

---

## 1. Tab bar icons (10 images)

Each tab needs two images: normal and `_active`. Size them as simple glyphs, readable at 26 pt.

Normal: "Style block. A simple single-colour glyph icon in deep brown #2A1814, outline style, 2 shapes at most: {subject}."
Active: "Same icon, filled style in coral #C9452A with a small gold #E8A54B accent."

| Asset name | Subject |
|---|---|
| `tab_today` / `tab_today_active` | a rising sun over a small heart |
| `tab_challenges` / `tab_challenges_active` | a trophy cup with a tiny flame on top |
| `tab_proof` / `tab_proof_active` | an instant photo with a check mark in the corner |
| `tab_progress` / `tab_progress_active` | three rising bars with a small star above the tallest |
| `tab_profile` / `tab_profile_active` | two overlapping heads, side by side |

## 2. Areas (3 images)

"Style block. A round badge icon on a peach #FDE4D8 circle: {subject}."

| Asset name | Subject |
|---|---|
| `area_body` | a dumbbell crossed with a leaf |
| `area_looks` | a hand mirror with three sparkles |
| `area_mind` | a brain shape with a small gold coin beside it |

## 3. Challenges (14 images)

"Style block. A badge-like object illustration for a challenge called '{name}': {subject}. Peach #FDE4D8 circle behind it."

| Asset name | Name | Subject |
|---|---|---|
| `challenge_the75` | The 75 | a bold coral flame inside a gold laurel wreath, the most premium of the set |
| `challenge_shred21` | 21-Day Shred | a kettlebell with motion lines |
| `challenge_steps14` | 10k Steps | two sneakers walking side by side, one coral, one sage |
| `challenge_dry30` | Dry 30 | a wine glass with a small sage leaf instead of wine |
| `challenge_sleep14` | Sleep Reset | a crescent moon resting on a pillow, two small stars |
| `challenge_protein21` | Protein Month | a bowl with an egg, broccoli and a slice of salmon |
| `challenge_glow30` | 30-Day Glow-Up | a glowing face silhouette made of sparkles (no features) |
| `challenge_skin14` | Clear Skin | a dropper bottle with a single water drop |
| `challenge_posture21` | Stand Tall | a straight spine drawn as a stack of rounded beads, with an up arrow |
| `challenge_nospend7` | No-Spend Week | a wallet with a padlock |
| `challenge_save30` | Savings Sprint | a piggy bank with a gold coin dropping in |
| `challenge_read30` | Read 30 | an open book with a bookmark ribbon |
| `challenge_detox7` | Phone Detox | a phone face down with a small sleeping "z" shape made of lines (no letters) |
| `challenge_skill30` | Skill Sprint | a graduation cap on top of a small lightbulb |

## 4. Ranks (7 badges)

The rank-up screen shows these at 150 pt, so they deserve the most detail. Make them one family: same shield shape,
getting more ornate with each level.

"Style block. A collectible game-style rank badge, level {n} of 7, shield shape with a rounded top: {subject}.
Higher levels have more gold trim. No numbers, no text."

| Asset name | Rank | Subject |
|---|---|---|
| `rank_spark` | 1 · Spark | a small single spark, plain peach shield, thin gold rim |
| `rank_kindle` | 2 · Kindle | two crossed twigs with a tiny flame, peach shield, gold rim |
| `rank_flame` | 3 · Flame | a full coral flame, coral and peach shield, thicker gold rim |
| `rank_blaze` | 4 · Blaze | twin flames intertwined like two people, gold rim with two small studs |
| `rank_forge` | 5 · Forge | an anvil with a glowing heart on it, gold rim with side wings |
| `rank_summit` | 6 · Summit | two small figures on a mountain peak holding a flag, ornate gold rim and wings |
| `rank_legend` | 7 · Legend | a gold crown over two flames forming a heart, the most ornate, gold laurels around the shield |

## 5. Icons (2 images)

| Asset name | Prompt |
|---|---|
| `icon_flame` | "Style block. A single streak flame, coral #C9452A outer flame and a pale gold #FFE08A inner flame, upright and calm, slightly rounded tip. It will be animated (it leans and stretches from its base), so keep the base flat and wide." |
| `icon_challenge` | "Style block. A gold trophy cup with a coral ribbon on one handle." |

## 6. Goal chips in onboarding (11 small icons)

"Style block. A tiny icon for a chip button, simple, 2 colours (coral and gold) on transparent: {subject}."

| Asset name | Subject |
|---|---|
| `goal_fitness` | a dumbbell |
| `goal_diet` | an avocado half |
| `goal_sleep` | a crescent moon with a star |
| `goal_steps` | a sneaker |
| `goal_skin` | a water drop with a sparkle |
| `goal_glowUp` | a sparkle burst |
| `goal_posture` | a person standing tall (simple stick shapes) |
| `goal_money` | a stack of coins |
| `goal_phoneTime` | a phone with an hourglass |
| `goal_discipline` | a closed book with a bookmark |
| `goal_skills` | a lightbulb |

## 7. App icon (1 image, not transparent)

Replace `Shared/Assets.xcassets/AppIcon.appiconset` (1024 × 1024, no transparency, no rounded corners: iOS rounds it).

> Flat vector app icon for "Pact", a couples self-improvement app. On a warm peach #FDE4D8 to ivory #FFF6F0
> background, two overlapping rounded flames, one coral #C9452A and one gold #E8A54B, leaning into each other to
> form a heart shape in the overlap. Thick smooth deep-brown #2A1814 outline. Bold, simple, readable at 60 px.
> No text. Square, full bleed, no rounded corners, no transparency.

Also update `LaunchLogo` (the splash) with the same flames on a transparent background.

## 8. Optional: empty states (3 images)

Wide 3:2 PNGs, transparent background. Used on Proof, Progress ("No challenges finished yet") and an empty Badges card.

| Asset name | Prompt |
|---|---|
| `empty_proof` | "Style block, wide 3:2. Two instant photos pinned side by side on a string, both blank, a small heart clip between them." |
| `empty_challenges` | "Style block, wide 3:2. A winding path up a small hill to a gold flag, two pairs of footprints on it." |
| `empty_badges` | "Style block, wide 3:2. An open gift box with three blank badges floating out of it." |
