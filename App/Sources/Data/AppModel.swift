import Foundation
import SwiftUI
import CloudKit
import WidgetKit

enum AppEnvironment {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// The DEBUG launch argument `-mock`.
    static var mockRequested: Bool {
        isDebug && ProcessInfo.processInfo.arguments.contains("-mock")
    }

    /// Mock mode only exists in DEBUG builds (Simulator, `-mock`, tests). A Release build always uses CloudKit.
    static var startsInMock: Bool {
        #if DEBUG
        return isSimulator || mockRequested || isRunningTests
        #else
        return false
        #endif
    }

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// The member's UUID: created on first launch and kept in the iCloud key-value store so it survives reinstalls.
enum Identity {
    private static let key = "memberID"
    private static let mockActingKey = "mockActingMemberID"

    static func memberID(isMock: Bool) -> MemberID {
        let defaults = UserDefaults.standard
        if isMock, let acting = defaults.string(forKey: mockActingKey) { return acting }
        let kvs = NSUbiquitousKeyValueStore.default
        if !isMock, let id = kvs.string(forKey: key) {
            defaults.set(id, forKey: key)
            return id
        }
        if let id = defaults.string(forKey: key) {
            if !isMock { kvs.set(id, forKey: key); kvs.synchronize() }
            return id
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: key)
        if !isMock { kvs.set(id, forKey: key); kvs.synchronize() }
        return id
    }

    /// Mock mode "Act as A / Act as B".
    static func setMockActing(_ id: MemberID?) {
        UserDefaults.standard.set(id, forKey: mockActingKey)
    }

    static func wipe() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: mockActingKey)
        NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

enum RootRoute: Equatable {
    case loading
    case iCloudRequired
    case codeEntry
    case onboardingA
    case joinB
    case partnerLeft
    case main
}

/// Something that was shown once and must not be shown again.
enum SeenEvents {
    private static let key = "seenEvents"

    static func contains(_ id: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(id)
    }

    static func insert(_ ids: [String]) {
        var all = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        all.formUnion(ids)
        UserDefaults.standard.set(Array(all), forKey: key)
    }

    static func wipe() { UserDefaults.standard.removeObject(forKey: key) }
}

enum Prefs {
    static let eveningWarningKey = "eveningWarningOn"
    static let onboardingDoneKey = "onboardingDone"
    static let seenCodeEntryKey = "seenCodeEntry"
    static let draftKey = "onboardingDraft"
    static let joinDraftKey = "joinDraft"
    static let invitePaidAtKey = "invitePaidAt"
    static let shareProgressKey = "shareProgressPhotos"
    static let healthProofKey = "healthProofOn"
    static let liveActivityKey = "liveActivityOn"
    /// The paywall's one-time offer has been shown on this install.
    static let exitOfferShownKey = "exitOfferShown"
    static var exitOfferShown: Bool {
        get { UserDefaults.standard.bool(forKey: exitOfferShownKey) }
        set { UserDefaults.standard.set(newValue, forKey: exitOfferShownKey) }
    }

    /// Notification choices (onboarding "Know when your partner checks in", and Profile). All on by default.
    static let partnerCheckInNotifsKey = "notifyPartnerCheckIns"
    static let dailyReminderKey = "notifyDailyReminder"
    static let weeklyRecapKey = "notifyWeeklyRecap"

    static var partnerCheckInNotifsOn: Bool {
        get { UserDefaults.standard.object(forKey: partnerCheckInNotifsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: partnerCheckInNotifsKey) }
    }
    /// The daily reminder at the wake-up time.
    static var dailyReminderOn: Bool {
        get { UserDefaults.standard.object(forKey: dailyReminderKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: dailyReminderKey) }
    }
    static var weeklyRecapOn: Bool {
        get { UserDefaults.standard.object(forKey: weeklyRecapKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: weeklyRecapKey) }
    }

    /// The evening Lock Screen progress (Live Activity). On by default.
    static var liveActivityOn: Bool {
        get { UserDefaults.standard.object(forKey: liveActivityKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: liveActivityKey) }
    }

    /// "Use Apple Health as proof" (off until the user turns it on and allows access).
    static var healthProofOn: Bool {
        get { UserDefaults.standard.bool(forKey: healthProofKey) }
        set { UserDefaults.standard.set(newValue, forKey: healthProofKey) }
    }

    /// "Share progress pics with partner": off by default (progress photos are private).
    static var shareProgressPhotos: Bool {
        get { UserDefaults.standard.bool(forKey: shareProgressKey) }
        set { UserDefaults.standard.set(newValue, forKey: shareProgressKey) }
    }

    static var eveningWarningOn: Bool {
        get { UserDefaults.standard.object(forKey: eveningWarningKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: eveningWarningKey) }
    }

    static func wipe() {
        for k in [eveningWarningKey, onboardingDoneKey, seenCodeEntryKey, draftKey, joinDraftKey, invitePaidAtKey,
                  shareProgressKey, healthProofKey, liveActivityKey, partnerCheckInNotifsKey, dailyReminderKey,
                  weeklyRecapKey] {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
}

/// Deep-link destinations (notifications, URLs).
enum DeepLink: Equatable {
    case today
    case progress
    case proof
    case checkIn(String)
    case pause
    case tweak
}

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private(set) var store: Store
    let purchases = PurchaseManager()
    /// My private daily progress photos (Part 4).
    let progress = ProgressPhotoStore()
    var presentedMilestone: Int?
    var presentedRecap: WeeklyRecap?
    /// A rule to open on Today (widget tap on a photo rule).
    var openRuleID: String?
    /// Today's Apple Health totals per rule id (only for rules Health can prove).
    var healthReadings: [String: Double] = [:]

    private(set) var facts: Facts
    private(set) var state: EngineState
    private(set) var meID: MemberID
    private(set) var isBootstrapped = false
    private(set) var iCloudAvailable = true
    private(set) var isSyncing = false
    /// Last successful sync with iCloud (shown as "Updated 2 min ago").
    private(set) var lastSyncedAt: Date?
    /// Why the last sync failed, if it did ("offline", "signed out").
    private(set) var syncProblem: SyncProblem?
    enum SyncProblem: Equatable { case offline, signedOut }
    /// Bumps every minute so time-based UI (evening banner, "Tap tonight") refreshes.
    private(set) var clockTick = Date()

    var draft: OnboardingDraft { didSet { draft.persist() } }
    var joinDraft: JoinDraft? { didSet { JoinDraft.persist(joinDraft) } }
    /// B's resolved invite (from a code or a link) before joining.
    var pendingInvite: InviteLookup?
    var invite: InviteInfo?
    var onboardingDone: Bool { didSet { UserDefaults.standard.set(onboardingDone, forKey: Prefs.onboardingDoneKey) } }
    var seenCodeEntry: Bool { didSet { UserDefaults.standard.set(seenCodeEntry, forKey: Prefs.seenCodeEntryKey) } }

    var tab: MainTab = .today
    var deepLink: DeepLink?
    /// A check-in to open in the Proof tab (notification or Today's "New from" row).
    var proofFocus: String?
    var errorMessage: String?
    var toast: String?
    /// A full-screen ivory curtain that fades in and out around "Delete my data" (no hard cut to onboarding).
    var curtain = false
    /// The error from the last failed save (e.g. iCloud full).
    var lastSaveError: StoreError?
    /// Less than 200 MB free on this iPhone: photos might not save (Today shows a heads-up).
    private(set) var deviceStorageLow = false

    func checkDeviceStorage() {
        let low = (LocalCache.freeSpace ?? .max) < 200_000_000
        if low != deviceStorageLow { deviceStorageLow = low }
    }

    /// Why setting up the couple after paying failed (the paywall's Try again screen).
    var lastSetupError: StoreError?
    /// An invite is being made right now (no second attempt in parallel).
    var makingInvite = false

    // Shown once (section 6.1).
    var presentedSave: SaveEvent?
    var presentedRoundEnd: RoundState?
    /// A finished challenge (the celebration screen).
    var presentedDay75: RoundState?
    /// The couple just reached a new rank.
    var presentedRankUp: Rank?
    /// The inviter's "{B} signed your pact" moment, once, when the partner joins.
    var presentedPartnerJoined = false
    /// A streak milestone (Day 7, 30, 50, 90): the celebration, then the share card. Once per phone.
    var presentedPactMilestone: PactMilestone?
    /// Shared XP and rank, recomputed with the state.
    private(set) var xp = CoupleXP(total: 0, today: 0, rank: Ranks.all[0], next: Ranks.all[1])

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastFetch: Date = .distantPast

    init() {
        let mock = AppEnvironment.startsInMock
        #if DEBUG
        let store: Store = mock ? MockStore() : RelayStore()
        let offset = (store as? MockStore)?.clockOffset ?? 0
        #else
        let store: Store = RelayStore()
        let offset: TimeInterval = 0
        #endif
        self.store = store
        let cached = store.cachedFacts()
        facts = cached
        let id = Identity.memberID(isMock: mock)
        meID = id
        state = RulesEngine.state(facts: cached, now: Date().addingTimeInterval(offset))
        draft = OnboardingDraft.load()
        joinDraft = JoinDraft.load()
        onboardingDone = UserDefaults.standard.bool(forKey: Prefs.onboardingDoneKey)
        // A fresh install opens on the hook ("Level up as a couple."); its "My partner invited me" opens the code screen.
        seenCodeEntry = UserDefaults.standard.object(forKey: Prefs.seenCodeEntryKey) as? Bool ?? true
        invite = store.currentInvite
        progress.cloudEnabled = !mock
    }

    var isMock: Bool { store.isMock }
    var pendingUploads: Int { _ = facts; return store.pendingUploads }
    #if DEBUG
    var mockStore: MockStore? { store as? MockStore }
    #endif

    /// "Now", including Mock-mode time travel.
    func now() -> Date {
        #if DEBUG
        return Date().addingTimeInterval(mockStore?.clockOffset ?? 0)
        #else
        return Date()
        #endif
    }

    // MARK: - Derived

    var me: MemberFact? { facts.member(meID) }
    var partner: MemberFact? { facts.members.first { $0.id != meID } }
    var isOwner: Bool { me?.role == .a }
    var memberA: MemberFact? { facts.memberA }
    var memberB: MemberFact? { facts.memberB }

    var nameA: String { memberA?.name ?? (draft.myName.isEmpty ? "You" : draft.myName) }
    var nameB: String {
        memberB?.name ?? facts.couple?.invitedName ?? (draft.partnerName.isEmpty ? "Partner" : draft.partnerName)
    }
    var myName: String { me?.name ?? draft.myName }
    var partnerName: String { me?.role == .b ? nameA : nameB }

    func name(of id: MemberID) -> String {
        facts.member(id)?.name ?? (id == PendingPartner.id ? nameB : "Partner")
    }

    var sceneA: SceneCharacter { SceneCharacter(avatar: memberA?.avatar ?? draft.avatar, name: nameA) }
    /// nil until B has built their avatar: draw the dashed partner outline instead.
    var sceneB: SceneCharacter? { memberB.map { SceneCharacter(avatar: $0.avatar, name: $0.name) } }
    /// B as built so far: their member record, or the avatar B made on A's phone ("together now"); nil = outline.
    var sceneBBuilt: SceneCharacter? {
        sceneB ?? (facts.couple?.invitedAvatar ?? draft.partnerAvatar).map { SceneCharacter(avatar: $0, name: nameB) }
    }
    /// Couple-level subscription: one subscription covers both partners.
    var coupleActive: Bool { state.coupleActive }
    var payerName: String { state.payerID.map { name(of: $0) } ?? nameA }
    /// The run is frozen because nobody's subscription is active.
    var subscriptionLapsed: Bool { !state.coupleActive && currentRound?.status == .active }
    /// Whether I'm (or was) the one paying.
    var iAmPayer: Bool { state.payerID == nil ? isOwner : state.payerID == meID }
    /// A's avatar while onboarding.
    var draftScene: SceneCharacter { SceneCharacter(avatar: draft.avatar, name: draft.myName) }
    /// B shown only once fully joined.
    var sceneBJoined: SceneCharacter? { memberB?.joinedAt == nil ? nil : sceneB }

    var currentRound: RoundState? { state.currentRound }
    var myToday: MemberToday? { state.today[meID] }
    var partnerToday: MemberToday? { partner.flatMap { state.today[$0.id] } }
    var todayA: MemberToday? { memberA.flatMap { state.today[$0.id] } }
    var todayB: MemberToday? { memberB.flatMap { state.today[$0.id] } }
    var currentBet: String {
        let round = currentRound?.number ?? 1
        return RulesEngine.betText(for: round, facts: facts, at: now())
    }
    var currentMode: RoundMode {
        currentRound?.mode ?? RulesEngine.config(for: currentRound?.number ?? 1, facts: facts)?.mode ?? .standard
    }

    func rules(for memberID: MemberID) -> [RuleFact] {
        RulesEngine.effectiveRules(for: memberID, round: currentRound?.number ?? 1, facts: facts, at: now())
    }

    var route: RootRoute {
        if !isBootstrapped { return .loading }
        if !iCloudAvailable && !isMock { return .iCloudRequired }
        if let me {
            if facts.members.contains(where: { $0.leftAt != nil }) { return .partnerLeft }
            if me.role == .b && me.joinedAt == nil { return .joinB }
            if me.role == .b && !onboardingDone { return .joinB }
            if me.role == .a && !onboardingDone { return .onboardingA }
            return .main
        }
        if pendingInvite != nil || joinDraft != nil { return .joinB }
        if facts.couple != nil, facts.memberA != nil, facts.memberB == nil, isMock == false { return .joinB }
        if !seenCodeEntry && !draft.started { return .codeEntry }
        return .onboardingA
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !isBootstrapped else { return }
        if !isMock {
            let status = (try? await CKContainer(identifier: Brand.cloudKitContainer).accountStatus()) ?? .couldNotDetermine
            if status != .available {
                #if DEBUG
                // No iCloud on a DEBUG build: run in Mock mode so everything can be clicked through.
                switchToMock()
                #else
                iCloudAvailable = false
                #endif
            }
        }
        purchases.onEntitlementChange = { [weak self] ent in
            Task { @MainActor in await self?.entitlementChanged(ent) }
        }
        purchases.start()
        isBootstrapped = true
        checkDeviceStorage()
        recompute()
        await refresh()
        startTimer()
        if !isMock { await store.registerForChanges() }
        await progress.refresh()
    }

    func recheckICloud() async {
        let status = (try? await CKContainer(identifier: Brand.cloudKitContainer).accountStatus()) ?? .couldNotDetermine
        iCloudAvailable = status == .available
        if iCloudAvailable { await refresh() }
    }

    #if DEBUG
    /// SwiftUI previews: load facts and act as `me` without touching iCloud.
    func loadPreview(facts newFacts: Facts, me: MemberID, onboardingDone done: Bool = true) {
        meID = me
        isBootstrapped = true
        onboardingDone = done
        facts = newFacts
        state = RulesEngine.state(facts: newFacts, now: now())
    }
    #endif

    /// Re-reads my member id (after "Act as", reset or delete).
    func meIDReset() {
        meID = Identity.memberID(isMock: isMock)
    }

    #if DEBUG
    private func switchToMock() {
        let mock = MockStore()
        store = mock
        meID = Identity.memberID(isMock: true)
        facts = mock.cachedFacts()
        invite = mock.currentInvite
        progress.cloudEnabled = false
    }
    #endif

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.clockTick = Date()
                self.checkDeviceStorage()
                self.recompute()
                if Date().timeIntervalSince(self.lastFetch) > 300 { await self.refresh() }
            }
        }
    }

    /// Fetch changes, recompute, update widgets/notifications. Called on launch, foreground, push and refresh.
    func refresh() async {
        guard isBootstrapped, iCloudAvailable || isMock else { return }
        isSyncing = true
        defer { isSyncing = false }
        lastFetch = Date()
        let oldFacts = facts
        let oldState = state
        do {
            let new = try await store.fetchChanges()
            apply(new)
            // After a reinstall or on a new phone, the couple comes back from iCloud: no onboarding again.
            if !onboardingDone, let me, me.joinedAt != nil, !draft.started, joinDraft == nil, pendingInvite == nil {
                onboardingDone = true
            }
            lastSyncedAt = Date()
            syncProblem = nil
        } catch let e as StoreError {
            if case .notAuthenticated = e {
                iCloudAvailable = AppEnvironment.isDebug ? iCloudAvailable : false
                syncProblem = .signedOut
            } else {
                syncProblem = .offline
            }
            recompute()
        } catch {
            syncProblem = .offline
            recompute()
        }
        // Light haptic when a partner's approval of one of my check-ins arrives.
        if oldFacts.couple != nil {
            let seen = Set(oldFacts.reactions.map(\.id))
            let mine = Set(facts.checkIns.filter { $0.memberID == meID }.map(\.id))
            if facts.reactions.contains(where: { !seen.contains($0.id) && $0.kind == .approve
                                                && $0.memberID != meID && mine.contains($0.checkInID) }) {
                Haptics.light()
            }
        }
        await refreshHealth()
        await saveQueuedWidgetCheckIns()
        await NotificationManager.shared.postPartnerEvents(oldFacts: oldFacts, newFacts: facts,
                                                          oldState: oldState, newState: state,
                                                          meID: meID, isInitial: oldFacts.couple == nil)
        await afterStateChange()
    }

    /// Replace facts and recompute.
    func apply(_ newFacts: Facts) {
        facts = newFacts
        recompute()
    }

    func recompute() {
        state = RulesEngine.state(facts: facts, now: now())
        xp = XP.compute(state: state, facts: facts, now: now())
        evaluatePresentations()
        evaluateRankUp()
        evaluateMilestone()
        evaluatePactMilestone()
        evaluateRecap()
        evaluateBadges()
    }

    func afterStateChange() async {
        updateTimeZoneIfNeeded()
        await closeInviteIfPartnerJoined()
        // Setup stopped before the invite was made (e.g. iCloud was full): keep trying quietly.
        if isOwner, invite == nil, facts.couple != nil, memberB?.joinedAt == nil {
            await ensureInvite(quiet: true)
        }
        writeWidgetSnapshot()
        await NotificationManager.shared.reschedule(model: self)
        await LiveActivityManager.shared.update(model: self)
    }

    /// Save facts, then recompute and refresh dependants.
    @discardableResult
    func save(_ records: [FactRecord]) async -> Bool {
        lastSaveError = nil
        do {
            let new = try await store.save(records)
            apply(new)
            await afterStateChange()
            return true
        } catch let e as StoreError {
            apply(store.cachedFacts())
            lastSaveError = e
            errorMessage = e.errorDescription
            return false
        } catch {
            apply(store.cachedFacts())
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func updateTimeZoneIfNeeded() {
        guard var m = me, m.timeZone != TimeZone.current.identifier, m.leftAt == nil else { return }
        m.timeZone = TimeZone.current.identifier
        Task { await save([.member(m)]) }
    }

    /// A: once B has joined, nobody else can use the old link or code.
    private func closeInviteIfPartnerJoined() async {
        guard isOwner, facts.memberB?.joinedAt != nil, invite != nil else { return }
        await store.closeInvite()
        invite = nil
    }

    // MARK: - Shown-once screens

    private func evaluatePresentations() {
        guard route == .main else { return }
        guard presentedSave == nil, presentedRoundEnd == nil, presentedDay75 == nil, !presentedPartnerJoined else { return }
        // The partner just joined (within the last 3 days, so it never pops up long after): the card moment.
        if isOwner, let b = memberB, let joined = b.joinedAt, let c = facts.couple {
            let key = "partner-joined-\(c.id)"
            if !SeenEvents.contains(key) {
                SeenEvents.insert([key])
                if now().timeIntervalSince(joined) < 3 * 86_400 {
                    presentedPartnerJoined = true
                    Haptics.success()
                    return
                }
            }
        }
        if let round = state.lastFinishedRound {
            let endID = "roundend-\(round.number)"
            let d75ID = "day75-\(round.number)"
            if round.status == .completed, !round.mode.isMaintenance, !SeenEvents.contains(d75ID) {
                SeenEvents.insert(state.allSaveEvents.map { $0.id })
                presentedDay75 = round
                Haptics.success()
                return
            }
            if round.status == .failed || (round.status == .completed && !round.owes.isEmpty), !SeenEvents.contains(endID) {
                SeenEvents.insert(state.allSaveEvents.map { $0.id })
                presentedRoundEnd = round
                return
            }
        }
        let unseen = state.allSaveEvents.filter { !SeenEvents.contains($0.id) }
        if let latest = unseen.last {
            SeenEvents.insert(unseen.map { $0.id })
            presentedSave = latest
            Haptics.warning()
        }
    }

    func dismissPartnerJoined() {
        presentedPartnerJoined = false
    }

    func dismissDay75() {
        guard let r = presentedDay75 else { return }
        SeenEvents.insert(["day75-\(r.number)"])
        presentedDay75 = nil
        if !r.owes.isEmpty && !SeenEvents.contains("roundend-\(r.number)") {
            presentedRoundEnd = r
        } else {
            SeenEvents.insert(["roundend-\(r.number)"])
        }
    }

    func dismissRoundEnd() {
        if let r = presentedRoundEnd { SeenEvents.insert(["roundend-\(r.number)"]) }
        presentedRoundEnd = nil
    }

    // MARK: - Widgets

    /// A challenge's length; 0 on daily habits (no end).
    private var widgetRoundLength: Int {
        guard let r = currentRound, !r.mode.isMaintenance else { return 0 }
        return r.length
    }

    func writeWidgetSnapshot() {
        guard let a = memberA else { return }
        let ta = todayA, tb = todayB
        let day = myToday?.dayNumber ?? ta?.dayNumber
        var status: String?
        switch state.phase {
        case .waitingForPartner, .warmup: status = "Warm-up"
        case .betweenRounds: status = "Starts tomorrow"
        case .partnerLeft: status = nil
        default:
            if state.isFrozen { status = "Paused" } else if myToday?.isPaused == true { status = "Paused" }
        }
        let snap = WidgetSnapshot(nameA: a.name, nameB: memberB?.name ?? nameB,
                                  characterA: a.characterID, characterB: memberB?.characterID ?? "",
                                  dayNumber: day, roundLength: widgetRoundLength,
                                  doneA: ta?.isComplete ?? false, doneB: tb?.isComplete ?? false,
                                  streak: state.streak, statusLine: status, updatedAt: Date(),
                                  avatarA: a.avatar, avatarB: memberB?.avatar)
        var full = snap
        full.myName = me?.name ?? ""
        full.partnerName = partnerName
        full.myRules = (myToday?.items ?? []).map {
            SnapshotRule(id: $0.rule.id, title: $0.rule.title, isHonour: $0.rule.type == .honour, done: $0.isChecked)
        }
        full.partnerLeft = partnerToday?.remaining ?? 0
        full.rankTitle = xp.rank.title
        full.rankSymbol = xp.rank.icon
        full.signedA = facts.couple?.createdAt
        full.signedB = memberB?.joinedAt
        full.partnerTotal = partnerToday?.items.count ?? 0
        full.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
