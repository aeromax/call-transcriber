import Foundation
import SwiftData

final class PersistenceController {
    static let shared = PersistenceController(inMemory: false)

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([Recording.self, Transcript.self, TranscriptSegment.self, Speaker.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static let preview = PersistenceController(inMemory: true)
}
