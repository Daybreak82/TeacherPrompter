import SwiftUI

/// UI language. Deliberately independent of the lesson's content language:
/// a German script can be taught with an English UI and vice versa.
enum UILanguage: String, Sendable {
    case de, en
}

struct Localizer: Sendable {
    var language: UILanguage

    func callAsFunction(_ key: L) -> String {
        key.text(language)
    }
}

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue = Localizer(language: .de)
}

extension EnvironmentValues {
    var loc: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}

/// All interface strings, German first. Typed keys make missing translations a compile error.
/// Lesson *content* is never passed through this table.
enum L {
    // General
    case lessons, newLesson, emptyLesson, importMaterials, settings
    case start, edit, rename, duplicate, delete, resetProgress, cancel, done, ok, close
    case searchPrompt, noLessons, noLessonsHint, otherLessons, untitledLesson, copySuffix
    case deleteLessonQuestion(String), progressShort(Int, Int)

    // Lesson details
    case lessonDetails, title, subject, classLevel, contentLanguage, plannedDuration(Int)

    // Editor
    case addBlock, addSection, sectionTitle, untitledSection, newSectionName, moveUp, moveDown
    case moveToSection, deleteSection, startLesson, addMaterial, markImportant, unmarkImportant
    case edited, emptyBlock, blocksInLesson(Int)

    // Block editor
    case editBlock, blockType, text, important, showOriginal, restoreOriginal, originalHint
    case expectedAnswerField, notesField, slideNumber, slideAndTiming, estimatedDuration(Int)
    case timerMinutes(Int), timerOff, showTranslation, translationHint

    // Lesson Mode
    case nextLabel, tapHint, back, skip, markDone, moveToLater, overview, pause, paused, resume, pausedHint
    case focusMode, previewNext, hideCompleted, strikeCompleted, showPrevious, textSmaller, textLarger
    case position(Int, Int), minutesProgress(Int, Int), slideBadge(Int), goToSlide(Int), nextSlide(Int)
    case startTimer(String), timerDone, lessonFinished, lessonFinishedHint, endOfLesson, undo
    case undoCompleted, undoSkipped, undoMovedLater, undoJumped, undoWentBack
    case resetLessonQuestion, moreOptions, cancelTimer

    // Import
    case pasteTab, filesTab, pastePlaceholder, chooseFiles, supportedFormats
    case recognition, modeStructured, modeParagraphs, modeStructuredHint, modeParagraphsHint
    case analyze, analyzing, preview, saveAsLesson, addToLesson, detectedLanguage, sources
    case nonVerbatimWarning(Int), notVerbatim, mergeWithNext, split, changeType, original
    case importFailed(String), unsupportedFile(String), nothingFound, clipboardName, wordingPromise

    // Settings
    case appearance, system, light, dark, interfaceLanguage, lessonMode, fontSize(Int), about
    case ownershipTitle, ownershipText, systemLanguage

    func text(_ language: UILanguage) -> String {
        let pair = strings
        return language == .de ? pair.de : pair.en
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private var strings: (de: String, en: String) {
        switch self {
        // General
        case .lessons: return ("Unterrichtsstunden", "Lessons")
        case .newLesson: return ("Neue Stunde", "New Lesson")
        case .emptyLesson: return ("Leere Stunde", "Empty Lesson")
        case .importMaterials: return ("Unterrichtsmaterial importieren", "Import Lesson Materials")
        case .settings: return ("Einstellungen", "Settings")
        case .start: return ("Starten", "Start")
        case .edit: return ("Bearbeiten", "Edit")
        case .rename: return ("Umbenennen", "Rename")
        case .duplicate: return ("Duplizieren", "Duplicate")
        case .delete: return ("Löschen", "Delete")
        case .resetProgress: return ("Fortschritt zurücksetzen", "Reset Progress")
        case .cancel: return ("Abbrechen", "Cancel")
        case .done: return ("Fertig", "Done")
        case .ok: return ("OK", "OK")
        case .close: return ("Schließen", "Close")
        case .searchPrompt: return ("Stunden und Texte durchsuchen", "Search lessons and text")
        case .noLessons: return ("Noch keine Stunden", "No Lessons Yet")
        case .noLessonsHint: return ("Lege eine Stunde an oder importiere deinen Unterrichtsverlauf.",
                                     "Create a lesson or import your lesson plan.")
        case .otherLessons: return ("Weitere", "Other")
        case .untitledLesson: return ("Neue Stunde", "Untitled Lesson")
        case .copySuffix: return (" (Kopie)", " (Copy)")
        case .deleteLessonQuestion(let title): return ("„\(title)“ löschen?", "Delete “\(title)”?")
        case let .progressShort(done, total): return ("\(done)/\(total) erledigt", "\(done)/\(total) done")

        // Lesson details
        case .lessonDetails: return ("Stunde", "Lesson")
        case .title: return ("Titel", "Title")
        case .subject: return ("Fach", "Subject")
        case .classLevel: return ("Klasse / Kurs", "Class")
        case .contentLanguage: return ("Sprache des Inhalts", "Content Language")
        case .plannedDuration(let minutes): return ("Geplante Dauer: \(minutes) min", "Planned duration: \(minutes) min")

        // Editor
        case .addBlock: return ("Block hinzufügen", "Add Block")
        case .addSection: return ("Abschnitt hinzufügen", "Add Section")
        case .sectionTitle: return ("Abschnittstitel", "Section Title")
        case .untitledSection: return ("Ohne Abschnitt", "Untitled Section")
        case .newSectionName: return ("Neuer Abschnitt", "New Section")
        case .moveUp: return ("Nach oben", "Move Up")
        case .moveDown: return ("Nach unten", "Move Down")
        case .moveToSection: return ("In Abschnitt verschieben", "Move to Section")
        case .deleteSection: return ("Abschnitt löschen", "Delete Section")
        case .startLesson: return ("Unterricht starten", "Start Lesson")
        case .addMaterial: return ("Material hinzufügen", "Add Material")
        case .markImportant: return ("Als wichtig markieren", "Mark as Important")
        case .unmarkImportant: return ("Nicht mehr wichtig", "Unmark Important")
        case .edited: return ("bearbeitet", "edited")
        case .emptyBlock: return ("(leer)", "(empty)")
        case .blocksInLesson(let count): return ("\(count) Blöcke", "\(count) blocks")

        // Block editor
        case .editBlock: return ("Block bearbeiten", "Edit Block")
        case .blockType: return ("Typ", "Type")
        case .text: return ("Text", "Text")
        case .important: return ("Wichtig", "Important")
        case .showOriginal: return ("Original anzeigen", "Show Original")
        case .restoreOriginal: return ("Original wiederherstellen", "Restore Original")
        case .originalHint: return ("Der importierte Wortlaut bleibt immer als Original erhalten.",
                                    "The imported wording is always kept as the original.")
        case .expectedAnswerField: return ("Erwartete Antwort (optional)", "Expected answer (optional)")
        case .notesField: return ("Notiz nur für mich", "Private note")
        case .slideNumber: return ("Foliennummer", "Slide number")
        case .slideAndTiming: return ("Folie & Zeit", "Slide & Timing")
        case .estimatedDuration(let minutes): return (minutes == 0 ? "Geschätzte Dauer: –" : "Geschätzte Dauer: \(minutes) min",
                                                      minutes == 0 ? "Estimated duration: –" : "Estimated duration: \(minutes) min")
        case .timerMinutes(let minutes): return ("Timer: \(minutes) min", "Timer: \(minutes) min")
        case .timerOff: return ("Timer: aus", "Timer: off")
        case .showTranslation: return ("Übersetzung anzeigen", "Show Translation")
        case .translationHint: return ("Die Übersetzung wird nur angezeigt. Dein Text bleibt unverändert.",
                                       "The translation is only displayed. Your text stays unchanged.")

        // Lesson Mode
        case .nextLabel: return ("DANACH", "NEXT")
        case .tapHint: return ("Tippen = erledigt  ·  Wischen ← zurück / weiter →", "Tap = done  ·  Swipe ← back / next →")
        case .back: return ("Zurück", "Back")
        case .skip: return ("Überspringen", "Skip")
        case .markDone: return ("Erledigt", "Done")
        case .moveToLater: return ("Auf später verschieben", "Move to Later")
        case .overview: return ("Übersicht", "Overview")
        case .pause: return ("Stunde pausieren", "Pause Lesson")
        case .paused: return ("Pausiert", "Paused")
        case .resume: return ("Fortsetzen", "Resume")
        case .pausedHint: return ("Die Stunde wartet an derselben Stelle.", "The lesson waits at the same place.")
        case .focusMode: return ("Fokusmodus", "Focus Mode")
        case .previewNext: return ("Nächsten Block zeigen", "Preview Next Block")
        case .hideCompleted: return ("Erledigte ausblenden", "Hide Completed Blocks")
        case .strikeCompleted: return ("Erledigte durchstreichen", "Strike Through Completed")
        case .showPrevious: return ("Vorherigen Block zeigen", "Show Previous Block")
        case .textSmaller: return ("Schrift kleiner", "Smaller Text")
        case .textLarger: return ("Schrift größer", "Larger Text")
        case let .position(index, total): return ("\(index) / \(total)", "\(index) / \(total)")
        case let .minutesProgress(elapsed, planned): return ("\(elapsed) / \(planned) min", "\(elapsed) / \(planned) min")
        case .slideBadge(let number): return ("FOLIE \(number)", "SLIDE \(number)")
        case .goToSlide(let number): return ("Zu Folie \(number) wechseln", "Go to slide \(number)")
        case .nextSlide(let number): return ("NÄCHSTE FOLIE → \(number)", "NEXT SLIDE → \(number)")
        case .startTimer(let duration): return ("Timer starten · \(duration)", "Start Timer · \(duration)")
        case .timerDone: return ("Zeit ist um", "Time’s up")
        case .lessonFinished: return ("Stunde abgeschlossen", "Lesson Complete")
        case .lessonFinishedHint: return ("Alle Blöcke sind erledigt oder übersprungen.", "All blocks are done or skipped.")
        case .endOfLesson: return ("Danach: Ende der Stunde", "After this: end of lesson")
        case .undo: return ("Rückgängig", "Undo")
        case .undoCompleted: return ("Erledigt", "Marked as done")
        case .undoSkipped: return ("Übersprungen", "Skipped")
        case .undoMovedLater: return ("Auf später verschoben", "Moved to later")
        case .undoJumped: return ("Gesprungen", "Jumped")
        case .undoWentBack: return ("Zurückgegangen", "Went back")
        case .resetLessonQuestion: return ("Fortschritt dieser Stunde zurücksetzen?", "Reset progress of this lesson?")
        case .moreOptions: return ("Weitere Optionen", "More Options")
        case .cancelTimer: return ("Timer beenden", "Stop Timer")

        // Import
        case .pasteTab: return ("Text", "Text")
        case .filesTab: return ("Dateien", "Files")
        case .pastePlaceholder: return ("Unterrichtsverlauf, Lehrertext oder Notizen hier einfügen …",
                                        "Paste your lesson plan, teacher script or notes here …")
        case .chooseFiles: return ("Dateien auswählen …", "Choose Files …")
        case .supportedFormats: return ("PDF, PowerPoint (.pptx), Word (.docx), Text und Markdown. Mehrere Dateien möglich – z. B. Präsentation und Unterrichtsverlauf.",
                                        "PDF, PowerPoint (.pptx), Word (.docx), text and Markdown. Several files at once – e.g. slides and lesson plan.")
        case .recognition: return ("Erkennung", "Recognition")
        case .modeStructured: return ("Struktur erkennen", "Detect Structure")
        case .modeParagraphs: return ("Jeder Absatz = ein Block", "One Block per Paragraph")
        case .modeStructuredHint: return ("Erkennt Phasen (Einstieg, Erarbeitung, Sicherung …), Lehrertext, Fragen, erwartete Antworten, Folien, Versuche und Zeiten. Der Wortlaut wird nicht verändert.",
                                          "Detects phases, teacher text, questions, expected answers, slides, experiments and timings. The wording is never changed.")
        case .modeParagraphsHint: return ("Jeder Absatz wird ein eigener Block. Der Wortlaut wird nicht verändert.",
                                          "Every paragraph becomes one block. The wording is never changed.")
        case .analyze: return ("Analysieren", "Analyze")
        case .analyzing: return ("Wird analysiert …", "Analyzing …")
        case .preview: return ("Vorschau", "Preview")
        case .saveAsLesson: return ("Als Stunde speichern", "Save as Lesson")
        case .addToLesson: return ("Zur Stunde hinzufügen", "Add to Lesson")
        case .detectedLanguage: return ("Erkannte Sprache", "Detected Language")
        case .sources: return ("Quellen", "Sources")
        case .nonVerbatimWarning(let count): return ("\(count) Block/Blöcke stimmen nicht wörtlich mit der Quelle überein – bitte prüfen.",
                                                     "\(count) block(s) do not match the source word for word – please check.")
        case .notVerbatim: return ("nicht wörtlich in der Quelle", "not verbatim in source")
        case .mergeWithNext: return ("Mit nächstem Block zusammenführen", "Merge with Next Block")
        case .split: return ("Teilen", "Split")
        case .changeType: return ("Typ ändern", "Change Type")
        case .original: return ("Original", "Original")
        case .importFailed(let name): return ("„\(name)“ konnte nicht gelesen werden.", "“\(name)” could not be read.")
        case .unsupportedFile(let name): return ("„\(name)“ wird nicht unterstützt.", "“\(name)” is not supported.")
        case .nothingFound: return ("Kein Text gefunden.", "No text found.")
        case .clipboardName: return ("Eingefügter Text", "Pasted text")
        case .wordingPromise: return ("Teacher Prompter ordnet dein Material nur. Jede Formulierung bleibt so, wie du sie geschrieben hast.",
                                      "Teacher Prompter only organises your material. Every sentence stays exactly as you wrote it.")

        // Settings
        case .appearance: return ("Darstellung", "Appearance")
        case .system: return ("System", "System")
        case .light: return ("Hell", "Light")
        case .dark: return ("Dunkel", "Dark")
        case .interfaceLanguage: return ("Sprache der App", "App Language")
        case .systemLanguage: return ("Wie System", "System")
        case .lessonMode: return ("Unterrichtsmodus", "Lesson Mode")
        case .fontSize(let size): return ("Schriftgröße: \(size) pt", "Text size: \(size) pt")
        case .about: return ("Über", "About")
        case .ownershipTitle: return ("Der Text gehört der Lehrkraft", "The teacher owns the words")
        case .ownershipText: return ("Die App strukturiert, ordnet und zeigt an. Sie formuliert nichts um, korrigiert nichts und übersetzt nichts ohne deine ausdrückliche Aktion. Importierte Formulierungen bleiben immer als Original erhalten.",
                                     "The app structures, sorts and displays. It never rephrases, corrects or translates without your explicit action. Imported wording is always kept as the original.")
        }
    }
}

/// Human-readable names for content languages (shown in the UI language).
enum ContentLanguage {
    static let common = ["de", "en", "fr", "es", "it", "la"]

    static func name(_ code: String, in language: UILanguage) -> String {
        Locale(identifier: language.rawValue).localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
