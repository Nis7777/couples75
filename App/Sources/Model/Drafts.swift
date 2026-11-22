import Foundation

/// Person A's onboarding answers (section 3.1), persisted so a relaunch resumes where they left off.
struct OnboardingDraft: Codable, Equatable {
    enum Step: String, Codable, CaseIterable {
        case hook, character, names, partnerIPhone, togetherNow, handOff, partnerAvatar, partnerFitness, partnerWake,
             handBack, together, longDistance, goals, personal, fitness, wakeUp, quit, mirror, level, building, planReveal, stakes
        // Without a step counter (the paywall has its own pages: outcome, trial, plans):
        case paywall, invite, notifications, android
    }

    var step: Step = .hook
    var myName = ""
    var partnerName = ""
    var avatar = Avatar(characterID: "w1")
    var characterID: String { avatar.characterID }
    /// Filled in when B is with A during onboarding ("Hand the phone to {B}").
    var partnerAvatar: Avatar?
    var partnerFitness: FitnessLevel?
    var partnerWakeTime: String?
    /// "Is {B} with you right now?"
    var partnerWithYou: Bool?
    var partnerOnIPhone: Bool?
    var together: String?
    var longDistance: Bool?
    var goals: [Goal] = []
    /// "Anything personal you want to work on?" (skippable).
    var personalGoals: [PersonalGoal] = []
    var personalOther = ""
    /// Goals typed into "Something else?", each with its cleaned name. Every one becomes a daily rule.
    var customGoals: [CustomGoal] = []
    /// Ideas for the typed goals (on-device model or keyword match), offered under "Suggested for you".
    var personalIdeas: [RuleIdea] = []
    /// THE plan: generated once when the plan is built (Building step) and stored. Everything else reads it.
    var planRules: [PlanRuleRow] = []
    /// Rules changed on the plan reveal ("Change"). They are saved as proposals the partner must approve.
    var ruleChanges: [DraftRuleChange] = []
    var fitness: FitnessLevel?
    var wakeTime = "07:30"
    var quitFrequency: Double = 1
    var level: Level = .couples75
    var bet: BetOption = .date
    var customBet = ""

    var started: Bool { step != .hook }

    var betText: String {
        bet == .custom ? String(customBet.trimmingCharacters(in: .whitespaces).prefix(BetOption.customMaxLength)) : bet.title
    }

    /// Steps that show "Step X of N" (paywall, invite, notifications and Android are outside the count).
    static let countedSteps: [Step] = [.hook, .character, .names, .partnerIPhone, .togetherNow,
                                       .together, .longDistance, .goals, .personal,
                                       .fitness, .wakeUp, .quit, .mirror, .level, .building, .planReveal,
                                       .stakes]

    /// The counted steps. Branch-only steps (handing the phone to the partner and B's answers there,
    /// the Android waitlist) never count and show no counter, so the total never jumps mid-flow.
    var shownSteps: [Step] { Self.countedSteps }
    var stepNumber: Int? { Self.countedSteps.firstIndex(of: step).map { $0 + 1 } }
    var stepTotal: Int { Self.countedSteps.count }

    /// Generates the plan from the answers. Called once, when the plan is built; going back and changing
    /// answers builds it again (and clears changes made on the old plan).
    mutating func generatePlan() {
        planRules = PlanGenerator.rows(goals: goals, personal: personalGoals, custom: customGoals, level: level,
                                       intensityA: myIntensity, intensityB: partnerIntensity)
        ruleChanges = []
    }

    var ruleKeys: [String] { planRules.compactMap { $0.a.libraryKey } }

    /// Rows for the plan reveal: reason, A's title, B's title; changed rules show as pending.
    var planRows: [PlanRow] {
        planRules.enumerated().map { i, r in
            let a = change(at: i, forPartner: false)
            let b = change(at: i, forPartner: true)
            return PlanRow(index: i, reason: r.reason, left: a?.title ?? r.a.title, right: b?.title ?? r.b.title,
                           pending: a != nil || b != nil)
        }
    }

    /// More than 6 rules: the plan review asks to swap or remove rules before "Set the stakes".
    var tooManyRules: Int { max(0, planRules.count - Brand.maxRules) }

    func change(at index: Int, forPartner: Bool) -> RuleIdea? {
        guard planRules.indices.contains(index) else { return nil }
        let id = planRules[index].id
        return ruleChanges.last { $0.rowID == id && $0.forPartner == forPartner }?.idea
    }

    /// Photo rules one side would end up with if `idea` replaced row `index` (or row `removing` were removed).
    func photoCount(forPartner: Bool, replacing index: Int? = nil, with idea: RuleIdea? = nil,
                    removing: Int? = nil) -> Int {
        planRules.enumerated().filter { i, r in
            if i == removing { return false }
            if i == index, let idea { return idea.type == .photo }
            if let c = change(at: i, forPartner: forPartner) { return c.type == .photo }
            return (forPartner ? r.b : r.a).type == .photo
        }.count
    }

    /// Removing keeps at least 2 photo rules each and never goes below 4 rules.
    func canRemove(_ index: Int) -> Bool {
        planRules.count > Brand.minRules
            && photoCount(forPartner: false, removing: index) >= Brand.minPhotoRules
            && photoCount(forPartner: true, removing: index) >= Brand.minPhotoRules
    }

    mutating func removeRow(_ index: Int) {
        guard planRules.indices.contains(index), canRemove(index) else { return }
        let id = planRules[index].id
        planRules.remove(at: index)
        ruleChanges.removeAll { $0.rowID == id }
    }

    /// "Swap" while trimming: replaces the row for both partners directly (each at their own intensity).
    mutating func swapRow(_ index: Int, idea: RuleIdea) {
        guard planRules.indices.contains(index) else { return }
        var row = planRules[index]
        row.reason = "You picked this"
        if let key = idea.libraryKey {
            row.a = RuleIdea.library(key, intensity: myIntensity) ?? idea
            row.b = RuleIdea.library(key, intensity: partnerIntensity) ?? idea
        } else {
            row.a = idea
            row.b = idea
        }
        planRules[index] = row
        ruleChanges.removeAll { $0.rowID == row.id }
    }

    mutating func setChange(index: Int, forPartner: Bool, idea: RuleIdea?) {
        guard planRules.indices.contains(index) else { return }
        let id = planRules[index].id
        ruleChanges.removeAll { $0.rowID == id && $0.forPartner == forPartner }
        if let idea { ruleChanges.append(DraftRuleChange(rowID: id, forPartner: forPartner, idea: idea)) }
    }

    /// Suggestions for the Change sheet: the typed-goal ideas, the personal picks, then the other goals' rules.
    func suggestions(intensity: Intensity, extra: [RuleIdea]) -> [RuleIdea] {
        var keys = personalGoals.map(\.ruleKey) + goals.flatMap(\.ruleKeys)
        keys = keys.filter { k in !ruleKeys.contains(k) }
        var out = extra
        for k in keys { if let i = RuleIdea.library(k, intensity: intensity), !out.contains(i) { out.append(i) } }
        return Array(out.prefix(6))
    }

    /// The rule facts written when the couple is created: the stored rows, positions 1…n, for A and for B
    /// (B's placeholder id), plus a proposal for every changed row (the partner approves it later).
    func makeRuleFacts(memberA: MemberID, now: Date) -> (rules: [RuleFact], proposals: [RuleProposalFact]) {
        let rules = PlanGenerator.ruleFacts(rows: planRules, partner: false, memberID: memberA, now: now)
            + PlanGenerator.ruleFacts(rows: planRules, partner: true, memberID: PendingPartner.id, now: now)
        var proposals: [RuleProposalFact] = []
        for (i, row) in planRules.enumerated() {
            for forPartner in [false, true] {
                guard let c = ruleChanges.last(where: { $0.rowID == row.id && $0.forPartner == forPartner }) else { continue }
                let forMember = forPartner ? PendingPartner.id : memberA
                let rule = c.idea.ruleFact(memberID: forMember, position: i + 1, round: 1, now: now)
                proposals.append(RuleProposalFact(id: .newID(), proposedBy: memberA, forMember: forMember,
                                                  ruleJSON: rule, effectiveFrom: nil, createdAt: now))
            }
        }
        return (rules, proposals)
    }

    var myIntensity: Intensity { level.adjust((fitness ?? .somewhatActive).intensity) }
    /// B's rules use Gentle intensity until B answers their own fitness question.
    var partnerIntensity: Intensity {
        guard let f = partnerFitness else { return .gentle }
        return level.adjust(f.intensity)
    }

    static func load() -> OnboardingDraft {
        guard let data = UserDefaults.standard.data(forKey: Prefs.draftKey),
              let d = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else { return OnboardingDraft() }
        return d
    }

    func persist() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Prefs.draftKey)
        }
    }
}

/// One rule changed on the plan reveal, for A (forPartner false) or B.
struct DraftRuleChange: Codable, Equatable {
    var rowID: String
    var forPartner: Bool
    var idea: RuleIdea
}

/// Person B's joining answers (section 3.5).
struct JoinDraft: Codable, Equatable {
    enum Step: String, Codable {
        case invited, character, fitness, wakeUp, tweak, imIn, notifications
    }

    var step: Step = .invited
    var code: String = ""
    var avatar = Avatar(characterID: "m1")
    var characterID: String { avatar.characterID }
    var fitness: FitnessLevel?
    var wakeTime = "07:30"
    var swappedPosition: Int?
    var swapKey: String?
    var changeBet = false
    var bet: BetOption = .date
    var customBet = ""

    var betText: String {
        bet == .custom ? String(customBet.trimmingCharacters(in: .whitespaces).prefix(BetOption.customMaxLength)) : bet.title
    }

    /// True when B already built the avatar and answered on A's phone: B just reviews and signs.
    var prebuilt = false

    static func prefilled(from couple: CoupleFact?, code: String) -> JoinDraft {
        var d = JoinDraft(code: code)
        if let a = couple?.invitedAvatar {
            d.avatar = a
            d.fitness = couple?.invitedFitness
            d.wakeTime = couple?.invitedWakeTime ?? "07:30"
            d.prebuilt = true
        }
        return d
    }

    static func load() -> JoinDraft? {
        guard let data = UserDefaults.standard.data(forKey: Prefs.joinDraftKey) else { return nil }
        return try? JSONDecoder().decode(JoinDraft.self, from: data)
    }

    static func persist(_ draft: JoinDraft?) {
        if let draft, let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: Prefs.joinDraftKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Prefs.joinDraftKey)
        }
    }
}

/// "HH:mm" helpers.
enum ClockTime {
    static func date(from hhmm: String, on day: Date = Date()) -> Date {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        let h = parts.first ?? 7, m = parts.count > 1 ? parts[1] : 30
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: day) ?? day
    }

    static func string(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 7, c.minute ?? 30)
    }

    static func components(_ hhmm: String) -> DateComponents {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        var c = DateComponents()
        c.hour = parts.first ?? 7
        c.minute = parts.count > 1 ? parts[1] : 0
        return c
    }

    /// "07:30" shown in the user's locale style.
    static func display(_ hhmm: String) -> String {
        date(from: hhmm).formatted(date: .omitted, time: .shortened)
    }
}
