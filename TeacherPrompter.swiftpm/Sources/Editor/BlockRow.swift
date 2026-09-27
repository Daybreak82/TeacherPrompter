import SwiftUI

struct BlockRow: View {
    let block: LessonBlock
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: block.type.symbol)
                .font(.title3)
                .foregroundStyle(block.type.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(block.type.label(loc.language).uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(block.type.tint)
                    if block.isImportant { ImportantMark(size: 12) }
                    if let slide = block.slideNumber { SlideBadge(number: slide, size: 11) }
                    if let timer = block.timerDuration, timer > 0 {
                        Label(DurationFormat.minutes(timer), systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if block.isTextModified {
                        Text(loc(.edited))
                            .font(.caption2.italic())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(block.text.isEmpty ? loc(.emptyBlock) : block.text)
                    .font(.body)
                    .foregroundStyle(block.text.isEmpty ? .tertiary : .primary)
                    .lineLimit(4)
                if let answer = block.expectedAnswer, !answer.isEmpty {
                    Text(answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddBlockMenu: View {
    var onSelect: (BlockType) -> Void
    @Environment(\.loc) private var loc

    var body: some View {
        Menu {
            ForEach(BlockType.allCases) { type in
                Button { onSelect(type) } label: {
                    Label(type.label(loc.language), systemImage: type.symbol)
                }
            }
        } label: {
            Label(loc(.addBlock), systemImage: "plus.circle.fill")
        }
    }
}
