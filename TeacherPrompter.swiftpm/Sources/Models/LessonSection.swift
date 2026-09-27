import Foundation
import SwiftData

@Model
final class LessonSection {
    @Attribute(.unique) var id: UUID
    /// Title exactly as written by the teacher / found in the source (e.g. "EINSTIEG").
    var title: String
    var order: Int
    var lesson: Lesson?
    @Relationship(deleteRule: .cascade, inverse: \LessonBlock.section)
    var blocks: [LessonBlock] = []

    init(title: String, order: Int) {
        self.id = UUID()
        self.title = title
        self.order = order
    }

    var orderedBlocks: [LessonBlock] {
        blocks.sorted { $0.order < $1.order }
    }

    var nextBlockOrder: Int {
        (blocks.map(\.order).max() ?? -1) + 1
    }
}
