import SwiftUI
import Translation

/// Edits one block. Changes are applied only when the teacher taps "Done" (explicit action).
/// The imported wording (`originalText`) is shown read-only and can be restored at any time.
struct BlockEditorView: View {
    let block: LessonBlock

    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var loc

    @State private var type: BlockType
    @State private var text: String
    @State private var expectedAnswer: String
    @State private var notes: String
    @State private var slideText: String
    @State private var isImportant: Bool
    @State private var estimatedMinutes: Int
    @State private var timerMinutes: Int
    @State private var showOriginal = false
    @State private var showTranslation = false

    init(block: LessonBlock) {
        self.block = block
        _type = State(initialValue: block.type)
        _text = State(initialValue: block.text)
        _expectedAnswer = State(initialValue: block.expectedAnswer ?? "")
        _notes = State(initialValue: block.notes ?? "")
        _slideText = State(initialValue: block.slideNumber.map(String.init) ?? "")
        _isImportant = State(initialValue: block.isImportant)
        _estimatedMinutes = State(initialValue: Int((block.estimatedDuration ?? 0) / 60))
        _timerMinutes = State(initialValue: Int((block.timerDuration ?? 0) / 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(loc(.blockType), selection: $type) {
                        ForEach(BlockType.allCases) { type in
                            Label(type.label(loc.language), systemImage: type.symbol).tag(type)
                        }
                    }
                    Toggle(isOn: $isImportant) {
                        Label(loc(.important), systemImage: "star")
                    }
                }

                Section {
                    // Autocorrection is off: the app must not change the teacher's words, not even while typing.
                    TextEditor(text: $text)
                        .font(.title3)
                        .frame(minHeight: 160)
                        .autocorrectionDisabled()
                } header: {
                    Text(loc(.text))
                } footer: {
                    if block.originalText != nil { Text(loc(.originalHint)) }
                }

                if let original = block.originalText {
                    Section {
                        DisclosureGroup(loc(.showOriginal), isExpanded: $showOriginal) {
                            Text(original)
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)
                            if text != original {
                                Button(loc(.restoreOriginal)) { text = original }
                            }
                        }
                    }
                }

                Section(loc(.expectedAnswerField)) {
                    TextEditor(text: $expectedAnswer)
                        .frame(minHeight: 70)
                        .autocorrectionDisabled()
                }

                Section(loc(.slideAndTiming)) {
                    LabeledContent(loc(.slideNumber)) {
                        TextField("–", text: $slideText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper(value: $estimatedMinutes, in: 0...90) {
                        Text(loc(.estimatedDuration(estimatedMinutes)))
                    }
                    Stepper(value: $timerMinutes, in: 0...90) {
                        Text(timerMinutes == 0 ? loc(.timerOff) : loc(.timerMinutes(timerMinutes)))
                    }
                }

                Section(loc(.notesField)) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 70)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        showTranslation = true
                    } label: {
                        Label(loc(.showTranslation), systemImage: "translate")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    // No `replacementAction`: the system sheet can only *show* the translation.
                    .translationPresentation(isPresented: $showTranslation, text: text)
                } footer: {
                    Text(loc(.translationHint))
                }
            }
            .navigationTitle(loc(.editBlock))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc(.done)) { save() }
                }
            }
        }
    }

    private func save() {
        block.type = type
        block.applyUserEdit(text)
        block.expectedAnswer = expectedAnswer.isEmpty ? nil : expectedAnswer
        block.notes = notes.isEmpty ? nil : notes
        block.slideNumber = Int(slideText.trimmingCharacters(in: .whitespaces))
        block.isImportant = isImportant
        block.estimatedDuration = estimatedMinutes > 0 ? TimeInterval(estimatedMinutes * 60) : nil
        block.timerDuration = timerMinutes > 0 ? TimeInterval(timerMinutes * 60) : nil
        if let lesson = block.section?.lesson {
            LessonStore.touch(lesson)
        }
        dismiss()
    }
}
