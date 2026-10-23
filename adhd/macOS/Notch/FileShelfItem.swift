import Foundation
import UniformTypeIdentifiers

/// A reference to a file staged in the shelf. The shelf never owns or deletes
/// the original file; it stores a bookmark so the file can be resolved later.
struct FileShelfItem: Codable, Identifiable, Equatable {
    let id: UUID
    let bookmarkData: Data
    let displayName: String
    let addedAt: Date

    init?(url: URL, id: UUID = UUID(), addedAt: Date = .now) {
        guard url.isFileURL,
              let bookmarkData = try? url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
              )
        else {
            return nil
        }

        self.id = id
        self.bookmarkData = bookmarkData
        self.displayName = url.lastPathComponent
        self.addedAt = addedAt
    }

    var resolvedURL: URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    var symbolName: String {
        guard let url = resolvedURL else { return "doc.questionmark" }

        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return "folder"
        }

        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .image) { return "photo" }
            if type.conforms(to: .movie) { return "film" }
            if type.conforms(to: .audio) { return "waveform" }
            if type.conforms(to: .pdf) { return "doc.richtext" }
        }

        return "doc"
    }
}
