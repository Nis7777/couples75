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

    static var eveningWarningOn: Bool {
        get { UserDefaults.standard.object(forKey: eveningWarningKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: eveningWarningKey) }
    }

    static func wipe() {
        for k in [eveningWarningKey, onboardingDoneKey, seenCodeEntryKey, draftKey, joinDraftKey, invitePaidAtKey] {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
}

/// Deep-link destinations (notifications, URLs).
enum DeepLink: Equatable {
    case today
    case progress
    case checkIn(String)
    case pause
    case tweak
}

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private(set) var store: Store
    let purchases = PurchaseManager()

    private(set) var facts: Facts
    private(set) var state: EngineState
    private(set) var meID: MemberID
    private(set) var isBootstrapped = false
    private(set) var iCloudAvailable = true
    private(set) var isSyncing = false
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
    var errorMessage: String?
    var toast: String?

    // Shown once (section 6.1).
    var presentedSave: SaveEvent?
    var presentedRoundEnd: RoundState?
    var presentedDay75: RoundState?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastFetch: Date = .distantPast

    init() {
        let mock = AppEnvironment.isSimulator || AppEnvironment.mockRequested || AppEnvironment.isRunningTests
        let store: Store = mock ? MockStore() : CloudKitStore()
        self.store = store
        let cached = store.cachedFacts()
        facts = cached
        let id = Identity.memberID(isMock: mock)
        meID = id
        let offset = (store as? MockStore)?.clockOffset ?? 0
        state = RulesEngine.state(facts: cached, now: Date().addingTimeInterval(offset))
        draft = OnboardingDraft.load()
        joinDraft = JoinDraft.load()
        onboardingDone = UserDefaults.standard.bool(forKey: Prefs.onboardingDoneKey)
        seenCodeEntry = UserDefaults.standard.bool(forKey: Prefs.seenCodeEntryKey)
        invite = store.currentInvite
    }

    var isMock: Bool { store.isMock }
    var mockStore: MockStore? { store as? MockStore }

    /// "Now", including Mock-mode time travel.
    func now() -> Date { Date().addingTimeInterval(mockStore?.clockOffset ?? 0) }

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

    var sceneA: SceneCharacter { SceneCharacter(characterID: memberA?.characterID ?? draft.characterID, name: nameA) }
    /// nil until B has picked a character.
    var sceneB: SceneCharacter? { memberB.map { SceneCharacter(characterID: $0.characterID, name: $0.name) } }
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
                if AppEnvironment.isDebug {
                    // No iCloud on a DEBUG build: run in Mock mode so everything can be clicked through.
                    switchToMock()
                } else {
                    iCloudAvailable = false
                }
            }
        }
        purchases.onEntitlementChange = { [weak self] ent in
            Task { @MainActor in await self?.entitlementChanged(ent) }
        }
        purchases.start()
        isBootstrapped = true
        recompute()
        await refresh()
        startTimer()
        if !isMock { await store.registerForChanges() }
    }

    func recheckICloud() async {
        let status = (try? await CKContainer(identifier: Brand.cloudKitContainer).accountStatus()) ?? .couldNotDetermine
        iCloudAvailable = status == .available
        if iCloudAvailable { await refresh() }
    }

    /// Re-reads my member id (after "Act as", reset or delete).
    func meIDReset() {
        meID = Identity.memberID(isMock: isMock)
    }

    private func switchToMock() {
        let mock = MockStore()
        store = mock
        meID = Identity.memberID(isMock: true)
        facts = mock.cachedFacts()
        invite = mock.currentInvite
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.clockTick = Date()
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
        } catch let e as StoreError {
            if case .notAuthenticated = e { iCloudAvailable = AppEnvironment.isDebug ? iCloudAvailable : false }
            recompute()
        } catch {
            recompute()
        }
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
        evaluatePresentations()
    }

    func afterStateChange() async {
        updateTimeZoneIfNeeded()
        await closeInviteIfPartnerJoined()
        writeWidgetSnapshot()
        await NotificationManager.shared.reschedule(model: self)
    }

    /// Save facts, then recompute and refresh dependants.
    @discardableResult
    func save(_ records: [FactRecord]) async -> Bool {
        do {
            let new = try await store.save(records)
            apply(new)
            await afterStateChange()
            return true
        } catch let e as StoreError {
            apply(store.cachedFacts())
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
        guard presentedSave == nil, presentedRoundEnd == nil, presentedDay75 == nil else { return }
        if let round = state.lastFinishedRound {
            let endID = "roundend-\(round.number)"
            let d75ID = "day75-\(round.number)"
            if round.status == .completed, !SeenEvents.contains(d75ID) {
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

    func writeWidgetSnapshot() {
        guard let a = memberA else { return }
        let ta = todayA, tb = todayB
        let day = myToday?.dayNumber ?? ta?.dayNumber
        var status: String?
        switch state.phase {
        case .waitingForPartner, .warmup: status = "Warm-up"
        case .betweenRounds: status = "Next round soon"
        case .partnerLeft: status = nil
        default:
            if state.isFrozen { status = "Paused" } else if myToday?.isPaused == true { status = "Paused" }
        }
        let snap = WidgetSnapshot(nameA: a.name, nameB: memberB?.name ?? nameB,
                                  characterA: a.characterID, characterB: memberB?.characterID ?? "",
                                  dayNumber: day, roundLength: Brand.roundLengthDays,
                                  doneA: ta?.isComplete ?? false, doneB: tb?.isComplete ?? false,
                                  streak: state.streak, statusLine: status, updatedAt: Date())
        snap.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
