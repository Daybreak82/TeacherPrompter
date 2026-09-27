import SwiftUI

/// The big "what do I say / do now" card. Text is rendered verbatim (`Text(String)` never
/// interprets Markdown), large and with generous line spacing for reading from 1–2 m.
struct CurrentBlockView: View {
    let block: LessonBlock
    let slide: Int?
    let fontSize: CGFloat
    var onStartTimer: (TimeInterval) -> Void

    @Environment(\.loc) private var loc

    private var labelSize: CGFloat { max(15, fontSize * 0.36) }

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.45) {
            HStack(spacing: 14) {
                BlockTypeLabel(type: block.type, size: labelSize)
                if block.isImportant { ImportantMark(size: labelSize) }
                Spacer(minLength: 0)
                if let slide { SlideBadge(number: slide, size: labelSize * 0.95) }
            }

            if block.type == .slide, let number = block.slideNumber {
                Text(loc(.goToSlide(number)))
                    .font(.system(size: fontSize, weight: .bold))
            }

            if !block.text.isEmpty {
                Text(block.text)
                    .font(.system(size: block.type == .slide ? fontSize * 0.7 : fontSize,
                                  weight: block.type == .note ? .regular : .semibold))
                    .lineSpacing(fontSize * 0.18)
                    .foregroundStyle(block.type == .note ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let answer = block.expectedAnswer, !answer.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    BlockTypeLabel(type: .expectedAnswer, size: labelSize * 0.8)
                    Text(answer)
                        .font(.system(size: fontSize * 0.6, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let notes = block.notes, !notes.isEmpty {
                Label {
                    Text(notes).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "note.text")
                }
                .font(.system(size: max(15, fontSize * 0.4)))
                .foregroundStyle(.secondary)
            }

            if let duration = timerDuration {
                Button {
                    onStartTimer(duration)
                } label: {
                    Label(loc(.startTimer(DurationFormat.minutes(duration))), systemImage: "timer")
                        .font(.system(size: max(17, fontSize * 0.4), weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private var timerDuration: TimeInterval? {
        if let duration = block.timerDuration, duration > 0 { return duration }
        return block.type == .timer ? 5 * 60 : nil
    }
}
