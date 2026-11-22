import Foundation

/// Apple Health as proof: steps, exercise minutes, water and mindful minutes check off matching rules.
extension AppModel {
    var healthProofOn: Bool { Prefs.healthProofOn }

    func healthMetric(for rule: RuleFact) -> HealthMetric? {
        healthProofOn ? HealthMetric.metric(for: rule) : nil
    }

    /// "6,120 / 8,000 steps" for a rule Health can prove, once a reading exists.
    func healthProgressText(for rule: RuleFact) -> String? {
        guard let metric = healthMetric(for: rule), let v = healthReadings[rule.id] else { return nil }
        return metric.progressText(v)
    }

    /// Profile → "Use Apple Health as proof".
    func setHealthProof(_ on: Bool) async {
        if on {
            guard HealthProof.shared.isAvailable else {
                errorMessage = "Apple Health isn't available on this device."
                return
            }
            _ = await HealthProof.shared.requestAccess()
        }
        Prefs.healthProofOn = on
        healthReadings = [:]
        if on { await refreshHealth() }
    }

    /// Reads today's totals and checks off every rule whose target is met.
    func refreshHealth() async {
        guard healthProofOn, let m = me, let today = myToday,
              today.dayNumber != nil || isWarmup, !(state.isFrozen) else { return }
        let tz = m.tz
        let start = LocalDate(now(), in: tz).startInstant(in: tz)
        var readings: [String: Double] = [:]
        var proved: [(RuleFact, String)] = []
        for item in today.items {
            guard let metric = HealthMetric.metric(for: item.rule),
                  let value = await HealthProof.shared.value(metric, from: start, to: Date()) else { continue }
            readings[item.rule.id] = value
            if !item.isChecked, item.checkIn == nil, value >= metric.target {
                proved.append((item.rule, metric.proofText(value)))
            }
        }
        healthReadings = readings
        for (rule, text) in proved {
            if await checkIn(rule: rule, photo: nil, healthProof: text) {
                toast = "\(rule.title) checked off from Apple Health."
            }
        }
    }
}
