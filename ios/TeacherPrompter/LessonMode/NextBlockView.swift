import SwiftUI

/// The quiet "what comes next" zone: readable in peripheral vision, never competing with Current.
struct NextBlockView: View {
    let block: LessonBlock?
    let slideChange: Int?
    let fontSize: CGFloat

    @Environment(\.loc) private var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Text(loc(.nextLabel))
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.tertiary)
                if let block {
                    BlockTypeLabel(type: block.type, size: max(13, fontSize * 0.28))
                        .opacity(0.75)
                    if block.isImportant { ImportantMark(size: max(13, fontSize * 0.28)) }
                }
                Spacer(minLength: 0)
                if let slideChange {
                    Label(loc(.nextSlide(slideChange)), systemImage: BlockType.slide.symbol)
                        .font(.system(size: max(14, fontSize * 0.3), weight: .bold))
                        .foregroundStyle(.teal)
                }
            }

            if let block {
                Text(previewText(block))
                    .font(.system(size: fontSize * 0.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                Text(loc(.endOfLesson))
                    .font(.system(size: fontSize * 0.4))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func previewText(_ block: LessonBlock) -> String {
        if block.text.isEmpty, block.type == .slide, let number = block.slideNumber {
            return loc(.goToSlide(number))
        }
        return block.text.isEmpty ? loc(.emptyBlock) : block.text
    }
}
