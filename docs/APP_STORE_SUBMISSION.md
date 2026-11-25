# App Store submission kit

## Name and subtitle
- **Name:** Pact (working name; check availability in App Store Connect before you commit to it)
- **Subtitle:** Level up as a couple

## Promotional text
Daily habits and challenges you do together. One streak, one rank, both of you. Try The 75 if you dare.

## Description
Pact is couple maxing: the two of you level up together, every day.

Pick what you want to work on, in three areas: Body (gym, diet, sleep), Looks (skin, glow-up, posture) and Mind & money (reading, skills, saving, phone time). Each of you gets 4 to 6 daily habits at your own level. Check them off with a photo taken in the app (recommended) or a quick tap. Your partner cheers you on, approves it, or asks a question.

You share everything: one streak, one XP total and one rank, from Spark to Legend. Habits have no stakes, so a bad day never ends anything.

Want a push? Start a challenge together: the 21-Day Shred, a 30-Day Glow-Up, a No-Spend Week, Read 30 and more. Add a bet if you like: whoever misses more plans the date. Or take on The 75: 75 days, photo proof and a bet, no saves.

Take a daily progress pic if you like. Progress photos are private by default: they stay in your own iCloud, and your partner only sees them if you choose to share. Compare Day 1 with today and play it back as a timelapse.

- One subscription covers you both
- Daily habits for body, looks, mind and money
- Challenges with optional bets, and The 75
- Shared streak, XP, ranks and badges
- Photo proof, reactions and love notes
- Private progress photos with a before/after slider and timelapse
- Widgets, Live Activity and Apple Health. No account to create: it runs on iCloud

## Keywords
couples,habits,glow up,self improvement,challenge,partner,accountability,streak,goals,level up

## Subscriptions
- Yearly, $39.99 (7-day free trial) — covers both partners
- Monthly, $12.99 (yearly saves 74%)

## App Privacy labels
Use the questionnaire answers below: only **Email Address** (optional waitlist) is collected, for App
Functionality, linked, not used for tracking. These match `App/PrivacyInfo.xcprivacy`.

## URLs
- Privacy Policy: https://nis7777.github.io/pact/privacy.html
- Terms of Use (EULA): https://nis7777.github.io/pact/terms.html
- Support: https://nis7777.github.io/pact/support.html
- Marketing: https://nis7777.github.io/pact/

## App Privacy questionnaire (App Store Connect → App Privacy)
Pact's data stays in the user's iCloud and never reaches the developer, except the optional waitlist email.
Apple counts data as "collected" only when the developer (or a third party) can access it, so answer:
- **Contact Info → Email Address**: collected (waitlist only); purpose App Functionality (to tell them
  when Pact works for their partner); not used for tracking.
- Answer "linked to the user" **Yes** (the safe answer).
- **Name: not collected.** The inviter's first name in an open invite is encrypted with the 6-letter code, so only
  the person with the code can read it, not the developer.
- Everything else (photos, health, fitness, user content, identifiers, purchases): not collected by the
  developer. What the partners share passes through the app's CloudKit database end-to-end encrypted with a key
  only the couple has, so the developer can't read it; progress photos are in the user's own private iCloud; Apple
  Health readings never leave the iPhone.
- Tracking: **No**.

## Before you press Submit
- **CloudKit → Production.** In the CloudKit Console, deploy the Development schema to Production. Check that
  `PactItem` has `couple` QUERYABLE and `___modTime` QUERYABLE + SORTABLE (review builds use Production; without
  them every sync fails).
- **Lock down `InviteCode` in Production** (see `docs/pact.ckdb`): remove the QUERYABLE index on `recordName`, and
  set the `_world` read permission to none (`_icloud` read only). Builds from now on name invite records by a hash
  of the code and no longer write the `code` field. Open invites made by older builds still work.
- The legacy record types in `docs/pact.ckdb` (Couple, Member, CheckIn…) aren't used by the app any more. If they
  were never deployed to Production, don't deploy them. If they were, set their `_world` read permission to none.
- **Privacy manifests** are in `App/` and `Widgets/` (`PrivacyInfo.xcprivacy`). After archiving, Xcode →
  Organizer → right-click the archive → Generate Privacy Report should list UserDefaults and Disk space.
- **Push entitlement.** In the archive (Organizer → Show in Finder → app → entitlements), `aps-environment` should
  read `production`. Xcode switches it from `development` when it signs for App Store distribution.
- **Encryption.** `ITSAppUsesNonExemptEncryption` is `false`: the app only uses the encryption built into iOS
  (CryptoKit AES-GCM, HTTPS). If App Store Connect asks, answer that the app uses encryption only through Apple's
  operating system. If you distribute in France, Apple may still ask for the French declaration.
- **iPad.** The app is iPhone-only, but reviewers sometimes run it on an iPad. Tap through onboarding, the paywall
  and Today once in an iPad simulator.
- Never name other programs or companies (e.g. other 75-day challenges) in the app, the description or keywords.
