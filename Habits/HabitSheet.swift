import HabitsKit
import SwiftUI

/// New or edited: a draft, written back on Done
struct Editing: Identifiable {
    var habit: Habit
    let isNew: Bool

    var id: Habit.ID { habit.id }
}

struct HabitSheet: View {
    @Environment(Store.self) var store
    @Environment(\.dismiss) var dismiss
    @State var draft: Habit
    @State var picking = false
    let isNew: Bool
    @State var deleting = false

    init(_ editing: Editing) {
        _draft = State(initialValue: editing.habit)
        isNew = editing.isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        if !draft.group {
                            Button { picking = true } label: {
                                Text(draft.icon)
                                    .font(.system(size: 28))
                                    .frame(width: 48, height: 48)
                                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("icon")
                        }
                        TextField("", text: $draft.name)
                            .font(.title3)
                            .accessibilityIdentifier("name")
                    }
                }
                .listRowBackground(Rows())
                Section {
                    Picker("Type", selection: type) {
                        Text("Yes / no").tag(0)
                        Text("Counter").tag(1)
                        Text("Group").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("type")
                    if !draft.isBinary {
                        stepper("Step", value: $draft.step, in: 1...1000, id: "step")
                    }
                    if !draft.group {
                        stepper("Weight", value: optional(\.weight), in: 0...100, id: "weight")
                    }
                }
                .listRowBackground(Rows())
                if !isNew {
                    Section {
                        if !draft.group {
                            Button("Archive", role: .destructive) {
                                store.archive(draft.id)
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("archive")
                        }
                        Button("Delete", role: .destructive) { deleting = true }
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("delete")
                            .confirmationDialog("Delete «\(draft.name)» with its history?", isPresented: $deleting, titleVisibility: .visible) {
                                Button("Delete", role: .destructive) {
                                    store.delete(draft.id)
                                    dismiss()
                                }
                                .accessibilityIdentifier("confirm-delete")
                            }
                    }
                    .listRowBackground(Rows())
                }
            }
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                        .accessibilityIdentifier("cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        isNew ? store.add(draft) : store.update(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || draft.icon.isEmpty)
                    .accessibilityIdentifier("done")
                }
            }
        }
        .sheet(isPresented: $picking) { EmojiPicker(icon: $draft.icon) }
        .presentationDetents([.large])
        .presentationBackground { Backdrop() }
    }

    /// 0 — yes / no, 1 — a counter, 2 — a group
    var type: Binding<Int> {
        Binding(
            get: { draft.group ? 2 : draft.isBinary ? 0 : 1 },
            set: {
                draft.group = $0 == 2
                draft.step = $0 == 1 ? max(draft.step, 1) : 0
            })
    }

    /// 0 — unset
    func optional(_ key: WritableKeyPath<Habit, Int?>) -> Binding<Int> {
        Binding(
            get: { draft[keyPath: key] ?? 0 },
            set: { draft[keyPath: key] = $0 == 0 ? nil : $0 })
    }

    func stepper(_ title: String, value: Binding<Int>, in range: ClosedRange<Int>, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.wrappedValue == 0 ? "—" : "\(value.wrappedValue)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(id)-value")
            Stepper("", value: value, in: range)
                .labelsHidden()
                .accessibilityIdentifier(id)
        }
    }
}
