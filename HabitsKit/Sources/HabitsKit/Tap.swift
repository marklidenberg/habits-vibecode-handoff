extension Habit {
    /// Binary: marked; a counter: +step, a skipped day from 0
    public mutating func tap(on day: Day) {
        setValue(isBinary ? 1 : max(value(on: day), 0) + step, on: day)
    }

    /// By the day before the double tap: anything in it — cleared, else skipped
    public mutating func doubleTap(on day: Day, before: Int) {
        setValue(before != 0 ? 0 : Habit.skipped, on: day)
    }
}

extension Store {
    public func tap(_ id: Habit.ID, on day: Day) {
        edit(id) { $0.tap(on: day) }
    }

    public func doubleTap(_ id: Habit.ID, on day: Day, before: Int) {
        edit(id) { $0.doubleTap(on: day, before: before) }
    }
}
