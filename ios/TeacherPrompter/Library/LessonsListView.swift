import SwiftUI
import SwiftData

/// "Lessons" screen: saved lessons grouped by subject + class.
struct LessonsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.loc) private var loc
    @Query(sort: \Lesson.modifiedAt, order: .reverse) private var lessons: [Lesson]

    @State private var path: [Lesson] = []
    @State private var search = ""
    @State private var teaching: Lesson?
    @State private var showNewLesson = false
    @State private var showImport = false
    @State private var showSettings = false
    @State private var renaming: Lesson?
    @State private var renameText = ""
    @State private var deleting: Lesson?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if lessons.isEmpty {
                    ContentUnavailableView {
                        Label(loc(.noLessons), systemImage: "text.book.closed")
                    } description: {
                        Text(loc(.noLessonsHint))
                    } actions: {
                        Button(loc(.newLesson)) { showNewLesson = true }
                            .buttonStyle(.borderedProminent)
                        Button(loc(.importMaterials)) { showImport = true }
                    }
                } else {
                    lessonList
                }
            }
            .navigationTitle(loc(.lessons))
            .navigationDestination(for: Lesson.self) { lesson in
                LessonEditorView(lesson: lesson)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Label(loc(.settings), systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showNewLesson = true } label: {
                            Label(loc(.emptyLesson), systemImage: "doc")
                        }
                        Button { showImport = true } label: {
                            Label(loc(.importMaterials), systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label(loc(.newLesson), systemImage: "plus")
                    }
                }
            }
        }
        .fullScreenCover(item: $teaching) { lesson in
            LessonModeView(lesson: lesson)
                .appEnvironment()
        }
        .sheet(isPresented: $showNewLesson) {
            NewLessonSheet { lesson in path.append(lesson) }
                .appEnvironment()
        }
        .sheet(isPresented: $showImport) {
            ImportView(target: .newLesson) { lesson in path.append(lesson) }
                .appEnvironment()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .appEnvironment()
        }
        .alert(loc(.rename), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(loc(.title), text: $renameText)
                .autocorrectionDisabled()
            Button(loc(.cancel), role: .cancel) { renaming = nil }
            Button(loc(.ok)) {
                let title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let lesson = renaming, !title.isEmpty {
                    lesson.title = title
                    LessonStore.touch(lesson)
                }
                renaming = nil
            }
        }
        .confirmationDialog(deleting.map { loc(.deleteLessonQuestion($0.title)) } ?? "",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button(loc(.delete), role: .destructive) {
                if let lesson = deleting {
                    path.removeAll { $0.id == lesson.id }
                    LessonStore.delete(lesson, in: context)
                }
                deleting = nil
            }
            Button(loc(.cancel), role: .cancel) { deleting = nil }
        }
    }

    // MARK: List

    private var filteredLessons: [Lesson] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return lessons }
        // localizedStandardContains: case- and diacritic-insensitive, locale-aware ("Uberleitung" finds "Überleitung").
        return lessons.filter { lesson in
            lesson.title.localizedStandardContains(query)
                || lesson.subject.localizedStandardContains(query)
                || lesson.classLevel.localizedStandardContains(query)
                || lesson.sections.contains { section in
                    section.title.localizedStandardContains(query)
                        || section.blocks.contains { $0.text.localizedStandardContains(query) }
                }
        }
    }

    private struct LessonGroup: Identifiable {
        let title: String
        let lessons: [Lesson]
        var id: String { title }
    }

    private var groups: [LessonGroup] {
        let grouped = Dictionary(grouping: filteredLessons, by: \.groupTitle)
        return grouped
            .map { LessonGroup(title: $0.key, lessons: $0.value) }
            .sorted { lhs, rhs in
                if lhs.title.isEmpty != rhs.title.isEmpty { return !lhs.title.isEmpty }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var lessonList: some View {
        List {
            ForEach(groups) { group in
                Section(group.title.isEmpty ? loc(.otherLessons) : group.title) {
                    ForEach(group.lessons) { lesson in
                        NavigationLink(value: lesson) {
                            LessonRow(lesson: lesson) { teaching = lesson }
                        }
                        .contextMenu { menu(for: lesson) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleting = lesson } label: {
                                Label(loc(.delete), systemImage: "trash")
                            }
                            Button { LessonStore.duplicate(lesson, titleSuffix: loc(.copySuffix), in: context) } label: {
                                Label(loc(.duplicate), systemImage: "plus.square.on.square")
                            }
                            .tint(.indigo)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: loc(.searchPrompt))
    }

    @ViewBuilder
    private func menu(for lesson: Lesson) -> some View {
        Button { teaching = lesson } label: {
            Label(loc(.startLesson), systemImage: "play.fill")
        }
        Button { path.append(lesson) } label: {
            Label(loc(.edit), systemImage: "pencil")
        }
        Button {
            renameText = lesson.title
            renaming = lesson
        } label: {
            Label(loc(.rename), systemImage: "character.cursor.ibeam")
        }
        Button { LessonStore.duplicate(lesson, titleSuffix: loc(.copySuffix), in: context) } label: {
            Label(loc(.duplicate), systemImage: "plus.square.on.square")
        }
        Button { LessonStore.resetProgress(lesson) } label: {
            Label(loc(.resetProgress), systemImage: "arrow.counterclockwise")
        }
        Divider()
        Button(role: .destructive) { deleting = lesson } label: {
            Label(loc(.delete), systemImage: "trash")
        }
    }
}

private struct LessonRow: View {
    let lesson: Lesson
    var onStart: () -> Void
    @Environment(\.loc) private var loc

    var body: some View {
        let blocks = lesson.sections.flatMap(\.blocks)
        let done = blocks.filter(\.isDone).count
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 8) {
                    Text(loc(.blocksInLesson(blocks.count)))
                    if done > 0 {
                        Text("·")
                        Text(loc(.progressShort(done, blocks.count)))
                    }
                    Text("·")
                    Text(lesson.modifiedAt, format: .dateTime.day().month().year())
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onStart) {
                Label(loc(.start), systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 6)
    }
}
