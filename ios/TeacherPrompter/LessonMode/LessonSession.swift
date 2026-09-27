import Foundation
import Observation
import UIKit

/// Runtime state of Lesson Mode: Current + Next navigation, undo, pause, timer, lesson clock.
///
/// Persistent state (block status, position, elapsed time) lives in the SwiftData models, so a
/// lesson always resumes where it was left. Transient state (undo, banner, timer) lives here.
@MainActor
@Observable
final class LessonSession {
    enum Direction {
        case forward, backward
    }

    enum UndoKind {
        case completed, skipped, movedLater, jumped, wentBack
    }

    struct UndoRecord {
        let token = UUID()
        let kind: UndoKind
        let currentBlockID: UUID?
        /// Snapshot of every block: (isCompleted, isSkipped, order).
        let states: [UUID: (Bool, Bool, Int)]
    }

    struct SectionBanner: Equatable {
        let id = UUID()
        let title: String
    }

    struct RunningTimer: Equatable {
        let id = UUID()
        let duration: TimeInterval
        let end: Date
        var finished = false
    }

    let lesson: Lesson
    var direction: Direction = .forward
    var sectionBanner: SectionBanner?
    private(set) var undo: UndoRecord?
    private(set) var isPaused = false
    private(set) var timer: RunningTimer?
    private var clockStartedAt: Date?

    init(lesson: Lesson) {
        self.lesson = lesson
    }

    // MARK: Current + Next

    var blocks: [LessonBlock] { lesson.orderedBlocks }

    /// The stored position, or the first block that is neither completed nor skipped.
    var current: LessonBlock? {
        let all = blocks
        if let id = lesson.currentBlockID, let block = all.first(where: { $0.id == id }) {
            return block
        }
        return all.first { !$0.isDone }
    }

    /// The next open block after the current one (wrapping around to blocks left open earlier).
    var next: LessonBlock? {
        guard let current else { return nil }
        return nextOpen(after: current, in: blocks)
    }

    /// The most recent finished block before the current one (shown greyed out above it).
    var previousDone: LessonBlock? {
        let all = blocks
        guard let current, let index = all.firstIndex(where: { $0.id == current.id }) else { return nil }
        return all[..<index].last { $0.isDone }
    }

    var isFinished: Bool { current == nil }

    var total: Int { blocks.count }

    var doneCount: Int { blocks.filter(\.isDone).count }

    var progress: Double { total == 0 ? 0 : Double(doneCount) / Double(total) }

    /// 1-based position of the current block (e.g. 14 in "14 / 32").
    var position: Int {
        let all = blocks
        guard let current, let index = all.firstIndex(where: { $0.id == current.id }) else { return all.count }
        return index + 1
    }

    var canGoBack: Bool {
        guard let current else { return total > 0 }
        return blocks.first?.id != current.id
    }

    var currentSectionTitle: String? {
        guard let title = current?.section?.title, !title.isEmpty else { return nil }
        return title
    }

    func status(of block: LessonBlock) -> BlockStatus {
        if block.id == current?.id { return .current }
        if block.isSkipped { return .skipped }
        if block.isCompleted { return .completed }
        return .upcoming
    }

    /// Slide a block belongs to: its own number or the last slide mentioned before it.
    func effectiveSlide(of block: LessonBlock) -> Int? {
        let all = blocks
        guard let index = all.firstIndex(where: { $0.id == block.id }) else { return block.slideNumber }
        return all[...index].last(where: { $0.slideNumber != nil })?.slideNumber
    }

    /// Slide the presentation must switch to before the next block, if it differs from now.
    var upcomingSlideChange: Int? {
        guard let next, let nextSlide = effectiveSlide(of: next) else { return nil }
        let currentSlide = current.flatMap { effectiveSlide(of: $0) }
        return nextSlide == currentSlide ? nil : nextSlide
    }

    private func nextOpen(after block: LessonBlock, in all: [LessonBlock]) -> LessonBlock? {
        guard let index = all.firstIndex(where: { $0.id == block.id }) else { return nil }
        return all[(index + 1)...].first { !$0.isDone } ?? all[..<index].first { !$0.isDone }
    }

    // MARK: Actions

    /// Tap / swipe left / Space / → : mark current as done, move on.
    func completeCurrent() {
        guard let current else { return }
        record(.completed)
        let target = nextOpen(after: current, in: blocks)
        current.isCompleted = true
        current.isSkipped = false
        move(to: target, from: current, announceSection: true)
    }

    func skipCurrent() {
        guard let current else { return }
        record(.skipped)
        let target = nextOpen(after: current, in: blocks)
        current.isSkipped = true
        current.isCompleted = false
        move(to: target, from: current, announceSection: true)
    }

    /// Swipe right / ← : the block before the current one becomes current again.
    func goBack() {
        let all = blocks
        let index: Int
        if let current, let position = all.firstIndex(where: { $0.id == current.id }) {
            index = position
        } else {
            index = all.count
        }
        guard index > 0 else { return }
        record(.wentBack)
        let previous = all[index - 1]
        previous.isCompleted = false
        previous.isSkipped = false
        move(to: previous, from: current, announceSection: false)
    }

    /// Overview: jump to any block. Blocks in between keep their status.
    func jump(to block: LessonBlock) {
        guard block.id != current?.id else { return }
        record(.jumped)
        block.isCompleted = false
        block.isSkipped = false
        move(to: block, from: current, announceSection: true)
    }

    /// "Move to later": the current block goes to the end of its section and stays open.
    func moveCurrentToLater() {
        guard let current, let section = current.section else { return }
        let target = nextOpen(after: current, in: blocks)
        guard target != nil else { return }
        record(.movedLater)
        var ordered = section.orderedBlocks
        ordered.removeAll { $0.id == current.id }
        ordered.append(current)
        for (position, block) in ordered.enumerated() { block.order = position }
        move(to: target, from: current, announceSection: true)
    }

    func toggleImportant(_ block: LessonBlock) {
        block.isImportant.toggle()
        save()
    }

    func reset() {
        LessonStore.resetProgress(lesson)
        undo = nil
        if clockStartedAt != nil { clockStartedAt = .now }
    }

    private func move(to target: LessonBlock?, from old: LessonBlock?, announceSection: Bool) {
        lesson.currentBlockID = target?.id
        if announceSection,
           let target,
           target.section?.id != old?.section?.id,
           let title = target.section?.title,
           !title.isEmpty {
            sectionBanner = SectionBanner(title: title)
        }
        save()
    }

    // MARK: Undo

    private func record(_ kind: UndoKind) {
        var states: [UUID: (Bool, Bool, Int)] = [:]
        for block in blocks { states[block.id] = (block.isCompleted, block.isSkipped, block.order) }
        undo = UndoRecord(kind: kind, currentBlockID: lesson.currentBlockID, states: states)
    }

    func performUndo() {
        guard let record = undo else { return }
        for block in blocks {
            guard let state = record.states[block.id] else { continue }
            block.isCompleted = state.0
            block.isSkipped = state.1
            block.order = state.2
        }
        lesson.currentBlockID = record.currentBlockID
        undo = nil
        sectionBanner = nil
        save()
    }

    func expireUndo(_ token: UUID) {
        if undo?.token == token { undo = nil }
    }

    // MARK: Pause & clock

    func startClock() {
        guard clockStartedAt == nil, !isPaused else { return }
        clockStartedAt = .now
    }

    func stopClock() {
        guard let started = clockStartedAt else { return }
        lesson.elapsedSeconds += Date().timeIntervalSince(started)
        clockStartedAt = nil
        save()
    }

    func elapsed(at date: Date) -> TimeInterval {
        lesson.elapsedSeconds + (clockStartedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    func pause() {
        stopClock()
        isPaused = true
    }

    func resume() {
        isPaused = false
        startClock()
    }

    // MARK: Timer

    func startTimer(duration: TimeInterval) {
        timer = RunningTimer(duration: duration, end: Date().addingTimeInterval(duration))
    }

    func timerDidFinish(_ id: UUID) {
        guard timer?.id == id, timer?.finished == false else { return }
        timer?.finished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func cancelTimer() {
        timer = nil
    }

    // MARK: Persistence

    private func save() {
        try? lesson.modelContext?.save()
    }
}
