import Foundation

/// German (first-class) and English vocabulary of lesson plans.
/// Used only to recognise *structure*; matched words are never rewritten.
enum PedagogicalVocabulary {

    struct LabelRule: Sendable {
        var type: BlockType
        /// Keep the label as part of the block text (e.g. "Merksatz: …", "Gruppenarbeit – 5 Minuten"),
        /// because the label itself carries meaning.
        var keepsLabel = false
        var isImportant = false
        var allowsTimer = false
        /// Becomes a `.timer` block when a duration is found in the line.
        var timerIfDuration = false
        /// "Thema:" – also used as suggested lesson title.
        var isTopic = false
    }

    struct LabelMatch {
        let rule: LabelRule
        /// Text after the colon, verbatim.
        let content: String
        /// The full line without a leading list bullet, verbatim.
        let line: String
    }

    // MARK: Folding

    /// Case-, diacritic- and width-insensitive key. "Überleitung" → "uberleitung", "Abschluß" → "abschluss".
    static func fold(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "de_DE"))
            .replacingOccurrences(of: "ß", with: "ss")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    // MARK: Sections

    static let sectionKeywords: Set<String> = Set([
        // Deutsch
        "Einstieg", "Einführung", "Motivation", "Problemstellung", "Problematisierung", "Wiederholung",
        "Hinführung", "Erarbeitung", "Sicherung", "Ergebnissicherung", "Transfer", "Vertiefung", "Übung",
        "Anwendung", "Abschluss", "Reflexion", "Experiment", "Hausaufgabe", "Hausaufgaben", "Auswertung",
        "Präsentation", "Stundenabschluss", "Ausblick", "Festigung", "Erkenntnisgewinnung",
        // English
        "Introduction", "Warm-up", "Warm up", "Starter", "Review", "Elaboration", "Input", "Practice",
        "Consolidation", "Conclusion", "Wrap-up", "Plenary", "Homework", "Extension",
    ].map(fold))

    // MARK: Labels

    static let labelRules: [String: LabelRule] = {
        var rules: [String: LabelRule] = [:]
        func add(_ names: [String], _ rule: LabelRule) {
            for name in names { rules[fold(name)] = rule }
        }
        add(["Lehrertext", "Lehrerimpuls", "Lehrervortrag", "Lehrerinformation", "Lehrerin", "Lehrer", "Impuls",
             "Erklärung", "Erläuterung", "Info", "Information", "Sagen", "Text", "Say", "Teacher", "Teacher text",
             "Script", "Explanation"],
            LabelRule(type: .say))
        add(["Definition", "Merksatz", "Merke", "Fachbegriff", "Key definition"],
            LabelRule(type: .say, keepsLabel: true, isImportant: true))
        add(["Frage", "Lehrerfrage", "Leitfrage", "Impulsfrage", "Problemfrage", "Fragestellung", "Question", "Ask",
             "Key question"],
            LabelRule(type: .question))
        add(["Antwort", "Erwartete Antwort", "Erwartete Antworten", "Erwartete Schülerantwort",
             "Erwartete Schülerantworten", "Schülerantwort", "Schülerantworten", "Erwartungshorizont", "Erwartung",
             "Lösung", "Musterlösung", "Expected answer", "Answer", "Solution"],
            LabelRule(type: .expectedAnswer))
        add(["Arbeitsauftrag", "Aktion", "Handlung", "Lehreraktion", "Lehreraktivität", "Tafel", "Tafelbild",
             "Tafelanschrieb", "Austeilen", "Medien", "Medium", "Action", "Task", "Do", "Board"],
            LabelRule(type: .action, allowsTimer: true))
        add(["Material", "Materialien", "Arbeitsblatt", "AB", "Plenum", "Hausaufgabe", "Hausaufgaben", "Worksheet",
             "Homework"],
            LabelRule(type: .action, keepsLabel: true, allowsTimer: true))
        add(["Partnerarbeit", "Gruppenarbeit", "Einzelarbeit", "Stillarbeit", "Think-Pair-Share", "Pair work",
             "Group work"],
            LabelRule(type: .action, keepsLabel: true, allowsTimer: true, timerIfDuration: true))
        add(["Experiment", "Versuch", "Durchführung", "Aufbau", "Versuchsaufbau", "Versuchsdurchführung"],
            LabelRule(type: .experiment, allowsTimer: true))
        add(["Schülerversuch", "Demonstrationsversuch", "Lehrerversuch", "Beobachtung", "Auswertung", "Observation"],
            LabelRule(type: .experiment, keepsLabel: true, allowsTimer: true))
        add(["Notiz", "Hinweis", "Anmerkung", "Tipp", "Achtung", "Didaktischer Hinweis", "Methodischer Hinweis",
             "Lernziel", "Ziel", "Note", "Hint", "Remark"],
            LabelRule(type: .note))
        add(["Thema", "Stundenthema", "Topic"],
            LabelRule(type: .note, keepsLabel: true, isTopic: true))
        add(["Timer", "Zeit", "Zeitvorgabe", "Dauer", "Time"],
            LabelRule(type: .timer, keepsLabel: true, allowsTimer: true))
        add(["Überleitung", "Übergang", "Überleitungssatz", "Transition"],
            LabelRule(type: .transition))
        return rules
    }()

    /// Words that start a timed social-form line even without a colon ("Gruppenarbeit – 5 Minuten").
    static let lineStartKeywords: Set<String> = Set(
        ["Gruppenarbeit", "Partnerarbeit", "Einzelarbeit", "Stillarbeit", "Timer"].map(fold)
    )

    // MARK: Matching

    static func label(in line: String) -> LabelMatch? {
        let stripped = stripBullet(line)
        if let colon = stripped.firstIndex(of: ":") {
            let rawLabel = String(stripped[..<colon])
            if rawLabel.count <= 40 {
                let cleaned = removeParentheticals(rawLabel)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "*_").union(.whitespaces))
                if let rule = labelRules[fold(cleaned)] {
                    let after = stripped[stripped.index(after: colon)...]
                    let content = String(after.drop { $0 == "*" || $0 == "_" || $0.isWhitespace })
                    return LabelMatch(rule: rule, content: content, line: stripped)
                }
            }
        }
        let firstWord = String(stripped.prefix { $0.isLetter || $0 == "-" })
        if lineStartKeywords.contains(fold(firstWord)), wordCount(stripped) <= 8 {
            let rule = LabelRule(type: .action, keepsLabel: true, allowsTimer: true, timerIfDuration: true)
            return LabelMatch(rule: rule, content: stripped, line: stripped)
        }
        return nil
    }

    /// Returns the section title (verbatim, without markdown hashes / trailing colon) if the line is a heading.
    static func sectionHeading(in line: String) -> String? {
        if line.hasPrefix("#") {
            let title = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : title
        }
        let hasTrailingColon = line.hasSuffix(":")
        let body = hasTrailingColon ? String(line.dropLast()).trimmingCharacters(in: .whitespaces) : line
        guard !body.isEmpty else { return nil }

        let withoutNumbering = stripNumbering(body)
        guard !withoutNumbering.contains(":"),
              let last = withoutNumbering.last,
              !".?!…".contains(last) else { return nil }
        let core = stripDurationSuffix(stripTrailingNumbering(withoutNumbering))
        guard !core.isEmpty else { return nil }

        let key = fold(core)
        let firstKey = fold(String(core.prefix { $0.isLetter || $0 == "-" }))
        let isNumbered = withoutNumbering != body

        if sectionKeywords.contains(key) || (sectionKeywords.contains(firstKey) && wordCount(core) <= 4) {
            // "Experiment:" alone is a label, "Experiment" / "3. Experiment" / "EXPERIMENT" a heading.
            if hasTrailingColon, !isNumbered, labelRules[key] != nil, core != core.uppercased() { return nil }
            return body
        }

        // Short ALL-CAPS line → heading (e.g. "ERARBEITUNG II").
        let letters = core.filter(\.isLetter)
        if letters.count >= 4,
           core == core.uppercased(),
           core != core.lowercased(),
           wordCount(core) <= 5,
           labelRules[key] == nil,
           slideMarker(in: line) == nil {
            return body
        }
        return nil
    }

    private static let slideRegex = regex(
        #"^(?:[-•*→>]+\s*)?(?:(?:n(?:ä|ae)chste|weiter\s+zur?|wechsel(?:n)?\s+zur?|zur?|next|go\s+to)\s+)?(?:folie|slide)\s*(?:nr\.?|no\.?)?\s*[:#\-–]?\s*(\d{1,3})(?!\d)"#
    )

    /// "Folie 4", "Nächste Folie: 5", "Zu Folie 6 wechseln", "Slide 3" → slide number.
    static func slideMarker(in line: String) -> Int? {
        guard let match = firstMatch(slideRegex, in: line),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return Int(line[range])
    }

    private static let minutesRegex = regex(
        #"(\d+(?:[.,]\d+)?)\s*(?:min(?:ute|uten|utes|s|\.)?(?![a-zäöüß])|['′’](?!\w))"#
    )
    private static let secondsRegex = regex(
        #"(\d+)\s*(?:sek(?:unden|\.)?|sec(?:onds|\.)?)(?![a-zäöüß])"#
    )

    /// Duration mentioned in a line ("5 Minuten", "10 min", "90 s").
    static func duration(in line: String) -> TimeInterval? {
        if let match = firstMatch(minutesRegex, in: line),
           let range = Range(match.range(at: 1), in: line),
           let value = Double(line[range].replacingOccurrences(of: ",", with: ".")) {
            return value * 60
        }
        if let match = firstMatch(secondsRegex, in: line),
           let range = Range(match.range(at: 1), in: line),
           let value = Double(line[range]) {
            return value
        }
        return nil
    }

    /// Question heuristic used only to *suggest* a type for unlabeled paragraphs.
    static func looksLikeQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”„«»‹›‚‘’)").union(.whitespacesAndNewlines))
        return trimmed.hasSuffix("?")
    }

    // MARK: Helpers

    private static let bulletRegex = regex(#"^(?:[-•*–·▪◦]|\d{1,2}[.)])\s+"#)
    private static let numberingRegex = regex(
        #"^(?:(?:(?:phase|stundenphase|teil|abschnitt|part|step|schritt|stage)\s*)?(?:\d{1,2}|[ivx]{1,4})?\s*[.):\-–]\s*|(?:phase|stundenphase|teil|abschnitt|part|step|schritt|stage)\s+\d{1,2}\s+)"#
    )
    private static let trailingNumberRegex = regex(#"\s+(?:\d{1,2}|[IVX]{1,4})$"#, caseInsensitive: false)
    private static let durationSuffixRegex = regex(
        #"\s*(?:[(\[]\s*(?:ca\.?\s*)?\d+\s*(?:-\s*\d+\s*)?(?:min\.?|minuten|minutes|mins|['′’])\s*[)\]]|[–-]\s*\d+\s*(?:min\.?|minuten|minutes))\s*$"#
    )
    private static let parentheticalRegex = regex(#"\s*\([^)]*\)"#)

    static func stripBullet(_ line: String) -> String {
        replace(bulletRegex, in: line, with: "")
    }

    static func stripNumbering(_ line: String) -> String {
        replace(numberingRegex, in: line, with: "").trimmingCharacters(in: .whitespaces)
    }

    static func stripTrailingNumbering(_ line: String) -> String {
        replace(trailingNumberRegex, in: line, with: "")
    }

    static func stripDurationSuffix(_ line: String) -> String {
        replace(durationSuffixRegex, in: line, with: "").trimmingCharacters(in: .whitespaces)
    }

    static func removeParentheticals(_ line: String) -> String {
        replace(parentheticalRegex, in: line, with: "")
    }

    static func wordCount(_ string: String) -> Int {
        string.split(whereSeparator: \.isWhitespace).count
    }

    private static func regex(_ pattern: String, caseInsensitive: Bool = true) -> NSRegularExpression {
        // Patterns are compile-time constants; a failure here is a programming error.
        try! NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
    }

    private static func firstMatch(_ regex: NSRegularExpression, in string: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
    }

    private static func replace(_ regex: NSRegularExpression, in string: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: string, range: NSRange(string.startIndex..., in: string), withTemplate: template)
    }
}
