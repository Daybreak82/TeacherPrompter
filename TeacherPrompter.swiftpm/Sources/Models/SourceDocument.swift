import Foundation
import SwiftData

@Model
final class SourceDocument {
    @Attribute(.unique) var id: UUID
    var filename: String
    var typeRaw: String
    var language: String?
    var importedAt: Date
    var lesson: Lesson?

    init(id: UUID = UUID(), filename: String, kind: SourceKind, language: String?) {
        self.id = id
        self.filename = filename
        self.typeRaw = kind.rawValue
        self.language = language
        self.importedAt = .now
    }

    var kind: SourceKind {
        SourceKind(rawValue: typeRaw) ?? .text
    }
}
