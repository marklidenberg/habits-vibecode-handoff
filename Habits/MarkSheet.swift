import HabitsKit
import SwiftUI

/// A held day: its own value, and a note
struct Marking: Identifiable {
    let habit: Habit.ID
    let day: Day

    var id: String { "\(habit)-\(day.index)" }
}

struct MarkSheet: View {
    @Environment(Store.self) var store
    @Environment(\.dismiss) var dismiss
    let marking: Marking

    var body: some View {
        if let habit = store.habit(marking.habit) {
            VStack(spacing: 18) {
                Text("\(habit.icon) \(habit.name) · \(title)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if habit.isBinary {
                    toggle(habit)
                } else {
                    counter(habit)
                }
                TextField("", text: note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14)
                    .frame(minHeight: 80, alignment: .topLeading)
                    .background(Rows().clipShape(.rect(cornerRadius: 22)))
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
                    .accessibilityIdentifier("note")
                Button("Reset", role: .destructive) {
                    store.setValue(0, of: marking.habit, on: marking.day)
                    store.setNote("", of: marking.habit, on: marking.day)
                    dismiss()
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("reset")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDetents([.height(390)])
            .presentationBackground { Backdrop() }
        }
    }

    var title: String {
        let today = Day.today()
        if marking.day == today { return "Today" }
        if marking.day == today.adding(-1) { return "Yesterday" }
        return String(format: "%d.%02d", marking.day.day, month)
    }

    var month: Int {
        Int(marking.day.iso.split(separator: "-")[1]) ?? 0
    }

    var note: Binding<String> {
        Binding(
            get: { store.habit(marking.habit)?.note(on: marking.day) ?? "" },
            set: { store.setNote($0, of: marking.habit, on: marking.day) })
    }

    var value: Binding<Int> {
        Binding(
            get: { max(store.habit(marking.habit)?.value(on: marking.day) ?? 0, 0) },
            set: { store.setValue(max($0, 0), of: marking.habit, on: marking.day) })
    }

    func toggle(_ habit: Habit) -> some View {
        let marked = habit.isMarked(on: marking.day)
        return Button {
            value.wrappedValue = marked ? 0 : 1
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(marked ? Color(hex: "#0b0d24") : .clear)
                .frame(width: 92, height: 92)
                .background(Circle().fill(marked ? Color(hex: store.color) : Color(hex: store.color).opacity(0.14)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityIdentifier("toggle")
    }

    func counter(_ habit: Habit) -> some View {
        HStack(spacing: 18) {
            step(habit, by: -1, "minus")
            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 46, weight: .bold).monospacedDigit())
                .frame(width: 130)
                .accessibilityIdentifier("value")
            step(habit, by: 1, "plus")
        }
    }

    func step(_ habit: Habit, by sign: Int, _ symbol: String) -> some View {
        Button {
            value.wrappedValue += sign * habit.step
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityIdentifier(symbol)
    }
}
