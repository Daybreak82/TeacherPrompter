import SwiftUI
import SwiftData

@main
struct TeacherPrompterApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .appEnvironment()
        }
        .modelContainer(for: [Lesson.self, LessonSection.self, LessonBlock.self, SourceDocument.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.didSeedSample) private var didSeedSample = false

    var body: some View {
        LessonsListView()
            .task {
                guard !didSeedSample else { return }
                didSeedSample = true
                SampleLesson.insert(into: context)
            }
    }
}
