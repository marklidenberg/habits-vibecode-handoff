import Foundation

/// A calendar day: days since 1970-01-01, the time zone left out
public struct Day: Hashable, Comparable, Sendable {
    public var index: Int

    public init(_ index: Int) {
        self.index = index
    }

    /// The day `date` falls on in `calendar`
    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.index = Int(Day.utc.date(from: parts)!.timeIntervalSince1970 / 86_400)
    }

    public static func today(calendar: Calendar = .current) -> Day {
        Day(Date(), calendar: calendar)
    }

    public func adding(_ days: Int) -> Day {
        Day(index + days)
    }

    public static func < (a: Day, b: Day) -> Bool {
        a.index < b.index
    }

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    var date: Date {
        Date(timeIntervalSince1970: Double(index) * 86_400)
    }

    public var day: Int {
        Day.utc.component(.day, from: date)
    }

    /// 0 — Monday … 6 — Sunday
    public var weekday: Int {
        (Day.utc.component(.weekday, from: date) + 5) % 7
    }

    public var iso: String {
        let parts = Day.utc.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    public init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = Day.utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return nil }
        self.index = Int(date.timeIntervalSince1970 / 86_400)
    }
}

extension Day: Codable, CodingKeyRepresentable {
    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let day = Day(iso: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not a day: \(text)"))
        }
        self = day
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    public var codingKey: CodingKey {
        AnyKey(stringValue: iso)
    }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(iso: codingKey.stringValue)
    }

    struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
