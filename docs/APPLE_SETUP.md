# Pact: Apple setup, from zero to TestFlight

Everything Apple needs before Pact runs on real iPhones with iCloud, subscriptions and invites.
Do the steps in order. Values to copy are in `code`.

## Identifiers at a glance

| What | Value |
|---|---|
| App bundle ID | `com.tomasbeja.pact` |
| Widgets bundle ID | `com.tomasbeja.pact.widgets` |
| Apple Watch bundle ID | `com.tomasbeja.pact.watchkitapp` |
| Tests bundle ID (never uploaded) | `com.tomasbeja.pact.tests` |
| App Group | `group.com.tomasbeja.pact` |
| iCloud container | `iCloud.com.tomasbeja.pact` |
| Subscription group | `Pact` |
| Yearly (3-day free trial) | `com.tomasbeja.pact.yearly` |
| Yearly (7-day free trial, exit offer) | `com.tomasbeja.pact.yearly7` |
| Monthly | `com.tomasbeja.pact.monthly` |
| URL scheme | `pactapp` |
| Background task | `com.tomasbeja.pact.refresh` (already in Info.plist) |

## 0. On your Mac

1. Pull the branch. The project is now **`Pact.xcodeproj`** (the old `Couples75.xcodeproj` is gone): close Xcode first,
   then open `Pact.xcodeproj` and pick the **Pact** scheme.
2. Delete the old "Couples 75" app from the Simulator and your iPhone (it had another bundle ID, so it would stay
   installed next to Pact).
3. Rename the GitHub repo to `pact` (GitHub → the repo → Settings → General → Repository name). **Required**: the
   app's Terms, Privacy and Support links point to `https://nis7777.github.io/pact/…`. GitHub redirects the old repo
   URL for git. On your Mac: `git remote set-url origin https://github.com/Nis7777/pact.git`.
4. Publish the website (Privacy Policy, Terms of Use, Support): first merge this branch into `main`, then GitHub →
   the repo → Settings → **Pages** → Source **Deploy from a branch** → Branch **main**, folder **/docs** → Save.
   After a minute these work (check each one in a browser):
   - https://nis7777.github.io/pact/ (home)
   - https://nis7777.github.io/pact/privacy.html
   - https://nis7777.github.io/pact/terms.html
   - https://nis7777.github.io/pact/support.html

   The repo must stay **public** for free GitHub Pages. If you ever make it private, move the four pages
   (`docs/index.html`, `privacy.html`, `terms.html`, `support.html`, `style.css`, `icon.png`) to a separate public
   repo and update the four URLs in `Shared/Brand.swift`.

## 1. Apple Developer Program

Join at developer.apple.com/programs ($99/year). As an **individual**, your own name shows as the seller on the
App Store; as an **organization**, the company name (needs a D-U-N-S number, takes a few days).

## 2. Identifiers (easiest: let Xcode create them)

In Xcode, for each of the targets **Pact**, **Widgets** and **PactWatch**: Signing & Capabilities → tick
"Automatically manage signing" → pick your Team. Then on the **Pact** target:

- **iCloud**: tick CloudKit, then under Containers press **+** and add `iCloud.com.tomasbeja.pact` (tick it).
- **App Groups**: press **+** and add `group.com.tomasbeja.pact` (tick it). Do the same on **Widgets**.
- **Push Notifications**, **Background Modes** (Remote notifications, Background fetch) and **HealthKit** are
  already in the project; leave them on.

Xcode registers the App IDs, the container and the group in your developer account by itself.

If you'd rather do it by hand (developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **+**):

1. **App Groups** → `group.com.tomasbeja.pact`
2. **iCloud Containers** → `iCloud.com.tomasbeja.pact`
3. **App IDs** → App:
   - `com.tomasbeja.pact`: tick **App Groups** (configure → the group), **iCloud** (CloudKit, configure → the
     container), **Push Notifications**, **HealthKit**.
   - `com.tomasbeja.pact.widgets`: tick **App Groups** (the same group).
   - `com.tomasbeja.pact.watchkitapp`: no capabilities needed.

## 3. App Store Connect: the app

appstoreconnect.apple.com → **Agreements, Tax, and Banking**: accept the **Paid Apps** agreement and fill in tax and
bank details. Subscriptions (even free test ones in TestFlight) don't load until this is active.

Apps → **+** → New App:
- Platform **iOS**, Name **Pact** (it must be unique on the App Store; if it's taken, use e.g. `Pact: Couples Habits`.
  The name under the icon stays "Pact"), Primary language **English (U.S.)**, Bundle ID `com.tomasbeja.pact`,
  SKU `pact-ios`, User access Full.

App Information: category **Health & Fitness** (secondary **Lifestyle**), **Privacy Policy URL**
`https://nis7777.github.io/pact/privacy.html`. On the version page: **Support URL**
`https://nis7777.github.io/pact/support.html`, **Marketing URL** `https://nis7777.github.io/pact/`, and in the
description's last line: `Terms of Use: https://nis7777.github.io/pact/terms.html` (Apple requires a link to the
terms for subscription apps; alternatively paste the same URL in App Information → License Agreement).

## 4. App Store Connect: the subscriptions

Your app → Monetization → **Subscriptions** → create the group **Pact**, then three auto-renewable subscriptions:

| Reference name | Product ID | Duration | Price | Introductory offer |
|---|---|---|---|---|
| Pact Yearly | `com.tomasbeja.pact.yearly` | 1 year | 39,99 € (Portugal base) | Free trial, 3 days |
| Pact Yearly 7-day trial | `com.tomasbeja.pact.yearly7` | 1 year | 39,99 € | Free trial, 1 week |
| Pact Monthly | `com.tomasbeja.pact.monthly` | 1 month | 7,99 € | none |

For each: a display name and description (e.g. "Pact for both of you, billed yearly"), and a review screenshot of
the paywall. Put the yearly plans above the monthly in the group's ranking. They're submitted with the first
app version; until then they work in TestFlight as free test purchases.

## 5. iCloud: create and deploy the data layout

TestFlight and the App Store use the **Production** iCloud database, which starts empty. Fill the Development one
first, then copy its layout to Production:

1. Run Pact from Xcode on **your iPhone** (signed into iCloud). This uses the Development database.
2. Go through everything once so every record type exists: onboarding and pay (a test purchase), invite, a second
   Apple ID joins with the code, a photo check-in, an honour tap, a reaction, a note and a nudge, a pause request
   and its answer, a habit change and its answer, a bucket list item, start a challenge and give it up, a progress
   pic with sharing on.
3. **Protect the waitlist emails.** CloudKit Console → Schema → **Security Roles** (Development): open the
   `Waitlist` record type and **untick Read for `_world` and `_icloud`** (keep Create for `_icloud`). Otherwise any
   iCloud user's app could read the emails people typed. Leave `InviteCode` as it is (it must be readable so the
   partner can look up the code).
4. icloud.developer.apple.com → CloudKit Console → `iCloud.com.tomasbeja.pact` → **Deploy Schema Changes…** →
   Production. Do this again whenever a new kind of data or field is added.

## 6. TestFlight

1. Xcode → set the destination to **Any iOS Device** → Product → **Archive** → Distribute App → **App Store
   Connect** → Upload.
2. App Store Connect → your app → TestFlight: after processing (10–30 min) the build appears.
3. **You**: Internal Testing → add yourself → install the TestFlight app on your iPhone → Pact.
4. **Your friend**: External Testing → a group → add their email or turn on a **public link**. The first build gets
   a short Apple beta review (usually under a day).
5. Each phone needs its **own Apple ID with iCloud on**. TestFlight purchases are free and renew every few minutes.
   Then: you sign up and pay → Send invite → your friend opens the link (or types the code) → joins free.

Silent pushes (your partner's check-in arriving within seconds) only work on real devices, which TestFlight is.
