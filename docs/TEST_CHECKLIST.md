# Pact: feature test checklist

Run in the Simulator (Mock mode, no iCloud needed). The **Debug menu** is a triple-tap on the "{A} & {B}"
header on Today (or Profile → Debug menu): use it to act as the partner, simulate check-ins, advance days,
jump to the last day, simulate a lapse, and reset.

Start with Product → Clean Build Folder (⇧⌘K), then Run on an iPhone 16/17 Pro and an iPhone SE.
Old onboarding progress from the 75-only version is discarded (start from the hook).

## 1. Launch and onboarding
- [ ] Hook: "Level up as a couple." with the one-line pitch; the couple breathes gently (try Reduce Motion: still).
- [ ] Step counter reads "of 16" on every counted step and never jumps (the stakes step is gone).
- [ ] Goals: three groups (Body, Looks, Mind & money) with icons; Continue needs 2 picks.
- [ ] "How big should your habits be?": Gentle / Steady (Most popular) / Hard mode.
- [ ] "Anything personal?": type "Learn to speak chinese", tap Add → pill "Learn Chinese".
- [ ] Plan review: "{A} & {B}'s daily habits", the "No stakes on habits" card, button "Looks good" → paywall.
- [ ] Paywall: "Become the best version of you. Together." with three value rows. × closes back to the plan.

## 2. Today on daily habits
- [ ] Hero label "Daily habits", centre "TODAY 0 / N" (both your habits), the ring fills as either of you checks in.
- [ ] Streak pill: the flame flickers (leans and stretches); grey and still at 0.
- [ ] Rank card (Spark, Level 1, XP, gold bar that grows after a check-in).
- [ ] "Daily habits · no stakes"; "Want a push? Start a challenge together" opens the Challenges tab.
- [ ] A photo habit → camera → "No photo? Check it off" → sheet → "Yes, I did" checks it off and closes the camera.
- [ ] "Which rule?" shows "Photo (recommended)".

## 3. Challenges tab
- [ ] Rank card, "On daily habits", The 75 signature card (living flame), then Body / Looks / Mind & money rows.
- [ ] Before the partner joins: a challenge's "Start tomorrow" is disabled with the reason.
- [ ] Debug → simulate partner joining → advance a day. Open "No-Spend Week": rules "on top of your habits",
      bet toggle off by default. Start → toast, Today banner "No-Spend Week starts tomorrow. Today's habits still count."
- [ ] Today's habits can still be checked in that day. Cancel from the Challenges tab → "Challenge cancelled.", no bet.
- [ ] Start again, advance a day: Today shows "DAY 1 / 7", the challenge title on the hero, "Day 1 of 7" bar,
      "Today's rules" (habits plus the challenge rule), and the streak carries on.
- [ ] The 75: bet section required ("Part of The 75"), rules replace the habits, no "No photo?" link in the camera.
- [ ] Give up mid-challenge with a bet → round-end screen "You gave up on Day N", you owe the bet; back to habits.
- [ ] Debug → Jump to the last day → advance: confetti, the badge reveal, "We finished {challenge}", +XP,
      "Pick our next challenge" / "Back to our daily habits". Progress shows it under "Challenges finished".

## 4. Ranks and badges
- [ ] Earning enough XP (several complete days or a finished challenge) shows "You're {Rank} now" once.
- [ ] Badges: Challenger, All-rounder, The 75, Habit machine (100 days) alongside the others.

## 5. Proof, Progress, Profile
- [ ] Proof: the coral pill slides between "From {partner}" and "Mine"; empty states show both avatars.
- [ ] Progress: grid titled "Daily habits" (latest 48 days) or the challenge name (its length);
      stats Best streak / Challenges / Couple XP; stakes card only during a challenge with a bet.
- [ ] Profile: Rank row, "Now" row (habits, the challenge and its day, or "starts tomorrow"), "Our habits".
- [ ] Delete my data fades to onboarding (no hard cut).

## 6. Outside the app
- [ ] Widgets: on habits the ring shows today's done state for you two and the text "🔥 {streak} · habits";
      during a challenge "Day X/N". Honour rules tappable after 18:00.
- [ ] Live Activity after 17:00 with rules left (real device or Simulator with Live Activities on).
- [ ] Apple Watch (paired Watch simulator): day, rules, partner; honour rule tap after 18:00.
- [ ] Apple Health (real device): steps/water/exercise/mindful progress under the rule; auto check-off when met.
- [ ] Notifications: finishing a challenge, a challenge ending early, saves used.

## 7. Custom art
- [ ] Drop any PNG from `docs/IMAGE_PROMPTS.md` into `Shared/Assets.xcassets` with its exact name (e.g. `rank_spark`,
      `tab_challenges`, `challenge_the75`); it replaces the SF Symbol with no code change.

## 8. Unit tests
- [ ] Product → Test (⌘U): RulesEngine, ChallengeTests (habits, start tomorrow, finish, give up, cancel, no bet,
      streak carry-over, ranks), plan consistency, Health parsing, maintenance, shields, recap.
