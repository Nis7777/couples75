# Pact (working name)

iPhone app for **couple maxing**: a couple levels up together. Both partners keep daily habits (Body, Looks,
Mind & money) with no stakes, share one streak, one XP total and one rank, and start challenges on top when they
want a push: short ones like the 21-Day Shred, the 30-Day Glow-Up or a No-Spend Week, or the signature **The 75**
(75 days, photo proof and a bet required). Swift + SwiftUI, iOS 17+, Apple frameworks only
(SwiftUI, CloudKit, StoreKit 2, AVFoundation, WidgetKit, UserNotifications, BackgroundTasks). No backend server:
the two phones share facts through CloudKit and each computes everything with the same `RulesEngine`.

- `CLAUDE_CODE_PROMPT.md`: the spec (source of truth; its first section describes the couple-maxing pivot)
- `docs/IMAGE_PROMPTS.md`: prompts for the custom icons, rank badges and app icon, and where each PNG goes
- `docs/TEST_CHECKLIST.md`: what to tap through in the Simulator
- `docs/APPLE_SETUP.md`: identifiers, App Store Connect, subscriptions, iCloud and TestFlight, step by step
- `docs/BRAND.md`: the locked colour palette and the coral rule
- `docs/APP_STORE_CONNECT_PROMPT.md`: a ready-to-paste prompt that sets up the App Store Connect record
- `reference/`: design mockups (visual direction only)
- `ArtSource/`: the original character art (already imported into `Shared/Assets.xcassets`)

## Build and run

1. Open `Pact.xcodeproj` in Xcode 16 or later.
2. Pick the **Pact** scheme and an iPhone Simulator (e.g. iPhone 16 Pro).
3. Press Run.

In the Simulator the app always starts in **Mock mode** (see below), so everything works without iCloud.
The Run action uses `Config/Products.storekit`, so the subscriptions can be bought in the Simulator with no
App Store Connect setup.

Tests: Product → Test (⌘U), or

```bash
xcodebuild -project Pact.xcodeproj -scheme Pact -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

### Project layout

| Folder | Target(s) | What |
|---|---|---|
| `App/Sources` | app | SwiftUI app: `Engine/` (pure `RulesEngine`), `Model/`, `Data/` (stores, StoreKit, notifications), `Design/`, `Screens/` (one file per screen) |
| `Shared/` | app + widget | `Brand.swift` (all config), `Theme.swift` (colours, character images), `WidgetSnapshot.swift`, `Assets.xcassets` (art + app icon) |
| `Widgets/` | widget extension | small and medium widgets |
| `Tests/` | unit tests | `RulesEngineTests` |
| `Config/` | — | Info.plists, entitlements, `Products.storekit` |

The project uses Xcode's synchronized folders: any file added to `App/`, `Shared/`, `Widgets/` or `Tests/` is
part of the matching target automatically.

## Mock mode

Mock mode keeps both members' facts in one local JSON file and runs the same `RulesEngine`. It exists only in
DEBUG builds (all of it is inside `#if DEBUG`) and is on when:

- running in the Simulator, or
- the DEBUG launch argument `-mock` is enabled (Scheme → Run → Arguments; it's there, unticked), or
- a DEBUG build has no iCloud account.

Release builds on a device without iCloud show "Turn on iCloud to use Pact" instead.

**Debug menu** (DEBUG builds): triple-tap the "{A} & {B}" header on Today, or use the "…" menu on Today, or
Profile → Debug menu. It can act as A or B, simulate the partner joining, checking in, reacting, Sus, a pause
request or a tweak proposal, advance to the next day (settles today), jump to the last day of the running
challenge (on habits: 29 days ahead), simulate a miss, lapse or renew the partner's subscription, and reset
everything. To try a challenge: simulate the partner joining, open the Challenges tab, start one, then
"Advance to next day".

Click-through as A: onboarding → paywall (StoreKit test purchase) → invite → Waiting → "Mock: simulate {B}
joining" (or Debug menu) → Day 1 starts tomorrow → Debug → "Advance to next day".
As B: on the first screen type any 6 letters (e.g. `K7M2QP`) → "Join Maya" → joining flow.

In the Simulator there's no camera: the shutter generates a sample photo with the stamp burned in.

## CloudKit setup

1. Apple Developer → Identifiers: create the App ID `com.tomasbeja.pact` with **iCloud (CloudKit)**,
   **Push Notifications** and **App Groups**; create the widget App ID `com.tomasbeja.pact.widgets` with
   **App Groups**.
2. Create the iCloud container `iCloud.com.tomasbeja.pact` and the App Group
   `group.com.tomasbeja.pact`, and enable them on both App IDs (the container only on the app).
3. In Xcode, select your team on the Pact and Widgets targets (Signing & Capabilities). The device
   entitlements are in `Config/App.entitlements` and `Config/Widgets.entitlements` (Simulator builds use none).
4. Run once on a device signed into iCloud (Development environment). CloudKit creates the record types the
   first time the app saves them. To create all of them, go through: A onboarding and pay, B joins with the code,
   a photo check-in, an honour tap, a reaction, a pause request + answer, a tweak + answer, "Paid" on a bet, and
   the Android waitlist.
5. CloudKit Console → your container → **Schema**: check the record types listed in
   `App/Sources/Data/CloudKitSchema.swift`:
   `Couple, Member, RoundConfig, Rule, RuleTweak, TweakAnswer, CheckIn, Reaction, PauseRequest, PauseAnswer,
   BetPaid` (couple zone) and `InviteCode, Waitlist` (public database). `RoundConfig` has the challenge fields
   `length`, `saves`, `challengeID`, `proofRequired` and `quitBy`: start a challenge (and give one up) once in
   Development so they exist before you deploy.
   No queries are used (everything is fetched by zone change tokens or by record name), so no extra indexes
   are needed. In **Security Roles** make sure `InviteCode` is readable by "Authenticated" users (default).
6. **Deploy Schema Changes…** to Production. Do this again whenever a record type gains a field.

How data is shared: A's phone creates a custom zone `Couple-{uuid}` in A's private database with a root
`Couple` record and a zone-wide `CKShare` (public permission read/write, closed once B has joined), plus an
`InviteCode` record (record name = the 6-letter code) in the public database. B accepts the share from the link
or the code, then reads and writes the same zone through the shared database. Silent pushes come from a
`CKRecordZoneSubscription` (A) and a `CKDatabaseSubscription` (B); changes are also fetched on launch, when
returning to the foreground, every few minutes while open, and in a background refresh task.

## App Store Connect: the subscriptions

One subscription covers both partners: only the person who starts (A) pays; the partner joins free.

1. Create the app with bundle ID `com.tomasbeja.pact`.
2. Subscriptions → create the group **Pact** with three auto-renewable subscriptions:
   - `com.tomasbeja.pact.yearly7`: 1 year, $39.99 (United States base price; let Apple fill the other
     storefronts), introductory offer **free trial, 1 week**. The paywall's yearly plan, preselected.
   - `com.tomasbeja.pact.monthly`: 1 month, $12.99, no introductory offer.
   - `com.tomasbeja.pact.yearlyoffer`: 1 year, $24.99, introductory offer **free trial, 1 week**. The paywall's
     one-time exit offer (38% off).
3. Add a display name and description to each, a review screenshot of the paywall, and submit them with the
   first app version.
4. The app sends `appAccountToken` = the member's UUID and writes `subscribedUntil` / `subscriptionProduct` to the
   buyer's own `Member` record. The couple counts as active while either member's subscription is active.
5. When a trial starts the app schedules a local reminder for Day 2 of the trial.

## Apple Watch, HealthKit, Live Activities

- The project has a watchOS target (`PactWatch`) embedded in the iPhone app. If Xcode says the watchOS
  platform isn't installed, click **Get** (Xcode → Settings → Components → watchOS) once; then Run works as before.
- Enable **HealthKit** for the App ID (read only) in the Apple Developer portal; the entitlement is in
  `Config/App.entitlements`.
- Live Activities need nothing extra (`NSSupportsLiveActivities` is in the Info.plist).
- New CloudKit record types to deploy to Production: `Nudge`, `BucketItem`, `ProgressShare` (couple zone)
  and `ProgressPhoto` (private zone `ProgressPhotos`), plus the `healthProof` field on `CheckIn`.

## Testing the invite on two iPhones

You need two iPhones signed into two **different** Apple IDs (a Sandbox tester on each for purchases:
Settings → App Store → Sandbox Account).

1. Install the same build on both (Xcode Run or TestFlight).
2. Phone A: onboarding → subscribe (sandbox) → "Send invite" → send the message to phone B.
3. Phone B: tap the iCloud link in Messages (opens the app and accepts the share) **or** open the app and type
   the 6-letter code. Pick a character, fitness, wake-up, accept or tweak, subscribe, "I'm in".
4. Phone A gets "{B} joined" and the invite closes (a third Apple ID trying the old link sees "This couple is
   already full"). Day 1 starts the next local morning on both.
5. Check in on one phone; the other gets "{name} finished {rule}. React?" within seconds (silent pushes need a
   real device; otherwise pull to refresh or reopen the app).

## Privacy (App Privacy labels)

The developer never receives any data: everything lives in the users' own iCloud (the couple's photos are
stored in the owner's iCloud and shared only with the partner). For the App Privacy questionnaire, the app
stores: **name**, **character choice**, **time zone**, **photos** (check-in proof), **check-ins / reactions**
(user content), and, for the Android waitlist only, an **email address** in the public database. Nothing is
used for tracking. Photos are personal data under GDPR; "Leave couple" and "Delete my data" remove them.

Pact's "The 75" challenge is not affiliated with 44Seven Media or the 75 HARD program.

## Renaming the app

`Brand.appName` in `Shared/Brand.swift` is used for every name the user sees in the app and widgets. Also change
`CFBundleDisplayName` in `Config/App-Info.plist` and `Config/Widgets-Info.plist`, the Watch title in
`Watch/WatchTodayView.swift`, the usage strings in `Config/App-Info.plist`, and the group name in
`Config/Products.storekit`. Bundle IDs, the CloudKit container and the URL scheme stay as they are (changing them
would reset everyone's data).

## Art

`Shared/Assets.xcassets` contains one image set per PNG in `ArtSource/` (`char_{w1…w6,m1…m6}_{stand,crossed,cheer,stretch,bust}`,
`partner_outline`, `trophy`) and `AppIcon.png` as the single-size app icon.

Custom icons (tab bar, areas, challenges, rank badges, the streak flame, goal chips) are optional: each one has an
SF Symbol fallback and is picked up by name as soon as its PNG is in `Shared/Assets.xcassets`. The names and the
prompts to generate them are in `docs/IMAGE_PROMPTS.md`.

## Motion

Animations follow the rossark motion skill (`.claude/skills/rossark-motion-skill`). Its SwiftUI engine is in
`App/Sources/Design/Motion.swift` (clocks, tracks, `wave`, `seg`, `seeded`, the two curves) and the living pieces
are in `App/Sources/Design/LivingViews.swift`, with every number in `MotionTokens`: the streak flame (leans 3° and
stretches 5% on 700 / 1100 ms waves), the breathing couple on Today and the hook (1.6 pt, out of phase), the XP bar
(draws on with ease-out), and the badge reveal on rank-up and challenge-complete screens. Everything freezes at
frame 0 with Reduce Motion and pauses off screen. If the art changes, replace the files
in `ArtSource/` and run `python3 scripts/import_art.py` (optional helper; the imported art is committed).

## Font

All text uses **Outfit** (SIL Open Font License, from google/fonts `ofl/outfit`), bundled as static weights in
`Shared/Fonts/` (Regular, Medium, SemiBold, Bold, ExtraBold) and registered with `UIAppFonts` in both Info.plists.
The licence is in `Shared/Fonts/Outfit-OFL.txt`. If the font can't load, the app falls back to SF Pro Rounded.
