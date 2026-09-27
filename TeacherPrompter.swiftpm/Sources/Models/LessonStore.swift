import Foundation
import SwiftData

/// All structural lesson operations in one place. None of them changes block text.
@MainActor
enum LessonStore {
    @discardableResult
    static func createLesson(title: String, subject: String, classLevel: String, language: String,
                             plannedMinutes: Int, firstSectionTitle: String, in context: ModelContext) -> Lesson {
        let lesson = Lesson(title: title, subject: subject, classLevel: classLevel, language: language,
                            plannedMinutes: plannedMinutes)
        context.insert(lesson)
        lesson.sections.append(LessonSection(title: firstSectionTitle, order: 0))
        try? context.save()
        return lesson
    }

    @discardableResult
    static func duplicate(_ lesson: Lesson, titleSuffix: String, in context: ModelContext) -> Lesson {
        let copy = Lesson(title: lesson.title + titleSuffix, subject: lesson.subject, classLevel: lesson.classLevel,
                          language: lesson.language, plannedMinutes: lesson.plannedMinutes)
        context.insert(copy)

        var documentIDs: [UUID: UUID] = [:]
        for document in lesson.sourceDocuments {
            let newDocument = SourceDocument(filename: document.filename, kind: document.kind, language: document.language)
            documentIDs[document.id] = newDocument.id
            copy.sourceDocuments.append(newDocument)
        }

        for section in lesson.orderedSections {
            let newSection = LessonSection(title: section.title, order: section.order)
            copy.sections.append(newSection)
            for block in section.orderedBlocks {
                let newBlock = LessonBlock(
                    type: block.type,
                    text: block.text,
                    originalText: block.originalText,
                    order: block.order,
                    slideNumber: block.slideNumber,
                    isImportant: block.isImportant,
                    expectedAnswer: block.expectedAnswer,
                    notes: block.notes,
                    timerDuration: block.timerDuration,
                    estimatedDuration: block.estimatedDuration,
                    sourceDocumentID: block.sourceDocumentID.flatMap { documentIDs[$0] }
                )
                newBlock.textEditedAt = block.textEditedAt
                newSection.blocks.append(newBlock)
            }
        }
        try? context.save()
        return copy
    }

    static func resetProgress(_ lesson: Lesson) {
        for block in lesson.sections.flatMap(\.blocks) {
            block.isCompleted = false
            block.isSkipped = false
        }
        lesson.currentBlockID = nil
        lesson.elapsedSeconds = 0
        try? lesson.modelContext?.save()
    }

    static func delete(_ lesson: Lesson, in context: ModelContext) {
        context.delete(lesson)
        try? context.save()
    }

    // MARK: Sections

    @discardableResult
    static func addSection(title: String, to lesson: Lesson) -> LessonSection {
        let order = (lesson.sections.map(\.order).max() ?? -1) + 1
        let section = LessonSection(title: title, order: order)
        lesson.sections.append(section)
        touch(lesson)
        return section
    }

    static func deleteSection(_ section: LessonSection, in context: ModelContext) {
        let lesson = section.lesson
        lesson?.sections.removeAll { $0.id == section.id }
        context.delete(section)
        if let lesson { touch(lesson) }
    }

    /// Swaps the section with its neighbour (`offset` = -1 up, +1 down).
    static func moveSection(_ section: LessonSection, by offset: Int) {
        guard let lesson = section.lesson else { return }
        var ordered = lesson.orderedSections
        guard let index = ordered.firstIndex(where: { $0.id == section.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        for (position, item) in ordered.enumerated() { item.order = position }
        touch(lesson)
    }

    // MARK: Blocks

    @discardableResult
    static func addBlock(_ type: BlockType, to section: LessonSection) -> LessonBlock {
        let block = LessonBlock(type: type, text: "", order: section.nextBlockOrder)
        section.blocks.append(block)
        if let lesson = section.lesson { touch(lesson) }
        return block
    }

    static func moveBlocks(in section: LessonSection, from source: IndexSet, to destination: Int) {
        var ordered = section.orderedBlocks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (position, block) in ordered.enumerated() { block.order = position }
        if let lesson = section.lesson { touch(lesson) }
    }

    static func move(_ block: LessonBlock, to section: LessonSection) {
        guard block.section?.id != section.id else { return }
        block.section?.blocks.removeAll { $0.id == block.id }
        block.order = section.nextBlockOrder
        section.blocks.append(block)
        if let lesson = section.lesson { touch(lesson) }
    }

    @discardableResult
    static func duplicateBlock(_ block: LessonBlock) -> LessonBlock? {
        guard let section = block.section else { return nil }
        for other in section.blocks where other.order > block.order { other.order += 1 }
        let copy = LessonBlock(
            type: block.type, text: block.text, originalText: block.originalText, order: block.order + 1,
            slideNumber: block.slideNumber, isImportant: block.isImportant, expectedAnswer: block.expectedAnswer,
            notes: block.notes, timerDuration: block.timerDuration, estimatedDuration: block.estimatedDuration,
            sourceDocumentID: block.sourceDocumentID
        )
        section.blocks.append(copy)
        if let lesson = section.lesson { touch(lesson) }
        return copy
    }

    static func deleteBlock(_ block: LessonBlock, in context: ModelContext) {
        let lesson = block.section?.lesson
        block.section?.blocks.removeAll { $0.id == block.id }
        if lesson?.currentBlockID == block.id { lesson?.currentBlockID = nil }
        context.delete(block)
        if let lesson { touch(lesson) }
    }

    static func touch(_ lesson: Lesson) {
        lesson.modifiedAt = .now
        try? lesson.modelContext?.save()
    }
}
