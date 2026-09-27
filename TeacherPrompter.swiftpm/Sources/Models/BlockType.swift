import Foundation

/// The kind of a script block. Stored as its raw value in SwiftData.
enum BlockType: String, Codable, CaseIterable, Identifiable, Sendable {
    case say
    case question
    case expectedAnswer
    case action
    case experiment
    case slide
    case note
    case timer
    case transition

    var id: String { rawValue }
}

/// Status of a block during a lesson. `current` is derived from `Lesson.currentBlockID`,
/// the other states from the block's own flags.
enum BlockStatus: Sendable {
    case upcoming
    case current
    case completed
    case skipped
}
