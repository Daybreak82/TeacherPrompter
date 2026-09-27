import Foundation

/// Future AI features (style suggestions, translation) produce *suggestions* – never edits.
/// A suggestion lives next to the block text; the block changes only when the teacher
/// explicitly chooses `.accept` or edits the suggestion. The default decision is `.keepOriginal`.
struct TextSuggestion: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case rephrase
        case translation
    }

    enum Decision: Sendable {
        case keepOriginal
        case accept
        case edited(String)
    }

    let id: UUID
    let blockID: UUID
    let kind: Kind
    let original: String
    let suggestion: String
    /// For translations: target language code.
    let targetLanguage: String?

    init(id: UUID = UUID(), blockID: UUID, kind: Kind, original: String, suggestion: String, targetLanguage: String? = nil) {
        self.id = id
        self.blockID = blockID
        self.kind = kind
        self.original = original
        self.suggestion = suggestion
        self.targetLanguage = targetLanguage
    }

    static let defaultDecision: Decision = .keepOriginal

    /// Applies a decision. Only `.accept` / `.edited` change the block – via the same explicit
    /// user-edit path as manual editing, so `originalText` stays untouched.
    @MainActor
    func apply(_ decision: Decision, to block: LessonBlock) {
        guard block.id == blockID else { return }
        switch decision {
        case .keepOriginal:
            break
        case .accept:
            block.applyUserEdit(suggestion)
        case .edited(let text):
            block.applyUserEdit(text)
        }
    }
}
