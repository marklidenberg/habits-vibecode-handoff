import HabitsKit
import SwiftUI

@main
struct HabitsApp: App {
    static let cloud = Demo.isOn ? nil : CloudStore()
    @State var store = HabitsApp.cloud?.store ?? Demo.store()
    @Environment(\.scenePhase) var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onChange(of: phase) { if phase == .active { store.sync() } }
        }
    }
}

struct RootView: View {
    @Environment(Store.self) var store

    var body: some View {
        NavigationStack {
            GridView()
                .background(Backdrop())
        }
        .tint(Color(hex: store.color))
        .preferredColorScheme(.dark)
    }
}
