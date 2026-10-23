import Foundation

/// Small local JSON store for quick captures. It does not sync or rewrite source files.
struct LocalThoughtStore: ThoughtRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let supportDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.fileURL = supportDirectory
                .appendingPathComponent("adhd/Thoughts", isDirectory: true)
                .appendingPathComponent("thoughts.json")
        }
    }

    func save(_ thought: Thought) throws {
        let timer = PerfLog.start("thought-save")
        defer { PerfLog.end(timer) }

        var thoughts = try fetchAll()
        thoughts.insert(thought, at: 0)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(thoughts).write(to: fileURL, options: .atomic)
        PerfLog.info("Saved a thought locally")
    }

    func fetchAll() throws -> [Thought] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([Thought].self, from: Data(contentsOf: fileURL))
    }
}
