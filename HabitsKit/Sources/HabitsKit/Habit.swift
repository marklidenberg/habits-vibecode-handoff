import Foundation

/// A habit and its log: a value per day, a note per day
public struct Habit: Identifiable, Hashable, Sendable {
    public var id: String  // 8 hex, given once
    public var icon: String
    public var name: String
    public var step: Int  // 0 — binary, else a counter
    public var weight: Int?
    public var archived: Bool
    public var parent: String?  // its group's id
    public var group: Bool  // a group: icon and name alone
    public var log: [Day: Int]
    public var notes: [Day: String]
    public var modified: Date  // its last change

    public init(
        id: String = Habit.newID(),
        icon: String,
        name: String,
        step: Int = 0,
        weight: Int? = nil,
        archived: Bool = false,
        parent: String? = nil,
        group: Bool = false,
        log: [Day: Int] = [:],
        notes: [Day: String] = [:],
        modified: Date = .distantPast
    ) {
        self.id = id
        self.icon = icon
        self.name = name
        self.step = step
        self.weight = weight
        self.archived = archived
        self.parent = parent
        self.group = group
        self.log = log
        self.notes = notes
        self.modified = modified
    }

    public static func newID() -> String {
        String(format: "%08x", UInt32.random(in: .min ... .max))
    }

    public var isBinary: Bool {
        step == 0
    }

    public func value(on day: Day) -> Int {
        log[day] ?? 0
    }

    public func isMarked(on day: Day) -> Bool {
        value(on: day) > 0
    }

    public func isSkipped(on day: Day) -> Bool {
        value(on: day) == Habit.skipped
    }

    public func note(on day: Day) -> String {
        notes[day] ?? ""
    }

    public static let skipped = -1

    /// Binary: 0 or 1; a counter: any value ≥ 0; either `skipped`. 0 clears the day
    public mutating func setValue(_ value: Int, on day: Day) {
        let value = value == Habit.skipped ? value : isBinary ? min(max(value, 0), 1) : max(value, 0)
        log[day] = value == 0 ? nil : value
    }

    /// An empty note clears it
    public mutating func setNote(_ note: String, on day: Day) {
        notes[day] = note.isEmpty ? nil : note
    }
}
