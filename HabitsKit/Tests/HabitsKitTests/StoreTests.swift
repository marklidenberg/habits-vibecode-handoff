import Foundation
import Testing
@testable import HabitsKit

@MainActor
@Suite struct StoreTests {
    let today = Day(iso: "2026-10-06")!

    func names(_ habits: [Habit]) -> [String] {
        habits.map(\.name)
    }

    func filled() -> Store {
        let store = Store(url: nil)
        for name in ["a", "b", "c"] {
            store.add(Habit(icon: "✨", name: name))
        }
        return store
    }

    @Test func archiveAndRestore() {
        let store = filled()
        let a = store.active[0].id
        store.archive(a)
        #expect(names(store.active) == ["b", "c"])
        #expect(names(store.archived) == ["a"])
        store.add(Habit(icon: "✨", name: "d"))
        #expect(names(store.habits) == ["b", "c", "d", "a"])
        store.restore(a)
        #expect(names(store.active) == ["b", "c", "d", "a"])
        #expect(store.archived.isEmpty)
    }

    @Test func move() {
        let store = filled()
        store.move(store.active[2].id, to: 0)
        #expect(names(store.active) == ["c", "a", "b"])
        store.move(store.active[0].id, to: 9)
        #expect(names(store.active) == ["a", "b", "c"])
    }

    @Test func tree() {
        let store = filled()
        store.add(Habit(icon: "🌅", name: "g", group: true))
        let (a, b, g) = (store.active[0].id, store.active[1].id, store.active[3].id)
        store.move(a, after: g, parent: g)
        store.move(b, after: a, parent: g)
        #expect(names(store.active) == ["c", "g", "a", "b"])
        store.move(g, after: nil, parent: nil)
        #expect(names(store.active) == ["g", "a", "b", "c"])
        #expect(store.ancestors(store.habit(b)!).map(\.name) == ["g"])
        store.move(g, after: a, parent: nil)
        #expect(names(store.active) == ["g", "a", "b", "c"])
        store.delete(g)
        #expect(names(store.active) == ["a", "b", "c"])
        #expect(store.active.allSatisfy { $0.parent == nil })
    }

    @Test func savedAndRead() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "habits-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = Store(url: url)
        store.add(Habit(icon: "💧", name: "Вода", step: 1))
        store.setValue(3, of: store.active[0].id, on: today)
        store.setNote("утро", of: store.active[0].id, on: today)
        store.color = "#ff9f0a"
        let again = Store(url: url)
        #expect(again.habits == store.habits)
        #expect(again.color == "#ff9f0a")
    }

    func file() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "habits-\(UUID()).json")
    }

    @Test func editsMergedByHabit() {
        let url = file()
        defer { try? FileManager.default.removeItem(at: url) }
        let phone = Store(url: url)
        phone.add(Habit(icon: "💧", name: "Вода", step: 1))
        phone.add(Habit(icon: "🏃", name: "Бег"))
        let mac = Store(url: url)
        let (water, run) = (phone.active[0].id, phone.active[1].id)
        phone.setValue(3, of: water, on: today)
        mac.setValue(1, of: run, on: today)
        phone.sync()
        #expect(phone.habit(water)?.value(on: today) == 3)
        #expect(phone.habit(run)?.value(on: today) == 1)
    }

    @Test func newerWins() async throws {
        let url = file()
        defer { try? FileManager.default.removeItem(at: url) }
        let phone = Store(url: url)
        phone.add(Habit(icon: "💧", name: "Вода", step: 1))
        let mac = Store(url: url)
        let water = phone.active[0].id
        mac.setValue(5, of: water, on: today)
        try await Task.sleep(for: .milliseconds(2))
        phone.setValue(3, of: water, on: today)
        mac.sync()
        #expect(mac.habit(water)?.value(on: today) == 3)
    }

    @Test func delete() {
        let store = filled()
        let a = store.active[0].id
        store.delete(a)
        #expect(names(store.habits) == ["b", "c"])
        #expect(store.deleted[a] != nil)
    }

    @Test func deletedNeverBack() throws {
        let url = file()
        defer { try? FileManager.default.removeItem(at: url) }
        let phone = Store(url: url)
        phone.add(Habit(icon: "💧", name: "Вода"))
        let id = phone.active[0].id
        var state = try Store.decode(try Data(contentsOf: url))
        state.habits = []
        state.deleted = [id: Store.now()]
        try Store.encode(state).write(to: url)
        phone.setValue(1, of: id, on: today)
        #expect(phone.habits.isEmpty)
        #expect(try Store.decode(try Data(contentsOf: url)).habits.isEmpty)
    }

    @Test func adopted() {
        let store = filled()
        store.adopt([Habit(icon: "💧", name: "Вода")], color: "#ff9f0a")
        #expect(names(store.active) == ["Вода", "a", "b", "c"])
        #expect(store.color == "#ff9f0a")
    }
}
