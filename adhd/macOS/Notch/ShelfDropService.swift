import AppKit
import Foundation
import UniformTypeIdentifiers

/// Converts Finder drag providers into durable shelf references.
@MainActor
enum ShelfDropService {
    static func items(from providers: [NSItemProvider]) async -> [FileShelfItem] {
        var items: [FileShelfItem] = []

        for provider in providers {
            guard let url = await fileURL(from: provider) else {
                PerfLog.warning("A dropped item did not provide a file URL")
                continue
            }

            if let item = FileShelfItem(url: url) {
                items.append(item)
            } else {
                PerfLog.warning("Could not create a shelf reference for a dropped file")
            }
        }

        return items
    }

    private static func fileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier,
                options: nil
            ) { item, error in
                if let error {
                    PerfLog.warning("Could not read dropped file URL: \(error.localizedDescription)")
                }
                continuation.resume(returning: decodeFileURL(item))
            }
        }
    }

    nonisolated private static func decodeFileURL(_ item: NSSecureCoding?) -> URL? {
        if let url = item as? URL, url.isFileURL { return url }
        if let url = item as? NSURL, (url as URL).isFileURL { return url as URL }
        if let data = item as? Data {
            guard let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL else {
                return nil
            }
            return url
        }
        if let string = item as? String, let url = URL(string: string), url.isFileURL {
            return url
        }
        return nil
    }
}
