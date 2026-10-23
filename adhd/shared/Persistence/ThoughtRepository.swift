import Foundation

protocol ThoughtRepository {
    func save(_ thought: Thought) throws
    func fetchAll() throws -> [Thought]
}
