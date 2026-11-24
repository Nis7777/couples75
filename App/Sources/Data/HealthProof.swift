import Foundation
import HealthKit

/// What a rule needs from Apple Health, parsed from its library key and title
/// ("Steps: 8k", "Water: 3L", "Workout: 45 min", "Walk: 20 min", "Meditate: 15 min").
enum HealthMetric: Equatable {
    case steps(Double)
    case exerciseMinutes(Double)
    case waterLiters(Double)
    case mindfulMinutes(Double)

    var target: Double {
        switch self {
        case .steps(let t), .exerciseMinutes(let t), .waterLiters(let t), .mindfulMinutes(let t): return t
        }
    }

    private static func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }

    /// "6,120 / 8,000 steps".
    func progressText(_ value: Double) -> String {
        let f = Self.fmt
        switch self {
        case .steps(let t): return "\(f(value.rounded(.down))) / \(f(t)) steps"
        case .exerciseMinutes(let t): return "\(Int(value)) / \(Int(t)) min exercise"
        case .waterLiters(let t): return "\(f((value * 10).rounded(.down) / 10)) / \(f(t)) L water"
        case .mindfulMinutes(let t): return "\(Int(value)) / \(Int(t)) mindful min"
        }
    }

    /// The proof line saved with the check-in and sent to the partner. It says only THAT Health confirmed the habit,
    /// never the reading itself: Apple doesn't allow health readings to be stored in iCloud. (The number is shown
    /// on this iPhone only, as progress on Today.)
    func proofText(_ value: Double) -> String { "Checked with Apple Health" }

    static func number(in title: String, before suffix: String) -> Double? {
        let pattern = "([0-9]+(?:[.,][0-9]+)?)\\s*" + NSRegularExpression.escapedPattern(for: suffix)
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let r = Range(m.range(at: 1), in: title) else { return nil }
        return Double(title[r].replacingOccurrences(of: ",", with: "."))
    }

    static func metric(for rule: RuleFact) -> HealthMetric? {
        let t = rule.title
        switch rule.libraryKey {
        case "steps": return number(in: t, before: "k").map { .steps($0 * 1000) }
        case "water": return number(in: t, before: "L").map { .waterLiters($0) }
        case "workout":
            guard let mins = number(in: t, before: "min") else { return nil }
            return .exerciseMinutes(t.contains("2 ×") || t.lowercased().contains("two") ? mins * 2 : mins)
        case "meditate": return number(in: t, before: "min").map { .mindfulMinutes($0) }
        default: return nil
        }
    }
}

/// Reads today's totals from Apple Health (read-only; nothing is written to Health).
@MainActor
final class HealthProof {
    static let shared = HealthProof()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var s = Set<HKObjectType>()
        if let t = HKObjectType.quantityType(forIdentifier: .stepCount) { s.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { s.insert(t) }
        if let t = HKObjectType.quantityType(forIdentifier: .dietaryWater) { s.insert(t) }
        if let t = HKObjectType.categoryType(forIdentifier: .mindfulSession) { s.insert(t) }
        return s
    }

    /// Shows the Health permission sheet (once). Returns whether the request completed.
    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    /// The total for a metric between two instants (today in the member's time zone).
    func value(_ metric: HealthMetric, from start: Date, to end: Date) async -> Double? {
        guard isAvailable else { return nil }
        let window = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        switch metric {
        case .steps: return await sum(.stepCount, unit: .count(), window)
        case .exerciseMinutes: return await sum(.appleExerciseTime, unit: .minute(), window)
        case .waterLiters: return await sum(.dietaryWater, unit: .liter(), window)
        case .mindfulMinutes:
            guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return nil }
            let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: window)],
                                                     sortDescriptors: [])
            guard let samples = try? await descriptor.result(for: store) else { return nil }
            return samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60
        }
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, _ window: NSPredicate) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        let descriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: window),
                                                     options: .cumulativeSum)
        do {
            let stats = try await descriptor.result(for: store)
            return stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
        } catch {
            return nil
        }
    }
}
