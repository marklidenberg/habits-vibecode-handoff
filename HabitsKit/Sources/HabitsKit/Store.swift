import Foundation
import Observation

/// Every habit and the accent color, saved at every change, merged with the file by habit
@MainActor
@Observable
public final class Store {
    /// In row order, the archived after
    public internal(set) var habits: [Habit]
    public var color: String {
        didSet { if color != oldValue, !applying { modified = Store.now(); save() } }
    }

    /// The deleted, by id: never back
    public internal(set) var deleted: [Habit.ID: Date]
    /// The order and the color's last change
    @ObservationIgnored var modified: Date

    @ObservationIgnored let url: URL?
    /// Left out of the file's notifications for its own writes
    @ObservationIgnored public weak var presenter: (any NSFilePresenter)?
    @ObservationIgnored var applying = false

    public static let defaultColor = "#8fa2ff"

    /// `url`: where it is saved, nil — in memory alone
    public init(url: URL?) {
        self.url = url
        let state = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? Store.decode($0) }
        self.habits = Store.ordered(state?.habits ?? [])
        self.color = state?.color ?? Store.defaultColor
        self.deleted = state?.deleted ?? [:]
        self.modified = state?.modified ?? .distantPast
    }

    public var active: [Habit] {
        habits.filter { !$0.archived }
    }

    public var archived: [Habit] {
        habits.filter(\.archived)
    }

    public func habit(_ id: Habit.ID) -> Habit? {
        habits.first { $0.id == id }
    }

    /// Last among the active
    public func add(_ habit: Habit) {
        var habit = habit
        habit.archived = false
        habit.modified = Store.now()
        habits.insert(habit, at: active.count)
        moved()
    }

    public func update(_ habit: Habit) {
        edit(habit.id) { $0 = habit }
    }

    /// Out of the grid, first in the archive
    public func archive(_ id: Habit.ID) {
        guard var habit = take(id) else { return }
        habit.archived = true
        habit.modified = Store.now()
        habits.insert(habit, at: active.count)
        moved()
    }

    /// Back in the grid, last
    public func restore(_ id: Habit.ID) {
        guard var habit = take(id) else { return }
        habit.archived = false
        habit.modified = Store.now()
        habits.insert(habit, at: active.count)
        moved()
    }

    /// Gone with its history, never back; a group's habits a level up
    public func delete(_ id: Habit.ID) {
        guard let gone = take(id) else { return }
        for index in habits.indices where habits[index].parent == id {
            habits[index].parent = gone.parent
            habits[index].modified = Store.now()
        }
        deleted[id] = Store.now()
        moved()
    }

    /// To `index` among the active
    public func move(_ id: Habit.ID, to index: Int) {
        guard let habit = habit(id), !habit.archived else { return }
        _ = take(id)
        habits.insert(habit, at: min(max(index, 0), active.count))
        moved()
    }

    /// With its group's habits: right after `after`, nil — first; into `parent`, nil — the top level
    public func move(_ id: Habit.ID, after: Habit.ID?, parent: Habit.ID?) {
        var block = subtree(id)
        guard !block.isEmpty, !block.contains(where: { $0.id == after || $0.id == parent }) else { return }
        let ids = Set(block.map(\.id))
        habits.removeAll { ids.contains($0.id) }
        let index = after.flatMap { after in habits.firstIndex { $0.id == after } }.map { $0 + 1 } ?? 0
        block[0].parent = parent
        block[0].modified = Store.now()
        habits.insert(contentsOf: block, at: index)
        moved()
    }

    /// Its groups up to the top, the nearest first
    public func ancestors(_ habit: Habit) -> [Habit] {
        var groups: [Habit] = []
        var next = habit.parent
        while let id = next, !groups.contains(where: { $0.id == id }), let group = active.first(where: { $0.id == id && $0.group }) {
            groups.append(group)
            next = group.parent
        }
        return groups
    }

    /// The habit, then its group's habits at any depth
    public func subtree(_ id: Habit.ID) -> [Habit] {
        let active = active
        guard let index = active.firstIndex(where: { $0.id == id }) else { return [] }
        let depth = ancestors(active[index]).count
        return [active[index]] + active[(index + 1)...].prefix { ancestors($0).count > depth }
    }

    /// Depth-first, each under its group, in their order; a group gone — the top level
    static func ordered(_ habits: [Habit]) -> [Habit] {
        let active = habits.filter { !$0.archived }
        let groups = Set(active.filter(\.group).map(\.id))
        var children: [String?: [Habit]] = [:]
        for habit in active {
            children[habit.parent.flatMap { groups.contains($0) ? $0 : nil }, default: []].append(habit)
        }
        var tree: [Habit] = []
        func walk(_ parent: String?) {
            for habit in children[parent] ?? [] {
                tree.append(habit)
                if habit.group { walk(habit.id) }
            }
        }
        walk(nil)
        let reached = Set(tree.map(\.id))
        return tree + active.filter { !reached.contains($0.id) } + habits.filter(\.archived)
    }

    /// Migration: these habits taken in, as just changed
    public func adopt(_ adopted: [Habit], color: String) {
        let now = Store.now()
        apply(Store.merge(State(habits: adopted.map { var habit = $0; habit.modified = now; return habit }, color: color, modified: now, deleted: [:]), state))
        save()
    }

    public func setValue(_ value: Int, of id: Habit.ID, on day: Day) {
        edit(id) { $0.setValue(value, on: day) }
    }

    public func setNote(_ note: String, of id: Habit.ID, on day: Day) {
        edit(id) { $0.setNote(note, on: day) }
    }

    func edit(_ id: Habit.ID, _ change: (inout Habit) -> Void) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        change(&habits[index])
        habits[index].modified = Store.now()
        save()
    }

    func take(_ id: Habit.ID) -> Habit? {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return nil }
        return habits.remove(at: index)
    }

    func moved() {
        habits = Store.ordered(habits)
        modified = Store.now()
        save()
    }

    struct State: Codable, Equatable {
        var v = 1
        var habits: [Habit]
        var color: String
        var modified: Date
        var deleted: [Habit.ID: Date]
    }

    var state: State {
        State(habits: habits, color: color, modified: modified, deleted: deleted)
    }

    func apply(_ state: State) {
        applying = true
        defer { applying = false }
        habits = state.habits
        color = state.color
        modified = state.modified
        deleted = state.deleted
    }

    /// `a` wins a tie
    static func merge(_ a: State, _ b: State) -> State {
        let (newer, older) = b.modified > a.modified ? (b, a) : (a, b)
        let deleted = a.deleted.merging(b.deleted, uniquingKeysWith: max)
        var byID: [Habit.ID: Habit] = [:]
        for habit in b.habits + a.habits where habit.modified >= byID[habit.id]?.modified ?? .distantPast {
            byID[habit.id] = habit
        }
        var seen: Set<Habit.ID> = []
        let habits = (newer.habits + older.habits).compactMap { seen.insert($0.id).inserted && deleted[$0.id] == nil ? byID[$0.id] : nil }
        return State(habits: ordered(habits), color: newer.color, modified: newer.modified, deleted: deleted)
    }

    func save() {
        sync()
    }

    /// The file read, merged in, written back where it lags. True — the file holds it all
    @discardableResult
    public func sync() -> Bool {
        guard let url, !downloading(url) else { return false }
        var failure: NSError?
        var written = false
        NSFileCoordinator(filePresenter: presenter).coordinate(writingItemAt: url, options: .forMerging, error: &failure) { url in
            let disk = (try? Data(contentsOf: url)).flatMap { try? Store.decode($0) }
            let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
            var merged = disk.map { Store.merge(state, $0) } ?? state
            for version in conflicts {
                if let other = (try? Data(contentsOf: version.url)).flatMap({ try? Store.decode($0) }) {
                    merged = Store.merge(merged, other)
                }
            }
            if merged != state { apply(merged) }
            if merged != disk {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                guard (try? Store.encode(merged).write(to: url, options: .atomic)) != nil else { return }
            }
            for version in conflicts { version.isResolved = true }
            if !conflicts.isEmpty { try? NSFileVersion.removeOtherVersionsOfItem(at: url) }
            written = true
        }
        return written
    }

    /// In iCloud, not here yet: its download started
    func downloading(_ url: URL) -> Bool {
        let placeholder = url.deletingLastPathComponent().appending(path: ".\(url.lastPathComponent).icloud")
        let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
        guard FileManager.default.fileExists(atPath: placeholder.path) || (status != nil && status != .current) else { return false }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return true
    }

    static func now() -> Date {
        Date(timeIntervalSince1970: (Date().timeIntervalSince1970 * 1000).rounded() / 1000)
    }

    static func encode(_ state: State) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var (seconds, ms) = Int((date.timeIntervalSince1970 * 1000).rounded()).quotientAndRemainder(dividingBy: 1000)
            if ms < 0 { (seconds, ms) = (seconds - 1, ms + 1000) }
            let text = Date.ISO8601FormatStyle().format(Date(timeIntervalSince1970: Double(seconds))).dropLast() + String(format: ".%03dZ", ms)
            var container = encoder.singleValueContainer()
            try container.encode(String(text))
        }
        return try encoder.encode(state)
    }

    static func decode(_ data: Data) throws -> State {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let parts = text.replacing("Z", with: "").split(separator: ".")
            let seconds = try Date.ISO8601FormatStyle().parse(parts[0] + "Z").timeIntervalSince1970
            let ms = parts.count > 1 ? Int(parts[1].prefix(3).padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0 : 0
            return Date(timeIntervalSince1970: (seconds * 1000 + Double(ms)) / 1000)
        }
        return try decoder.decode(State.self, from: data)
    }
}
