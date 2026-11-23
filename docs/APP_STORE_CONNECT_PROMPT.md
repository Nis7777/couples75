# Prompt: set up Pact in App Store Connect

Paste everything below the line into Claude with browser access on your Mac (Claude in Chrome, or the Claude desktop
app with computer use), signed in to your Apple Developer account. Or follow it yourself, step by step.

---

You are helping me (Tomás Beja) set up my iPhone app **Pact** in the Apple Developer portal and App Store Connect.
I'm signed in to developer.apple.com and appstoreconnect.apple.com in this browser. Do the steps in order, using
exactly the values given. Rules:

- Never accept agreements, enter tax or bank details, or pay for anything: stop and ask me to do those myself.
- Never press **Submit for Review** or **Add for Review**. Stop when everything is filled in and tell me what's left.
- If a value is rejected (for example the app name is taken), stop and ask me instead of inventing one.
- If a page looks different from what's described here, describe what you see and ask me.
- At the end, give me a checklist of what you did and what's still missing.

## Step 1. Identifiers (developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → +)

Skip any that already exist.

1. **App Groups** → Description `Pact`, Identifier `group.com.tomasbeja.pact`.
2. **iCloud Containers** → Description `Pact`, Identifier `iCloud.com.tomasbeja.pact`.
3. **App IDs → App**:
   - Description `Pact`, Bundle ID (Explicit) `com.tomasbeja.pact`. Capabilities: **App Groups** (then Configure →
     `group.com.tomasbeja.pact`), **iCloud** (choose "Include CloudKit support", then Configure →
     `iCloud.com.tomasbeja.pact`), **Push Notifications**, **HealthKit**. Save.
   - Description `Pact Widgets`, Bundle ID `com.tomasbeja.pact.widgets`. Capabilities: **App Groups** (Configure →
     `group.com.tomasbeja.pact`). Save.
   - Description `Pact Watch`, Bundle ID `com.tomasbeja.pact.watchkitapp`. No capabilities. Save.

## Step 2. Check the agreements (App Store Connect → Business)

Check whether the **Paid Apps** agreement is **Active**. If it isn't, stop and tell me: I'll accept it and fill in
tax and banking myself. Subscriptions don't work until it's active.

Also check **Business → Digital Services Act / Trader status** (needed to sell in the EU). Don't fill it in: tell me
it's there. An app that sells subscriptions counts as a "trader", and Apple shows the trader's address, phone and
email on the EU App Store, so I'll decide what to enter.

## Step 3. Create the app (App Store Connect → Apps → + → New App)

- Platforms: **iOS**
- Name: **Pact** (if it's taken, stop and ask me; my backup is `Pact: Couples Habits`)
- Primary Language: **English (U.S.)**
- Bundle ID: `com.tomasbeja.pact`
- SKU: `pact-ios`
- User Access: **Full Access**

## Step 4. App Information

- Subtitle: `Level up as a couple`
- Category: Primary **Health & Fitness**, Secondary **Lifestyle**
- Privacy Policy URL: `https://nis7777.github.io/pact/privacy.html`
- Content Rights: the app does **not** contain, show or access third-party content.
- Age Rating: answer every question honestly from these facts:
  - No violence, mature or suggestive themes, profanity, horror, drugs, gambling (bets in the app are informal
    agreements between two partners, no money involved), contests or medical treatment information.
  - Partners can send each other short notes and comments and see each other's proof photos (only between the two
    of them; no public sharing, no strangers).
  - Health and wellness topics: yes (habits like workouts, sleep and diet).
  - No unrestricted web access, no advertising.
- License Agreement: keep **Apple's standard EULA**.

## Step 5. Pricing and Availability

- Price: **Free** (the app is free to download; it uses subscriptions).
- Availability: all countries and regions.

## Step 6. Subscriptions (Monetization → Subscriptions)

Create a subscription group: Reference Name `Pact`, then group localization English (U.S.), Display Name `Pact`.

Create three auto-renewable subscriptions in that group:

| Reference Name | Product ID | Duration | Price (base country Portugal) | Display Name | Description |
|---|---|---|---|---|---|
| Pact Yearly | `com.tomasbeja.pact.yearly` | 1 Year | 39,99 € | `Pact Yearly` | `Pact for both of you, billed yearly` |
| Pact Yearly 7-day trial | `com.tomasbeja.pact.yearly7` | 1 Year | 39,99 € | `Pact Yearly` | `Pact for both of you, 7-day free trial` |
| Pact Monthly | `com.tomasbeja.pact.monthly` | 1 Month | 7,99 € | `Pact Monthly` | `Pact for both of you, billed monthly` |

- For prices: set **Portugal** as the base country, pick the 39,99 € / 7,99 € price points, and let Apple calculate
  all other countries.
- Introductory offers: **Pact Yearly** → Free Trial, **3 days**, all countries, starting now, no end date.
  **Pact Yearly 7-day trial** → Free Trial, **1 week**, same settings. **Pact Monthly** → none.
- Subscription ranking inside the group: Pact Yearly first, Pact Yearly 7-day trial second, Pact Monthly last.
- Each subscription asks for a **Review Screenshot**: leave it empty and tell me (I'll upload a screenshot of the
  paywall).

## Step 7. App Privacy (App Privacy → Get Started)

Pact stores user data in the user's own iCloud with Apple; the developer can't access it. Only two things reach the
developer. Answer:

- Do you collect data? **Yes**.
- **Contact Info → Name**: used for **App Functionality**; linked to the user **Yes**; tracking **No**.
  (The inviter's first name is in the invite-code record while an invite is open.)
- **Contact Info → Email Address**: used for **App Functionality**; linked to the user **Yes**; tracking **No**.
  (Optional Android waitlist.)
- Nothing else is collected (no health, photos, user content, identifiers, usage data, diagnostics or purchases by
  the developer). Tracking: **No**.
- Publish the privacy answers.

## Step 8. The iOS version page (1.0)

- Promotional Text:
  `Daily habits and challenges you do together. One streak, one rank, both of you. Try The 75 if you dare.`
- Description (paste exactly, keeping the blank lines):

```
Pact is couple maxing: the two of you level up together, every day.

Pick what you want to work on, in three areas: Body (gym, diet, sleep), Looks (skin, glow-up, posture) and Mind & money (reading, skills, saving, phone time). Each of you gets 4 to 6 daily habits at your own level. Check them off with a live photo for your partner (recommended) or a quick tap. Your partner cheers you on, or calls it sus.

You share everything: one streak, one XP total and one rank, from Spark to Legend. Habits have no stakes, so a bad day never ends anything.

Want a push? Start a challenge together: the 21-Day Shred, a 30-Day Glow-Up, a No-Spend Week, Read 30 and more. Add a bet if you like: whoever misses more plans the date. Or take on The 75: 75 days, photo proof and a bet, no saves.

Take a daily progress pic if you like. Progress photos are private by default: they stay in your own iCloud, and your partner only sees them if you choose to share. Compare Day 1 with today and play it back as a timelapse.

- One subscription covers you both
- Daily habits for body, looks, mind and money
- Challenges with optional bets, and The 75
- Shared streak, XP, ranks and badges
- Live photo proof, reactions and love notes
- Private progress photos with a before/after slider and timelapse
- Widgets, Live Activity, Apple Watch and Apple Health. No account to create: it runs on iCloud

Subscriptions: Pact Yearly and Pact Monthly renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in Settings > [your name] > Subscriptions. One subscription covers both partners.

Terms of Use: https://nis7777.github.io/pact/terms.html
Privacy Policy: https://nis7777.github.io/pact/privacy.html

The 75 challenge in Pact is not affiliated with 44Seven Media or the 75 HARD program.
```

- Keywords: `couples,habits,glow up,self improvement,challenge,partner,accountability,streak,goals,level up`
- Support URL: `https://nis7777.github.io/pact/support.html`
- Marketing URL: `https://nis7777.github.io/pact/`
- Version: `1.0`
- Copyright: `2026 Tomás Beja`
- Screenshots: leave empty and tell me (I'll upload them from the Simulator).
- Build: leave empty (I'll upload it from Xcode).
- In-App Purchases and Subscriptions section: add the three subscriptions to this version.
- App Review Information:
  - Sign-in required: **No** (the app uses the device's iCloud account; no login).
  - Contact: First name `Tomás`, Last name `Beja`, Email `pact.couples.app@gmail.com`, Phone: ask me.
  - Notes (paste exactly):

```
Pact is for couples: two people on two iPhones, each signed in to iCloud with their own Apple ID.

To review:
1. Open Pact, tap "Let's start" and go through onboarding (any names; tap "No, I'll invite them").
2. Subscribe on the paywall with a sandbox account. One subscription covers both partners.
3. The app shows an invite link and a 6-letter code. On a second iPhone (another Apple ID, iCloud on), open Pact, tap "My partner invited me" and enter the code. The partner joins free and picks their own habits.
4. Day 1 starts the day after the partner joins. On Today: check in with a live photo or an honour tap; the partner sees it in Proof and can react. Challenges tab: start a challenge (it starts the next day).

The app has no servers: all data is stored in the users' own iCloud (CloudKit) and shared between the two partners through iCloud sharing. Apple Health is optional and read-only (Profile > Use Apple Health as proof).

Contact: pact.couples.app@gmail.com
```

## Step 9. Stop

Do not submit. Tell me exactly what's still empty (screenshots, build, review screenshots for the subscriptions,
phone number, agreements) and anything you couldn't do.
