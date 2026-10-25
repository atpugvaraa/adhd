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
    @Published private(set) var selectedIndex = 0
    @Published private(set) var completedActionCount = 0

    private let captureThought = CaptureThought()
    private let applications: [ApplicationEntry]
    private let usageStore = ApplicationUsageStore.shared

    init() {
        applications = UniversalSearchModel.findApplications()
    }

    func update(query: String) {
        statusMessage = nil
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            setResults([])
            return
        }

        if let thought = Self.quotedThought(in: query) {
            setResults([UniversalSearchResult(
                title: "Save thought",
                detail: "Keep this wording for later",
                symbol: "quote.bubble",
                action: .saveThought(thought)
            )])
            return
        }

        let searchTerms = Self.searchTerms(from: query)
        let timer = PerfLog.start("universal-search-match")
        defer { PerfLog.end(timer) }

        let appResults = applications
            .compactMap { app -> RankedResult? in
                guard let matchScore = Self.score(searchTerms, against: app.name) else { return nil }
                let usageScore = usageStore.rankingBoost(for: app.usageKey)
                return RankedResult(
                    result: UniversalSearchResult(
                        title: app.name,
                        detail: "Application",
                        symbol: "app",
                        action: .launch(app.url)
                    ),
                    score: matchScore + usageScore
                )
            }
            .sorted {
                $0.score == $1.score
                    ? $0.result.title.localizedCaseInsensitiveCompare($1.result.title) == .orderedAscending
                    : $0.score > $1.score
            }

        let settingsResults = Self.settings
            .compactMap { setting -> RankedResult? in
                let score = ([setting.title] + setting.aliases)
                    .compactMap { Self.score(searchTerms, against: $0) }
                    .max()
                guard let score else { return nil }
                return RankedResult(
                    result: UniversalSearchResult(
                        title: setting.title,
                        detail: "System Settings",
                        symbol: "gearshape",
                        action: .open(setting.url)
                    ),
                    score: score
                )
            }
            .sorted {
                $0.score == $1.score
                    ? $0.result.title.localizedCaseInsensitiveCompare($1.result.title) == .orderedAscending
                    : $0.score > $1.score
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

        let visibleResults = appResults.prefix(2).map(\.result)
            + settingsResults.prefix(2).map(\.result)
            + Array(webResults.prefix(1))
        setResults(visibleResults)
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    func submit(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard results.indices.contains(selectedIndex) else { return }
        perform(results[selectedIndex])
    }

    func perform(_ result: UniversalSearchResult) {
        switch result.action {
        case .launch(let url):
            let application = applications.first { $0.url == url }
            if let application {
                usageStore.recordSearch(for: application.usageKey)
            }

            let timer = PerfLog.start("universal-search-launch")
            let opened = NSWorkspace.shared.open(url)
            PerfLog.end(timer)
            if opened, let application {
                usageStore.recordOpen(for: application.usageKey)
            } else if !opened {
                PerfLog.warning("Could not open selected application")
            }
            if opened { completeAction() }
        case .open(let url):
            let timer = PerfLog.start("universal-search-open-url")
            let opened = NSWorkspace.shared.open(url)
            PerfLog.end(timer)
            if opened {
                completeAction()
            } else {
                PerfLog.warning("Could not open selected URL")
            }
        case .saveThought(let text):
            do {
                try captureThought(text)
                statusMessage = "Thought saved"
                PerfLog.mark("quick-thought-saved")
                completeAction()
            } catch {
                statusMessage = "Couldn’t save thought"
                PerfLog.error("Quick thought save failed: \(error.localizedDescription)")
            }
        }
    }

    private func completeAction() {
        completedActionCount += 1
        PerfLog.mark("universal-search-action-completed")
    }

    private struct ApplicationEntry {
        let name: String
        let url: URL
        let bundleIdentifier: String?

        var usageKey: String { bundleIdentifier ?? url.standardizedFileURL.path }
    }

    private func setResults(_ newResults: [UniversalSearchResult]) {
        results = newResults
        selectedIndex = 0
    }

    private struct SettingsEntry {
        let title: String
        let aliases: [String]
        let url: URL
    }

    private struct RankedResult {
        let result: UniversalSearchResult
        let score: Double
    }

    private static let settings: [SettingsEntry] = [
        ("Apple ID", ["account", "icloud"], "com.apple.preferences.AppleIDPrefPane"),
        ("Appearance", ["theme", "dark mode", "light mode"], "com.apple.Appearance-Settings.extension"),
        ("Bluetooth", ["devices", "wireless"], "com.apple.BluetoothSettings"),
        ("Displays", ["display", "screen", "monitor", "resolution", "arrangement"], "com.apple.Displays-Settings.extension"),
        ("Keyboard", ["key repeat", "input source", "keyboard shortcuts"], "com.apple.Keyboard-Settings.extension"),
        ("Network", ["wifi", "wi-fi", "internet"], "com.apple.Network-Settings.extension"),
        ("Notifications", ["alerts", "banners"], "com.apple.Notifications-Settings.extension"),
        ("Privacy & Security", ["privacy", "permissions", "security"], "com.apple.settings.PrivacySecurity"),
        ("Sound", ["audio", "output", "input", "volume"], "com.apple.Sound-Settings.extension"),
        ("Trackpad", ["gestures", "pointer"], "com.apple.Trackpad-Settings.extension")
    ].compactMap { title, aliases, pane in
        URL(string: "x-apple.systempreferences:\(pane)").map {
            SettingsEntry(title: title, aliases: aliases, url: $0)
        }
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
                guard !excludedApplicationNames.contains(normalizedApplicationName(name)) else { continue }
                byPath[url.standardizedFileURL.path] = ApplicationEntry(
                    name: name,
                    url: url,
                    bundleIdentifier: Bundle(url: url)?.bundleIdentifier
                )
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

    private static let excludedApplicationNames: Set<String> = [
        "dictionary",
        "digital color meter",
        "screenshot",
        "script editor",
        "screen sharing"
    ]

    private static func normalizedApplicationName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func score(_ terms: [String], against candidate: String) -> Double? {
        guard !terms.isEmpty, terms.joined().count >= 2 else { return nil }
        let words = candidate
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        guard !words.isEmpty else { return nil }

        let similarities = terms.map { term -> Double in
            let foldedTerm = term.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: nil
            )
            return words.map { word in
                if word == foldedTerm { return 1.0 }
                if word.hasPrefix(foldedTerm) || foldedTerm.hasPrefix(word) { return 0.92 }

                let queryCharacters = Array(foldedTerm)
                var unmatchedCharacters = Array(word)
                var sharedCharacterCount = 0
                for character in queryCharacters {
                    if let index = unmatchedCharacters.firstIndex(of: character) {
                        unmatchedCharacters.remove(at: index)
                        sharedCharacterCount += 1
                    }
                }
                let characterCoverage = Double(sharedCharacterCount) / Double(queryCharacters.count)
                let similarity = jaroWinkler(foldedTerm, word)
                return characterCoverage >= 0.72 && similarity >= 0.82 ? similarity : 0
            }.max() ?? 0
        }

        guard similarities.allSatisfy({ $0 >= 0.72 }) else { return nil }
        let average = similarities.reduce(0, +) / Double(similarities.count)
        let joinedQuery = terms.joined().lowercased()
        let joinedName = words.joined().lowercased()
        let exactBonus = joinedName == joinedQuery ? 25.0 : 0
        return average * 100 + exactBonus
    }

    /// Jaro-Winkler favors close spellings and shared prefixes, as in common launcher search.
    private static func jaroWinkler(_ lhs: String, _ rhs: String) -> Double {
        let left = Array(lhs)
        let right = Array(rhs)
        guard !left.isEmpty, !right.isEmpty else { return left == right ? 1 : 0 }
        if left == right { return 1 }

        let matchDistance = max(max(left.count, right.count) / 2 - 1, 0)
        var leftMatched = Array(repeating: false, count: left.count)
        var rightMatched = Array(repeating: false, count: right.count)
        var matches = 0

        for leftIndex in left.indices {
            let lowerBound = max(0, leftIndex - matchDistance)
            let upperBound = min(leftIndex + matchDistance + 1, right.count)
            guard lowerBound < upperBound else { continue }

            for rightIndex in lowerBound..<upperBound where !rightMatched[rightIndex] {
                guard left[leftIndex] == right[rightIndex] else { continue }
                leftMatched[leftIndex] = true
                rightMatched[rightIndex] = true
                matches += 1
                break
            }
        }

        guard matches > 0 else { return 0 }
        let matchedLeft = left.indices.compactMap { leftMatched[$0] ? left[$0] : nil }
        let matchedRight = right.indices.compactMap { rightMatched[$0] ? right[$0] : nil }
        let transpositions = zip(matchedLeft, matchedRight)
            .filter { $0.0 != $0.1 }
            .count / 2
        let matchCount = Double(matches)
        let jaro = (
            matchCount / Double(left.count)
                + matchCount / Double(right.count)
                + (matchCount - Double(transpositions)) / matchCount
        ) / 3

        let prefixLength = zip(left, right)
            .prefix(while: { $0.0 == $0.1 })
            .prefix(4)
            .count
        return jaro + Double(prefixLength) * 0.1 * (1 - jaro)
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

/// Stores lightweight local search and app-activation counts for ranking suggestions.
@MainActor
private final class ApplicationUsageStore {
    static let shared = ApplicationUsageStore()

    private struct Counts: Codable {
        var searches = 0
        var uses = 0
        var opens = 0
    }

    private let defaultsKey = "universal-search.application-usage.v1"
    private var countsByApplication: [String: Counts]
    private var activationObserver: NSObjectProtocol?

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Counts].self, from: data) {
            countsByApplication = decoded
        } else {
            countsByApplication = [:]
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleIdentifier = application.bundleIdentifier
            else { return }

            Task { @MainActor [weak self] in
                self?.recordUse(for: bundleIdentifier)
            }
        }
    }

    func rankingBoost(for key: String) -> Double {
        guard let counts = countsByApplication[key] else { return 0 }
        let weightedCount = Double(counts.searches)
            + Double(counts.uses) * 2
            + Double(counts.opens) * 3
        return min(log1p(weightedCount) * 2, 12)
    }

    func recordSearch(for key: String) {
        countsByApplication[key, default: Counts()].searches += 1
        persist()
        PerfLog.mark("universal-search-app-selected")
    }

    func recordOpen(for key: String) {
        countsByApplication[key, default: Counts()].opens += 1
        persist()
        PerfLog.mark("universal-search-app-opened")
    }

    private func recordUse(for bundleIdentifier: String) {
        countsByApplication[bundleIdentifier, default: Counts()].uses += 1
        persist()
        PerfLog.mark("universal-search-app-activated")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(countsByApplication) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
