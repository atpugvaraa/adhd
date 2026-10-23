import AppKit
import Combine
import Foundation

struct UniversalSearchResult: Identifiable {
    enum Action {
        case launch(URL)
        case open(URL)
        case saveThought(String)
    }

    let title: String
    let detail: String
    let symbol: String
    let action: Action

    var id: String { "\(title)|\(detail)" }
}

/// Owns search matching and actions; the SwiftUI field only edits a query and renders results.
@MainActor
final class UniversalSearchModel: ObservableObject {
    @Published private(set) var results: [UniversalSearchResult] = []
    @Published private(set) var statusMessage: String?

    private let captureThought = CaptureThought()
    private let applications: [ApplicationEntry]

    init() {
        applications = UniversalSearchModel.findApplications()
    }

    func update(query: String) {
        statusMessage = nil
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            return
        }

        if let thought = Self.quotedThought(in: query) {
            results = [UniversalSearchResult(
                title: "Save thought",
                detail: "Keep this wording for later",
                symbol: "quote.bubble",
                action: .saveThought(thought)
            )]
            return
        }

        let searchTerms = Self.searchTerms(from: query)
        let appResults = applications
            .compactMap { app -> (entry: ApplicationEntry, score: Int)? in
                guard let score = Self.score(searchTerms, against: app.name) else { return nil }
                return (app, score)
            }
            .sorted { $0.score == $1.score ? $0.entry.name < $1.entry.name : $0.score > $1.score }
            .prefix(4)
            .map { app in
                UniversalSearchResult(
                    title: app.entry.name,
                    detail: "Application",
                    symbol: "app",
                    action: .launch(app.entry.url)
                )
            }

        let settingsResults = Self.settings
            .compactMap { setting -> (entry: SettingsEntry, score: Int)? in
                guard let score = Self.score(searchTerms, against: setting.title) else { return nil }
                return (setting, score)
            }
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map { setting in
                UniversalSearchResult(
                    title: setting.entry.title,
                    detail: "System Settings",
                    symbol: "gearshape",
                    action: .open(setting.entry.url)
                )
            }

        var webResults: [UniversalSearchResult] = []
        if let url = Self.webURL(from: query) {
            webResults.append(UniversalSearchResult(
                title: "Open \(url.host() ?? query)",
                detail: "Website",
                symbol: "globe",
                action: .open(url)
            ))
        } else {
            webResults.append(UniversalSearchResult(
                title: "Search the web for ‘\(query)’",
                detail: "Web Search",
                symbol: "magnifyingglass",
                action: .open(Self.webSearchURL(for: query))
            ))
        }

        results = Array(appResults + settingsResults + webResults)
    }

    func submit(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let thought = Self.quotedThought(in: trimmed) {
            do {
                try captureThought(thought)
                statusMessage = "Thought saved"
                PerfLog.mark("quick-thought-saved")
            } catch {
                statusMessage = "Couldn’t save thought"
                PerfLog.error("Quick thought save failed: \(error.localizedDescription)")
            }
            return
        }

        guard let first = results.first else { return }
        perform(first)
    }

    func perform(_ result: UniversalSearchResult) {
        switch result.action {
        case .launch(let url):
            let timer = PerfLog.start("universal-search-launch")
            let opened = NSWorkspace.shared.open(url)
            PerfLog.end(timer)
            if !opened { PerfLog.warning("Could not open selected application") }
        case .open(let url):
            let timer = PerfLog.start("universal-search-open-url")
            let opened = NSWorkspace.shared.open(url)
            PerfLog.end(timer)
            if !opened { PerfLog.warning("Could not open selected URL") }
        case .saveThought(let text):
            do {
                try captureThought(text)
                statusMessage = "Thought saved"
                PerfLog.mark("quick-thought-saved")
            } catch {
                statusMessage = "Couldn’t save thought"
                PerfLog.error("Quick thought save failed: \(error.localizedDescription)")
            }
        }
    }

    private struct ApplicationEntry {
        let name: String
        let url: URL
    }

    private struct SettingsEntry {
        let title: String
        let url: URL
    }

    private static let settings: [SettingsEntry] = [
        ("Apple ID", "com.apple.preferences.AppleIDPrefPane"),
        ("Appearance", "com.apple.Appearance-Settings.extension"),
        ("Bluetooth", "com.apple.BluetoothSettings"),
        ("Displays", "com.apple.Displays-Settings.extension"),
        ("Keyboard", "com.apple.Keyboard-Settings.extension"),
        ("Network", "com.apple.Network-Settings.extension"),
        ("Notifications", "com.apple.Notifications-Settings.extension"),
        ("Privacy & Security", "com.apple.settings.PrivacySecurity"),
        ("Sound", "com.apple.Sound-Settings.extension"),
        ("Trackpad", "com.apple.Trackpad-Settings.extension")
    ].compactMap { title, pane in
        URL(string: "x-apple.systempreferences:\(pane)").map { SettingsEntry(title: title, url: $0) }
    }

    private static func findApplications() -> [ApplicationEntry] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
        let timer = PerfLog.start("universal-search-index-apps")
        defer { PerfLog.end(timer) }

        var byPath: [String: ApplicationEntry] = [:]
        for root in roots {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls where url.pathExtension == "app" {
                let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName)
                    ?? url.deletingPathExtension().lastPathComponent
                byPath[url.standardizedFileURL.path] = ApplicationEntry(name: name, url: url)
            }
        }
        PerfLog.info("Indexed \(byPath.count) local applications")
        return byPath.values.sorted { $0.name < $1.name }
    }

    private static func searchTerms(from query: String) -> [String] {
        let normalized = query.lowercased()
        let prefixes = ["open ", "launch ", "app ", "settings ", "setting "]
        var cleaned = query
        if let prefix = prefixes.first(where: normalized.hasPrefix) {
            cleaned = String(query.dropFirst(prefix.count))
        }
        return cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func score(_ terms: [String], against candidate: String) -> Int? {
        guard !terms.isEmpty else { return nil }
        let name = candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        var total = 0
        for term in terms {
            let foldedTerm = term.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            guard let range = name.range(of: foldedTerm) else { return nil }
            total += range.lowerBound == name.startIndex ? 100 : 50
            if name == foldedTerm { total += 100 }
        }
        return total
    }

    private static func quotedThought(in query: String) -> String? {
        guard query.count >= 2, query.first == "\"", query.last == "\"" else { return nil }
        let text = String(query.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func webURL(from query: String) -> URL? {
        let candidate = query.contains("://") ? query : "https://\(query)"
        guard !query.contains(where: \.isWhitespace),
              let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              host.contains(".")
        else { return nil }
        return components.url
    }

    private static func webSearchURL(for query: String) -> URL {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }
}
