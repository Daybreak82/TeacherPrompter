import Foundation
import NaturalLanguage
import Observation
import SwiftData

enum ImportTarget {
    case newLesson
    case append(Lesson)
}

/// Editable result of an analysis, shown in the import preview. Nothing is saved until `commit`.
@Observable
final class ImportDraft: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var subject = ""
    var classLevel = ""
    var language: String
    var sections: [DraftSection]
    let sources: [ExtractedDocument]
    let sourceLanguages: [UUID: String]

    init(script: ParsedScript, sources: [ExtractedDocument], fallbackTitle: String) {
        self.sections = script.sections
        self.sources = sources
        var languages: [UUID: String] = [:]
        for source in sources {
            if let language = LanguageDetector.detect(source.plainText) { languages[source.id] = language }
        }
        self.sourceLanguages = languages
        self.language = LanguageDetector.detect(sources.map(\.plainText).joined(separator: "\n")) ?? "de"
        let fileTitle = sources.first.map { ($0.filename as NSString).deletingPathExtension } ?? ""
        self.title = script.suggestedTitle ?? (fileTitle.isEmpty ? fallbackTitle : fileTitle)
    }

    static func == (lhs: ImportDraft, rhs: ImportDraft) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var blockCount: Int { sections.reduce(0) { $0 + $1.blocks.count } }
    var nonVerbatimCount: Int { sections.flatMap(\.blocks).filter { !$0.isVerbatim }.count }

    // MARK: Editing (structure only; text changes happen in the block editor on explicit request)

    func block(with id: UUID) -> DraftBlock? {
        guard let position = locate(id) else { return nil }
        let (s, b) = position
        return sections[s].blocks[b]
    }

    func update(_ block: DraftBlock) {
        guard let position = locate(block.id) else { return }
        let (s, b) = position
        sections[s].blocks[b] = block
    }

    func setType(_ type: BlockType, for id: UUID) {
        guard let position = locate(id) else { return }
        let (s, b) = position
        sections[s].blocks[b].type = type
    }

    func delete(_ id: UUID) {
        guard let position = locate(id) else { return }
        let (s, b) = position
        sections[s].blocks.remove(at: b)
    }

    func deleteBlocks(in sectionID: UUID, at offsets: IndexSet) {
        guard let s = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[s].blocks.remove(atOffsets: offsets)
    }

    func moveBlocks(in sectionID: UUID, from source: IndexSet, to destination: Int) {
        guard let s = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[s].blocks.move(fromOffsets: source, toOffset: destination)
    }

    func renameSection(_ sectionID: UUID, to title: String) {
        guard let s = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[s].title = title
    }

    func canMergeWithNext(_ id: UUID) -> Bool {
        guard let position = locate(id) else { return false }
        let (s, b) = position
        return b + 1 < sections[s].blocks.count
    }

    /// Joins two neighbouring blocks with a line break. Both texts stay word-for-word.
    func mergeWithNext(_ id: UUID) {
        guard let position = locate(id) else { return }
        let (s, b) = position
        guard b + 1 < sections[s].blocks.count else { return }
        let next = sections[s].blocks[b + 1]
        sections[s].blocks[b].text += "\n" + next.text
        sections[s].blocks[b].originalText += "\n" + next.originalText
        if sections[s].blocks[b].slideNumber == nil { sections[s].blocks[b].slideNumber = next.slideNumber }
        sections[s].blocks[b].isImportant = sections[s].blocks[b].isImportant || next.isImportant
        sections[s].blocks[b].isVerbatim = sections[s].blocks[b].isVerbatim && next.isVerbatim
        sections[s].blocks.remove(at: b + 1)
    }

    func canSplit(_ id: UUID) -> Bool {
        guard let block = block(with: id) else { return false }
        return Self.pieces(of: block.text).count > 1
    }

    /// Splits at line breaks, or – for a single line – at sentence boundaries.
    /// Every piece is an exact substring of the original text.
    func split(_ id: UUID) {
        guard let position = locate(id) else { return }
        let (s, b) = position
        let block = sections[s].blocks[b]
        let pieces = Self.pieces(of: block.text)
        guard pieces.count > 1 else { return }
        let unchanged = !block.isTextModified
        let newBlocks = pieces.enumerated().map { index, piece -> DraftBlock in
            var copy = DraftBlock(
                type: block.type,
                text: piece,
                originalText: unchanged ? piece : (index == 0 ? block.originalText : piece),
                slideNumber: block.slideNumber,
                sourceDocumentID: block.sourceDocumentID,
                isImportant: block.isImportant,
                timerDuration: index == 0 ? block.timerDuration : nil,
                notes: index == 0 ? block.notes : nil,
                expectedAnswer: index == pieces.count - 1 ? block.expectedAnswer : nil
            )
            copy.isVerbatim = block.isVerbatim
            return copy
        }
        sections[s].blocks.replaceSubrange(b...b, with: newBlocks)
    }

    static func pieces(of text: String) -> [String] {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if lines.count > 1 { return lines }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        return sentences
    }

    private func locate(_ id: UUID) -> (Int, Int)? {
        for (s, section) in sections.enumerated() {
            if let b = section.blocks.firstIndex(where: { $0.id == id }) { return (s, b) }
        }
        return nil
    }

    // MARK: Commit

    @MainActor
    @discardableResult
    func commit(to target: ImportTarget, context: ModelContext, untitled: String) -> Lesson {
        let lesson: Lesson
        switch target {
        case .newLesson:
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            lesson = Lesson(title: cleanTitle.isEmpty ? untitled : cleanTitle, subject: subject,
                            classLevel: classLevel, language: language)
            context.insert(lesson)
        case .append(let existing):
            lesson = existing
        }

        for source in sources {
            let document = SourceDocument(id: source.id, filename: source.filename, kind: source.kind,
                                          language: sourceLanguages[source.id])
            lesson.sourceDocuments.append(document)
        }

        var nextOrder = (lesson.sections.map(\.order).max() ?? -1) + 1
        for draftSection in sections where !draftSection.blocks.isEmpty || !draftSection.title.isEmpty {
            let section: LessonSection
            if draftSection.title.isEmpty, let last = lesson.orderedSections.last {
                section = last
            } else {
                section = LessonSection(title: draftSection.title, order: nextOrder)
                nextOrder += 1
                lesson.sections.append(section)
            }
            var order = section.nextBlockOrder
            for draft in draftSection.blocks {
                let block = LessonBlock(
                    type: draft.type,
                    text: draft.text,
                    originalText: draft.originalText,
                    order: order,
                    slideNumber: draft.slideNumber,
                    isImportant: draft.isImportant,
                    expectedAnswer: draft.expectedAnswer,
                    notes: draft.notes,
                    timerDuration: draft.timerDuration,
                    sourceDocumentID: draft.sourceDocumentID
                )
                order += 1
                section.blocks.append(block)
            }
        }
        lesson.modifiedAt = .now
        try? context.save()
        return lesson
    }
}
