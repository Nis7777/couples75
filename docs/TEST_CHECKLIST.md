# Pact: feature test checklist

Run in the Simulator (Mock mode, no iCloud needed). The **Debug menu** is in Today's "…" menu on the header card
(or Profile → Debug menu): use it to act as the partner, simulate check-ins, advance days,
jump to the last day, simulate a lapse, and reset.

Start with Product → Clean Build Folder (⇧⌘K), then Run on an iPhone 16/17 Pro and an iPhone SE.
Old onboarding progress from the 75-only version is discarded (start from the hook).

## 1. Launch and onboarding
- [ ] Hook: "Level up as a couple." with the one-line pitch; the couple breathes gently (try Reduce Motion: still).
- [ ] Step counter reads "of 21" on every counted step and never jumps.
- [ ] After the names: "This is your pact." The card rises in, both names type themselves on, "Made {today}" stamps
      on with a light haptic, then the empty grid ("Your first 30 days", 0 done) fades in. Your partner is the dashed
      outline. The card number ("Pact #0427") is the same if you go back and come forward again, and after a relaunch.
- [ ] Goals: three groups (Body, Looks, Mind & money) with icons; Continue needs 2 picks.
- [ ] "How big should your habits be?": Gentle / Steady (Most popular) / Hard mode.
- [ ] "Anything personal?": type "Learn to speak chinese", tap Add → pill "Learn Chinese".
- [ ] Plan review: "{A} & {B}'s daily habits", the "No stakes on habits" card, button "Looks good" → paywall.
- [ ] Your habits come only from your answers. "Yes, we're together": the partner builds their avatar, answers
      fitness and wake-up, then picks THEIR OWN goals on your phone; the plan review shows "Your daily habits" plus
      a "{partner}'s daily habits" card from their answers. "No, I'll invite them": that card says they pick their own.
- [ ] Partner joining (code on a second Simulator/user): Invited → avatar → fitness → wake-up → goals → "Your daily
      habits" (from their goals, at their level): edit, delete (min 4, 2 photo), add (max 6), no approval from you.
- [ ] Mirror: "You picked {goals} for you and {partner}", the line for how long you've been together, the reframe card,
      three tiny wins from your goals. Scrolls on iPhone SE.
- [ ] Plan review → "Sign your pact" (hold the fingerprint 1.5 s) → your card: the signature writes on, the seal
      stamps, then a coral "SIGNED" stamp slams on (three haptics) → couple score.
- [ ] Couple score: busts, Level 1 · Spark, and "Your couple map": the hexagon (Body, Mind, Rest, Fuel, Connection,
      Discipline) draws in from the centre. Your shape is caramel; your partner's is sage if they answered on your
      phone ("Yes, we're together"), otherwise a dashed sage outline and "Waiting for {partner}'s answers". Tap the
      chart: whole numbers appear; tap again: they go. "See your score in 90 days" grows the shapes and counts the
      level up for 1.5 s with haptic ticks (Forge, level 5); the button turns into Continue. Reduce Motion: jumps.
- [ ] Your next 90 days: today's date highlighted + the next 6; edit a habit (pencil or tap the row), delete one
      (blocked below 4 habits or 2 photo habits, with the reason), "+ Add a habit" (up to 6). FAQ rows expand.
- [ ] Notifications: three toggles on; Continue shows the iOS prompt (not if all are off). No second ask after the invite.
- [ ] Paywall: Monthly first ("$12.99 / month for 2 people", "$6.50 / person / month"), then Yearly preselected
      with a check ("$39.99 / year for 2 people", "$1.67 / person / month", "3-day free trial first", "SAVE 74%").
      × goes back to "Your next 90 days".
- [ ] After paying and the invite, Today shows exactly the habits from "Your next 90 days" (including edits).
- [ ] Profile: Partner checked in / Daily reminder / Weekly recap switches match what you chose.

## 2. Today
- [ ] iPhone 16 Pro, no scrolling needed for: the header card, the week strip, both habit cards and the main button,
      also with 6 + 6 habits and a banner showing (try: Debug → Simulate pause request).
      iPhone SE: those are reachable with a short scroll; only "More today" is far below.
- [ ] Header card (espresso, about a quarter of the screen): "{A} & {B}" and "Pact #… · Daily pact" on the left;
      rank badge, flame and streak number on the right, then "…" (Life happens, Debug). Both busts either side of a
      small ring reading "0/8 today" that fills as either of you checks in (1/8, 2/8 …). One line under it:
      warm-up "Warm-up · Day 1 starts tomorrow" (or "…the day after {B} joins"), then "Day 12", and in a challenge
      "Day 3 of 21 · 1 save left". No "PACT" label, no orange blob, no "4 left" pills, no warm-up banner.
      Tap the card (not the "…"): the full Pact Card in a sheet.
- [ ] Banners never push the screen down: at most one shows, as a one-line pill in the header card where the
      status line is (highest first: pause request to answer, change to review, subscription ended, not sent, a
      love note, "n habits left" after 21:00, your pause request waiting). Tap it: pause / change open their answer
      sheets; the rest open a detail sheet (a note: "Send one back" / "Clear note"). Debug → Simulate pause request.
- [ ] Week strip: completed days are caramel with a tick, today is ringed and labelled "Today", future days empty.
      No "0-day streak" line.
- [ ] "Today": two cards side by side, the same height and both full contrast (the partner's is not greyed out).
      Labels stay on one line ("Skincare AM+PM", "Workout 45m", "Socials ≤30m"), long ones end in "…".
      At most 5 rows each: with 6 habits, unfinished ones come first and "+1 more" opens the card in place
      ("Show less" closes it). Each row is at least 36 pt tall. The sync line ("Updated just now") sits right of "Today".
      Your card: tap a habit to check in. Partner's card: ○ pending (tap shows the full name), ✓ done, a coral dot
      and "Tap to approve" when they checked in and you haven't reacted (tap opens it in Proof). A heart next to the
      partner's name opens "A note for {B}"; a nudge icon appears next to it when they're behind.
- [ ] Button: "Practise check-in ›" on the warm-up day, "Check in ›" after; when your habits are all done it turns
      into "Done for today ✓" (secondary) with "Waiting on {B}" under it until they're done too. Both done: no line.
- [ ] "More today": compact rows "Progress pic · optional, only you see it ›" (opens the camera) and "Want a push?
      Start a challenge ›" (Challenges tab); "New from {B} · … React" when there's something to react to; during a
      challenge "Stakes: …". The last row clears the tab bar; nothing peeks out under the bar.
- [ ] No "Daily habits · no stakes / Score" pill. During a challenge, Progress shows "Misses so far: {A} n · {B} n".
- [ ] Release build (Archive / TestFlight): no "Mock mode" text anywhere.
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

## 4. Ranks, badges and milestones
- [ ] Earning enough XP (several complete days or a finished challenge) shows "You're {Rank} now" once, with
      "Share our card" (opens the share preview) and "Keep going".
- [ ] Debug menu → Milestones → "Simulate day 30": confetti, "Day 30" stamps on with a haptic, "30 days in a row,
      together", "See our card" / "Not now". See our card → "Share the moment": Story 9:16 / Square 1:1 switch, the
      preview (wordmark, "Day 30", "{A} & {B} · of our pact", your Pact Card with its grid, the couple map on the
      story, "Pact: Couples Habits · on the App Store" at the bottom). "Include a proof photo" (only shown once a
      proof photo is on this phone) is off by default and adds a tilted polaroid. Share opens the share sheet with the
      image and "Day 30 of our pact 🤝". Save to Photos asks for photo access only now, then shows "Saved to Photos ✓".
- [ ] Debug menu → "Simulate rank-up": "You're {next rank} now" → Share our card → the rank card.
- [ ] Real streaks: at 7, 30, 50 and 90 days in a row the celebration shows once on each phone (never again on that
      phone, also after a relaunch). A finished challenge's screen has "Share our card" with the challenge's card.
- [ ] Progress → "Your couple map": Now / Day 1 switch (the shapes draw in again), tap for numbers, "Updated daily".
      Before your partner has habits: their dashed outline and "Waiting for {partner}'s answers".
- [ ] Progress → "Milestones": "Your first one is a 7-day streak…" at first; later a row of tiles (streak days,
      ranks, finished challenges). Tap one: the share preview without the celebration.
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

## 9. Two real iPhones (TestFlight)
- [ ] A creates the couple and pays: the invite code shows on the invite screen and on Waiting, with a full iCloud too
      (Pact doesn't use the users' iCloud storage any more).
- [ ] B: "My partner invited me" → the code → joins and sees A's name and character. A wrong code says so.
- [ ] A photo check-in on one phone appears on the other within seconds (or after pulling down), with the photo.
- [ ] Reactions, notes and nudges arrive both ways.
- [ ] Delete Pact on one phone and reinstall it: the couple, habits and streak come back (old photos don't).
- [ ] Profile → Delete my data on one phone: the other phone shows that their partner left.
- [ ] Paywall × → exit offer: "Try monthly" and "7-day free trial" buy that plan; "Back to the plan" returns to
      "Your next 90 days" with everything kept. In airplane mode, a plan button says it couldn't reach the App Store.
- [ ] Close the app right after paying and reopen it: it continues to the invite, without charging again.
- [ ] The invite picture (Send invite) shows the 6-letter code big. "Copy invite code" copies the code and link.
- [ ] iPhone almost full (under 200 MB free): Today shows "Your iPhone is almost full · photos may not save".
      Completely full: a photo check-in shows "Couldn't check in · Your iPhone is full…" on the camera.
- [ ] Each of you uses your own Apple ID (two phones on the same Apple ID would look like the same person).
- [ ] B leaves (Profile → Leave): A sees "{B} left the couple" and, as the payer, "Start over with a new partner"
      goes through onboarding without paying again. The leave sheet tells the payer leaving doesn't cancel.
- [ ] A (payer) leaves: B sees "{A} left"; starting over asks B for their own subscription.
- [ ] Delete my data in airplane mode: it says to connect first and deletes nothing; online it deletes and the
      partner sees that you left.
- [ ] Fresh install opens on "Level up as a couple."; "My partner invited me" there opens the code screen.
- [ ] A is still on "Send {B} their invite" when B joins: within seconds it shows "{B} is joining", then moves on to
      "{B} accepted your invite" (the card with their signature). Same from the Waiting screen.
- [ ] Front camera proof photo: the saved photo looks like the preview (mirrored, like a selfie); the stamp text reads
      normally.
