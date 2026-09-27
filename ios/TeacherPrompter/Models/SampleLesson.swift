import Foundation
import SwiftData

/// Demo lesson inserted on first launch. It is built by the real import pipeline,
/// so it also shows what the parser recognises.
enum SampleLesson {
    static let text = """
    EINSTIEG

    Folie 1
    Lehrertext:
    „Heute beschäftigen wir uns mit einer Grenze, die gleichzeitig durchlässig sein muss.“

    Frage:
    „Was könnte passieren, wenn eine Zelle überhaupt keine Membran hätte?“

    Erwartete Antwort:
    „Der Zellinhalt würde sich mit der Umgebung vermischen.“

    ERARBEITUNG

    Folie 3
    Lehrertext:
    „Die Zellmembran besteht hauptsächlich aus einer Phospholipid-Doppelschicht.“

    Frage:
    „Welche Eigenschaften haben die beiden Teile eines Phospholipids?“

    Erwartete Antwort:
    „hydrophiler Kopf, hydrophobe Schwänze“

    Merksatz: Die Biomembran ist selektiv permeabel.

    Folie 4
    Frage:
    „Welche Stoffe können direkt durch diese Membran gelangen?“

    Aktion:
    Modell der Biomembran zeigen.

    EXPERIMENT

    Versuch:
    Präparate verteilen.

    Gruppenarbeit – 5 Minuten

    Beobachtung: Was passiert mit den Zwiebelzellen in der Salzlösung?

    Hinweis: Mikroskope vorher auf 10x einstellen.

    SICHERUNG

    Folie 6
    Lehrertext:
    „Diffusion erfolgt aufgrund der zufälligen Eigenbewegung der Teilchen.“

    Frage:
    „Was glaubt ihr, warum geht das Wasser jetzt aus der Zelle raus?“

    Überleitung:
    „Nächste Stunde schauen wir uns an, wie Zellen Stoffe gegen ein Konzentrationsgefälle transportieren.“
    """

    @MainActor
    static func insert(into context: ModelContext) {
        let document = ExtractedDocument(filename: "Zellmembran.txt", kind: .text, segments: [.text(text)])
        var builder = ScriptBuilder()
        builder.ingest(text, sourceID: document.id)
        var script = builder.result()
        VerbatimGuard.annotate(&script, sources: [text])
        let draft = ImportDraft(script: script, sources: [document], fallbackTitle: "Zellmembran")
        draft.title = "Zellmembran"
        draft.subject = "Biologie"
        draft.classLevel = "Q1"
        draft.commit(to: .newLesson, context: context, untitled: "Zellmembran")
    }
}
