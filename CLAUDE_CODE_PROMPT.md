You are building a native iOS app, ready for the App Store, in **Swift + SwiftUI**. It is **Couples 75**: a couple does a 75-day challenge together. Each partner has 4 daily rules, proves them to the other with live photos or an evening honour tap, and the couple shares 3 "saves" that cover missed days. Whoever misses more owes a real-life bet (for example "Loser plans the date"). **Each partner has their own subscription (3,99 € / $3.99 a month per person)**: you pay, then you invite your partner, and they subscribe when they join. iPhone only. Work autonomously. Make reasonable decisions without asking me, and stop only if something needs my Apple Developer account or Supabase dashboard.

**Visual reference:** the folder `reference/` holds 32 mockups (`01_hook.jpg` … `30_partner_iphone.jpg`, plus `overview.jpg`). Use them for **colours, layout, illustration style, spacing and mood**. They are AI-generated at 720×1280 (9:16), so some look squashed or cropped. Build every screen properly for real iPhone sizes (iPhone SE up to Pro Max) and never copy their proportions pixel for pixel. **The mockups contain outdated copy and rules. This prompt is the source of truth. Wherever a mockup and this prompt disagree, this prompt wins.** Ignore `reference/README.txt` where it conflicts with this prompt. Section 4 lists every screen with the exact corrections.

## CONFIG (keep these in one `Brand.swift` file and use them everywhere)

```
APP_NAME             = "Couples 75"            // never "Couple's 75" and never "75 Hard"
TAGLINE              = "75 days. Same rules. One bet."
BUNDLE_ID            = "com.dinismagina.couples75"
APP_GROUP            = "group.com.dinismagina.couples75"
URL_SCHEME           = "couples75"
INVITE_DOMAIN        = "couples75.app"         // TODO: replace with the real domain; used for universal links
SUPPORT_EMAIL        = "nismagina@gmail.com"
TERMS_URL            = "https://example.com/terms"
PRIVACY_URL          = "https://example.com/privacy"
SUPABASE_URL         = ""                       // I'll fill these in
SUPABASE_ANON_KEY    = ""
BRANCH_KEY           = ""                       // optional; empty = code fallback only
IAP_MONTHLY          = "com.dinismagina.couples75.monthly"   // 3,99 € / $3.99 per person, auto-renewing, no trial
IAP_YEARLY           = "com.dinismagina.couples75.yearly"    // 29,99 € / $29.99 per person, auto-renewing, no trial
SAVES_PER_ROUND      = 3
ROUND_LENGTH_DAYS    = 75
MAX_PAUSE_DAYS       = 3
PAUSE_AUTO_ACCEPT_H  = 12
TWEAK_AUTO_ACCEPT_H  = 24
EVENING_WARNING      = "21:00"
LAPSE_GRACE_DAYS     = 7
MIN_IOS              = 17.0
```

When BOTH `SUPABASE_URL` and `SUPABASE_ANON_KEY` are empty, the app runs in **Mock mode** (section 7), so I can click through everything in the Simulator before any backend exists.

## 0. Project setup (do this first)

- Use **XcodeGen**: write `project.yml` and generate the project with `xcodegen generate` (`brew install xcodegen` if missing). Don't hand-write a pbxproj.
- Targets:
  1. `App`: the main SwiftUI app.
  2. `Widgets`: a WidgetKit extension (small + medium widgets, section 5.9).
  - Both share the App Group `APP_GROUP`. The app writes a small `WidgetSnapshot` JSON there; the widget only reads it.
- Capabilities on `App`: Sign in with Apple, Push Notifications, Associated Domains (`applinks:INVITE_DOMAIN`), App Groups, Background Modes (remote notifications).
- Swift packages (only these): `supabase-swift` and `branch-ios-sdk` (only used if `BRANCH_KEY` is set). Nothing else in the app. Purchases use **StoreKit 2 directly** (no RevenueCat).
- Add a **StoreKit Configuration file** `Products.storekit` with both subscriptions in one subscription group "Couples 75" (storefront Portugal, EUR: monthly 3,99 €, yearly 29,99 €; no introductory offers). Set it on the Run scheme so purchases work in the Simulator.
- Backend code lives in `supabase/`: SQL migrations in `supabase/migrations/`, Edge Functions (TypeScript/Deno) in `supabase/functions/`. Use the Supabase CLI layout so I can run `supabase db push` and `supabase functions deploy`.
- Art: import every PNG from `ArtSource/` into `Assets.xcassets` with the file name as the asset name (section 1.3). `AppIcon.png` may not be 1024×1024: resize it with `sips`, strip alpha, and use it as the single-size App Icon. **If an image is missing, show a neutral placeholder (a peach rounded rectangle with the character's initial) and never crash.**
- Write a `README.md` with: build-and-run steps, how to set up Supabase (create project, run migrations, set secrets, enable pg_cron, deploy functions, Apple sign-in provider), how to create the two subscriptions in App Store Connect, APNs key setup, and how to use Mock mode.

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
- Type: SF Pro Rounded for titles (bold, 28–34pt, centred on onboarding), SF Pro for body. Support Dynamic Type where layouts allow.
- Primary button: full width, 58pt tall, fully rounded capsule, `coral`, white 18pt semibold label ending in " ›".
- Secondary button: white capsule, 1pt border #EAD5CA, `textPrimary` label.
- Option card (radio): 72pt tall, radius 18, white; when selected, `peach` fill, 1.5pt `coral` border and a filled coral check circle on the left.
- Onboarding header: a 6pt gold progress bar (rounded) and "Step X of N" (13pt, `textSecondary`) under it. N is computed from the actual steps shown (section 3); never hard-code.
- Floating tab bar (not the system bar): a white rounded rectangle with a soft shadow and 3 items: **Today** (`sun.max`), **Progress** (`circle.grid.2x2`), **Profile** (`person`). The selected item is `coral`. No Challenges tab.
- Day ring: a gold circular progress ring (stroke 14) showing day/75, with "DAY 14 / 75" in the centre and the two characters overlapping it (see 15_today).
- Haptics: light impact on taps, success haptic on a check-in and on Day 75, warning haptic on a save used.
- Animations: push-style slide + fade between onboarding steps, spring animations on selections, confetti on Day 75.

### 1.3 Characters (important)
The mockups always show the same two people, "Maya" and "Joao". In the real app each user picks a character, so every scene must be **composed from two separate single-person images**, never one combined picture.
- v1 avatar = **pick one of 8 preset characters** (4 women `w1`–`w4`, 4 men `m1`–`m4`, varied skin tones and hair). Either partner can pick any character (same-sex couples work automatically). `w1` = Maya's look, `m1` = Joao's look. **Replace the mockup's face/hair/outfit avatar builder (02) with a simple character picker in the same style** (big character preview on top, a 4×2 grid of character busts below).
- Asset names: `char_{id}_{pose}` with poses `stand` (hands on hips), `crossed` (arms crossed, serious), `cheer` (one fist up), `stretch` (lunge/stretch), `bust` (head and shoulders for circles), all transparent PNGs. Plus `partner_outline` (the dashed "not joined yet" figure, used for any partner) and `trophy`.
- Compose scenes in SwiftUI: two characters side by side, partner A on the left, slightly overlapping, bottoms aligned, scaled to fit the available height (never cropped at the head). The gold ring, trophy and confetti are separate layers.
- Partner A's accent is `coral`, partner B's is `sage` (rule list headers, progress rings).
- Never use gendered pronouns in copy. Use names: "Day 1 starts the morning after Joao joins", never "after he joins".

## 2. Game rules (implement exactly; the server is the source of truth)

### 2.1 Couple, round and rules
- A **couple** has exactly 2 members: A (creator) and B (joined by invite). Each has their own subscription.
- A **round** is one 75-day attempt. Fields: `mode` (`standard` with `SAVES_PER_ROUND` saves, or `hard` with 0 saves), `status` (`waiting`, `active`, `completed`, `failed`, `abandoned`), per-member start date, per-member miss count, saves used, the bet, pause used (bool).
- Each member has exactly **4 rules** for the round. Each rule has a `type`: `photo` (proved by an in-app live photo) or `honour` (proved by an evening tap "I stuck to it today"). Every member has at least 2 photo rules. Intensity can differ per member (Maya "45 min workout", Joao "20 min walk").
- Rule library (seed it; use these titles exactly), with Easy / Couples 75 / Hard intensities:
  - Workout (photo): "20 min walk" / "45 min workout" / "Two 45 min workouts"
  - Water (photo): "2L of water" / "3L of water" / "4L of water"
  - Reading (photo): "Read 5 pages" / "Read 10 pages" / "Read 20 pages"
  - Cold shower (photo): "Cold shower" (all levels)
  - Steps (photo, screenshot of the in-app camera of a step counter is fine): "6k steps" / "8k steps" / "10k steps"
  - No sugar (honour), No alcohol (honour), No phone in bed (honour), No junk food (honour), In bed by 23:30 (honour)
- The plan generator picks rules from the quiz answers (goals: Fitness → workout + water, Discipline → reading + no phone in bed, Sleep → in bed by 23:30, Diet → no sugar / no junk food, Phone time → no phone in bed, Money → no junk food) and each member's fitness level sets that member's intensity. Always end with 4 rules per member, at least 2 photo.

### 2.2 Days and time zones
- Every member stores their IANA time zone (update it on every app launch and when it changes).
- **Day 1** for each member is the first full local calendar day after BOTH have joined (never the same evening). Before that the couple is in **warm-up**: check-ins work but don't count.
- A member's Day N is their own Nth local calendar day of the round, not counting paused days. Long-distance couples simply have different local dates.
- A check-in counts for the local date on which it was **submitted** (server timestamp converted to the member's time zone). Nothing can be checked in for a past date.
- A member's day is **final at their local midnight**. Nothing about a closed day ever changes.
- A member's day is **complete** if all 4 rules have a valid check-in for that date. Otherwise it's a **miss** (at most one miss per member per day).

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

### 2.6 Subscription (one per person, StoreKit 2, no RevenueCat)
- **Each partner pays for their own subscription**: 3,99 € / $3.99 a month or 29,99 € / $29.99 a year per person. Prices always come from StoreKit, never hard-coded.
- A pays during onboarding, then invites B. B subscribes during joining (3.5). The copy must make this obvious at every step: "3,99 € a month each", "After you subscribe, you'll invite {B}", "{B} joins with their own subscription".
- Use StoreKit 2: `Product.products(for:)`, `purchase()`, `Transaction.currentEntitlements` on launch and `Transaction.updates` while running, `AppStore.sync()` for Restore. Set `appAccountToken` on purchases to the user's Supabase UUID.
- After every entitlement change, the app writes `subscribed_until` (the transaction's `expirationDate`) and `subscription_product` to the user's `profiles` row, so the partner's phone and the server know whether both are active. (Client-reported is fine for v1; leave a `// TODO: verify with App Store Server API` in the Edge Function.)
- **Day 1 only starts once both partners have an active subscription.** Until B subscribes, A stays on Waiting for {B} (3.6).
- If either partner's subscription lapses: that partner sees a "Renew to keep your run" paywall, the partner sees a banner "{name}'s subscription ended. Your run is paused until they renew.", and the active round is **frozen** (no days settle, nothing counts) for up to `LAPSE_GRACE_DAYS`. If it isn't renewed in time, the round ends as `abandoned` with no bet.
- Each person manages only their own subscription. Nobody can pay for the other.

## 3. Flows

### 3.1 Person A onboarding (steps that show "Step X of N")
1. **Hook** (01): TAGLINE as the headline, the couple standing, "Let's start ›".
2. **Pick your character** (replaces 02): "Pick your character", big preview, 4×2 grid, "Looks like me ›".
3. **Names** (03): "Who's in this with you?", your name field and your partner's name field. The partner card shows `partner_outline` and "Picks their character later".
4. **Is {partner} on iPhone?** (30, moved here from just before the paywall): two option cards "Yes, iPhone" and "No, Android", **nothing preselected**, Continue disabled until one is picked. Remove the footnote from this screen. "No, Android" → the Android waitlist screen (3.4) and nothing else.
5. **Is {partner} with you right now?** (new, same style as 04): "Yes, we're together" / "No, I'll invite them". If together → "Hand the phone to {partner}" screen → B picks a character and answers B's two questions (fitness level, wake-up time) → "Hand it back to {A}" → continue. B's answers are saved into the plan, so B later only signs in.
6. **How long have you been together?** (04): <1 yr, 1–3 yrs, 3+ yrs.
7. **Long distance?** (05): Yes / No.
8. **What do you want to fix together?** (06): multi-select, at least 2: Fitness, Money, Phone time, Discipline, Sleep, Diet.
9. **Your fitness level** (new, same style as 04): Just starting / Somewhat active / Very active.
10. **When do you usually wake up?** (new): a time wheel, default 07:30.
11. **How often do you start something together and quit?** (07): slider Rarely / Sometimes / Usually / Always.
12. **Mirror moment** (08): keep exactly: "Most couples quit before it gets hard. Not because they're weak. Because no one's watching."
13. **Pick your level** (09): rename the options to "Easy", "Couples 75" (with the "Most popular" pill, preselected) and "Hard mode". Never show the words "75 Soft" or "75 Hard". Under Hard mode, small text: "No saves. One miss restarts the round."
14. **Building your plan** (10): animated checklist "Matching rules to your goals…", "Building Day 1", "Setting the finish line", ~3 seconds, auto-advances.
15. **Plan reveal** (11): "{A} & {B}'s 75-day plan", the ring scene, a Daily rules card with two columns (A in coral, B in sage). The saves card reads "3 saves" with subtitle **"Shared. Each one covers a missed day."** (not "Life happens passes"); in Hard mode it reads "No saves" / "One miss restarts the round". If B hasn't answered yet, label B's column "Draft: {B} can adjust when they join" and use Couples 75 intensity for B. Button "See our plan ›" → next.
16. **Set the stakes** (12): "Set the stakes", subtitle "{B} accepts this when they join." Options: Loser plans the date / Loser cooks dinner for a week / Loser plans the trip / Custom (opens a one-line text field, max 40 characters). Below: "Hold to sign", "We finish this together", and the fingerprint button: hold for 1.5 s with a filling coral ring and a success haptic, then advance.
17. **Outcome** (13a): "In 75 days, you'll be the couple who finished." with the cheer + trophy scene.
Then without a step counter:
18. **Paywall** (13c, section 3.3).
19. **Invite partner** (14, section 3.2), skipped if they set it up together (B then just needs the code shown on a "Get {B} in" screen with the same share button).
Delete 13b ("How your trial works"): there is no trial.

### 3.2 Invite
- Screen 14: "Send {B} their invite", A's character standing next to `partner_outline`, a card showing the invite link `https://INVITE_DOMAIN/join/{CODE}` with a copy button, and "Send invite ›".
- The code is 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no 0/O/1/I), unique, valid until used.
- "Send invite" renders a **shareable invite card image** (A's character, partner outline, "{A} invited you to Couples 75", the 4 rules, the bet, and a small line "{monthly price}/month each") and opens the share sheet (`ShareLink`) with that image and the text: "I just signed us up for 75 days. {bet}. You in? {link}". Messages appears first on iPhone automatically.
- Deep links: universal link `https://INVITE_DOMAIN/join/{CODE}` and `URL_SCHEME://join/{CODE}`. If `BRANCH_KEY` is set, use Branch for deferred deep linking (code survives the App Store install). Otherwise B uses the code screen. Put this behind an `InviteLinkService` protocol. Also write `apple-app-site-association` JSON into `web/.well-known/` for me to host.

### 3.3 Paywall (13c) and exit sheet (13d)
- Remove the stars, the "4.9" and the quote completely (no fake ratings). The header becomes "3,99 € a month each" (22pt semibold, price from StoreKit) with the subtitle "You subscribe now, then invite {B}. {B} joins with their own subscription."
- Monthly card (preselected): "Monthly", "{monthly price}/month per person".
- Yearly card: "Yearly", gold pill "BEST VALUE · {monthly equivalent}/month" (yearly price ÷ 12, localized), and "{yearly price}/year per person". **No trial text.**
- Under the cards, a 3-step strip so nobody is confused: "1. You subscribe" → "2. Invite {B}" → "3. {B} subscribes and Day 1 starts". Then "Cancel anytime."
- Primary: "Start our challenge ›". Footer links: "Terms · Privacy · Restore". All prices come from StoreKit, never hard-coded.
- The × opens the exit sheet (13d): "Not ready to start?", body "It's {monthly price} a month each. Cancel anytime.", primary "Start monthly ›", secondary "Back to plans". Remove "Get a 7-day trial instead". Dismissing the sheet returns to the paywall; closing the paywall entirely returns to the plan reveal, never into the app.
- On purchase: write `subscribed_until` to the profile (2.6), show a short confirmation "You're in. Now invite {B}.", then go to Invite.

### 3.4 Android waitlist (new, style of 30)
Title "Couples 75 is iPhone-only for now", body "Leave your email and we'll tell you when Android is ready.", email field, "Notify me ›" (saves to the `waitlist` table), then "Thanks! We'll be in touch." and a "Done" button that returns to the hook. No paywall ever.

### 3.5 Person B joining
1. **Opens the link** → **"{A} invited you"** (25): small coral label "You're in", title "{A} invited you", A's bust in a circle, a card "{A} picked this plan for you both" listing A's and B's rules, "3 saves, shared" (not "Life happens saves"), and the bet box. "See the plan ›". Footer: "You can swap one rule and change the bet. Couples 75 is {monthly price} a month each, so you'll subscribe before Day 1."
2. If no link or the deep link failed, the first screen is **"Did your partner invite you?"** (26) with 6 code boxes, "Join {A} ›" (enabled when the code resolves; show A's name after resolving), and "I don't have a code" → the normal A onboarding.
3. If they set it up together: B lands on "Welcome back, {B}" → Sign in with Apple → linked. Skip to step 7.
4. **Pick your character** (same as A).
5. **Your fitness level** and **When do you usually wake up?** (same screens as A).
6. **Accept or tweak** (new): B's 4 rules (from B's own fitness level), "Swap a rule" (pick one rule to replace from the library), and "Change the bet" (same options as 12). A gets a push to accept or decline; if A doesn't answer in `TWEAK_AUTO_ACCEPT_H` hours, B's version is used.
7. **Sign in with Apple**.
8. **Paywall for B** (same design as 13c): header "Join {A}: {monthly price} a month", subtitle "{A} already subscribed. Subscribe to start Day 1 together." Same monthly/yearly cards, no 3-step strip, primary "Join {A} ›", footer Terms · Privacy · Restore. Closing it goes to a screen "{A} is waiting for you" with "Subscribe ›"; B cannot start without subscribing.
9. "I'm in" → Day 1 is the next local day.
B never sees steps 6–17 of A's quiz. If B already has an active subscription (from an earlier couple), skip step 8.

### 3.6 Waiting and warm-up
- **Waiting for {B}** (27): header "{A} & {B}" with a "Not started" pill, "Waiting for {B}", "Day 1 starts the morning after {B} joins and subscribes.", A's character + `partner_outline`, "Remind {B} ›" (re-opens the share sheet), "Copy invite code", and "Or start a warm-up day. It doesn't count." Remind reminders are also sent as local notifications to A on days 1, 3 and 6 after paying: "Nudge {B}? Your plan is waiting." On day 7 the Waiting screen adds: "Invite someone else" (new code; old code invalidated) and "Manage subscription" (opens the App Store subscriptions page).
- **Warm-up day** (28): banner "Warm-up day: this doesn't count", "Practise a check-in while you wait. Day 1 starts the morning after {B} joins." Today's practice lists both columns; "Practise check-in ›". Practice check-ins are stored with `is_warmup = true` and never count.

## 4. Main app screens (mockup → corrections)

### 4.1 Today (15)
- Header: "{A} & {B}" and a gold streak pill "🔥 {streak}".
- The ring scene with "DAY {n} / 75". A speech bubble from whoever is done: "{name}'s done. Your turn." (only when exactly one of them is done for today). Status chips under each character: "Done" (sage) or "{x} left" (brown).
- Week dots (S M T W T F S) for the current week: gold = complete, coral ring = today, faint = future, and a small coral "S" dot for a day covered by a save, grey for paused.
- **Replace "Miss a day = restart"** with a row: "Saves" + three small gold squares (filled = left) and "Score: {A} {missesA} · {B} {missesB}". In Hard mode: "Hard mode · no saves".
- "Today's rules": two cards side by side (A, B), each rule with a check circle; your own rules are tappable. Photo rule → camera (21). Honour rule → a small sheet "Did you stick to {rule} today?" with "Yes, I did ›" (only enabled after 18:00 local; before that the row says "Tap tonight").
- Primary "Check in ›" opens your next unchecked rule.
- Bet row at the bottom: "🏆 Stakes: {bet}".
- After 21:00, if you still have rules left, a coral banner: "{x} rules left. {hours} hours to go."

### 4.2 Check-in camera (21)
Full-screen dark camera (`AVCaptureSession`, back camera default, flip button). Top: rule title and "Live photo · not from your camera roll", a "LIVE" pill. Bottom: "Snap proof for {partner}", Cancel, shutter. After capture: preview with "Retake" / "Send ›". **Burn a stamp into the image** (bottom left, dark pill): "DAY {n} · {SAT 21 NOV} · {07:14}" in the member's local time. Compress to max 1600 px, JPEG 0.7, upload to Storage, then create the check-in. Photo prompts under the rule title keep photos non-intimate, e.g. cold shower: "Photo of the running shower or your face after. Never your body." There is no way to pick from the photo library.

### 4.3 Partner check-in (22)
Opened from the push or by tapping the partner's rule. Header "{name} checked in", rule title, "Day {n} · {time}", the photo. "React": ❤️ 🔥 💪 👀 😂, a one-line comment field, then two buttons: **"Sus 🤨"** (secondary) and **"Approve ›"** (primary). **Remove "Prove it"**. Add a small "Report" link at the bottom (sends a report row and opens an email draft to SUPPORT_EMAIL with the check-in id).

### 4.4 Save used (23)
Shown to both members the next time they open the app after a miss. Characters `crossed`. Title "Save used". Body: "{name} missed a rule on Day {n}. One save covered it, so the run continues." Card rows: "Saves left: {x} of 3", "Score: {A} {a} · {B} {b}", "Whoever has more misses at Day 75 owes the bet." Button "Back to today ›". **Never say "Life happens pass", "skipped" or "no restart" here.**

### 4.5 Round end (24)
- Failed round: small coral label "Round over", title "Out of saves on Day {n}", characters `crossed`. Bet card: "🏆 The bet", "{name} owes:" (or "You both owe:" or nothing), the bet in 26pt bold, "Final score: {A} {a} · {B} {b}", "Back to Day 1 tomorrow. Best streak: {x} days. Your history is kept." Primary "Paid ›" (hidden if nobody owes), secondary text button "Start round 2".
- Completed round: go to Day 75 (4.7) first, then this card if someone owes.

### 4.6 Progress (16)
Title "Progress", "{A} & {B}", the two characters, a 75-day grid (gold = both complete, half gold = one complete + one save, coral outline = today, grey = paused, empty = future), "Day {n} of 75", a horizontal strip of both partners' recent photos (tap → full-screen viewer with the stamp and reactions), "Best streak", "Rounds", and the bet row. Photos are visible only to the couple.

### 4.7 Day 75 (19)
Confetti, "Day 75", "We finished Couples 75" (fix the name), "{A} & {B}", the cheer + trophy scene. A recap card: saves used, final score, best streak, most sus moments, and who owes the bet (or "Nobody owes anything"). Buttons: "Share our card ›" (renders a 1080×1920 image without photos and opens the share sheet), "Start round 2" (reruns steps 9 and 13 of the quiz, offers Hard mode).

### 4.8 Profile (18)
Your character, your name, "Partner linked" pill (sage; make sure it isn't cut off). Rows: **Mode** (Couples 75 · 3 saves / Hard mode), **Saves left** ("{x} of 3"), **Wake-up reminder** (time), **Evening warning** (21:00, on/off), **Partner** ({name}), **Subscription** (your own: Active · Monthly / Yearly, renews {date}) → Manage, **Partner's subscription** (Active / Ended), **Restore purchases**, **Terms**, **Privacy**, **Contact support**. Then quiet text buttons: **"Leave couple"** and **"Delete account"** (section 6.4). Remove "Missed-day rule: Restart".

### 4.9 Pause request (29)
- Requester side (new): from Today's "…" menu → "Life happens": pick 1–3 days, start Today/Tomorrow, reason field ("Travelling", "Sick", or custom), "Send request ›". Disabled with an explanation if the round's pause is already used.
- Receiver side (29): small coral label "Pause request", title "{name} asked to pause", body: "{reason}. Pause {x} day(s) from {date}? Paused days don't count for either of you and don't use a save. If you don't answer in 12 hours, it's accepted." Buttons "Agree ›" / "Not now". **Replace the mockup copy** ("one save is used", "Saves left if you agree") with this.

### 4.10 Widgets (20)
- Small: the ring with both characters' busts and "Day {n}/75".
- Medium: the two characters, "Day {n}/75", "{A} ✓ · {B} …" (✓ when complete, … when not) and the streak flame.
- Never show photos in widgets. Update the snapshot after every check-in, settlement and app launch, then call `WidgetCenter.shared.reloadAllTimelines()`.

### 4.11 Locked states
- Your subscription lapsed (2.6): full-screen "Renew to keep your run" paywall. Your partner's lapsed: a banner on Today, and the round shows as paused.
- Round frozen banner on Today: "Your run is paused until the subscription is renewed."

## 5. Notifications

- Ask for permission with a priming screen right after the invite step (or after B's "I'm in"): "Turn on reminders so neither of you misses a day" → system prompt.
- **Local** (scheduled on device, rescheduled daily): wake-up reminder "Day {n}. 4 rules today." (+ " {partner} is already up." if the partner has checked in); 21:00 warning only if rules are left: "{x} rules left. {hours} hours to go." (cancel when complete); A's invite nudges (3.6).
- **Remote** (Edge Function `notify`, APNs HTTP/2 with a .p8 key stored as Supabase secrets): partner checked in ("{name} finished {rule}. React?"), reaction or comment on your check-in, Sus ("{name} thinks that's sus 🤨"), save used, round ended, pause request and its answer, B joined, tweak proposal and its answer, subscription lapsed.
- Store APNs device tokens per user (multiple devices allowed). Deep link every push to the right screen.

## 6. Backend (Supabase)

### 6.1 Tables (write as migrations, with RLS enabled on every table)
- `profiles` (id = auth.uid, name, character_id, time_zone, wake_time, fitness_level, apns_tokens text[], subscribed_until, subscription_product, created_at)
- `couples` (id, created_by, status `active|ended`, created_at)
- `couple_members` (couple_id, user_id, role `A|B`, joined_at) — unique user_id while active
- `invites` (code, couple_id, created_by, expires_at, used_by, used_at)
- `rounds` (id, couple_id, number, mode, status, bet_text, reward_text, start_date_a, start_date_b, misses_a, misses_b, saves_total, saves_used, pause_used, frozen_since, ended_at, end_reason, bet_owed_by `none|A|B|both`, bet_paid_at)
- `rules` (id, round_id, user_id, library_key, title, type `photo|honour`, position 1–4)
- `rule_tweaks` (id, round_id, proposed_by, payload jsonb, status `pending|accepted|declined|auto`, created_at)
- `checkins` (id, round_id, rule_id, user_id, local_date, created_at server default now(), photo_path, is_warmup)
- `reactions` (id, checkin_id, user_id, kind `approve|emoji|sus|comment|seen`, emoji, comment, created_at)
- `day_results` (round_id, user_id, local_date, day_number, result `complete|miss|paused`, settled_at) — primary key (round_id, user_id, local_date)
- `pauses` (id, round_id, requested_by, start_date, days, reason, status `pending|accepted|declined|auto`, created_at, resolved_at)
- `reports` (id, checkin_id, reported_by, created_at)
- `waitlist` (email, created_at)
- Storage bucket `checkins` (private). Path `{couple_id}/{round_id}/{user_id}/{checkin_id}.jpg`. Policies: only members of that couple can read; only the owner can write their own path. The app uses signed URLs (1 hour).
- RLS: a user can read rows of their own couple only. Writes that change game state (`day_results`, `rounds.misses_*`, `saves_used`, `status`) are **server-only** (Edge Functions with the service role). Clients may insert their own `checkins`, `reactions`, `pauses` requests, `rule_tweaks`, `reports`.
- A trigger rejects check-ins whose `local_date` isn't the member's current local date (computed from `profiles.time_zone` and `now()`).

### 6.2 Edge Functions
- `settle-days` (called by **pg_cron every 10 minutes**): for each active, non-frozen round, for each member, settle every local date that has ended and isn't settled yet, in date order, applying section 2 exactly (pending pauses block settlement of their dates; accepted pauses produce `paused`). Process both members' same date together. Handle round end, bet settlement and the next round's creation. Auto-accept pauses older than 12 hours and tweaks older than 24 hours. Send the matching pushes. **Must be idempotent** (safe to run twice).
- `redeem-invite`: validates a code, adds the caller as B, invalidates the code, notifies A.
- `subscription-check` (called by `settle-days` before settling): if either member's `subscribed_until` is in the past, freeze the round (set `frozen_since`) and notify both; unfreeze when both are active again; end it as `abandoned` after `LAPSE_GRACE_DAYS`. Round start (Day 1) also requires both active.
- `notify`: internal helper for APNs.
- `leave-couple` and `delete-account` (6.4).
- Write unit tests for the settlement logic as a pure TypeScript module (`supabase/functions/_shared/rules.ts`) with Deno tests covering: a normal complete day; one miss uses a save; the 4th miss ends the round; both miss the same day; hard mode; tie at 0, tie above 0, unequal misses; pause accepted, declined, auto-accepted, pending at midnight; time zones 8 hours apart; warm-up check-ins ignored; settlement run twice changes nothing.

### 6.3 The app's data layer
- `Backend` protocol with `SupabaseBackend` and `MockBackend` (section 7). All screens talk to `Backend` through `@Observable` view models.
- Use Supabase Realtime on `checkins`, `reactions`, `pauses`, `rounds` for the couple so the partner's progress updates live.
- Sign in with Apple via `ASAuthorizationAppleIDProvider` → Supabase `signInWithIdToken`. Sign-in happens at the end of onboarding (before the paywall for A, at "I'm in" for B).
- Cache the last state locally so the app opens instantly offline. Queue check-in uploads offline and retry, but tell the user if a check-in hasn't reached the server by midnight ("Not sent yet. Connect to the internet before midnight.").

### 6.4 Leave couple, delete account, report
- **Leave couple** (Profile): a sheet "Leave {partner}?" explaining that the run ends and the shared photos are deleted for both. First offer "Save my photos" (exports the user's own photos to a share sheet as images), then "Leave couple" (destructive). Server deletes the couple's storage folder, ends the round, notifies the partner. Each person keeps their own subscription and can invite a new partner.
- **Delete account** (Profile, Apple requirement): confirm sheet, then the server deletes the profile, leaves the couple as above, deletes the auth user, and the app returns to the hook.
- Report: see 4.3. Leaving the couple doubles as "block".

## 7. Mock mode (so I can test without any backend)

When `SUPABASE_URL` is empty, use `MockBackend`: everything in memory + persisted to a local JSON file, purchases via the StoreKit configuration file, and the same settlement logic ported to Swift (`RulesEngine.swift`, mirroring `rules.ts`, with XCTest unit tests for the same cases as 6.2). Add a hidden **Debug menu** (triple-tap the Today header in DEBUG builds) with:
- "Act as {A} / Act as {B}" (switch which member you are)
- "Simulate partner check-in", "Simulate partner reaction", "Simulate Sus"
- "Advance to next day" (settles the current day), "Jump to Day 74"
- "Simulate miss", "Simulate pause request", "Simulate tweak proposal"
- "Simulate subscription lapse / renewal"
- "Reset everything"
In Mock mode the camera falls back to a generated placeholder image in the Simulator.

## 8. App Store requirements

- Paywall shows the price, the renewal period, "Cancel anytime", Terms, Privacy and Restore. Prices are always localized from StoreKit.
- In-app account deletion (6.4), report and block (4.3, 6.4).
- Privacy: photos are personal data under GDPR. Note in the README which data is collected (name, character, time zone, photos, check-ins) for the App Privacy labels.
- Never use "75 Hard" anywhere in the UI, metadata or code strings. Add to Profile → About: "Couples 75 is not affiliated with 44Seven Media or the 75 HARD program."
- Camera usage string: "Couples 75 uses the camera to take live proof photos for your partner." Notifications priming as in 5.

## 9. Build order (finish and test each stage before the next)

1. Project setup, design system, character compositing, Mock backend + `RulesEngine.swift` with tests.
2. A onboarding (3.1) including paywall (StoreKit config) and invite UI.
3. B joining (3.5), waiting and warm-up (3.6).
4. Today, check-in camera, partner check-in, honour sheet.
5. Saves, round end, Day 75, Progress, pause flow, Profile, Leave couple / Delete account.
6. Widgets, local notifications, Debug menu.
7. Supabase: migrations, RLS, Edge Functions + Deno tests, Realtime, Sign in with Apple, Storage.
8. StoreKit 2 subscriptions for both partners, lapse/freeze flow, remote pushes, deep links.

## 10. Quality bar

- iPhone only, portrait only, iOS 17+. Works on iPhone SE (small) through Pro Max with nothing cropped: scale illustrations to the available height.
- MVVM with `@Observable`, one file per screen, no third-party packages beyond those in section 0.
- VoiceOver labels on every control; the ring and the grid read their values.
- Must **build with zero errors and warnings**. Run `xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`, fix everything, then run all XCTest and Deno tests and fix failures.
- When you finish, give me a checklist of what I still have to do by hand: Apple Developer (bundle ID, App Group, Sign in with Apple, Push key, Associated Domains), Supabase (project, secrets, pg_cron, Apple provider), App Store Connect (the two subscriptions, prices, privacy labels), hosting the `apple-app-site-association` file, and the character PNGs I need to generate.
