import Foundation
import SwiftData
import Testing
@testable import TeacherPrompter

@MainActor
@Suite("Current + Next navigation")
struct LessonSessionTests {
    private func makeLesson() throws -> (ModelContainer, Lesson) {
        let container = try ModelContainer(
            for: Lesson.self, LessonSection.self, LessonBlock.self, SourceDocument.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let lesson = Lesson(title: "Zellmembran")
        context.insert(lesson)
        let intro = LessonSection(title: "Einstieg", order: 0)
        let work = LessonSection(title: "Erarbeitung", order: 1)
        lesson.sections.append(intro)
        lesson.sections.append(work)
        intro.blocks.append(LessonBlock(type: .say, text: "A", order: 0, slideNumber: 1))
        intro.blocks.append(LessonBlock(type: .question, text: "B", order: 1))
        work.blocks.append(LessonBlock(type: .say, text: "C", order: 0, slideNumber: 2))
        work.blocks.append(LessonBlock(type: .action, text: "D", order: 1))
        try context.save()
        return (container, lesson)
    }

    @Test func tapCompletesAndAdvances() throws {
        let (container, lesson) = try makeLesson()
        _ = container
        let session = LessonSession(lesson: lesson)

        #expect(session.current?.text == "A")
        #expect(session.next?.text == "B")
        #expect(session.upcomingSlideChange == nil)

        session.completeCurrent()
        #expect(session.current?.text == "B")
        #expect(session.previousDone?.text == "A")
        #expect(session.status(of: lesson.orderedBlocks[0]) == .completed)
        #expect(session.upcomingSlideChange == 2)

        session.completeCurrent()
        #expect(session.current?.text == "C")
        #expect(session.sectionBanner?.title == "Erarbeitung")
        #expect(session.position == 3)
        #expect(session.progress == 0.5)
    }

    @Test func undoRestoresPreviousState() throws {
        let (container, lesson) = try makeLesson()
        _ = container
        let session = LessonSession(lesson: lesson)

        session.completeCurrent()
        #expect(session.current?.text == "B")
        session.performUndo()
        #expect(session.current?.text == "A")
        let doneCount = lesson.orderedBlocks.filter { $0.isDone }.count
        #expect(doneCount == 0)
    }

    @Test func backSkipJumpAndMoveLater() throws {
        let (container, lesson) = try makeLesson()
        _ = container
        let session = LessonSession(lesson: lesson)

        session.skipCurrent()
        #expect(session.current?.text == "B")
        #expect(session.status(of: lesson.orderedBlocks[0]) == .skipped)

        session.goBack()
        #expect(session.current?.text == "A")
        #expect(!lesson.orderedBlocks[0].isDone)

        session.jump(to: lesson.orderedBlocks[3])
        #expect(session.current?.text == "D")
        // Blocks left open earlier come next (wrap-around).
        #expect(session.next?.text == "A")

        session.jump(to: lesson.orderedBlocks[0])
        session.moveCurrentToLater()
        #expect(lesson.orderedSections[0].orderedBlocks.map(\.text) == ["B", "A"])
        #expect(session.current?.text == "B")
    }

    @Test func finishingTheLesson() throws {
        let (container, lesson) = try makeLesson()
        _ = container
        let session = LessonSession(lesson: lesson)
        for _ in 0..<4 { session.completeCurrent() }
        #expect(session.isFinished)
        #expect(session.progress == 1)
        session.goBack()
        #expect(session.current?.text == "D")
    }

    @Test func userEditKeepsOriginal() {
        let block = LessonBlock(type: .say, text: "Jetzt schauen wir, was mit der Zelle passiert.",
                                originalText: "Jetzt schauen wir, was mit der Zelle passiert.")
        block.applyUserEdit("Beobachtet nun, wie sich die Zelle verändert.")
        #expect(block.originalText == "Jetzt schauen wir, was mit der Zelle passiert.")
        #expect(block.isTextModified)
        block.restoreOriginal()
        #expect(block.text == block.originalText)
    }
}
