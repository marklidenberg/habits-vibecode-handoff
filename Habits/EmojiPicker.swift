import HabitsKit
import SwiftUI

/// Every emoji by Unicode's groups, the habits' icons first; a tap picks
struct EmojiPicker: View {
    @Environment(Store.self) var store
    @Environment(\.dismiss) var dismiss
    @Binding var icon: String
    @State var search = ""

    struct EmojiGroup: Decodable {
        let group: String
        let emoji: [[String]]
    }

    static let groups: [EmojiGroup] = {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([EmojiGroup].self, from: data)) ?? []
    }()

    var shown: [(name: String, emoji: [String])] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            let found = Self.groups.flatMap(\.emoji).filter { $0[1].contains(query) }.map { $0[0] }
            return found.isEmpty ? [] : [("", found)]
        }
        var used: [String] = []
        for habit in store.habits where !used.contains(habit.icon) { used.append(habit.icon) }
        return (used.isEmpty ? [] : [("In use", used)]) + Self.groups.map { ($0.group, $0.emoji.map { $0[0] }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], alignment: .leading, spacing: 4) {
                    ForEach(shown, id: \.name) { group in
                        Section {
                            ForEach(group.emoji, id: \.self) { emoji in
                                Button {
                                    icon = emoji
                                    dismiss()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 30))
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityIdentifier("pick-\(emoji)")
                            }
                        } header: {
                            if !group.name.isEmpty {
                                Text(group.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 12)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("", text: $search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("emoji-search")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { Backdrop() }
    }
}
