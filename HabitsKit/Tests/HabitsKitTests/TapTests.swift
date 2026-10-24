import Testing
@testable import HabitsKit

@Suite struct TapTests {
    let today = Day(iso: "2026-10-06")!

    @Test func binary() {
        var habit = Habit(icon: "🏃", name: "Бег")
        habit.tap(on: today)
        habit.tap(on: today)
        #expect(habit.isMarked(on: today))
        habit.doubleTap(on: today, before: 1)
        #expect(habit.log.isEmpty)
        habit.doubleTap(on: today, before: 0)
        #expect(habit.isSkipped(on: today))
        habit.doubleTap(on: today, before: Habit.skipped)
        #expect(habit.log.isEmpty)
    }

    @Test func counter() {
        var habit = Habit(icon: "📖", name: "Чтение", step: 10)
        habit.tap(on: today)
        habit.tap(on: today)
        #expect(habit.value(on: today) == 20)
        habit.doubleTap(on: today, before: 20)
        #expect(habit.log.isEmpty)
        habit.doubleTap(on: today, before: 0)
        #expect(habit.isSkipped(on: today))
        habit.tap(on: today)
        #expect(habit.value(on: today) == 10)
    }
}
