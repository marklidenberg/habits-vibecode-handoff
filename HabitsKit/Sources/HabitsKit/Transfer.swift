extension Store {
    public var contents: HabitFile.Contents {
        HabitFile.Contents(habits: habits, color: color)
    }

    /// Import: everything replaced, the ids kept, the rest deleted
    public func replace(with contents: HabitFile.Contents) {
        let now = Store.now()
        let imported = contents.habits.filter { deleted[$0.id] == nil }.map { var habit = $0; habit.modified = now; return habit }
        for habit in habits where !imported.contains(where: { $0.id == habit.id }) { deleted[habit.id] = now }
        apply(State(habits: imported.filter { !$0.archived } + imported.filter(\.archived), color: contents.color, modified: now, deleted: deleted))
        save()
    }
}
