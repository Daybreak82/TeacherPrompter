import Foundation
import SwiftData

/// One step of the lesson script.
///
/// Text ownership rule ("the teacher owns the words"):
/// - `originalText` is written exactly once, at import time, and is never changed by the app.
/// - `text` is the working copy. It starts equal to `originalText` and changes **only** through
///   `applyUserEdit(_:)` / `restoreOriginal()`, i.e. through an explicit user action.
@Model
final class LessonBlock {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var originalText: String?
    var text: String
    var expectedAnswer: String?
    var isCompleted: Bool
    var isImportant: Bool
    var isSkipped: Bool
    var estimatedDuration: TimeInterval?
    var timerDuration: TimeInterval?
    var slideNumber: Int?
    var notes: String?
    var sourceDocumentID: UUID?
    var order: Int
    var textEditedAt: Date?
    var section: LessonSection?

    init(
        type: BlockType,
        text: String,
        originalText: String? = nil,
        order: Int = 0,
        slideNumber: Int? = nil,
        isImportant: Bool = false,
        expectedAnswer: String? = nil,
        notes: String? = nil,
        timerDuration: TimeInterval? = nil,
        estimatedDuration: TimeInterval? = nil,
        sourceDocumentID: UUID? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.text = text
        self.originalText = originalText
        self.order = order
        self.slideNumber = slideNumber
        self.isImportant = isImportant
        self.expectedAnswer = expectedAnswer
        self.notes = notes
        self.timerDuration = timerDuration
        self.estimatedDuration = estimatedDuration
        self.sourceDocumentID = sourceDocumentID
        self.isCompleted = false
        self.isSkipped = false
    }

    var type: BlockType {
        get { BlockType(rawValue: typeRaw) ?? .say }
        set { typeRaw = newValue.rawValue }
    }

    var isDone: Bool { isCompleted || isSkipped }

    /// `true` when the teacher changed the imported wording.
    var isTextModified: Bool {
        guard let originalText else { return false }
        return originalText != text
    }

    /// The only way the working text changes: an explicit edit by the user.
    func applyUserEdit(_ newText: String) {
        guard newText != text else { return }
        text = newText
        textEditedAt = .now
    }

    /// Explicit user action: go back to the imported wording.
    func restoreOriginal() {
        guard let originalText else { return }
        text = originalText
        textEditedAt = nil
    }
}
