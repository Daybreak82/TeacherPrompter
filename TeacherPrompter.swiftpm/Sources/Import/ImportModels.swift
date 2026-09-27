import Foundation

enum ImportMode: String, CaseIterable, Identifiable, Sendable {
    /// Recognise sections, labels (Lehrertext:, Frage: …) and slide markers.
    case structured
    /// Simple MVP mode: every paragraph becomes one block.
    case paragraphs

    var id: String { rawValue }
}

enum SourceKind: String, Codable, CaseIterable, Sendable {
    case pdf, pptx, docx, text, markdown, clipboard
}

/// A block proposed by an analyzer. `originalText` is a verbatim excerpt of the source.
struct DraftBlock: Identifiable, Hashable, Sendable {
    let id: UUID
    var type: BlockType
    var text: String
    var originalText: String
    var expectedAnswer: String?
    var notes: String?
    var slideNumber: Int?
    var isImportant: Bool
    var timerDuration: TimeInterval?
    var sourceDocumentID: UUID?
    /// Set by `VerbatimGuard`: `false` if the text could not be found word-for-word in the sources.
    var isVerbatim: Bool

    init(
        id: UUID = UUID(),
        type: BlockType,
        text: String,
        originalText: String? = nil,
        slideNumber: Int? = nil,
        sourceDocumentID: UUID? = nil,
        isImportant: Bool = false,
        timerDuration: TimeInterval? = nil,
        notes: String? = nil,
        expectedAnswer: String? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.originalText = originalText ?? text
        self.slideNumber = slideNumber
        self.sourceDocumentID = sourceDocumentID
        self.isImportant = isImportant
        self.timerDuration = timerDuration
        self.notes = notes
        self.expectedAnswer = expectedAnswer
        self.isVerbatim = true
    }

    var isTextModified: Bool { text != originalText }
}

struct DraftSection: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var blocks: [DraftBlock]

    init(id: UUID = UUID(), title: String, blocks: [DraftBlock] = []) {
        self.id = id
        self.title = title
        self.blocks = blocks
    }
}

/// Output of every analyzer: structure only, words untouched.
struct ParsedScript: Sendable {
    var sections: [DraftSection]
    var suggestedTitle: String?

    var allBlocks: [DraftBlock] { sections.flatMap(\.blocks) }
}

/// Text extracted from one source file, before any structuring.
struct ExtractedDocument: Identifiable, Sendable {
    enum Segment: Sendable {
        case text(String)
        /// A presentation slide. `notes` are the speaker notes (usually the Lehrertext).
        case slide(number: Int, title: String?, body: String, notes: String)
    }

    let id: UUID
    let filename: String
    let kind: SourceKind
    var segments: [Segment]

    init(id: UUID = UUID(), filename: String, kind: SourceKind, segments: [Segment]) {
        self.id = id
        self.filename = filename
        self.kind = kind
        self.segments = segments
    }

    /// Everything the document contains, used for language detection and the verbatim check.
    var plainText: String {
        segments.map { segment -> String in
            switch segment {
            case .text(let text):
                return text
            case let .slide(_, title, body, notes):
                return [title ?? "", body, notes].joined(separator: "\n")
            }
        }
        .joined(separator: "\n\n")
    }
}
