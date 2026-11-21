import Foundation

/// A calendar date with no time and no time zone ("2026-11-21").
/// Stored as the number of days since 1970-01-01 so arithmetic and comparison are trivial.
struct LocalDate: Hashable, Comparable, Codable, CustomStringConvertible {
    let ordinal: Int

    init(ordinal: Int) { self.ordinal = ordinal }

    init(year: Int, month: Int, day: Int) {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        let date = LocalDate.utc.date(from: c) ?? Date(timeIntervalSince1970: 0)
        ordinal = Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Parses "yyyy-MM-dd".
    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    /// The local calendar date of `date` in `timeZone`.
    init(_ date: Date, in timeZone: TimeZone) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool { lhs.ordinal < rhs.ordinal }

    func adding(_ days: Int) -> LocalDate { LocalDate(ordinal: ordinal + days) }

    func days(until other: LocalDate) -> Int { other.ordinal - ordinal }

    private var utcDate: Date { Date(timeIntervalSince1970: TimeInterval(ordinal) * 86_400) }

    var components: (year: Int, month: Int, day: Int) {
        let c = LocalDate.utc.dateComponents([.year, .month, .day], from: utcDate)
        return (c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// 1 = Sunday ... 7 = Saturday.
    var weekday: Int { LocalDate.utc.component(.weekday, from: utcDate) }

    var string: String {
        let c = components
        return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
    }

    var description: String { string }

    /// The instant this date begins (local midnight) in `timeZone`.
    func startInstant(in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = components
        var dc = DateComponents()
        dc.year = c.year; dc.month = c.month; dc.day = c.day
        return cal.date(from: dc) ?? utcDate
    }

    /// The instant this date ends (the next local midnight): the moment the day becomes final.
    func closeInstant(in timeZone: TimeZone) -> Date {
        adding(1).startInstant(in: timeZone)
    }

    /// Codable as "yyyy-MM-dd".
    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let d = LocalDate(string: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
        }
        self = d
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(string)
    }

    private static let utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
}
