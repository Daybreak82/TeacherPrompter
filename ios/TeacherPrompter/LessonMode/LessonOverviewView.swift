import SwiftUI

/// Sidebar with the whole lesson structure. Tap any block to jump there.
struct LessonOverviewView: View {
    let session: LessonSession
    let hideCompleted: Bool
    var onSelect: (LessonBlock) -> Void

    @Environment(\.loc) private var loc

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(session.lesson.orderedSections) { section in
                    Section {
                        ForEach(visibleBlocks(in: section)) { block in
                            Button {
                                onSelect(block)
                            } label: {
                                row(for: block)
                            }
                            .buttonStyle(.plain)
                            .id(block.id)
                        }
                    } header: {
                        Text(section.title.isEmpty ? loc(.untitledSection) : section.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .top) {
                HStack {
                    Text(loc(.overview)).font(.title2.bold())
                    Spacer()
                    Text(loc(.progressShort(session.doneCount, session.total)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .onAppear {
                if let id = session.current?.id {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func visibleBlocks(in section: LessonSection) -> [LessonBlock] {
        let currentID = session.current?.id
        return section.orderedBlocks.filter { !hideCompleted || !$0.isDone || $0.id == currentID }
    }

    private func row(for block: LessonBlock) -> some View {
        let status = session.status(of: block)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            statusIcon(status)
                .frame(width: 22)
            Image(systemName: block.type.symbol)
                .foregroundStyle(block.type.tint)
                .font(.subheadline)
            Text(preview(block))
                .lineLimit(2)
                .font(status == .current ? .body.weight(.semibold) : .body)
                .foregroundStyle(status == .completed || status == .skipped ? .secondary : .primary)
                .strikethrough(status == .skipped)
            Spacer(minLength: 4)
            if block.isImportant { ImportantMark(size: 13) }
            if let number = block.slideNumber, block.type == .slide {
                Text("\(number)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.teal)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusIcon(_ status: BlockStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark").foregroundStyle(.green)
        case .current:
            Image(systemName: "arrow.right").foregroundStyle(Color.accentColor).fontWeight(.bold)
        case .skipped:
            Image(systemName: "forward").foregroundStyle(.secondary)
        case .upcoming:
            Image(systemName: "circle").foregroundStyle(.tertiary)
        }
    }

    private func preview(_ block: LessonBlock) -> String {
        if block.text.isEmpty {
            if block.type == .slide, let number = block.slideNumber { return loc(.goToSlide(number)) }
            return loc(.emptyBlock)
        }
        return block.text
    }
}
