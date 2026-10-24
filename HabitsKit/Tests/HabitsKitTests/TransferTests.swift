import Testing
@testable import HabitsKit

@MainActor
@Suite struct TransferTests {
    @Test func replaceTakesEverything() throws {
        let from = Store(url: nil)
        from.add(Habit(icon: "💧", name: "Вода", step: 1))
        from.add(Habit(icon: "🏃", name: "Бег"))
        from.archive(from.active[1].id)
        from.color = "#ff9f0a"

        let to = Store(url: nil)
        to.add(Habit(icon: "🧘", name: "Медитация"))
        to.replace(with: try HabitFile.read(try HabitFile.write(from.contents)))
        #expect(to.active.map(\.name) == ["Вода"])
        #expect(to.archived.map(\.name) == ["Бег"])
        #expect(to.color == "#ff9f0a")
        #expect(to.habits.map(\.id) == from.habits.map(\.id))
        #expect(to.deleted.count == 1)
    }
}
