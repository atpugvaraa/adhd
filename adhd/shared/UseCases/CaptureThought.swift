import Foundation

struct CaptureThought {
    private let repository: any ThoughtRepository

    init(repository: any ThoughtRepository = LocalThoughtStore()) {
        self.repository = repository
    }

    @discardableResult
    func callAsFunction(_ text: String) throws -> Thought {
        let thought = Thought(text: text)
        try repository.save(thought)
        return thought
    }
}
