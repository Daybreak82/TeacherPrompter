import Foundation

/// Rule-based, deterministic parser that turns plain text into sections and blocks.
///
/// It only decides *where* a block starts and ends and *which type* it probably has.
/// Block text is always an exact excerpt of the input: structural labels such as
/// "Lehrertext:" or "Frage:" are removed, surrounding whitespace is trimmed, and
/// nothing else is touched (no quote, spelling, grammar or wording changes).
struct ScriptBuilder {
    private(set) var sections: [DraftSection] = [DraftSection(title: "")]
    private(set) var suggestedTitle: String?
    /// Slide the following blocks belong to ("Folie 4" → 4).
    var currentSlide: Int?
    private var pending: Pending?

    private struct Pending {
        var type: BlockType
        var lines: [String]
        /// Type was guessed (no label) – may become `.question` if the text ends with "?".
        var inferred: Bool
        var isImportant: Bool
        var timerDuration: TimeInterval?
        var sourceID: UUID?
    }

    // MARK: Input

    mutating func ingest(_ raw: String, mode: ImportMode = .structured, sourceID: UUID? = nil) {
        let text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
        switch mode {
        case .structured: ingestStructured(text, sourceID: sourceID)
        case .paragraphs: ingestParagraphs(text, sourceID: sourceID)
        }
        flush()
    }

    /// A presentation slide: creates a slide block whose text is the slide title (verbatim)
    /// and keeps the visible slide content in `notes`.
    mutating func appendSlide(number: Int, title: String?, body: String?, sourceID: UUID?) {
        flush()
        currentSlide = number
        let titleText = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bodyText = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let block = DraftBlock(
            type: .slide,
            text: titleText,
            slideNumber: number,
            sourceDocumentID: sourceID,
            notes: bodyText.isEmpty ? nil : bodyText
        )
        append(block)
    }

    mutating func startDocument() {
        flush()
        currentSlide = nil
    }

    func result() -> ParsedScript {
        var copy = self
        copy.flush()
        let sections = copy.sections.filter { !$0.blocks.isEmpty || !$0.title.isEmpty }
        return ParsedScript(sections: sections, suggestedTitle: copy.suggestedTitle)
    }

    // MARK: Modes

    private mutating func ingestStructured(_ text: String, sourceID: UUID?) {
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                // A blank line ends a block – unless we are still waiting for the content of a label.
                if let pending, !pending.lines.isEmpty { flush() }
                continue
            }

            if let slide = PedagogicalVocabulary.slideMarker(in: line) {
                flush()
                currentSlide = slide
                append(DraftBlock(type: .slide, text: line, slideNumber: slide, sourceDocumentID: sourceID))
                continue
            }

            if let heading = PedagogicalVocabulary.sectionHeading(in: line) {
                flush()
                startSection(heading)
                continue
            }

            if let label = PedagogicalVocabulary.label(in: line) {
                flush()
                let rule = label.rule
                if rule.isTopic, suggestedTitle == nil, !label.content.isEmpty {
                    suggestedTitle = label.content
                }
                let firstLine = rule.keepsLabel ? label.line : label.content
                let duration = rule.allowsTimer ? PedagogicalVocabulary.duration(in: line) : nil
                var type = rule.type
                if rule.timerIfDuration, duration != nil { type = .timer }
                pending = Pending(
                    type: type,
                    lines: firstLine.isEmpty ? [] : [firstLine],
                    inferred: false,
                    isImportant: rule.isImportant,
                    timerDuration: duration,
                    sourceID: sourceID
                )
                continue
            }

            if pending != nil {
                pending?.lines.append(line)
            } else {
                pending = Pending(type: .say, lines: [line], inferred: true, isImportant: false,
                                  timerDuration: nil, sourceID: sourceID)
            }
        }
    }

    private mutating func ingestParagraphs(_ text: String, sourceID: UUID?) {
        var paragraphs: [String] = []
        var current: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !current.isEmpty { paragraphs.append(current.joined(separator: "\n")) }
                current.removeAll()
            } else {
                current.append(trimmed)
            }
        }
        if !current.isEmpty { paragraphs.append(current.joined(separator: "\n")) }

        for paragraph in paragraphs {
            let type: BlockType = PedagogicalVocabulary.looksLikeQuestion(paragraph) ? .question : .say
            append(DraftBlock(type: type, text: paragraph, slideNumber: currentSlide, sourceDocumentID: sourceID))
        }
    }

    // MARK: Building

    private mutating func flush() {
        guard let finished = pending else { return }
        pending = nil
        let body = finished.lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        var type = finished.type
        if finished.inferred, PedagogicalVocabulary.looksLikeQuestion(body) { type = .question }
        let block = DraftBlock(
            type: type,
            text: body,
            slideNumber: currentSlide,
            sourceDocumentID: finished.sourceID,
            isImportant: finished.isImportant,
            timerDuration: finished.timerDuration
        )
        append(block)
    }

    private mutating func startSection(_ title: String) {
        if let last = sections.last, last.title.isEmpty, last.blocks.isEmpty {
            sections[sections.count - 1].title = title
        } else {
            sections.append(DraftSection(title: title))
        }
    }

    private mutating func append(_ block: DraftBlock) {
        sections[sections.count - 1].blocks.append(block)
    }
}
