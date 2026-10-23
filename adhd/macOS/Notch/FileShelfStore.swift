import AppKit
import Combine
import Foundation

/// Owns the local shelf list and its persistence. Removing an entry only
/// removes the reference from this list; it never deletes the source file.
@MainActor
final class FileShelfStore: ObservableObject {
    static let shared = FileShelfStore()

    @Published private(set) var items: [FileShelfItem]
    @Published private(set) var isLoading = false

    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let shelfDirectory = supportDirectory
            .appendingPathComponent("adhd", isDirectory: true)
            .appendingPathComponent("Shelf", isDirectory: true)
        storageURL = shelfDirectory.appendingPathComponent("items.json")

        do {
            try FileManager.default.createDirectory(
                at: shelfDirectory,
                withIntermediateDirectories: true
            )
            if let data = try? Data(contentsOf: storageURL) {
                items = try decoder.decode([FileShelfItem].self, from: data)
            } else {
                items = []
            }
            PerfLog.info("File shelf loaded \(items.count) item(s)")
        } catch {
            items = []
            PerfLog.error("Could not load file shelf: \(error.localizedDescription)")
        }
    }

    func stage(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty, !isLoading else { return }

        isLoading = true
        let timer = PerfLog.start("file-shelf-stage")
        Task { @MainActor [weak self] in
            let stagedItems = await ShelfDropService.items(from: providers)
            guard let self else { return }

            add(stagedItems)
            isLoading = false
            PerfLog.end(timer)
            PerfLog.info("File shelf staged \(stagedItems.count) item(s)")
        }
    }

    func remove(_ item: FileShelfItem) {
        items.removeAll { $0.id == item.id }
        persist()
        PerfLog.debug("Removed file reference from shelf; source preserved")
    }

    func open(_ item: FileShelfItem) {
        guard let url = item.resolvedURL,
              FileManager.default.fileExists(atPath: url.path)
        else {
            PerfLog.warning("Could not open staged file because it is unavailable")
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func add(_ newItems: [FileShelfItem]) {
        guard !newItems.isEmpty else { return }

        var knownPaths = Set(items.compactMap { $0.resolvedURL?.standardizedFileURL.path })
        let additions = newItems.filter { item in
            guard let path = item.resolvedURL?.standardizedFileURL.path else { return true }
            return knownPaths.insert(path).inserted
        }

        guard !additions.isEmpty else { return }
        items = additions.reversed() + items
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            PerfLog.error("Could not save file shelf: \(error.localizedDescription)")
        }
    }
}
