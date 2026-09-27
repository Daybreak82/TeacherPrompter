import SwiftUI
import SwiftData

/// Preview before import: the teacher checks type, section, slide and order of every block.
/// Nothing is stored until "Save as lesson".
struct ImportPreviewView: View {
    @Bindable var draft: ImportDraft
    let target: ImportTarget
    var onSaved: (Lesson) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.loc) private var loc

    @State private var editing: DraftBlock?

    private var isNewLesson: Bool {
        if case .newLesson = target { return true }
        return false
    }

    var body: some View {
        List {
            if isNewLesson {
                Section(loc(.lessonDetails)) {
                    TextField(loc(.title), text: $draft.title)
                    TextField(loc(.subject), text: $draft.subject)
                    TextField(loc(.classLevel), text: $draft.classLevel)
                    Picker(loc(.contentLanguage), selection: $draft.language) {
                        ForEach(languageOptions, id: \.self) { code in
                            Text(ContentLanguage.name(code, in: loc.language)).tag(code)
                        }
                    }
                }
                .autocorrectionDisabled()
            }

            Section(loc(.sources)) {
                ForEach(draft.sources) { source in
                    LabeledContent {
                        if let language = draft.sourceLanguages[source.id] {
                            Text("\(loc(.detectedLanguage)): \(ContentLanguage.name(language, in: loc.language))")
                        }
                    } label: {
                        Label(source.filename, systemImage: icon(for: source.kind))
                    }
                }
                Text(loc(.blocksInLesson(draft.blockCount)))
                    .foregroundStyle(.secondary)
            }

            if draft.nonVerbatimCount > 0 {
                Section {
                    Label(loc(.nonVerbatimWarning(draft.nonVerbatimCount)), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            ForEach(draft.sections) { section in
                Section {
                    ForEach(section.blocks) { block in
                        DraftBlockRow(block: block, draft: draft)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = block }
                            .contextMenu { menu(for: block) }
                    }
                    .onMove { source, destination in
                        draft.moveBlocks(in: section.id, from: source, to: destination)
                    }
                    .onDelete { offsets in
                        draft.deleteBlocks(in: section.id, at: offsets)
                    }
                } header: {
                    TextField(loc(.untitledSection), text: Binding(
                        get: { section.title },
                        set: { draft.renameSection(section.id, to: $0) }
                    ))
                    .font(.headline)
                    .textCase(nil)
                    .autocorrectionDisabled()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(loc(.preview))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button {
                    let lesson = draft.commit(to: target, context: context, untitled: loc(.untitledLesson))
                    onSaved(lesson)
                } label: {
                    Text(isNewLesson ? loc(.saveAsLesson) : loc(.addToLesson)).fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.blockCount == 0)
            }
        }
        .sheet(item: $editing) { block in
            DraftBlockEditor(block: block) { updated in
                draft.update(updated)
            }
            .appEnvironment()
        }
    }

    private var languageOptions: [String] {
        ContentLanguage.common.contains(draft.language) ? ContentLanguage.common : ContentLanguage.common + [draft.language]
    }

    private func icon(for kind: SourceKind) -> String {
        switch kind {
        case .pdf: return "doc.richtext"
        case .pptx: return "rectangle.on.rectangle"
        case .docx: return "doc.text"
        case .text, .markdown: return "doc.plaintext"
        case .clipboard: return "doc.on.clipboard"
        }
    }

    @ViewBuilder
    private func menu(for block: DraftBlock) -> some View {
        Button { editing = block } label: {
            Label(loc(.edit), systemImage: "pencil")
        }
        Menu {
            ForEach(BlockType.allCases) { type in
                Button { draft.setType(type, for: block.id) } label: {
                    Label(type.label(loc.language), systemImage: type.symbol)
                }
            }
        } label: {
            Label(loc(.changeType), systemImage: "square.grid.2x2")
        }
        if draft.canMergeWithNext(block.id) {
            Button { draft.mergeWithNext(block.id) } label: {
                Label(loc(.mergeWithNext), systemImage: "arrow.down.and.line.horizontal.and.arrow.up")
            }
        }
        if draft.canSplit(block.id) {
            Button { draft.split(block.id) } label: {
                Label(loc(.split), systemImage: "scissors")
            }
        }
        Divider()
        Button(role: .destructive) { draft.delete(block.id) } label: {
            Label(loc(.delete), systemImage: "trash")
        }
    }
}

private struct DraftBlockRow: View {
    let block: DraftBlock
    let draft: ImportDraft
    @Environment(\.loc) private var loc

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Menu {
                ForEach(BlockType.allCases) { type in
                    Button { draft.setType(type, for: block.id) } label: {
                        Label(type.label(loc.language), systemImage: type.symbol)
                    }
                }
            } label: {
                Image(systemName: block.type.symbol)
                    .font(.title3)
                    .foregroundStyle(block.type.tint)
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(block.type.label(loc.language).uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(block.type.tint)
                    if block.isImportant { ImportantMark(size: 12) }
                    if let slide = block.slideNumber { SlideBadge(number: slide, size: 11) }
                    if let timer = block.timerDuration {
                        Label(DurationFormat.minutes(timer), systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !block.isVerbatim {
                        Label(loc(.notVerbatim), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text(block.text.isEmpty ? loc(.emptyBlock) : block.text)
                    .lineLimit(5)
                if let notes = block.notes {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if block.isTextModified {
                    Text("\(loc(.original)): \(block.originalText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Editor for one proposed block. The original excerpt is always visible for comparison.
struct DraftBlockEditor: View {
    var onSave: (DraftBlock) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var loc
    @State private var block: DraftBlock
    @State private var slideText: String

    init(block: DraftBlock, onSave: @escaping (DraftBlock) -> Void) {
        self.onSave = onSave
        _block = State(initialValue: block)
        _slideText = State(initialValue: block.slideNumber.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(loc(.blockType), selection: $block.type) {
                        ForEach(BlockType.allCases) { type in
                            Label(type.label(loc.language), systemImage: type.symbol).tag(type)
                        }
                    }
                    Toggle(loc(.important), isOn: $block.isImportant)
                    LabeledContent(loc(.slideNumber)) {
                        TextField("–", text: $slideText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section(loc(.text)) {
                    TextEditor(text: $block.text)
                        .font(.title3)
                        .frame(minHeight: 160)
                        .autocorrectionDisabled()
                }
                Section(loc(.original)) {
                    Text(block.originalText)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if block.text != block.originalText {
                        Button(loc(.restoreOriginal)) { block.text = block.originalText }
                    }
                }
            }
            .navigationTitle(loc(.editBlock))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc(.done)) {
                        block.slideNumber = Int(slideText.trimmingCharacters(in: .whitespaces))
                        onSave(block)
                        dismiss()
                    }
                }
            }
        }
    }
}
