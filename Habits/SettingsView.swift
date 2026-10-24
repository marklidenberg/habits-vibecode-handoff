import HabitsKit
import SwiftUI

/// Settings, a page of its own
struct SettingsView: View {
    @Environment(Store.self) var store
    @AppStorage("style") var style = "pills"
    @AppStorage("chime") var chime = Chime.off

    static let presets = [
        "#8fa2ff", "#34c759", "#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f",
        "#ff453a", "#ff9f0a", "#ffd60a", "#64d2ff", "#e5e5ea",
    ]

    var body: some View {
        Form {
            Section {
                colors
            }
            .listRowBackground(Rows())
            Section {
                Picker("Style", selection: $style) {
                    Text("Pills").tag("pills")
                    Text("Tiles").tag("tiles")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("style")
                Picker("Sound", selection: $chime) {
                    ForEach(Chime.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .onChange(of: chime) { chime.play() }
                .accessibilityIdentifier("sound")
            }
            .listRowBackground(Rows())
            Section {
                NavigationLink("Archive") {
                    ArchiveView()
                }
                .accessibilityIdentifier("archive")
            }
            .listRowBackground(Rows())
            TransferSection()
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop())
    }

    var colors: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 14) {
            ForEach(Self.presets, id: \.self) { hex in
                Button {
                    store.color = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 38, height: 38)
                        .padding(4)
                        .overlay {
                            if store.color == hex {
                                Circle().stroke(.white, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("color-\(hex)")
            }
            ColorPicker("", selection: custom, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.35)
                .frame(width: 46, height: 46)
                .overlay {
                    if !Self.presets.contains(store.color) {
                        Circle().stroke(.white, lineWidth: 2)
                    }
                }
                .accessibilityIdentifier("color-custom")
        }
        .padding(.vertical, 6)
    }

    var custom: Binding<Color> {
        Binding(
            get: { Color(hex: store.color) },
            set: { store.color = $0.hex })
    }
}
