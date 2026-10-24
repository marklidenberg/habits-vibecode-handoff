import HabitsKit
import Foundation

/// The store in iCloud Drive, `habits.json`, watched; on the device where iCloud is off
@MainActor
final class CloudStore: NSObject, NSFilePresenter {
    let store: Store
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue.main

    override init() {
        let support = URL.applicationSupportDirectory
        let local = support.appending(path: "habits.json")
        let cloud = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appending(path: "Documents/habits.json")
        presentedItemURL = cloud ?? local
        store = Store(url: presentedItemURL)
        super.init()
        store.presenter = self
        NSFileCoordinator.addFilePresenter(self)

        guard store.sync() else { return }
        if cloud != nil, FileManager.default.fileExists(atPath: local.path) {
            let device = Store(url: local)
            store.adopt(device.habits, color: device.color)
            if store.sync() { try? FileManager.default.removeItem(at: local) }
        }
    }

    nonisolated func presentedItemDidChange() {
        MainActor.assumeIsolated { store.sync() }
    }

    nonisolated func presentedItemDidGain(_ version: NSFileVersion) {
        MainActor.assumeIsolated { store.sync() }
    }
}
