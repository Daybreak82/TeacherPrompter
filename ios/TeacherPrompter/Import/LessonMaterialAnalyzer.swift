import Foundation

/// Turns extracted documents into a lesson structure.
///
/// Contract for every implementation (today rule-based, later AI – "Generate Prompter Script"):
/// the analyzer is a *parser and organizer*, not an author. It may decide sections, block
/// boundaries, block types, slide numbers, timers and importance. It must not rewrite,
/// shorten, translate or correct text. `VerbatimGuard` checks this after every analysis.
protocol LessonMaterialAnalyzer: Sendable {
    func analyze(_ documents: [ExtractedDocument], mode: ImportMode) async throws -> ParsedScript
}

struct RuleBasedAnalyzer: LessonMaterialAnalyzer {
    func analyze(_ documents: [ExtractedDocument], mode: ImportMode) async throws -> ParsedScript {
        var builder = ScriptBuilder()
        for document in documents {
            builder.startDocument()
            for segment in document.segments {
                switch segment {
                case .text(let text):
                    builder.ingest(text, mode: mode, sourceID: document.id)
                case let .slide(number, title, body, notes):
                    builder.appendSlide(number: number, title: title, body: body, sourceID: document.id)
                    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        builder.ingest(notes, mode: mode, sourceID: document.id)
                    }
                }
            }
        }
        var script = builder.result()
        VerbatimGuard.annotate(&script, sources: documents.map(\.plainText))
        return script
    }
}

/// Placeholder for phase 2. An AI analyzer would send the extracted text to a model with the
/// instruction to return *only* structure (ranges/indices into the source + a type), then build
/// `DraftBlock`s by slicing the source text – so the words cannot be changed by construction.
/// Its result must still pass through `VerbatimGuard.annotate` before the preview is shown.
struct AIAssistedAnalyzer: LessonMaterialAnalyzer {
    let fallback = RuleBasedAnalyzer()

    func analyze(_ documents: [ExtractedDocument], mode: ImportMode) async throws -> ParsedScript {
        try await fallback.analyze(documents, mode: mode)
    }
}
