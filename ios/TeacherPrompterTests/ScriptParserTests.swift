import Foundation
import Testing
@testable import TeacherPrompter

@Suite("Rule-based lesson parser")
struct ScriptParserTests {
    private func parse(_ text: String, mode: ImportMode = .structured) -> ParsedScript {
        var builder = ScriptBuilder()
        builder.ingest(text, mode: mode)
        return builder.result()
    }

    @Test func slideTeacherTextQuestionAnswer() {
        let source = """
        Folie 4
        Thema: Zellmembran
        Lehrertext:
        „Die Zellmembran trennt den Zellinnenraum von der Umgebung.“
        Frage:
        „Welche Stoffe müssen trotzdem durch die Membran gelangen?“
        Erwartete Antwort:
        „Wasser, Sauerstoff, Glucose.“
        Nächste Folie: 5
        """
        let script = parse(source)
        let blocks = script.allBlocks

        #expect(blocks.map(\.type) == [.slide, .note, .say, .question, .expectedAnswer, .slide])
        #expect(blocks[2].text == "„Die Zellmembran trennt den Zellinnenraum von der Umgebung.“")
        #expect(blocks[3].text == "„Welche Stoffe müssen trotzdem durch die Membran gelangen?“")
        #expect(blocks[4].text == "„Wasser, Sauerstoff, Glucose.“")
        #expect(blocks[0].slideNumber == 4)
        #expect(blocks[2].slideNumber == 4)
        #expect(blocks[5].slideNumber == 5)
        #expect(script.suggestedTitle == "Zellmembran")
    }

    @Test func sectionsFromCapitalisedHeadings() {
        let source = """
        EINSTIEG
        Heute sprechen wir über die Zellmembran.

        Frage:
        Wie können Stoffe in eine Zelle gelangen?

        ERARBEITUNG
        Die Zellmembran besteht ...
        """
        let script = parse(source)
        #expect(script.sections.map(\.title) == ["EINSTIEG", "ERARBEITUNG"])
        #expect(script.sections[0].blocks.map(\.type) == [.say, .question])
        #expect(script.sections[1].blocks.map(\.text) == ["Die Zellmembran besteht ..."])
    }

    @Test func numberedAndMarkdownHeadings() {
        let source = """
        1. Einstieg (5 min)
        Begrüßung.

        ## Erarbeitung II
        Text.

        Phase 3: Sicherung
        Merksatz.
        """
        let titles = parse(source).sections.map(\.title)
        #expect(titles == ["1. Einstieg (5 min)", "Erarbeitung II", "Phase 3: Sicherung"])
    }

    @Test func colloquialWordingIsPreservedExactly() {
        let original = "„Was glaubt ihr, warum geht das Wasser jetzt aus der Zelle raus?“"
        let blocks = parse("Frage:\n\(original)").allBlocks
        #expect(blocks.count == 1)
        #expect(blocks[0].text == original)
        #expect(blocks[0].originalText == original)
    }

    @Test func unlabeledQuestionIsSuggestedAsQuestion() {
        let blocks = parse("Kann Wasser durch eine Zellmembran gelangen?\n\nDas schauen wir uns an.").allBlocks
        #expect(blocks.map(\.type) == [.question, .say])
    }

    @Test func germanLabelsWithUmlauts() {
        let source = """
        Überleitung: Jetzt zum Versuch.

        Schülerantwort: Osmose

        Erwartungshorizont: Plasmolyse und Deplasmolyse

        Arbeitsauftrag: Lest den Text auf S. 34.

        Merksatz: Die Biomembran ist selektiv permeabel.
        """
        let blocks = parse(source).allBlocks
        #expect(blocks.map(\.type) == [.transition, .expectedAnswer, .expectedAnswer, .action, .say])
        #expect(blocks[1].text == "Osmose")
        #expect(blocks[4].text == "Merksatz: Die Biomembran ist selektiv permeabel.")
        #expect(blocks[4].isImportant)
        #expect(blocks[3].timerDuration == nil)
    }

    @Test func socialFormWithDurationBecomesTimer() {
        let blocks = parse("Gruppenarbeit – 5 Minuten").allBlocks
        #expect(blocks.count == 1)
        #expect(blocks[0].type == .timer)
        #expect(blocks[0].timerDuration == 300)
        #expect(blocks[0].text == "Gruppenarbeit – 5 Minuten")
    }

    @Test func experimentLabelVersusHeading() {
        let script = parse("EXPERIMENT\n\nVersuch:\nPräparate verteilen.")
        #expect(script.sections.map(\.title) == ["EXPERIMENT"])
        #expect(script.allBlocks.map(\.type) == [.experiment])
        #expect(script.allBlocks.first?.text == "Präparate verteilen.")
    }

    @Test func paragraphModeKeepsEveryParagraph() {
        let blocks = parse("Erster Absatz.\nZweite Zeile.\n\nZweiter Absatz?", mode: .paragraphs).allBlocks
        #expect(blocks.map(\.text) == ["Erster Absatz.\nZweite Zeile.", "Zweiter Absatz?"])
        #expect(blocks.map(\.type) == [.say, .question])
    }

    @Test func windowsLineEndings() {
        let blocks = parse("Frage:\r\nWarum?\r\n\r\nLehrertext: Darum.").allBlocks
        #expect(blocks.map(\.text) == ["Warum?", "Darum."])
    }

    @Test func slideMarkers() {
        #expect(PedagogicalVocabulary.slideMarker(in: "Folie 7") == 7)
        #expect(PedagogicalVocabulary.slideMarker(in: "Nächste Folie: 8") == 8)
        #expect(PedagogicalVocabulary.slideMarker(in: "Zu Folie 6 wechseln.") == 6)
        #expect(PedagogicalVocabulary.slideMarker(in: "Slide 3") == 3)
        #expect(PedagogicalVocabulary.slideMarker(in: "Die Folien zeigen 3 Zellen.") == nil)
    }
}

@Suite("Verbatim guard")
struct VerbatimGuardTests {
    @Test func acceptsExcerptsAndRejectsRewrites() {
        let source = "Frage:\n„Was glaubt ihr, warum geht das Wasser jetzt aus der Zelle raus?“"
        var script = ParsedScript(sections: [
            DraftSection(title: "", blocks: [
                DraftBlock(type: .question, text: "„Was glaubt ihr, warum geht das Wasser jetzt aus der Zelle raus?“"),
                DraftBlock(type: .question, text: "Warum tritt Wasser aus der Zelle aus?"),
            ]),
        ])
        VerbatimGuard.annotate(&script, sources: [source])
        #expect(script.sections[0].blocks[0].isVerbatim)
        #expect(!script.sections[0].blocks[1].isVerbatim)
    }

    @Test func ruleBasedAnalyzerOutputIsAlwaysVerbatim() async throws {
        let document = ExtractedDocument(filename: "Stunde.txt", kind: .text, segments: [.text(SampleLesson.text)])
        let script = try await RuleBasedAnalyzer().analyze([document], mode: .structured)
        let blocks = script.allBlocks
        let nonVerbatim = blocks.filter { !$0.isVerbatim }.count
        #expect(!blocks.isEmpty)
        #expect(nonVerbatim == 0)
    }
}

@Suite("Import draft editing")
struct ImportDraftTests {
    @Test func splitAndMergeKeepWords() {
        let text = "Die Membran grenzt ab. Sie lässt aber Stoffe durch."
        let script = ParsedScript(sections: [DraftSection(title: "", blocks: [DraftBlock(type: .say, text: text)])])
        let draft = ImportDraft(script: script, sources: [], fallbackTitle: "Test")
        let id = draft.sections[0].blocks[0].id

        draft.split(id)
        #expect(draft.sections[0].blocks.map(\.text) == ["Die Membran grenzt ab.", "Sie lässt aber Stoffe durch."])

        draft.mergeWithNext(draft.sections[0].blocks[0].id)
        #expect(draft.sections[0].blocks.count == 1)
        #expect(draft.sections[0].blocks[0].text == "Die Membran grenzt ab.\nSie lässt aber Stoffe durch.")
    }
}
