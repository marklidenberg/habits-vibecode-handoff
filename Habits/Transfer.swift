import HabitsKit
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// The export: written when shared
struct Export: Transferable {
    let contents: HabitFile.Contents

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .gzip) { export in
            let url = URL.temporaryDirectory.appending(path: HabitFile.name())
            try HabitFile.write(export.contents).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        .suggestedFileName(HabitFile.name())
    }
}

/// Export to the share sheet, import from Files — confirmed, then everything replaced
struct TransferSection: View {
    @Environment(Store.self) var store
    @State var picking = false
    @State var picked: HabitFile.Contents?
    @State var failed = false

    var body: some View {
        Section {
            ShareLink(item: Export(contents: store.contents), preview: SharePreview(HabitFile.name())) {
                Text("Export")
            }
            .accessibilityIdentifier("export")
            Button("Import") { picking = true }
                .accessibilityIdentifier("import")
        }
        .listRowBackground(Rows())
        .fileImporter(isPresented: $picking, allowedContentTypes: [.gzip, .json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                picked = try HabitFile.read(try Data(contentsOf: url))
            } catch {
                failed = true
            }
        }
        .alert("Replaces every habit and all history", isPresented: Binding(get: { picked != nil }, set: { if !$0 { picked = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) {
                if let picked { store.replace(with: picked) }
            }
        }
        .alert("Can't read the file", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        }
    }
}
