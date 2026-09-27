import Foundation
import SwiftData

@Model
final class Lesson {
    @Attribute(.unique) var id: UUID
    var title: String
    var subject: String
    var classLevel: String
    /// BCP-47 code of the *content* language (e.g. "de"). Independent of the UI language.
    var language: String
    @Relationship(deleteRule: .cascade, inverse: \LessonSection.lesson)
    var sections: [LessonSection] = []
    /// Persisted lesson position. `nil` means "first open block".
    var currentBlockID: UUID?
    var createdAt: Date
    var modifiedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \SourceDocument.lesson)
    var sourceDocuments: [SourceDocument] = []
    var plannedMinutes: Int = 45
    /// Time spent in Lesson Mode (pauses excluded).
    var elapsedSeconds: Double = 0

    init(title: String, subject: String = "", classLevel: String = "", language: String = "de", plannedMinutes: Int = 45) {
        self.id = UUID()
        self.title = title
        self.subject = subject
        self.classLevel = classLevel
        self.language = language
        self.plannedMinutes = plannedMinutes
        self.createdAt = .now
        self.modifiedAt = .now
    }

    /// SwiftData does not keep to-many relationships ordered, so every level carries an `order`.
    var orderedSections: [LessonSection] {
        sections.sorted { $0.order < $1.order }
    }

    var orderedBlocks: [LessonBlock] {
        orderedSections.flatMap(\.orderedBlocks)
    }

    var groupTitle: String {
        [subject, classLevel].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
