import SwiftUI
import SwiftData

/// "Import Lesson Materials": pasted text or files → analysis → preview → lesson.
struct ImportView: View {
    let target: ImportTarget
    var onFinished: (Lesson) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.loc) private var loc

    private enum Source: Hashable {
        case paste, files
    }

    @State private var source: Source = .paste
    @State private var pasted = ""
    @State private var mode: ImportMode = .structured
    @State private var showFileImporter = false
    @State private var draft: ImportDraft?
    @State private var isWorking = false
    @State private var errorMessage: String?

    /// Swap for `AIAssistedAnalyzer()` in phase 2 – the preview and VerbatimGuard stay the same.
    let analyzer: any LessonMaterialAnalyzer = RuleBasedAnalyzer()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $source) {
                        Text(loc(.pasteTab)).tag(Source.paste)
                        Text(loc(.filesTab)).tag(Source.files)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                switch source {
                case .paste:
                    Section {
                        ZStack(alignment: .topLeading) {
                            if pasted.isEmpty {
                                Text(loc(.pastePlaceholder))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $pasted)
                                .frame(minHeight: 280)
                                .autocorrectionDisabled()
                        }
                        PasteButton(payloadType: String.self) { strings in
                            pasted = strings.joined(separator: "\n")
                        }
                    }
                case .files:
                    Section {
                        Button {
                            showFileImporter = true
                        } label: {
                            Label(loc(.chooseFiles), systemImage: "doc.badge.plus")
                        }
                    } footer: {
                        Text(loc(.supportedFormats))
                    }
                }

                Section {
                    Picker(loc(.recognition), selection: $mode) {
                        Text(loc(.modeStructured)).tag(ImportMode.structured)
                        Text(loc(.modeParagraphs)).tag(ImportMode.paragraphs)
                    }
                } footer: {
                    Text(mode == .structured ? loc(.modeStructuredHint) : loc(.modeParagraphsHint))
                }

                if source == .paste {
                    Section {
                        Button {
                            analyzePasted()
                        } label: {
                            HStack {
                                Spacer()
                                if isWorking { ProgressView().padding(.trailing, 6) }
                                Text(isWorking ? loc(.analyzing) : loc(.analyze)).fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Label(loc(.wordingPromise), systemImage: "lock.doc")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(loc(.importMaterials))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc(.cancel)) { dismiss() }
                }
            }
            .overlay {
                if isWorking && source == .files {
                    ProgressView(loc(.analyzing))
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: DocumentExtractor.supportedTypes,
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    analyzeFiles(urls)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .navigationDestination(item: $draft) { draft in
                ImportPreviewView(draft: draft, target: target) { lesson in
                    onFinished(lesson)
                    dismiss()
                }
            }
        }
    }

    // MARK: Actions

    private func analyzePasted() {
        let document = DocumentExtractor.clipboard(pasted, name: loc(.clipboardName))
        run([document])
    }

    private func analyzeFiles(_ urls: [URL]) {
        errorMessage = nil
        isWorking = true
        Task {
            var documents: [ExtractedDocument] = []
            var problems: [String] = []
            for url in urls {
                do {
                    let document = try await Task.detached(priority: .userInitiated) {
                        try DocumentExtractor.extract(from: url)
                    }.value
                    documents.append(document)
                } catch DocumentExtractor.ExtractorError.unsupported(let name) {
                    problems.append(loc(.unsupportedFile(name)))
                } catch {
                    problems.append(loc(.importFailed(url.lastPathComponent)))
                }
            }
            if !problems.isEmpty { errorMessage = problems.joined(separator: "\n") }
            if documents.isEmpty {
                isWorking = false
                return
            }
            run(documents)
        }
    }

    private func run(_ documents: [ExtractedDocument]) {
        isWorking = true
        let mode = mode
        let analyzer = analyzer
        Task {
            defer { isWorking = false }
            do {
                let script = try await analyzer.analyze(documents, mode: mode)
                guard !script.allBlocks.isEmpty else {
                    errorMessage = loc(.nothingFound)
                    return
                }
                draft = ImportDraft(script: script, sources: documents, fallbackTitle: loc(.untitledLesson))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
