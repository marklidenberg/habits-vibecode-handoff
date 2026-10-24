import Foundation
import Testing
@testable import HabitsKit

@Suite struct DayTests {
    @Test func isoRoundTrip() {
        let day = Day(iso: "2026-10-06")!
        #expect(day.iso == "2026-10-06")
        #expect(day.adding(1).iso == "2026-10-07")
        #expect(day.weekday == 1)  // Tuesday
        #expect(day.day == 6)
    }

    @Test func fromLocalDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 23, minute: 30))!
        #expect(Day(date, calendar: calendar).iso == "2026-10-06")
    }

    @Test func badIso() {
        #expect(Day(iso: "nope") == nil)
    }
}

@Suite struct HabitTests {
    let today = Day(iso: "2026-10-06")!

    @Test func idIs8Hex() {
        #expect(Habit(icon: "🏃", name: "Бег").id.wholeMatch(of: /[0-9a-f]{8}/) != nil)
    }

    @Test func binaryClamps() {
        var habit = Habit(icon: "🏃", name: "Бег")
        habit.setValue(5, on: today)
        #expect(habit.value(on: today) == 1)
        habit.setValue(0, on: today)
        #expect(habit.log.isEmpty)
    }

    @Test func counterKeepsAnyValue() {
        var habit = Habit(icon: "💧", name: "Вода", step: 1)
        habit.setValue(37, on: today)
        #expect(habit.value(on: today) == 37)
        habit.setValue(-3, on: today)
        #expect(!habit.isMarked(on: today))
    }

    @Test func skipped() {
        var habit = Habit(icon: "🏃", name: "Бег")
        habit.setValue(Habit.skipped, on: today)
        #expect(habit.isSkipped(on: today) && !habit.isMarked(on: today))
    }

    @Test func notes() {
        var habit = Habit(icon: "📖", name: "Чтение", step: 10)
        habit.setNote("Только половину", on: today)
        #expect(habit.note(on: today) == "Только половину")
        habit.setNote("", on: today)
        #expect(habit.notes.isEmpty)
    }
}
