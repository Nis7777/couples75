# Prompt: build, set up iCloud, and upload Pact to TestFlight (not released)

Paste everything below the line into the Claude on the Mac (Cowork), signed in to Xcode, the Apple Developer
site and App Store Connect.

---

You're on my Mac, helping me get my iPhone app **Pact** onto TestFlight. It must NOT go live on the App Store yet.
Do the steps in order.

Rules:
- Never press **Submit for Review** or **Add for Review**. Never accept agreements or enter tax, bank or payment details.
- Never delete or rename anything in CloudKit, and never use "Reset Environment".
- Don't change any code. If something fails or looks different from what's described here, stop and tell me
  exactly what you see.
- At the end, give me a checklist of what you did and what's still missing.

## Step 1. Get the latest code and build it

1. In Terminal, find my clone of the repo (a folder named `pact` with `Pact.xcodeproj` inside; ask me if you
   can't find it). Run `git checkout main && git pull`. If there's no clone, run
   `git clone https://github.com/Nis7777/pact.git ~/pact`.
2. Open `Pact.xcodeproj` in Xcode. Pick the **Pact** scheme and an **iPhone 16 Pro** simulator. Run Product →
   Clean Build Folder (⇧⌘K), then Product → Build (⌘B).
3. **If the build fails, stop.** Open the Issue navigator and give me every error: file, line and message, word for
   word. Don't try to fix them.
4. If it builds, run Product → Test (⌘U). Tell me the name and message of any test that fails, then carry on.

## Step 2. Create the data layout in iCloud and deploy it to Production

TestFlight and the App Store use the **Production** iCloud database. It only accepts data whose record types and
fields were created in Development and then deployed. An **empty Development schema is expected**: the app has
never run against real iCloud (the Simulator always uses Mock mode). The container ID is correct.

**Fastest: import the schema file.** The repo has the whole layout in `docs/pact.ckdb`.
1. In CloudKit Console (signed in), open the account menu → **Manage Tokens** (CloudKit Management Tokens) → **+**,
   name it `cktool`, create it, and copy the token.
2. In Terminal, run `xcrun cktool save-token --type management` and paste the token when it asks.
3. From the repo folder, run:
   `xcrun cktool import-schema --team-id MS2AB6H9ZG --container-id iCloud.com.tomasbeja.pact --environment development --file docs/pact.ckdb`
   Never run `reset-schema`, and never use `--environment production`.
4. In the Console (Development → Record Types) check that all 19 record types below are there, with their fields.
   Then go to step 3 below (the security roles are already in the file: just check them) and step 4 (deploy).

If the import fails, give me the exact error, then create the record types by hand instead:

1. Go to icloud.developer.apple.com → CloudKit Console → container `iCloud.com.tomasbeja.pact` → **Schema** →
   **Record Types**, in the **Development** environment.
2. Make sure every record type below exists, with these fields and types. Create any record type that's missing,
   and add any missing field. Leave everything that's already there as it is: don't remove, rename or change a
   field's type. If an existing field has a different type from the one here, stop and tell me.
   The types map to the Console like this: String = String, Int(64) = Int(64), Date/Time = Date/Time, Asset = Asset.
   No indexes are needed.

| Record type | Fields |
|---|---|
| Couple | createdAt (Date/Time), ownerMemberID (String), title (String), invitedName (String), invitedAvatar (String), invitedFitness (String), invitedWakeTime (String), together (String), longDistance (Int(64)), level (String) |
| Member | role (String), name (String), characterID (String), timeZone (String), wakeTime (String), fitnessLevel (String), joinedAt (Date/Time), subscribedUntil (Date/Time), subscriptionProduct (String), subscriptionPeriods (String), leftAt (Date/Time), skinColor (String), hairColor (String), jacketColor (String) |
| RoundConfig | fromRound (Int(64)), mode (String), betText (String), rewardText (String), createdBy (String), createdAt (Date/Time), length (Int(64)), saves (Int(64)), challengeID (String), proofRequired (Int(64)), quitBy (String) |
| Rule | memberID (String), fromRound (Int(64)), position (Int(64)), libraryKey (String), title (String), type (String), createdAt (Date/Time), photoHint (String) |
| RuleProposal | proposedBy (String), forMember (String), ruleJSON (String), effectiveFrom (String), createdAt (Date/Time) |
| RuleAnswer | proposalID (String), accepted (Int(64)), answeredAt (Date/Time) |
| RuleTweak | proposedBy (String), payload (String), createdAt (Date/Time) |
| TweakAnswer | tweakID (String), accepted (Int(64)), answeredAt (Date/Time) |
| CheckIn | memberID (String), ruleID (String), capturedAt (Date/Time), localDate (String), stampText (String), hasPhoto (Int(64)), isWarmup (Int(64)), honourFallback (Int(64)), healthProof (String), photo (Asset) |
| Reaction | checkInID (String), memberID (String), kind (String), emoji (String), comment (String), createdAt (Date/Time) |
| PauseRequest | requestedBy (String), startDate (String), days (Int(64)), reason (String), createdAt (Date/Time) |
| PauseAnswer | pauseID (String), accepted (Int(64)), answeredAt (Date/Time) |
| BetPaid | roundNumber (Int(64)), memberID (String), paidAt (Date/Time) |
| ProgressShare | memberID (String), localDate (String), dayNumber (Int(64)), capturedAt (Date/Time), photo (Asset) |
| ProgressPhoto | localDate (String), dayNumber (Int(64)), capturedAt (Date/Time), photo (Asset) |
| Nudge | from (String), to (String), kind (String), text (String), createdAt (Date/Time) |
| BucketItem | text (String), addedBy (String), createdAt (Date/Time), doneAt (Date/Time), rewardRound (Int(64)) |
| InviteCode | code (String), shareURL (String), inviterName (String), createdAt (Date/Time) |
| Waitlist | email (String), createdAt (Date/Time) |

3. **Schema → Security Roles** (still Development) → **Waitlist**: untick **Read** for `_world` and for `_icloud`,
   and keep **Create** for `_icloud`. Save. Leave **InviteCode** as it is: the partner needs to read it to join.
4. Click **Deploy Schema Changes…** (to Production). Read the list of changes it shows, confirm, and tell me what
   was deployed.

## Step 3. Archive and upload to App Store Connect (this does not release it)

1. Go to App Store Connect → Apps → **Pact** → **TestFlight** and note the highest build number already uploaded for
   version 1.0 (0 if there are none).
2. In Xcode: select the **Pact** project → **Pact** target → **General** → Identity. Version: `1.0`. Build: that
   number + 1. The widgets and Watch targets must have the same Version and Build: set them too if they show
   their own.
3. Set the run destination to **Any iOS Device (arm64)**, then Product → **Archive**.
4. When the Organizer opens: **Distribute App** → **App Store Connect** → **Upload**, keeping the default options
   (automatic signing). If signing fails, stop and show me the message.
5. Wait for the build to finish processing in TestFlight (10–30 minutes). If it asks about encryption, the app
   declares none (`ITSAppUsesNonExemptEncryption` is NO), so pick "None of the algorithms mentioned above".

## Step 4. TestFlight for both of us

1. TestFlight → **Internal Testing**: if there's no group, create one called `Us`. Add me and my partner as
   testers. Internal testers must already be users in this App Store Connect team: if one of us isn't, tell me
   instead of inviting anyone.
2. Add the new build to that group, and turn on automatic distribution of new builds to it.

## Step 5. Make sure it can't go live by itself

1. App Store → **iOS App 1.0** → **App Store Version Release**: choose **Manually release this version**, then Save.
2. Do not submit it.

## Step 6. Report

Tell me:
- the build number you uploaded, and any errors or failing tests
- what was deployed to the Production schema
- what's still empty on the 1.0 version page (screenshots, a Review Screenshot for each of the 3 subscriptions,
  the phone number under App Review Information, the EU trader status)
