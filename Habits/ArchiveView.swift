import HabitsKit
import SwiftUI

/// The archived habits, searched by name, brought back with their history or deleted
struct ArchiveView: View {
    @Environment(Store.self) var store
    @State var query = ""
    @State var deleting: Habit?

    var found: [Habit] {
        store.archived.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(found) { habit in
            HStack(spacing: 12) {
                Text(habit.icon).font(.title3)
                Text(habit.name).lineLimit(1)
                Spacer()
                Button("Restore") {
                    store.restore(habit.id)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("restore-\(habit.name)")
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deleting = habit
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .accessibilityIdentifier("delete-\(habit.name)")
            }
            .listRowBackground(Rows())
        }
        .confirmationDialog("Delete «\(deleting?.name ?? "")» with its history?", isPresented: .init { deleting != nil } set: { if !$0 { deleting = nil } }, titleVisibility: .visible, presenting: deleting) { habit in
            Button("Delete", role: .destructive) { store.delete(habit.id) }
                .accessibilityIdentifier("confirm-delete")
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .animation(.default, value: found.map(\.id))
    }
}
