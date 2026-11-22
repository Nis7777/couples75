import Foundation

/// Person A's onboarding answers (section 3.1), persisted so a relaunch resumes where they left off.
struct OnboardingDraft: Codable, Equatable {
    enum Step: String, Codable, CaseIterable {
        case hook, character, names, partnerIPhone, togetherNow, handOff, partnerAvatar, partnerFitness, partnerWake,
             handBack, together, longDistance, goals, fitness, wakeUp, quit, mirror, level, building, planReveal, stakes
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
                                       .together, .longDistance, .goals,
                                       .fitness, .wakeUp, .quit, .mirror, .level, .building, .planReveal,
                                       .stakes]

    /// The steps actually shown: B's own steps only count when B is with A ("Hand the phone to {B}").
    var shownSteps: [Step] {
        var steps = Self.countedSteps
        if partnerWithYou == true, let i = steps.firstIndex(of: .togetherNow) {
            steps.insert(contentsOf: [.partnerAvatar, .partnerFitness, .partnerWake], at: i + 1)
        }
        return steps
    }
    var stepNumber: Int? { shownSteps.firstIndex(of: step).map { $0 + 1 } }
    var stepTotal: Int { shownSteps.count }

    /// The plan follows the quiz (each rule knows why it's there).
    var plan: [PlannedRule] { PlanGenerator.plan(goals: goals) }
    var ruleKeys: [String] { plan.map { $0.key } }

    /// Rows for the plan reveal: reason, A's title, B's title.
    var planRows: [PlanRow] {
        plan.enumerated().map { i, p in
            PlanRow(index: i, reason: p.reason,
                    left: RuleLibrary.rule(p.key)?.title(for: myIntensity) ?? p.key,
                    right: RuleLibrary.rule(p.key)?.title(for: partnerIntensity) ?? p.key)
        }
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
