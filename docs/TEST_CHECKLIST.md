# Couples 75: feature test checklist

Run in the Simulator (Mock mode, no iCloud needed). The **Debug menu** is a triple-tap on the "{A} & {B}"
header on Today (or Profile → Debug menu): use it to act as the partner, simulate check-ins, advance days,
jump to Day 74, simulate a lapse, and reset.

Start with Product → Clean Build Folder (⇧⌘K), then Run on an iPhone 16/17 Pro and an iPhone SE.

## 1. Launch and onboarding
- [ ] Launch: peach screen with the app icon, then the logo springs up, both avatars slide in and meet (light haptic), fade into the app. No white/blank flash.
- [ ] Step counter reads "of 17" on every counted step and never jumps.
- [ ] Single-answer steps advance only after a tap; dragging across an option doesn't select it; swiping right from the left edge goes back.
- [ ] "How hard should it be?": Continue is visible at the bottom on iPhone SE.
- [ ] "Anything personal?": type "Learn to speak chinese", tap Add → pill "Learn Chinese".
- [ ] Plan review shows "Learn Chinese: 15 min" (10 on Gentle, 30 on Hard). With 7+ rules: "Swap / Remove" until 6, "Set the stakes" disabled until then.
- [ ] Paywall: × opens the exit sheet; closing goes back to the plan, never into the app.

## 2. Today
- [ ] Sync line under the header ("Mock mode · saved on this phone" in the Simulator).
- [ ] "Day X of 75" bar with percentage under the week dots.
- [ ] Rule titles wrap to 2 lines, never cut off.
- [ ] "Check in ›" opens "Which rule?" (medium/large sheet with grabber), never the camera directly.
- [ ] Checking off a rule: checkmark pops, "x left" counts down, success haptic.
- [ ] "Nudge {partner}" (only while they have rules left) and "Send a note". As the partner (Debug), the note shows as a banner.
- [ ] "Take today's progress pic": camera with the Day 1 photo as a ghost (from the 2nd photo on); one per day, retake replaces.

## 3. Proof, Progress, Profile
- [ ] Proof: the coral pill slides between "From {partner}" and "Mine"; empty states show both avatars.
- [ ] Progress: Our week button, Transformation (before/after slider, timeline, Play, Save / Share video), 75-day grid with legend, Badges, Bucket list.
- [ ] Profile: Use Apple Health as proof, Evening progress on Lock Screen, Share progress pics with partner (off by default), Our rules → Reminders and Request a change.
- [ ] Delete my data fades to onboarding (no hard cut).

## 4. Rounds and stakes (Debug: Jump to Day 74, Advance to next day)
- [ ] Day 25 / 50 / 75 milestone screen (needs at least one progress pic).
- [ ] Day 75 screen: "Start round 2" and "Keep it up with maintenance mode"; nobody owes → pick a bucket list reward.
- [ ] Maintenance: Today shows "Keep it up", "Maintenance · no stakes", "New 75 ›"; misses never end it.
- [ ] Streak shield: after 7 complete days a shield shows in the streak pill; a missed day keeps the streak.
- [ ] Monday: the weekly recap shows once; "Share our week" works.

## 5. Outside the app
- [ ] Widgets: "My rules today" (honour rules tappable after 18:00, photo rules open the camera), Lock Screen widgets.
- [ ] Live Activity after 17:00 with rules left (real device or Simulator with Live Activities on).
- [ ] Apple Watch (paired Watch simulator): day, rules, partner; honour rule tap after 18:00.
- [ ] Apple Health (real device): steps/water/exercise/mindful progress under the rule; auto check-off when met.

## 6. Unit tests
- [ ] Product → Test (⌘U): RulesEngine, plan consistency, Health parsing, maintenance, shields, recap.
