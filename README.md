# Couples 75

iPhone app: a couple does a 75-day challenge together with a bet. Swift + SwiftUI, iOS 17+, Apple frameworks only
(SwiftUI, CloudKit, StoreKit 2, AVFoundation, WidgetKit, UserNotifications, BackgroundTasks). No backend server:
the two phones share facts through CloudKit and each computes everything with the same `RulesEngine`.

- `CLAUDE_CODE_PROMPT.md`: the spec (source of truth)
- `reference/`: design mockups (visual direction only)
- `ArtSource/`: the original character art (already imported into `Shared/Assets.xcassets`)

## Build and run

1. Open `Couples75.xcodeproj` in Xcode 16 or later.
2. Pick the **Couples75** scheme and an iPhone Simulator (e.g. iPhone 16 Pro).
3. Press Run.

In the Simulator the app always starts in **Mock mode** (see below), so everything works without iCloud.
The Run action uses `Config/Products.storekit`, so the subscriptions can be bought in the Simulator with no
App Store Connect setup.

Tests: Product → Test (⌘U), or

```bash
xcodebuild -project Couples75.xcodeproj -scheme Couples75 -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
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

Mock mode keeps both members' facts in one local JSON file and runs the same `RulesEngine`. It is on when:

- running in the Simulator, or
- the DEBUG launch argument `-mock` is enabled (Scheme → Run → Arguments; it's there, unticked), or
- a DEBUG build has no iCloud account.

Release builds on a device without iCloud show "Turn on iCloud to use Couples 75" instead.

**Debug menu** (DEBUG builds): triple-tap the "{A} & {B}" header on Today, or use the "…" menu on Today, or
Profile → Debug menu. It can act as A or B, simulate the partner joining, checking in, reacting, Sus, a pause
request or a tweak proposal, advance to the next day (settles today), jump to Day 74, simulate a miss, lapse or
renew the partner's subscription, and reset everything.

Click-through as A: onboarding → paywall (StoreKit test purchase) → invite → Waiting → "Mock: simulate {B}
joining" (or Debug menu) → Day 1 starts tomorrow → Debug → "Advance to next day".
As B: on the first screen type any 6 letters (e.g. `K7M2QP`) → "Join Maya" → joining flow.

In the Simulator there's no camera: the shutter generates a sample photo with the stamp burned in.

## CloudKit setup

1. Apple Developer → Identifiers: create the App ID `com.dinismagina.couples75` with **iCloud (CloudKit)**,
   **Push Notifications** and **App Groups**; create the widget App ID `com.dinismagina.couples75.widgets` with
   **App Groups**.
2. Create the iCloud container `iCloud.com.dinismagina.couples75` and the App Group
   `group.com.dinismagina.couples75`, and enable them on both App IDs (the container only on the app).
3. In Xcode, select your team on the Couples75 and Widgets targets (Signing & Capabilities). The device
   entitlements are in `Config/App.entitlements` and `Config/Widgets.entitlements` (Simulator builds use none).
4. Run once on a device signed into iCloud (Development environment). CloudKit creates the record types the
   first time the app saves them. To create all of them, go through: A onboarding and pay, B joins with the code,
   a photo check-in, an honour tap, a reaction, a pause request + answer, a tweak + answer, "Paid" on a bet, and
   the Android waitlist.
5. CloudKit Console → your container → **Schema**: check the record types listed in
   `App/Sources/Data/CloudKitSchema.swift`:
   `Couple, Member, RoundConfig, Rule, RuleTweak, TweakAnswer, CheckIn, Reaction, PauseRequest, PauseAnswer,
   BetPaid` (couple zone) and `InviteCode, Waitlist` (public database).
   No queries are used (everything is fetched by zone change tokens or by record name), so no extra indexes
   are needed. In **Security Roles** make sure `InviteCode` is readable by "Authenticated" users (default).
6. **Deploy Schema Changes…** to Production. Do this again whenever a record type gains a field.

How data is shared: A's phone creates a custom zone `Couple-{uuid}` in A's private database with a root
`Couple` record and a zone-wide `CKShare` (public permission read/write, closed once B has joined), plus an
`InviteCode` record (record name = the 6-letter code) in the public database. B accepts the share from the link
or the code, then reads and writes the same zone through the shared database. Silent pushes come from a
`CKRecordZoneSubscription` (A) and a `CKDatabaseSubscription` (B); changes are also fetched on launch, when
returning to the foreground, every few minutes while open, and in a background refresh task.

## App Store Connect: the two subscriptions

1. Create the app with bundle ID `com.dinismagina.couples75`.
2. Subscriptions → create the group **Couples 75** with two auto-renewable subscriptions, **no introductory offers**:
   - `com.dinismagina.couples75.monthly`: 1 month, 3,99 € (Portugal base; let Apple fill other storefronts, e.g. $3.99)
   - `com.dinismagina.couples75.yearly`: 1 year, 29,99 € (e.g. $29.99)
3. Add a display name and description to each, a review screenshot of the paywall, and submit them with the
   first app version.
4. Each person buys their own subscription. The app sends `appAccountToken` = the member's UUID and writes
   `subscribedUntil` / `subscriptionProduct` to their own `Member` record so the partner's phone knows.

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

Couples 75 is not affiliated with 44Seven Media or the 75 HARD program.

## Art

`Shared/Assets.xcassets` contains one image set per PNG in `ArtSource/` (`char_{w1…w6,m1…m6}_{stand,crossed,cheer,stretch,bust}`,
`partner_outline`, `trophy`) and `AppIcon.png` as the single-size app icon. If the art changes, replace the files
in `ArtSource/` and run `python3 scripts/import_art.py` (optional helper; the imported art is committed).
