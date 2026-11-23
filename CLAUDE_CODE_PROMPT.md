# PIVOT (read first): couple maxing

**This section supersedes everything below that conflicts with it.** The rest of the spec still describes the
architecture, design system, CloudKit, StoreKit, proof, reactions, pauses, widgets and so on, which all still apply.
Where it says "the 75-day round", read "a challenge"; where it says "round 1", read "daily habits".

**What the app is.** Not a habit tracker and not a single 75-day challenge: a couple **levels up together**
("couple maxing"). Areas: **Body** (gym, diet, sleep), **Looks** (skin, glow-up, posture) and **Mind & money**
(focus, skills, saving). Not the relationship itself. Working name **Pact**, tagline "Level up as a couple."
(`Brand.appName`; renaming is one line plus the plist display names).

**Daily habits (the base).** After onboarding the couple is on daily habits: a `maintenance`-mode round with no end,
no saves, no bet; misses never end anything. Each partner has 4–6 habits from their goals (the plan generator and
the double-approval rule changes are unchanged). Photo proof is **optional but recommended**: photo habits can be
checked off without a photo ("No photo? Check it off" in the camera).

**Challenges (on top).** A catalogue in `Model/Challenges.swift`: the signature **The 75** (75 days, workout 2×45,
water 4 L, read 10 pages, no alcohol, no junk, progress pic; replaces the habits for its length; **photo proof and
a bet are required**, no saves) plus short ones per area (21-Day Shred, 10k Steps, Dry 30, Sleep Reset, Protein
Month, 30-Day Glow-Up, Clear Skin, Stand Tall, No-Spend Week, Savings Sprint, Read 30, Phone Detox, Skill Sprint),
which add their rules on top of the habits. Bets are optional for those (they can be left out). Starting one writes
two `RoundConfig` facts: the challenge round (with `length`, `saves`, `challengeID`, `proofRequired`) and the habits
round after it, so the couple always goes back to habits. It starts the next morning; today's habits still count.
Giving up writes a habits config with `quitBy`: the challenge ends then, lost by that member (they owe the bet if
there is one); before Day 1 it's a cancel (nothing lost). Only one challenge at a time, only once the partner has
joined.

**Pure team.** One couple streak across habits and challenges (with the shields), one shared **XP** total and one
**rank** (Spark, Kindle, Flame, Blaze, Forge, Summit, Legend), plus badges. XP: 2 per check-in, 10 per complete day
each, 10 more when you both complete a day, and a bonus for every finished challenge (20 × its days, +500 for The
75). XP and ranks are computed from the facts, never stored. A new rank shows a celebration once.

**Navigation.** Five tabs: Today, Challenges, Proof, Progress, Profile. Onboarding has no stakes step (the plan
review says "No stakes on habits"); the level picker sizes the habits (Gentle / Steady / Hard mode).

**Motion.** Follow `.claude/skills/rossark-motion-skill` (engine in `Design/Motion.swift`, pieces in
`Design/LivingViews.swift`): calm, no teleporting, small amplitudes, frozen with Reduce Motion, paused off screen.

**Custom art.** `docs/IMAGE_PROMPTS.md` lists every custom image slot (tab icons, area icons, challenge icons, rank
badges, the flame, goal chips, the app icon) with its asset name; each falls back to an SF Symbol until added.

---

You are building a native iOS app, ready for the App Store, in **Swift + SwiftUI**. It is **Pact**: a couple does a 75-day challenge together. Each partner has 4 to 6 daily rules, proves them to the other with live photos or an evening honour tap, and the couple shares 3 "saves" that cover missed days. Whoever misses more owes a real-life bet (for example "Loser plans the date"). **One subscription covers both partners** ($39.99 a year with a 3-day free trial, or $7.99 a month; US base prices): the person who starts pays, then invites their partner, who joins free. iPhone only. Work autonomously. Make reasonable decisions without asking me, and stop only if something needs my Apple Developer account. **There is no backend server**: the two phones share data through Apple's **CloudKit** (iCloud), and every game result is computed on the phone from shared facts (section 6).

**Visual reference:** the folder `reference/` holds 32 mockups (`01_hook.jpg` … `30_partner_iphone.jpg`, plus `overview.jpg`). Use them for **colours, layout, illustration style, spacing and mood**. They are AI-generated at 720×1280 (9:16), so some look squashed or cropped. Build every screen properly for real iPhone sizes (iPhone SE up to Pro Max) and never copy their proportions pixel for pixel. **The mockups contain outdated copy and rules. This prompt is the source of truth. Wherever a mockup and this prompt disagree, this prompt wins.** Ignore `reference/README.txt` where it conflicts with this prompt. Section 4 lists every screen with the exact corrections.

## CONFIG (keep these in one `Brand.swift` file and use them everywhere)

```
APP_NAME             = "Pact"                  // formerly "Couples 75"; never "75 Hard"
TAGLINE              = "Level up as a couple."
BUNDLE_ID            = "com.tomasbeja.pact"
APP_GROUP            = "group.com.tomasbeja.pact"
URL_SCHEME           = "pactapp"
SUPPORT_EMAIL        = "pact.couples.app@gmail.com"
TERMS_URL            = "https://example.com/terms"
PRIVACY_URL          = "https://example.com/privacy"
CLOUDKIT_CONTAINER   = "iCloud.com.tomasbeja.pact"
CHECKIN_UPLOAD_WINDOW_H = 6                     // a check-in must reach iCloud within 6 h of being taken
IAP_YEARLY           = "com.tomasbeja.pact.yearly"    // $39.99 a year, 3-day free trial (covers both partners)
IAP_YEARLY7          = "com.tomasbeja.pact.yearly7"   // same price, 7-day free trial (offered only on the exit sheet)
IAP_MONTHLY          = "com.tomasbeja.pact.monthly"   // $7.99 a month, no trial
SAVES_PER_ROUND      = 3
ROUND_LENGTH_DAYS    = 75
MAX_PAUSE_DAYS       = 3
PAUSE_AUTO_ACCEPT_H  = 12
TWEAK_AUTO_ACCEPT_H  = 24
EVENING_WARNING      = "21:00"
LAPSE_GRACE_DAYS     = 7
MIN_IOS              = 17.0
```

In **DEBUG builds only**, the Simulator, the launch argument `-mock`, the unit tests and a device with no iCloud account run in **Mock mode** (section 7), so I can click through everything in the Simulator. A Release build never uses Mock mode.

## 0. Project setup (do this first)

- Commit a complete `Pact.xcodeproj` (objectVersion 77, `PBXFileSystemSynchronizedRootGroup` folders, so every file in `App/`, `Shared/`, `Widgets/` and `Tests/` is included automatically) with a shared scheme **Pact** that uses `Config/Products.storekit` on Run. No XcodeGen or scripts are needed to open and run it.
- Targets:
  1. `Pact`: the main SwiftUI app.
  2. `Widgets`: a WidgetKit extension (home, interactive and Lock Screen widgets plus the Live Activity, section 4.10).
  3. `PactTests`: XCTest unit tests.
  4. `PactWatch`: a watchOS 10 app (section 4.15), embedded in the iPhone app. Sources in `Watch/`; the payload type shared with the iPhone lives in `WatchShared/` (compiled into both).
  - Both share the App Group `APP_GROUP`. The app writes a small `WidgetSnapshot` JSON there; the widget only reads it.
- Capabilities on `App`: iCloud with **CloudKit** (container `CLOUDKIT_CONTAINER`), Push Notifications, App Groups, Background Modes (remote notifications, background fetch), **HealthKit** (read only), Live Activities (`NSSupportsLiveActivities`). Add `CKSharingSupported = YES` to Info.plist so iCloud share links open the app. No Sign in with Apple: the user's iCloud account is their identity.
- **No third-party packages at all.** Apple frameworks only: SwiftUI, CloudKit, StoreKit (StoreKit 2), AVFoundation, WidgetKit, UserNotifications, BackgroundTasks, HealthKit, ActivityKit, AppIntents, WatchConnectivity.
- **English only.** No translations and no other languages anywhere.
- Add a **StoreKit Configuration file** `Products.storekit` with the three subscriptions in one subscription group "Pact" (storefront United States, USD): yearly $39.99 with a 3-day free-trial introductory offer, yearly7 $39.99 with a 7-day free trial, monthly $7.99 with no introductory offer. Set it on the Run scheme so purchases work in the Simulator.
- Art: every PNG from `ArtSource/` is an image set in `Shared/Assets.xcassets` (shared by the app and the widget) named after the file; `AppIcon.png` (1024×1024, no alpha) is the single-size App Icon. Avatar recolouring layers (section 1.3) live in `ArtSource/masks/`, with the stand and bust poses in `Shared/Assets.xcassets` and the other poses in `App/Masks.xcassets`.
- Font: bundle **Outfit** (OFL, google/fonts `ofl/outfit`) as static weights in `Shared/Fonts/` and register them with `UIAppFonts` in both Info.plists.
- Write a `README.md` with: build-and-run steps, how to set up the CloudKit container and deploy the schema to Production in the CloudKit Console, how to create the three subscriptions (and their free-trial offers) in App Store Connect, how to test sharing between two Apple IDs on two devices, and how to use Mock mode.

## 1. Design system

### 1.1 Colours (use these, not the lighter coral some older mockups show)
- `ivory` #FFF6F0: every screen background
- `peach` #FDE4D8: selected cards, banners, soft fills
- `card` #FFFFFF at 70–100%: cards (with a 1pt #F1DDD2 border)
- `textPrimary` #2A1814, `textSecondary` #4A322B (never lighter than this for small text, for contrast)
- `coral` #C9452A: primary buttons, selected radios and checks, accents. White text on coral.
- `gold` #E8A54B: progress bar, day ring, streak dots, "Best value" pill, trophy accents
- `sage` #3F8F6B: "Done", "Partner linked", the second partner's accent colour
- Errors use system red.
- Onboarding screens 01–07, 09, 10 and 14 in the mockups use an older lighter coral and a ">" chevron: build them with `coral` #C9452A and the "›" chevron like the rest.

### 1.2 Components
- Type: **Outfit** for all text (fallback SF Pro Rounded): titles bold 26–30pt (centred on onboarding), body 15–17pt. Support Dynamic Type where layouts allow.
- Background: `ivory` with a very soft peach glow. Illustrations sit on a full-width `peach` panel or a soft peach blob and take 40–50% of the screen height on onboarding.
- Cards: white, radius 20, soft shadow (black 5%, radius 12, y 4) and a faint #F1DDD2 border. Pills: gold "Most popular" / "BEST VALUE", sage "Done" / "Partner linked", brown "{x} left".
- Primary button: full width, 58pt tall, fully rounded capsule, `coral`, white 18pt semibold label ending in " ›".
- Secondary button: white capsule, 1pt border #EAD5CA, `textPrimary` label.
- Option card (radio): 64–72pt tall, radius 18, white, 1pt #F1DDD2 border; when selected, `peach` fill, 1.5pt `coral` border and a filled coral check circle on the left.
- Onboarding header: a 6pt gold progress bar (rounded) on a light peach track and "Step X of N" under it. N is computed from the actual steps shown (section 3); never hard-code.
- Floating tab bar (not the system bar): a plain white rounded rectangle with a soft shadow (no top line), floating above the bottom edge, with 4 items: **Today** (`sun.max`), **Proof** (`checkmark.seal`, with a coral number badge, section 4.12), **Progress** (`circle.grid.2x2`), **Profile** (`person`). The selected item is `coral`. No Challenges tab. Every tab screen has enough bottom padding that nothing is hidden behind the bar.
- Day ring: a gold circular progress ring (stroke 14) showing day/75, with "DAY 14 / 75" in the centre and the two characters overlapping it (see 15_today).
- Haptics: light impact on taps, **success** when a rule is checked off and on Day 75, **light** when a partner's approval arrives (and when the avatars meet in the opening animation), **heavy** when "Hold to sign" completes, warning on a save used.
- Animations: push-style slide + fade between onboarding steps, spring animations on selections, confetti on Day 75. Count changes ("4 left" → "3 left") roll like a counter (`.numericText`); the checkmark pops (scale) when a rule is checked off.
- Segmented controls (Proof "From {partner} | Mine"): a custom control on a white capsule track where a **coral pill slides** to the selected option (white text), with a cross-fade of the content. Never the default grey control.
- Sheets: native sheets with medium/large detents, spring snapping and a grabber ("Which rule?").
- Empty states: friendly, with both avatars (the partner's outline until they join) and one line, e.g. "No proof yet today.", "No progress photos yet. Take your first one today."
- Onboarding pages: the content scrolls when it doesn't fit and the primary button is **pinned to the bottom safe area** on every step, so it can never be pushed off screen (iPhone SE included).

### 1.3 Characters (important)
The mockups always show the same two people, "Maya" and "Joao". In the real app each user picks a character, so every scene must be **composed from two separate single-person images**, never one combined picture.
- **Avatar builder** (styled like 02): a big live preview on a gold pedestal, tabs **Hairstyle**, **Skin**, **Hair colour**, **Outfit**, an options grid or colour swatches, and "Looks like me ›".
  - Hairstyle: the 12 base characters (6 women `w1`–`w6`, 6 men `m1`–`m6`, covering Black, East Asian, South Asian, Latina/Latino, Middle Eastern/North African and White people; women and men mixed, no labels for ethnicity) as round head thumbnails (`char_*_bust`). This picks the base image. Either partner can pick any character. `w1` = Maya's look, `m1` = Joao's look. Plus 4 more looks, `x1`–`x4` (short, wavy, curly, ponytail), made from the layered Grok art in the same style; they exist in the stand and bust poses only, so other poses show them standing (`Characters.standOnly`). Their recolour masks are built from the separate layers, so the picked colour is exact. The Hairstyle grid scrolls.
  - Skin: #F6D7C3, #EBC1A0, #D9A27C, #C68B5F, #A86B45, #8A5233, #6B3D25, #4A2A1A.
  - Hair colour: black #1E1A18, dark brown #3B2A20, brown #6B4630, auburn #8C3F24, ginger #C8642E, blonde #E2B96A, platinum #EFE3C8, grey #A8A29E. For `w5` (hijab) this tab is "Hijab" and changes the hijab colour: dusty rose #D99A9A, sage #7FA38A, navy #2E3F66, beige #D8C3A5, black #1E1A18, lavender #B9A3D9, teal #2F7F7C, terracotta #C9684A.
  - Outfit (jacket): coral #F08A73, sage #7FA38A, mustard #E2A93B, lavender #B9A3D9, navy #2E3F66, terracotta #C9684A, teal #2F7F7C, dusty rose #D99A9A.
  - Each tab also offers the character's original colour first (the default). Save characterID + skin + hairColor + jacketColor on the `Member` record and use them in every scene (Today, Proof, Progress, Day 75, invite card, widgets, partner views).
- Recolouring: `scripts/make_masks.py` (Python, Pillow, numpy, scipy; run once, offline) builds, for each of the 60 `char_*.png`, a skin mask (face, ears, neck, hands, ankles), a hair mask (hair, beard, moustache, eyebrows; for `w5` the hijab) and a jacket mask (chest, sleeves, collar). Outlines, eyes, mouth, trousers and shoes are never in a mask. Each mask is saved as a shading layer `mask_{id}_{pose}_{skin|hair|jacket}` (grey = the region's brightness normalised so its brightest pixels are white, alpha = mask). Every result is checked by eye in `ArtSource/masks/check/` (skin green, hair blue, jacket red). `CharacterView(characterID:pose:skin:hairColor:jacketColor:)` draws the original image, then each layer multiplied by the chosen colour so the original shadows stay.
- **A partner who hasn't built an avatar yet is always drawn as `partner_outline`** (the dashed figure), everywhere. Never show a default character for them.
- Asset names: `char_{id}_{pose}` with poses `stand` (hands on hips), `crossed` (arms crossed, serious), `cheer` (one fist up), `stretch` (lunge/stretch), `bust` (head and shoulders for circles), all transparent PNGs. Plus `partner_outline` (the dashed "not joined yet" figure, used for any partner) and `trophy`.
- Compose scenes in SwiftUI: two characters side by side, partner A on the left, slightly overlapping, bottoms aligned, scaled to fit the available space and never cropped at the head or the sides; most scenes show them from head to hips or waist on a peach panel. The gold ring, trophy and confetti are separate layers.
- Partner A's accent is `coral`, partner B's is `sage` (rule list headers, progress rings).
- Never use gendered pronouns in copy. Use names: "Day 1 starts the morning after Joao joins", never "after he joins".

## 2. Game rules (implement exactly, as one pure function both phones run; section 6.3)

### 2.1 Couple, round and rules
- A **couple** has exactly 2 members: A (creator) and B (joined by invite). One subscription (whoever bought it) covers both.
- A **round** is one 75-day attempt. Fields: `mode` (`standard` with `SAVES_PER_ROUND` saves, or `hard` with 0 saves), `status` (`waiting`, `active`, `completed`, `failed`, `abandoned`), per-member start date, per-member miss count, saves used, the bet, pause used (bool).
- Each member has **4 to 6 rules** for the round. Each rule has a `type`: `photo` (proved by an in-app live photo) or `honour` (proved by an evening tap "I stuck to it today"). Every member has at least 2 photo rules. Intensity can differ per member (Maya "45 min workout", Joao "20 min walk").
- Rule titles use the short format **"Name: amount"** so they fit on Today (they may wrap to 2 lines, never cut off). Rule library (seed it; use these titles exactly), Gentle / Pact / Hard:
  - Workout (photo): "Walk: 20 min" / "Workout: 45 min" / "Workout: 2 × 45 min"
  - Water (photo): "Water: 2L" / "Water: 3L" / "Water: 4L"
  - Reading (photo): "Read: 5 pages" / "Read: 10 pages" / "Read: 20 pages"
  - Cold shower (photo): "Cold shower" (all levels)
  - Steps (photo): "Steps: 6k" / "Steps: 8k" / "Steps: 10k"
  - No sugar, No alcohol, No phone in bed, No junk food, Bed by 23:30, No takeaway spending (all honour)
  - Personal rules (Gentle **10 min**, Pact **15 min**, Hard mode **30 min**, set by the level): Learn a language "Language: 10/15/30 min" (photo); Meditate "Meditate: 10/15/30 min" (honour); Practise an instrument "Instrument: …" (photo); Journal "Journal: …" (photo); Stretch "Stretch: …" (photo); Study "Study: …" (photo); Less social media "Social media: max 1h / 45 min / 30 min" (photo, Screen Time); Cook at home "Cook one meal" (photo). Read more = Reading, Save money = No takeaway spending.
  - **Typed personal goals** ("Something else?") become rules too: a clean, short, capitalised name plus the level's minutes, e.g. "Learn to speak chinese" → **"Learn Chinese: 15 min"** (photo rule). The name comes from Apple's on-device Foundation Models when available (iOS 26+), otherwise keyword rules (languages → "Learn {Language}", instruments → "Practise {instrument}") and capitalisation. **Never put other apps' brand names in a rule title** (strip Duolingo, Instagram, TikTok, …).
- The plan follows the quiz: each goal adds one rule (Fitness → workout, Discipline → reading, Sleep → bed by 23:30, Diet → no junk food (or no sugar), Phone time → no phone in bed, Money → no takeaway spending), then every personal goal (chips and typed), then photo fillers (reading, water, steps, cold shower, workout last) until there are at least 4 rules with at least 2 photo rules. If there are more than 6, the plan review asks the user to trim (3.1). The reason shows under each rule: "Because you picked {goal}" (fillers: "To round out your plan"). Each member's fitness level sets that member's intensity for the quiz goals; B's rules use Gentle unless B answered on A's phone.
- **One source of truth:** the plan is generated **once** (on the Building step) and stored as rows (A's and B's version of each rule). The plan review shows the stored rows; "Set the stakes" writes exactly those as A's rules and B's draft rules; when B joins, B's rules are an **exact copy** of the stored draft rules (never regenerated). Today, the invite card, the widgets and the RulesEngine all read the stored rules. A unit test fails if the plan review and the stored/engine rules ever differ.

### 2.2 Days and time zones
- Every member stores their IANA time zone (update it on every app launch and when it changes).
- **Day 1** for each member is the first full local calendar day after BOTH have joined (never the same evening). Before that the couple is in **warm-up**: check-ins work but don't count.
- A member's Day N is their own Nth local calendar day of the round, not counting paused days. Long-distance couples simply have different local dates.
- A check-in counts for the local date on which it was **taken** (`capturedAt`, the device time at the shutter or the honour tap, converted with the member's time zone). It only counts if it reached iCloud (the record's server `creationDate`) within `CHECKIN_UPLOAD_WINDOW_H` hours of `capturedAt`, so nobody can backfill old days. Nothing can be checked in for a past date in the UI.
- A member's day is **final at their local midnight**. Nothing about a closed day ever changes.
- A member's day is **complete** if all of their rules have a valid check-in for that date. Otherwise it's a **miss** (at most one miss per member per day).

### 2.3 Saves, restarts and the bet
- Each miss increments that member's miss count and uses one save from the shared pool.
- If a miss happens when no saves are left (the 4th miss in standard mode, the 1st in hard mode), the round ends with status `failed`. If both members miss the same day, count both misses.
- When a round ends (`completed` after both members' Day 75 closes, or `failed`), settle the bet **once**:
  - The member with more misses owes it.
  - Tied at 0: nobody owes, and the optional shared reward (if set) unlocks.
  - Tied above 0: both owe.
- After `failed`, a new round starts automatically: same rules, same bet, same mode, Day 1 = the next local day for each member. Round history and the best streak are kept forever.
- "Paid": the owing member (or either partner) can tap Paid on the bet card; store `paid_at`.

### 2.4 Approvals and reactions
- Approvals are social only. **Nothing a partner does can fail the other's day.**
- On a partner's check-in you can: Approve (heart), react with an emoji (❤️ 🔥 💪 👀 😂), write one comment line (max 80 characters), or tap **Sus 🤨** (a playful doubt reaction; no effect on the day; counted for the Day 75 recap "most sus moments").
- Show "Approved" when the partner approved, "Seen" when they opened it, nothing otherwise. There is **no "Prove it"** feature.

### 2.5 Pause ("Life happens")
- Once per round, either member can request a pause of 1–`MAX_PAUSE_DAYS` consecutive days starting today or tomorrow, with a short reason.
- The partner can Agree or tap Not now. If they don't answer within `PAUSE_AUTO_ACCEPT_H` hours, it's accepted automatically.
- Paused dates don't count for either member: no misses, no saves used, the day counter doesn't advance.
- While a request covering today is pending, settlement for that date waits until it's resolved.
- A declined request doesn't use up the round's pause.

### 2.6 Subscription (one for the couple, StoreKit 2, no RevenueCat)
- **One subscription covers both partners.** Products: yearly $39.99 with a 3-day free trial (preselected); yearly7, the same price with a 7-day free trial, offered only on the exit sheet; monthly $7.99 with no trial. Prices and trial lengths always come from StoreKit, never hard-coded. Show the trial only when the user is eligible for the introductory offer.
- **Only A sees a paywall** (3.3). B joins free: never show B a paywall or any per-person price. Never write "each", "per person" or "{B} joins with their own subscription" anywhere.
- Use StoreKit 2: `Product.products(for:)`, `purchase()`, `Transaction.currentEntitlements` on launch and `Transaction.updates` while running, `AppStore.sync()` for Restore. Set `appAccountToken` on purchases to the member's UUID.
- After every entitlement change (and on every launch), the app writes `subscribedUntil` (the transaction's `expirationDate`) and `subscriptionProduct` to the member's own `Member` record and merges the period into `subscriptionPeriods`, so both phones know. (Self-reported is fine for v1.)
- **The couple is active while ANY member's subscription is active** (the union of both members' subscription periods). Day 1 starts the morning after B joins.
- When a free trial starts, schedule a real local reminder for **Day 2** of the trial (48 h before it ends): "Your free trial ends in {n} day(s). Nothing to do if you're staying; you can cancel anytime in Settings."
- If the couple's subscription lapses (nobody active): the payer sees a full-screen "Renew to keep your run" paywall; the partner sees "Keep your run going: take over the subscription" (the same plans, dismissible), and the round is **frozen** (no days settle) for up to `LAPSE_GRACE_DAYS`. If nobody subscribes in time, the round ends as `abandoned` with no bet.

### 2.7 Personal and custom rules (double approval)
- Rules can be changed only with the partner's approval. A custom or changed rule is **Pending** until the partner approves it ("{name} wants to add: {rule}" → "Approve ›" / "Suggest a change"). The original rule stays active until then. **Pending never blocks Day 1**, and nothing is ever auto-approved.
- Limits: 4 rules each, at least 2 photo rules each. A custom rule has a title (max 40 characters), Photo or Honour, and an optional photo hint (shown in the camera instead of the library prompt).
- An approved rule starts the **next local day** after the approval.
- **Rules lock on Day 1.** After that, each person gets **one swap per round** (needs approval, starts the next local day). Anything else asked after the swap is used applies from the next round.
- "Suggest a change" declines the proposal and sends a new proposal for the same rule back to the proposer.
- Free text ideas ("Something else?"): on iOS 26+, when `SystemLanguageModel.default.availability` is `.available`, Apple's **on-device** Foundation Models write 3 ideas (title ≤ 40 characters, photo or honour, with a photo hint). Otherwise, a keyword match against the rule library (plus generic ideas from the text). **Never call an online AI service.**

### 2.8 Maintenance mode (after Day 75)
- From the Day 75 screen: "Keep it up with maintenance mode". Each person picks which of their rules to keep (the partner keeps theirs and can change them through "Our rules").
- A maintenance round (`RoundMode.maintenance`): **no saves, no bet, misses are only recorded and never end anything, no end date**. Today shows "DAY {n} · Keep it up", "Maintenance · no stakes" and a "New 75 ›" button. Starting a new 75 ends maintenance (no bet) and the new round's Day 1 is the next local day.
- Day 75 / milestone screens and the "You finished" notification never fire for maintenance.

### 2.9 Streak shields, badges and the shared reward
- **Streak shields**: every 7 days in a row that both complete earns a shield (at most 2 banked). A day that isn't complete for both uses a shield instead of breaking the couple's streak (the streak doesn't grow that day). Shields only protect the streak: misses, saves and the bet are unaffected. The streak pill shows a sage shield (and the count when 2).
- **Badges** (computed, never stored), shown on Progress with a toast when one unlocks: First proof, 7 together, Shielded, Day 25, Day 50, Day 75, 30-day streak, Flawless (a round with no saves used), Shutterbug (50 photo check-ins), Cheerleader (25 cheers given), Sweet talker (10 love notes), Glow-up (10 progress pics), In sync (a rule proved by Apple Health), Dream big (a bucket list item done).
- **Shared bucket list** (Progress): either partner adds things to do together and ticks them off. When a round ends with **nobody owing**, the Day 75 screen offers "Nobody owes. Treat yourselves." and the couple picks a bucket list item (or adds one) as their **shared reward**.

## 3. Flows

### 3.1 Person A onboarding (steps that show "Step X of N")
- "Step X of N": N is computed once from the steps every user sees (17). Branch-only steps (handing the phone to the partner and B's answers there, the Android waitlist) show no counter and never change N.
- Single-answer screens (option cards) advance **only after a tap** on that step, about 0.3 s later (a pending advance is cancelled by any navigation). Option cards react to taps only: a swipe or drag across them never selects or advances. Swiping back from the left edge is allowed. Multi-select screens, sliders and steps with a preselected answer ("How hard should it be?") keep a pinned Continue button.
1. **Hook** (01): TAGLINE as the headline, the couple standing, "Let's start ›".
2. **Build your avatar** (02): the avatar builder from section 1.3 (the tab row scrolls and shows a half-cut tab so it's obvious there are more).
3. **Names** (03): "Who's in this with you?", your name field and your partner's name field. The partner card shows `partner_outline` and "Picks their character later".
4. **Is {partner} on iPhone?** (30): "Yes, iPhone" / "No, Android", nothing preselected. "No, Android" → the Android waitlist (3.4) and nothing else.
5. **Is {B} with you right now?**: "Yes, we're together" / "No, I'll invite them". If together: **"Hand the phone to {B}"** ("I'm {B} ›"), then B's own **avatar**, **fitness level** and **wake-up time** on A's phone, then **"Hand it back to {A}"**. These answers are saved on the `Couple` record (invitedAvatar, invitedFitness, invitedWakeTime) so B's phone starts with them when B joins.
6. **How long have you been together?** (04): <1 yr, 1–3 yrs, 3+ yrs.
7. **Long distance?** (05): Yes / No.
8. **What do you want to fix together?** (06): multi-select, at least 2: Fitness, Money, Phone time, Discipline, Sleep, Diet.
9. **Anything personal you want to work on?**: multi-select chips (Learn a language, Read more, Meditate, Save money, Less social media, Practise an instrument, Study, Cook at home, Journal, Stretch) plus a free-text field "Something else?" (max 60 characters) with "Add": a typed goal becomes its own coral pill with its clean name (tap to remove); text left in the field when continuing is added too. Skippable ("Skip ›" until something is picked). **Every picked chip and every typed goal becomes a daily rule** (2.1); the typed text also feeds ideas (2.7) under "Suggested for you".
10. **Your fitness level**: Just starting / Somewhat active / Very active.
11. **When do you usually wake up?**: a time wheel, default **07:30**.
12. **How often do you start something together and quit?** (07): slider Rarely / Sometimes / Usually / Always.
13. **Mirror moment** (08): keep exactly: "Most couples quit before it gets hard. Not because they're weak. Because no one's watching."
14. **How hard should it be?** (09): both characters in the stretch pose above the title, then "Gentle" ("Lighter daily rules · 3 saves"), "Pact" ("Most popular", preselected; "The full plan · 3 shared saves") and "Hard mode" ("The full plan · no saves, one miss restarts"). Gentle lowers each member's rule intensity one step; Hard mode raises it one step and has no saves. Never show "75 Soft" or "75 Hard".
15. **Building your plan** (10): animated checklist, ~3 seconds, auto-advances.
16. **Plan reveal** (11): "{A} & {B}'s 75-day plan", the ring scene with both avatars (B's as built on A's phone, else `partner_outline`), the Daily rules card with a row per rule (A in coral, B in sage), "Because you picked {goal}" under each row, and a **"Change"** button per row. **More than 6 rules:** a coral note "Up to 6 rules each. Swap or remove {n} more to continue." and **"Swap" / "Remove"** on each row (Swap replaces the row for both; Remove is disabled when it would leave fewer than 4 rules or fewer than 2 photo rules); "Set the stakes" stays disabled until there are 6. Change opens a sheet with "Suggested for you", "From the list" and "Write your own", and a picker for whose rule it is; changed rows show a brown "Pending" pill and the note "Changed rules are pending until {B} approves. The original rule stays until then." The saves card reads "3 saves" / "Shared. Each one covers a missed day." (Hard mode: "No saves" / "One miss restarts the round"). If B hasn't answered for themselves, label B's column "Draft: {B} can adjust when they join". Button **"Set the stakes ›"**.
17. **Set the stakes** (12): "Set the stakes", subtitle "{B} accepts this when they join." Loser plans the date / Loser cooks dinner for a week / Loser plans the trip / Custom (max 40 characters). Then "Hold to sign" / "We finish this together" and the fingerprint button (hold 1.5 s with a filling coral ring and a success haptic).
Then without a step counter:
18. **Paywall** (13a–13d, section 3.3).
19. **Invite partner** (14, section 3.2).
20. **Notifications priming** (section 5).
Before step 1, check `CKContainer.accountStatus()`. If there's no iCloud account, show "Turn on iCloud to use Pact" (Settings → [your name] → iCloud) with a "Check again" button. There is no separate sign-up.

### 3.2 Invite (iCloud share link + 6-letter code)
- After paying, A's phone creates the couple: a custom record zone `Couple-{uuid}` in A's private database, a root `Couple` record, and a `CKShare` of that zone with `publicPermission = .readWrite` (so anyone with the link can join) and the title "{A}'s Pact". As soon as B has joined, A's phone sets `publicPermission = .none` so nobody else can join with the old link.
- A's phone also writes an `InviteCode` record to the **public** database: `code` (6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`), `shareURL`, `inviterName`, `createdAt`. Delete it once B joins.
- Screen 14: "Send {B} their invite", both avatars (B's as built on A's phone, else `partner_outline`), the line "Free for {B}: your subscription covers you both.", "Send invite ›", and under the button "Or share code {CODE}" (tap to copy the code and the link).
- "Send invite" renders a **shareable invite card image** (both avatars, "{A} invited you to Pact", the 4 rules of each partner, the bet, and "Free for you: {A}'s subscription covers you both.") and opens the share sheet (`ShareLink`) with that image and the text: "I just signed us up for 75 days. {bet}. You in? Download Pact and tap this link: {shareURL}".
- B joins either by tapping the iCloud link (the app receives it in `windowScene(_:userDidAcceptCloudKitShareWith:)`) or by typing the code (fetch the `InviteCode` from the public database, then `CKFetchShareMetadataOperation` + `CKAcceptSharesOperation` on its `shareURL`). Both paths end in the same place. If the app wasn't installed when B tapped the link, iOS sends B to the App Store; after installing, B either taps the link again or types the code, and the first screen says so.
- Only one partner can join. If a second person tries, show "This couple is already full."

### 3.3 Paywall (13a–13c) and exit sheet (13d): A only
Four pages with page dots; the × is on every page:
1. **Outcome** (13a): "In 75 days, you'll be the couple who finished." with the cheer + trophy scene and a short line about the app. **Never show invented ratings, review counts, quotes or user numbers.** Leave a clearly marked spot in code (`SocialProof`) for the real App Store rating, shown only once real numbers are filled in.
2. **Trial timeline** (13b, only when the user is eligible for the trial): "How your free trial works", gold dots on a gold line: "Today · Full access for both of you", "Day 2 · We remind you", "Day 3 · Trial ends, billing starts" (coral dot), "No commitment. Cancel anytime.", "Continue ›".
3. **Plans** (13c): "Start your 75 days together". **Yearly preselected**: "Yearly", gold pill "BEST VALUE · {yearly price ÷ 52}/week", "{yearly price}/year after 3 free days". **Monthly**: "{monthly price}/month". Under the cards: "{weekly price}/week, less than one date night." and "One subscription covers you both." Primary **"Start my free trial ›"** (yearly with a trial) or **"Subscribe ›"**. Footer: "View all plans" (a sheet with every plan and the full auto-renewal terms) · Terms · Privacy · Restore.
4. **Exit sheet** (13d), opened by the ×: "Not ready for a year?", "Try monthly {price}", "Get a 7-day free trial instead" (buys yearly7) and "Keep yearly". Dismissing it returns to the plans; closing the paywall entirely goes back to the plan reveal. **The × never drops into the app.**
- On purchase: record the subscription (2.6), schedule the trial reminder, create the couple, show "You're in. Now invite {B}.", then go to Invite.
- Lapsed couple: the payer gets the same plans page as a non-dismissible "Renew to keep your run"; the partner gets "Keep your run going: take over the subscription".

### 3.4 Android waitlist (new, style of 30)
Title "Pact is iPhone-only for now", body "Leave your email and we'll tell you when Android is ready.", email field, "Notify me ›" (saves a `Waitlist` record in the CloudKit public database), then "Thanks! We'll be in touch." and a "Done" button that returns to the hook. No paywall ever.

### 3.5 Person B joining (free: A's subscription covers both)
1. **Taps the link or enters the code** → **"{A} invited you"** (25): "You're in", A's bust, a card "{A} picked this plan for you both" with both partners' rules, "3 saves, shared", the bet box, and "Free for you: {A}'s subscription covers you both." "See the plan ›".
2. If the app was opened without a link, the first screen is **"Did your partner invite you?"** (26): six code boxes, "Join {A} ›", and "I don't have a code" → A's onboarding.
3. **Build your avatar**, **Your fitness level**, **When do you usually wake up?** (the same screens as A). If A already made these on A's phone ("Hand the phone to {B}"), B starts with them done and goes straight to step 4.
4. **Accept or tweak**: B's 4 rules (from B's fitness level), "Swap a rule" (from the library, keeping 2 photo rules) and "Change the bet". A gets a notification to accept or decline; no answer in `TWEAK_AUTO_ACCEPT_H` hours = B's version. B also sees A's pending rule changes (2.7) in Proof → Plan changes.
5. **"I'm in"**: "Hold to sign" (same fingerprint button). Day 1 is the next local day.
6. Notifications priming.
B never sees A's couple quiz and never sees a paywall.

### 3.6 Waiting and warm-up
- **Waiting for {B}** (27): header "{A} & {B}" with a "Not started" pill, "Waiting for {B}", "Day 1 starts the morning after {B} joins.", A's character + `partner_outline`, "Remind {B} ›" (re-opens the share sheet), "Copy invite code" (copies the code and the link), and "Or start a warm-up day. It doesn't count." Remind reminders are also sent as local notifications to A on days 1, 3 and 6 after paying: "Nudge {B}? Your plan is waiting." On day 7 the Waiting screen adds: "Invite someone else" (new code and a new share; the old ones are deleted) and "Manage subscription" (opens the App Store subscriptions page).
- **Warm-up day** (28): uses the **same layout as Today** (4.1) with the peach, coral-bordered banner "Warm-up day: this doesn't count" + "Practise a check-in while you wait. Day 1 starts the morning after {B} joins." at the top, a "Warm-up" pill in the header instead of the streak, "Today's practice" with both columns (B's draft rules until B joins), and "Practise check-in ›" as the button. Practice check-ins are stored with `isWarmup = true` and never count.

## 4. Main app screens (mockup → corrections)

### 4.1 Today (15)
- Header: "{A} & {B}" and a gold streak pill "🔥 {streak}".
- A peach hero card with the gold day ring centred behind both characters, shown head to waist and always fully inside the card (never cropped at the head or the sides), "DAY {n} / 75" between them. Before Day 1 the ring reads **"Day 1" / "tomorrow"** on two lines, each shrinking to fit, so it's never cut off. A speech bubble from whoever is done: "{name}'s done. Your turn." (only when exactly one of them is done for today). Status chips across their waists: "Done" (sage) or "{x} left" (brown).
- Under the week dots: a **75-day progress bar**, "Day X of 75", coral fill, the percentage on the right, animating when the day goes up (Day 0 during warm-up).
- Week dots (S M T W T F S) for the current week: gold = complete, coral ring = today, faint = future, and a small coral "S" dot for a day covered by a save, grey for paused.
- **Replace "Miss a day = restart"** with a row: "Saves" + three small gold squares (filled = left) and "Score: {A} {missesA} · {B} {missesB}". In Hard mode: "Hard mode · no saves".
- Above the rule cards, when the partner has check-ins you haven't reacted to: a peach row "New from {partner}" with the latest unreacted thumbnail and "Tap to react ›" that opens it in Proof (4.12).
- "Today's rules": two cards side by side (A, B), rule text 15pt wrapping to at most 2 lines (never cut off), each rule with a check circle; in the partner's card each checked photo rule shows a small rounded thumbnail instead of the check (a coral dot if you haven't reacted) and the header shows "{n} to react"; tapping it opens Proof. **Tapping any of your own rules checks in that rule**: photo rule → camera (21); honour rule → a small sheet "Did you stick to {rule} today?" with "Yes, I did ›" (only enabled after 18:00 local; before that the row says "Tap tonight").
- Primary "Check in ›" (warm-up: "Practise check-in ›") first opens a small sheet **"Which rule?"** listing your unchecked rules (photo rules first); picking one opens the camera or the honour sheet. It never opens the camera directly.
- **"Take today's progress pic"** card (optional, separate from rule proof; section 4.13): opens the progress camera; once taken it shows the thumbnail, "Progress pic done" and "Retake".
- Under the header: a small **sync line** so sync is visible: "Updated 2 min ago" (sage dot), "Syncing…" (gold), "Offline · 2 waiting to send" / "Signed out of iCloud · not syncing" (coral).
- A **love note** from the partner shows as a peach banner ("{name} sent you a note") until dismissed (24 h max).
- Under the Check in button: **"Nudge {partner}"** (only while they have rules left, at most once every 2 hours) and **"Send a note"** (presets "Proud of you ❤️", "You've got this 💪", "Thanks for doing this with me", "Miss you 😘", or one custom line, 80 characters).
- With Apple Health on (4.17), rules Health can prove show live progress under the title ("6,120 / 8,000 steps") and check themselves off when the target is met.
- Bet row at the bottom: "🏆 Stakes: {bet}" (maintenance: the maintenance row instead).
- After 21:00, if you still have rules left, a coral banner: "{x} rules left. {hours} hours to go."

### 4.2 Check-in camera (21)
Full-screen dark camera (`AVCaptureSession`, back camera default, flip button). Top: rule title and "Live photo · not from your camera roll", a "LIVE" pill. Bottom: "Snap proof for {partner}", Cancel, shutter. After capture: preview with "Retake" / "Send ›". **Burn a stamp into the image** (bottom left, dark pill): "DAY {n} · {SAT 21 NOV} · {07:14}" in the member's local time. Compress to max 1080 px on the long side, HEIC (or JPEG 0.6), aiming for ~150 KB, and save it as a `CKAsset` on the `CheckIn` record. If iCloud says the storage is full, show "{owner}'s iCloud is full, so photos can't be saved. Free up space or check in with an honour tap today." and let the user submit that photo rule as an honour tap for that day only. Photo prompts under the rule title keep photos non-intimate, e.g. cold shower: "Photo of the running shower or your face after. Never your body." Custom rules show their own photo hint. There is no way to pick from the photo library.

### 4.3 Partner check-in (22)
Opened full screen from Proof (tap a photo); swiping goes to the next unreacted check-in. Header "{name} checked in", rule title, "Day {n} · {time}", the photo. "React": ❤️ 🔥 💪 👀 😂, a one-line comment field, then two buttons: **"Sus 🤨"** (secondary) and **"Approve ›"** (primary). **Remove "Prove it"**. Add a small "Report" link at the bottom (opens an email draft to SUPPORT_EMAIL with the check-in id).

### 4.4 Save used (23)
Shown to both members the next time they open the app after a miss. Characters `crossed`. Title "Save used". Body: "{name} missed a rule on Day {n}. One save covered it, so the run continues." Card rows: "Saves left: {x} of 3", "Score: {A} {a} · {B} {b}", "Whoever has more misses at Day 75 owes the bet." Button "Back to today ›". **Never say "Life happens pass", "skipped" or "no restart" here.**

### 4.5 Round end (24)
- Failed round: small coral label "Round over", title "Out of saves on Day {n}", characters `crossed`. Bet card: "🏆 The bet", "{name} owes:" (or "You both owe:" or nothing), the bet in 26pt bold, "Final score: {A} {a} · {B} {b}", "Back to Day 1 tomorrow. Best streak: {x} days. Your history is kept." Primary "Paid ›" (hidden if nobody owes), secondary text button "Start round 2".
- Completed round: go to Day 75 (4.7) first, then this card if someone owes.

### 4.6 Progress (16)
Title "Progress", "{A} & {B}", then the **Transformation** section (4.13) at the top, both avatars (busts) above the grid (B's as built on A's phone before B joins), a 75-day grid that is never empty (a small gold star "Warm-up done" marks the warm-up day; until Day 1 the line under the grid reads "Day 0 done. 75 to go."), (gold = both complete, half gold = one complete + one save, coral outline = today, grey = paused, empty = future), "Day {n} of 75", a horizontal strip of both partners' recent photos (tap → full-screen viewer with the stamp and reactions), "Best streak", "Rounds", and the bet row. Photos are visible only to the couple. The grid legend ("Both done", "One + save", "Today") uses 13 pt dots with 13 pt labels in `textPrimary`.

### 4.7 Day 75 (19)
Confetti, "Day 75", "We finished Pact" (fix the name), "{A} & {B}", the cheer + trophy scene. A recap card: saves used, final score, best streak, most sus moments, and who owes the bet (or "Nobody owes anything"). Buttons: "Share our card ›" (renders a 1080×1920 image without photos and opens the share sheet), "Start round 2" (reruns steps 9 and 13 of the quiz, offers Hard mode).

### 4.8 Profile (18)
Your character, your name, "Partner linked" pill (sage; make sure it isn't cut off). Rows: **Mode** (Pact · 3 saves / Hard mode), **Saves left** ("{x} of 3"), **Wake-up reminder** (time), **Evening warning** (21:00, on/off), **Partner** ({name}), **Evening progress on Lock Screen** (toggle, 4.10), **Use Apple Health as proof** (toggle, 4.17), **Share progress pics with partner** (toggle, **off by default**, section 4.13), **Our rules** (both partners' rules, pending changes, **per-rule reminder times** ("Add time", e.g. "Meditate at 07:00"; skipped once the rule is done), and "Request a change", section 2.7), **Subscription** ("Active · {plan} (free trial), renews {date} · covers you both", or "Covered by {payer}'s subscription", or "Not active") → Manage, **Restore purchases**, and when notifications were denied, **"Reminders are off · Turn on in Settings"** (opens the app's Settings page), **Terms**, **Privacy**, **Contact support**. Then quiet text buttons: **"Leave couple"** and **"Delete my data"** (section 6.5). Remove "Missed-day rule: Restart".

### 4.9 Pause request (29)
- Requester side (new): from Today's "…" menu → "Life happens": pick 1–3 days, start Today/Tomorrow, reason field ("Travelling", "Sick", or custom), "Send request ›". Disabled with an explanation if the round's pause is already used.
- Receiver side (29): small coral label "Pause request", title "{name} asked to pause", body: "{reason}. Pause {x} day(s) from {date}? Paused days don't count for either of you and don't use a save. If you don't answer in 12 hours, it's accepted." Buttons "Agree ›" / "Not now". **Replace the mockup copy** ("one save is used", "Saves left if you agree") with this.

### 4.10 Widgets (20) and Live Activity
- Small: the ring with both characters' busts and "Day {n}/75".
- Medium: the two characters, "Day {n}/75", "{A} ✓ · {B} …" (✓ when complete, … when not) and the streak flame.
- **"My rules today"** (medium/large, interactive): my rules with check circles. Honour rules tick off from the Home Screen **from 18:00** (an App Intent that conforms to `LiveActivityIntent`, so it runs in the app's process and saves a real check-in; if the app can't take it right then, the tap is queued in the App Group with its time and saved on the next launch/refresh). Photo rules open that rule's camera (`pactapp://rule/{id}`). The partner's progress in the corner.
- **Lock Screen**: circular day gauge, rectangular ("Day 14/75 · 2 rules left · Joao is done") and inline.
- **Live Activity** (evening): from 17:00, while I still have rules left, both partners' progress on the Lock Screen and in the Dynamic Island. Started/updated by the app (no push server), ends when I'm done (after 30 min) or at midnight. Profile toggle "Evening progress on Lock Screen" (on by default).
- Never show photos in widgets. Update the snapshot after every check-in, settlement and app launch, then call `WidgetCenter.shared.reloadAllTimelines()`.

### 4.15 Apple Watch
- A watchOS app: the day and streak, my rules (honour rules tick off on the wrist from 18:00; photo rules say "Use your iPhone camera") and the partner's progress. The iPhone sends the payload over WatchConnectivity (application context) whenever the widget snapshot changes; a tap goes back as a message, or as queued user info with its time when the phone is away.

### 4.16 Weekly recap and the App Store rating prompt
- **"Our week"** (the 7 days ending yesterday): headline ("A perfect week." / "A strong week." / …), "{x} of 7 days together", each partner's days complete with 7 dots and reactions received, streak, saves used, photos. Shown once on the first open of a Monday, always reachable from Progress ("Our week: 5/7 days · See recap ›"), with "Share our week" (a rendered card, never photos). A Monday 09:00 notification "Your week together is ready."
- The App Store rating prompt (`requestReview`) only at happy moments: closing a recap with 5+ days complete, or a milestone (4.13). At most once every 120 days. No invented ratings anywhere.

### 4.17 Proof through Apple Health
- Profile → **"Use Apple Health as proof"** (off until turned on; read-only HealthKit access to steps, exercise minutes, water and mindful minutes; nothing is written).
- Mapping from the rule: Steps "Steps: 8k" → 8,000 steps; Water "Water: 3L" → 3 L dietary water; Workout "Walk: 20 min" / "Workout: 45 min" / "Workout: 2 × 45 min" → 20 / 45 / 90 exercise minutes; Meditate "Meditate: 15 min" → 15 mindful minutes. Other rules still need a photo or tap.
- Today's totals are read on every refresh; when a target is met the rule is checked off automatically with the proof line "Apple Health · 8,412 steps" (shown to the partner in Proof instead of a photo).

### 4.11 Locked states
- The couple's subscription lapsed (2.6): the payer gets the full-screen "Renew to keep your run" paywall; the partner gets "Keep your run going: take over the subscription" and a banner on Today; the round shows as paused.
- Round frozen banner on Today: "Your run is paused until the subscription is renewed."

### 4.12 Proof (new tab)
- Title "Proof" and the coral sliding-pill segmented control "From {partner}" | "Mine" (1.2), with a cross-fade between the lists. The tab icon shows a coral number badge: how many partner check-ins you haven't reacted to (approve, emoji, Sus or comment; "Seen" doesn't count).
- "From {partner}": cards grouped by day ("Today", "Yesterday", "Day 21"), newest first, unreacted ones at the top of each day with a coral dot.
  - Photo check-in card: the photo large (rounded, 4:5) with its burned-in day/time stamp, the rule name and time, then the emoji reactions (❤️ 🔥 💪 👀 😂), "Sus 🤨" and "Approve ›".
  - Honour check-in card (compact): "{partner} stuck to {rule}" with the same reactions, Sus and Approve.
  - Tapping a photo opens the full-screen partner check-in (4.3) with the comment field; swiping goes to the next unreacted check-in.
  - Empty state: both characters with "All caught up. Nothing to check right now."
- "Mine": your own check-ins with what your partner did: "Approved ❤️", their emoji, "Sus 🤨", their comment, or "Not seen yet" / "Seen".
- **Plan changes** (shown above the list only when there are any): the partner's pending rule proposals as peach cards "{name} wants to add: {rule}" ("Instead of {old rule}") with "Approve ›" and "Suggest a change", and your own as "Waiting for {partner} to approve". They count in the tab badge.
- Works in Mock mode: Debug menu → "Act as {partner}" → "Simulate partner check-in" shows the new check-in, the badge and the dot.

### 4.13 Daily progress photos and Transformation
- **Progress pic** (Today card, optional): the camera opens with the **Day 1 progress photo as a ghost overlay at ~30% opacity** (toggle "Ghost on/off") so the pose lines up. One photo per person per local day; retaking replaces it. Not a rule check-in.
- **Private by default**: stored on the phone (Application Support, not the App Group the widget reads) and in the user's **own private CloudKit database** (zone `ProgressPhotos`), never in the couple's shared zone. Profile → **"Share progress pics with partner"** (off by default): when turned on, copies go to the shared zone as `ProgressShare` records so the partner can see them; when turned off, those copies are deleted from the shared zone. Leave couple deletes the shared copies; Delete my data deletes everything, including the private zone.
- **Transformation** (top of Progress): a **before/after slider** (Day 1 vs the latest photo, drag handle in the middle), a horizontal **timeline** of all progress photos (tap → full screen), **"Play"** (timelapse, ~0.15 s per photo) and **"Save / Share"**, which exports a vertical 9:16 video (1080×1920, H.264, `AVAssetWriter`) with the day label and a small "Pact" watermark and opens the share sheet. The partner's progress photos appear in their own row only if they share them. Empty state: "No progress photos yet. Take your first one today."
- **Milestones**: on Day 25, 50 and 75 (once each per round, if the user has progress photos), a celebration screen shows Day 1 and today side by side: only the user's own photos, plus the partner's if they share.

### 4.14 Launch screen and opening animation
- The launch screen (Info.plist `UILaunchScreen`: color `LaunchPeach` #FDE4D8, image `LaunchLogo` = the app icon with rounded corners, 120 pt, centred, ignoring safe areas) is **identical to the first frame** of the animation, so there is never a blank peach flash.
- Then ~1.2 s: the 75 + heart logo scales up with a gentle spring, the two avatars (the user's and the partner's, or the dashed outline if not joined) slide in from the left and right and meet in the middle with a **light haptic**, then everything cross-fades into Today (or onboarding for new users). The app loads underneath.
- Reduce Motion: no movement, just a short fade. Never block the user longer than ~1.5 s.

## 5. Notifications

- Ask for permission with a priming screen right after the invite step (or after B's "I'm in"): "Turn on reminders so neither of you misses a day", then `requestAuthorization`. If it was denied, Profile shows "Turn on in Settings".
- **Local** (scheduled on device, rescheduled daily): wake-up reminder "Day {n}. {x} rules today." (+ " {partner} is already up." if the partner has checked in); 21:00 warning only if rules are left: "{x} rules left. {hours} hours to go." — for people who take progress pics and haven't taken today's yet: "{x} rules left **and your progress pic**. {hours} hours to go." (cancel when complete); A's invite nudges (3.6); the trial reminder on Day 2 of a free trial (2.6); per-rule reminders "Time for {rule}." at the chosen times (4.8); the weekly recap on Monday 09:00 (4.16).
- **Partner events** (partner checked in, reaction or comment on your check-in, Sus, save used, round ended, pause request and its answer, B joined, tweak proposal and its answer, rule proposal "{name} suggested a new rule. Approve?" and its answer, a nudge "{name} nudged you 👀 2 rules left today.", a love note "{name}: Proud of you ❤️", partner's subscription ended): there is no server, so use CloudKit subscriptions. A subscribes to its couple zone in the private database, B to the shared database (`CKDatabaseSubscription` / `CKRecordZoneSubscription` with `shouldSendContentAvailable = true`). When the silent push arrives, fetch the changes (`CKFetchDatabaseChangesOperation` + `CKFetchRecordZoneChangesOperation` with saved change tokens) and post a **local** notification with the right text ("{name} finished {rule}. React?", "{name} thinks that's sus 🤨", ...). iOS doesn't always deliver silent pushes, so also fetch changes on every app open, when returning to the foreground, and in a `BGAppRefreshTask`. Deep link every notification to the right screen; "{name} finished {rule}. React?" opens that exact check-in in Proof.

## 6. Data and sync (CloudKit, no server)

### 6.1 The core idea: store facts, compute everything else
- The shared zone stores only **facts** people create: who the members are, their rules, check-ins, reactions, pause requests and answers, rule tweaks and answers, bet payments, round settings, subscription dates.
- **Nothing derived is ever stored**: not the day number, saves used, score, round status, who owes the bet, or whether the round is frozen. Each phone computes all of it with one pure function, `RulesEngine.state(facts:now:)`, which implements section 2 exactly. Because both phones run the same function on the same facts, they always agree, and there are no write conflicts.
- A missed day is noticed the next time either phone computes (app open, foreground, background refresh or widget refresh). When the computed state shows a new save used or a round end since the last time this phone looked, show 4.4 / 4.5 once (remember what was shown in UserDefaults).

### 6.2 Record types (all in the couple's zone, all children of the `Couple` root record so the share includes them)
- `Couple`: createdAt, ownerMemberID, title, invitedName, invitedAvatar (JSON), invitedFitness, invitedWakeTime (what B chose on A's phone).
- `Member`: memberID (UUID created on first launch and stored in the iCloud key-value store so it survives reinstalls), role `A|B`, name, characterID, skinColor, hairColor, jacketColor (avatar colours as "#RRGGBB"; empty = the character's original), timeZone (IANA; update on every launch), wakeTime, fitnessLevel, joinedAt, subscribedUntil, subscriptionProduct, subscriptionPeriods (JSON), leftAt.
- `RoundConfig`: fromRound (the round number it applies from), mode `standard|hard`, betText, rewardText, createdBy, createdAt. The latest config whose fromRound ≤ the round number applies.
- `Rule`: memberID, fromRound, position 1–4, libraryKey (`custom` for custom rules), title, type `photo|honour`, photoHint.
- `RuleProposal`: proposedBy, forMember (B's placeholder id before B joins), ruleJSON (the rule, with its position and fromRound), effectiveFrom (yyyy-MM-dd; set for the in-round swap), createdAt. `RuleAnswer`: proposalID, accepted, answeredAt. Never auto-accepted (2.7).
- `RuleTweak`: proposedBy, payload (JSON: swapped rule, new bet), createdAt. `TweakAnswer`: tweakID, accepted (Bool), answeredAt. No answer after `TWEAK_AUTO_ACCEPT_H` hours = accepted.
- `CheckIn`: memberID, ruleID, capturedAt, localDate (yyyy-MM-dd in the member's time zone), stampText, photo (`CKAsset`, photo rules only), isWarmup. Validity rule in 2.2.
- `Reaction`: checkInID, memberID, kind `approve|emoji|sus|comment|seen`, emoji, comment, createdAt.
- `PauseRequest`: requestedBy, startDate, days, reason, createdAt. `PauseAnswer`: pauseID, accepted, answeredAt. No answer after `PAUSE_AUTO_ACCEPT_H` hours = accepted.
- `BetPaid`: roundNumber, memberID, paidAt.
- `Nudge`: from, to, kind `nudge|note`, text, createdAt.
- `BucketItem`: text, addedBy, createdAt, doneAt, rewardRound (set when it's picked as a round's shared reward).
- `CheckIn` also has `healthProof` ("Apple Health · 8,412 steps") when Apple Health proved it.
- `RoundConfig.mode` can be `maintenance` (2.8).
- `ProgressShare`: memberID, localDate, dayNumber, capturedAt, photo (`CKAsset`). Only while the owner shares progress pics; deleted when they stop.
- Private database only (zone `ProgressPhotos`, never shared): `ProgressPhoto`: localDate, dayNumber, capturedAt, photo (`CKAsset`).
- Public database only: `InviteCode` (3.2) and `Waitlist` (email, createdAt).
- Write the schema as code and document in the README how to deploy it to Production in the CloudKit Console.

### 6.3 RulesEngine
- `RulesEngine.swift`: pure Swift, no CloudKit imports. Input: all facts + `now`. Output: rounds (number, start date per member, status, end reason, misses per member, saves used, who owes the bet, paid), today's day number and checklist per member, streak, best streak, frozen state, pending pauses and tweaks.
- Round 1 starts on the first local day after both members joined. Each following round starts the local day after the previous one ended.
- The couple is active while any member's subscription is active. Frozen: when nobody's is, days from that date on don't settle; after `LAPSE_GRACE_DAYS` the round ends as `abandoned` with no bet.
- Rules: the member's rules for the round, then B's join tweak, then **only approved** rule proposals, each from the local day after its approval; only the first approved in-round swap per member per round counts.
- **XCTest unit tests** covering: a normal complete day; one miss uses a save; the 4th miss ends the round and starts the next; both miss the same day; hard mode; tie at 0, tie above 0, unequal misses; pause accepted, declined, auto-accepted, pending at midnight; time zones 8 hours apart; a check-in uploaded too late is ignored; warm-up check-ins ignored; subscription lapse freeze and abandon; one subscription covers both (a partner's lapse alone doesn't freeze); Day 75 completion; a pending rule proposal doesn't count; an approved swap starts the next day; a second swap in a round is rejected; the plan review, the stored rules (A and B's copy) and Today always show identical rules; maintenance never fails, uses no saves, owes nothing and ends when a new round is set up; streak shields (7 days earn one, a miss uses it, max 2); the weekly recap counts the 7 days ending yesterday; Apple Health targets parse from rule titles; a typed goal becomes "Learn Chinese: 15/10/30 min" by level; plans are trimmed to 4–6 rules keeping 2 photo rules; typed goal names never contain brands; the same facts always give the same state.

### 6.4 The app's data layer
- `Store` protocol with `CloudKitStore` and `MockStore` (section 7). All screens use `@Observable` view models that read the latest `RulesEngine` state.
- A (the owner) reads and writes the zone in its **private** database; B reads and writes the same zone through its **shared** database. Hide that difference inside `CloudKitStore`.
- Cache all fetched records locally (Codable JSON in the App Group) so the app and the widget open instantly offline. Queue writes made offline and retry. If a check-in hasn't reached iCloud and the upload window is about to close, warn: "Not sent yet. Connect to the internet so it counts."
- Handle CloudKit errors properly: retry `CKError.retryAfterSeconds`, merge on `serverRecordChanged` (facts are append-only, so this is rare), and show clear messages for `quotaExceeded`, `notAuthenticated` (iCloud signed out) and `participantMayNeedVerification`.

### 6.5 Leave couple, delete my data, report
- **Leave couple** (Profile): a sheet "Leave {partner}?" explaining that the run ends and the shared photos are deleted for both. First offer "Save my photos" (exports the user's own photos to a share sheet as images), then "Leave couple" (destructive). If A leaves: delete the couple zone (this removes it for B too). If B leaves: write `leftAt` on B's Member record, then leave the share. Either way the other phone shows "{name} left the couple" and offers to start over with a new partner. The subscription stays with whoever bought it.
- **Delete my data** (Profile): same as Leave couple, plus delete all progress photos (local and the private `ProgressPhotos` zone), clear all local caches and the iCloud key-value store, then **fade** (not cut) back to the hook. (There is no account to delete, because the app has no sign-up.)
- Report: see 4.3. Leaving the couple doubles as "block".

## 7. Mock mode (so I can test without any backend)

In DEBUG builds the Simulator always runs in Mock mode. **Everything for Mock mode is inside `#if DEBUG`**: `MockStore`, the mock data, the Debug menu and its triggers, every "Mock: …" button and the Simulator camera placeholder. A Release build never turns on Mock mode. In Mock mode, use `MockStore`: both members' facts live in a local JSON file, purchases go through the StoreKit configuration file, and the same `RulesEngine` computes everything. Add a hidden **Debug menu** (triple-tap the Today header in DEBUG builds) with:
- "Act as {A} / Act as {B}" (switch which member you are)
- "Simulate partner check-in", "Simulate partner reaction", "Simulate Sus"
- "Advance to next day" (settles the current day), "Jump to Day 74"
- "Simulate miss", "Simulate pause request", "Simulate tweak proposal"
- "Simulate subscription lapse / renewal"
- "Reset everything"
In DEBUG builds without a camera (the Simulator) the shutter makes a generated sample photo; this code and its text exist only in DEBUG. A Release build without camera access says "Allow camera access in Settings to check in with a photo."

## 8. App Store requirements

- Paywall shows the price, the renewal period, the trial length and what happens when it ends, "Cancel anytime", Terms, Privacy and Restore. Prices are always localized from StoreKit. No invented ratings or reviews.
- "Delete my data" and "Leave couple" (6.5), report and block (4.3, 6.5). The app has no sign-up, so Apple's account-deletion rule doesn't apply, but keep "Delete my data" anyway.
- Privacy: photos are personal data under GDPR. They are stored in the couple owner's iCloud and shared only with the partner; the developer never sees them. Note in the README which data is collected (name, character, time zone, photos, check-ins) for the App Privacy labels.
- Never use "75 Hard" anywhere in the UI, metadata or code strings. Add to Profile → About: "Pact is not affiliated with 44Seven Media or the 75 HARD program."
- Camera usage string: "Pact uses the camera to take live proof photos for your partner." Photo library (add only) usage string, for saving the timelapse: "Pact saves your progress timelapse video to your photo library when you ask it to." App Store description: see `docs/APP_STORE_SUBMISSION.md` ("4 to 6 daily rules each", private progress photos and the timelapse). Notifications priming as in 5.

## 9. Build order (finish and test each stage before the next)

1. Project setup, design system, character compositing, `MockStore` + `RulesEngine.swift` with tests.
2. A onboarding (3.1) including paywall (StoreKit config) and invite UI.
3. B joining (3.5), waiting and warm-up (3.6).
4. Today, check-in camera, partner check-in, honour sheet.
5. Saves, round end, Day 75, Progress, pause flow, Profile, Leave couple / Delete my data.
6. Widgets, local notifications, Debug menu.
7. CloudKit: schema, zone + share creation, invite codes in the public database, accepting shares, sync with change tokens, silent-push subscriptions, background refresh.
8. StoreKit 2 subscription (one for the couple), trials and the trial reminder, lapse/freeze and take-over flow, iCloud-full and signed-out handling.

## 10. Quality bar

- iPhone only, portrait only, iOS 17+. Works on iPhone SE (small) through Pro Max with nothing cropped, nothing hidden behind buttons or the tab bar and no text cut off: scale illustrations to the available space. Keep SwiftUI previews of every screen at iPhone SE and Pro Max sizes (`App/Sources/Previews/ScreenPreviews.swift`).
- MVVM with `@Observable`, one file per screen, no third-party packages.
- VoiceOver labels on every control; the ring and the grid read their values.
- Must **build with zero errors and warnings**. Run `xcodebuild -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`, fix everything, then run all XCTest tests and fix failures.
- When you finish, give me a checklist of what I still have to do by hand: Apple Developer (bundle ID, App Group, iCloud container, Push Notifications), CloudKit Console (deploy the schema to Production), App Store Connect (the three subscriptions, free-trial offers, prices, privacy labels), testing the invite on two real iPhones with two different Apple IDs, and the character PNGs I need to generate.
