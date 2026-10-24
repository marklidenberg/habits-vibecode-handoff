import Foundation

/// The export: every habit and all their history, compact JSON, gzipped
public enum HabitFile {
    public struct Contents: Equatable, Sendable {
        public var habits: [Habit]
        public var color: String

        public init(habits: [Habit], color: String) {
            self.habits = habits
            self.color = color
        }
    }

    public static func name(on day: Day = .today()) -> String {
        "habits-\(day.iso).json.gz"
    }

    public static func write(_ contents: Contents) throws -> Data {
        let file = File(v: 1, color: contents.color, habits: contents.habits.map { var entry = Entry($0); entry.modified = nil; return entry })
        return Gzip.compress(try JSONEncoder().encode(file))
    }

    /// A `.json.gz`, or a plain `.json`
    public static func read(_ data: Data) throws -> Contents {
        let json = Gzip.isGzip(data) ? try Gzip.decompress(data) : data
        let file = try JSONDecoder().decode(File.self, from: json)
        return Contents(habits: file.habits.map(\.habit), color: file.color)
    }

    struct File: Codable {
        var v: Int
        var color: String
        var habits: [Entry]
    }

    struct Entry: Codable {
        var id: String?  // none — given on read
        var modified: Date?  // the store's alone
        var icon: String
        var name: String
        var parent: String?
        var group: Bool?
        var step: Int
        var weight: Int?
        var archived: Bool
        var from: String?
        var log: [Int]?
        var notes: [String: String]?

        /// The log a value per day, in a row from `from`
        init(_ habit: Habit) {
            id = habit.id
            modified = habit.modified
            icon = habit.icon
            name = habit.name
            parent = habit.parent
            group = habit.group ? true : nil
            step = habit.step
            weight = habit.weight
            archived = habit.archived
            if let first = habit.log.keys.min(), let last = habit.log.keys.max() {
                from = first.iso
                log = (first.index...last.index).map { habit.log[Day($0)] ?? 0 }
            }
            if !habit.notes.isEmpty {
                notes = Dictionary(uniqueKeysWithValues: habit.notes.map { ($0.key.iso, $0.value) })
            }
        }

        var habit: Habit {
            var habit = Habit(id: id ?? Habit.newID(), icon: icon, name: name, step: step, weight: weight, archived: archived, parent: parent, group: group ?? false, modified: modified ?? .distantPast)
            if let from = from.flatMap(Day.init(iso:)) {
                for (offset, value) in (log ?? []).enumerated() where value != 0 {
                    habit.log[from.adding(offset)] = value
                }
            }
            for (iso, note) in notes ?? [:] {
                if let day = Day(iso: iso) { habit.notes[day] = note }
            }
            return habit
        }
    }
}

/// As an entry of the file
extension Habit: Codable {
    public init(from decoder: Decoder) throws {
        self = try HabitFile.Entry(from: decoder).habit
    }

    public func encode(to encoder: Encoder) throws {
        try HabitFile.Entry(self).encode(to: encoder)
    }
}
