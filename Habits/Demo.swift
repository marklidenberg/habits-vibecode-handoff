import HabitsKit
import Foundation

/// `-demo` at launch: sample habits and a group, in memory alone
enum Demo {
    static var isOn: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    @MainActor
    static func store() -> Store {
        let store = Store(url: nil)
        let rows: [(String, String, Int)] = [
            ("💧", "Water", 1), ("🏃", "Run", 0), ("📖", "Reading", 10),
            ("🧘", "Meditation", 0), ("💪", "Push-ups", 10), ("🍬", "No sugar", 0),
        ]
        var seed: UInt64 = 7
        func random() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(1 << 31)
        }
        let today = Day.today()
        for (icon, name, step) in rows {
            var habit = Habit(icon: icon, name: name, step: step)
            let odds = 0.45 + random() * 0.45
            for back in 1..<60 where random() < odds {
                habit.setValue(step == 0 ? 1 : step * (1 + Int(random() * 6)), on: today.adding(-back))
            }
            store.add(habit)
        }
        store.add(Habit(icon: "🌅", name: "Morning", group: true))
        let morning = store.active.last!.id
        store.move(morning, after: nil, parent: nil)
        for name in ["Push-ups", "Reading"] {
            store.move(store.active.first { $0.name == name }!.id, after: morning, parent: morning)
        }
        for (icon, name) in [("🎹", "Piano"), ("🚴", "Cycling"), ("🥛", "No dairy")] {
            store.add(Habit(icon: icon, name: name))
            store.archive(store.active.last!.id)
        }
        return store
    }
}
