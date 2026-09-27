import SwiftUI
import SwiftData

/// Lesson editor: metadata, sections and blocks. Blocks can be reordered by drag and drop.
struct LessonEditorView: View {
    @Bindable var lesson: Lesson

    @Environment(\.modelContext) private var context
    @Environment(\.loc) private var loc

    @State private var editingBlock: LessonBlock?
    @State private var teaching = false
    @State private var showImport = false
    @State private var renamingSection: LessonSection?
    @State private var sectionTitle = ""

    var body: some View {
        List {
            detailsSection

            ForEach(lesson.orderedSections) { section in
                Section {
                    ForEach(section.orderedBlocks) { block in
                        BlockRow(block: block)
                            .contentShape(Rectangle())
                            .onTapGesture { editingBlock = block }
                            .contextMenu { blockMenu(block) }
                    }
                    .onMove { source, destination in
                        LessonStore.moveBlocks(in: section, from: source, to: destination)
                    }
                    .onDelete { offsets in
                        let blocks = section.orderedBlocks
                        for index in offsets { LessonStore.deleteBlock(blocks[index], in: context) }
                    }

                    AddBlockMenu { type in
                        editingBlock = LessonStore.addBlock(type, to: section)
                    }
                } header: {
                    sectionHeader(section)
                }
            }

            Section {
                Button {
                    let section = LessonStore.addSection(title: loc(.newSectionName), to: lesson)
                    sectionTitle = section.title
                    renamingSection = section
                } label: {
                    Label(loc(.addSection), systemImage: "rectangle.stack.badge.plus")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lesson.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showImport = true } label: {
                    Label(loc(.addMaterial), systemImage: "square.and.arrow.down")
                }
                EditButton()
                Button { teaching = true } label: {
                    Label(loc(.startLesson), systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(item: $editingBlock) { block in
            BlockEditorView(block: block)
                .appEnvironment()
        }
        .sheet(isPresented: $showImport) {
            ImportView(target: .append(lesson)) { _ in }
                .appEnvironment()
        }
        .fullScreenCover(isPresented: $teaching) {
            LessonModeView(lesson: lesson)
                .appEnvironment()
        }
        .alert(loc(.sectionTitle),
               isPresented: Binding(get: { renamingSection != nil }, set: { if !$0 { renamingSection = nil } })) {
            TextField(loc(.sectionTitle), text: $sectionTitle)
                .autocorrectionDisabled()
            Button(loc(.cancel), role: .cancel) { renamingSection = nil }
            Button(loc(.ok)) {
                renamingSection?.title = sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                LessonStore.touch(lesson)
                renamingSection = nil
            }
        }
        .onChange(of: lesson.title) { lesson.modifiedAt = .now }
        .onChange(of: lesson.subject) { lesson.modifiedAt = .now }
        .onChange(of: lesson.classLevel) { lesson.modifiedAt = .now }
    }

    // MARK: Parts

    private var detailsSection: some View {
        Section(loc(.lessonDetails)) {
            LabeledContent(loc(.title)) {
                TextField(loc(.title), text: $lesson.title)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent(loc(.subject)) {
                TextField(loc(.subject), text: $lesson.subject)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent(loc(.classLevel)) {
                TextField(loc(.classLevel), text: $lesson.classLevel)
                    .multilineTextAlignment(.trailing)
            }
            Picker(loc(.contentLanguage), selection: $lesson.language) {
                ForEach(languageOptions, id: \.self) { code in
                    Text(ContentLanguage.name(code, in: loc.language)).tag(code)
                }
            }
            Stepper(value: $lesson.plannedMinutes, in: 5...240, step: 5) {
                Text(loc(.plannedDuration(lesson.plannedMinutes)))
            }
            if !lesson.sourceDocuments.isEmpty {
                LabeledContent(loc(.sources)) {
                    Text(lesson.sourceDocuments.map(\.filename).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .autocorrectionDisabled()
    }

    private var languageOptions: [String] {
        ContentLanguage.common.contains(lesson.language)
            ? ContentLanguage.common
            : ContentLanguage.common + [lesson.language]
    }

    private func sectionHeader(_ section: LessonSection) -> some View {
        HStack {
            Text(section.title.isEmpty ? loc(.untitledSection) : section.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .textCase(nil)
            Spacer()
            Menu {
                Button {
                    sectionTitle = section.title
                    renamingSection = section
                } label: {
                    Label(loc(.rename), systemImage: "character.cursor.ibeam")
                }
                Button { LessonStore.moveSection(section, by: -1) } label: {
                    Label(loc(.moveUp), systemImage: "arrow.up")
                }
                Button { LessonStore.moveSection(section, by: 1) } label: {
                    Label(loc(.moveDown), systemImage: "arrow.down")
                }
                Divider()
                Button(role: .destructive) { LessonStore.deleteSection(section, in: context) } label: {
                    Label(loc(.deleteSection), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
        }
    }

    @ViewBuilder
    private func blockMenu(_ block: LessonBlock) -> some View {
        Button { editingBlock = block } label: {
            Label(loc(.edit), systemImage: "pencil")
        }
        Button {
            block.isImportant.toggle()
            LessonStore.touch(lesson)
        } label: {
            Label(block.isImportant ? loc(.unmarkImportant) : loc(.markImportant),
                  systemImage: block.isImportant ? "star.slash" : "star")
        }
        Menu {
            ForEach(BlockType.allCases) { type in
                Button {
                    block.type = type
                    LessonStore.touch(lesson)
                } label: {
                    Label(type.label(loc.language), systemImage: type.symbol)
                }
            }
        } label: {
            Label(loc(.changeType), systemImage: "square.grid.2x2")
        }
        let otherSections = lesson.orderedSections.filter { $0.id != block.section?.id }
        if !otherSections.isEmpty {
            Menu {
                ForEach(otherSections) { section in
                    Button(section.title.isEmpty ? loc(.untitledSection) : section.title) {
                        LessonStore.move(block, to: section)
                    }
                }
            } label: {
                Label(loc(.moveToSection), systemImage: "arrow.right.doc.on.clipboard")
            }
        }
        Button { LessonStore.duplicateBlock(block) } label: {
            Label(loc(.duplicate), systemImage: "plus.square.on.square")
        }
        Divider()
        Button(role: .destructive) { LessonStore.deleteBlock(block, in: context) } label: {
            Label(loc(.delete), systemImage: "trash")
        }
    }
}
