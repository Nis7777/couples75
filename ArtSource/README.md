# Art to generate (transparent PNGs)

Put the finished PNGs in this folder with exactly these names. Until a file exists, the app shows a placeholder.

## Characters: 8 presets x 5 poses = 40 files
Characters: w1 (Maya's look: dark wavy bob, gold hoop, coral zip-up), w2, w3, w4, m1 (Joao's look: dark curls, sage zip-up), m2, m3, m4.
Vary skin tones and hairstyles across w2-w4 and m2-m4. Same outfit style for all: zip-up jacket + black trousers.

Poses (one file per character per pose):
- char_{id}_stand.png    full body, hands on hips, smiling
- char_{id}_crossed.png  full body, arms crossed, serious
- char_{id}_cheer.png    full body, one fist raised, big smile
- char_{id}_stretch.png  full body, lunge with arms up
- char_{id}_bust.png     head and shoulders, smiling, facing forward

Example: char_w1_stand.png, char_m1_cheer.png

## Other files
- partner_outline.png    dashed-line outline of a person standing (the "not joined yet" partner)
- trophy.png             gold trophy with a star
- AppIcon.png            1024x1024, no transparency

## Image-generation prompt (reuse for every file, change only the character + pose)
"Flat vector illustration, warm editorial style, soft shading, clean outlines, single person, full body,
facing camera, centred, TRANSPARENT background, no text, no shadow on the ground.
Character: [describe character]. Pose: [pose]. Same art style as the attached reference image."
Attach reference/01_hook.jpg as the style reference every time so all 40 match.
Generate at least 1024 px tall. Check that hands, feet and the top of the head are not cropped.
