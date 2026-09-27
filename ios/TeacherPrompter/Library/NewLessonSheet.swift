import SwiftUI
import SwiftData

struct NewLessonSheet: View {
    var onCreate: (Lesson) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.loc) private var loc

    @State private var title = ""
    @State private var subject = ""
    @State private var classLevel = ""
    @State private var language = "de"
    @State private var plannedMinutes = 45

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(loc(.title), text: $title)
                    TextField(loc(.subject), text: $subject)
                    TextField(loc(.classLevel), text: $classLevel)
                }
                .autocorrectionDisabled()
                Section {
                    Picker(loc(.contentLanguage), selection: $language) {
                        ForEach(ContentLanguage.common, id: \.self) { code in
                            Text(ContentLanguage.name(code, in: loc.language)).tag(code)
                        }
                    }
                    Stepper(value: $plannedMinutes, in: 5...240, step: 5) {
                        Text(loc(.plannedDuration(plannedMinutes)))
                    }
                }
            }
            .navigationTitle(loc(.newLesson))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc(.done)) { create() }
                }
            }
        }
    }

    private func create() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // First section named in the *content* language, since it is part of the script.
        let firstSection = language == "de" ? "Einstieg" : (language == "en" ? "Introduction" : "")
        let lesson = LessonStore.createLesson(
            title: cleanTitle.isEmpty ? loc(.untitledLesson) : cleanTitle,
            subject: subject.trimmingCharacters(in: .whitespaces),
            classLevel: classLevel.trimmingCharacters(in: .whitespaces),
            language: language,
            plannedMinutes: plannedMinutes,
            firstSectionTitle: firstSection,
            in: context
        )
        dismiss()
        onCreate(lesson)
    }
}
