import Foundation

/// Extracts text from Word (.docx) and PowerPoint (.pptx) files without third-party libraries.
/// Text runs are concatenated exactly as stored; nothing is normalised or corrected.
enum OOXMLExtractor {
    enum ExtractionError: Error {
        case missingPart(String)
    }

    struct Slide {
        let number: Int
        let title: String?
        let body: String
        let notes: String
    }

    // MARK: Word

    /// Paragraphs separated by blank lines. Heading paragraphs are prefixed with "# " so the
    /// parser can recognise them as sections (the marker is structure, not content).
    static func docxText(data: Data) throws -> String {
        let zip = try ZipArchive(data: data)
        guard let xml = try zip.data(for: "word/document.xml") else {
            throw ExtractionError.missingPart("word/document.xml")
        }
        let collector = WordCollector()
        parse(xml, delegate: collector)
        return collector.paragraphs.joined(separator: "\n\n")
    }

    // MARK: PowerPoint

    static func pptxSlides(data: Data) throws -> [Slide] {
        let zip = try ZipArchive(data: data)
        var slidePaths: [String] = []

        // Real slide order comes from presentation.xml (sldIdLst) + its relationships.
        if let presentation = try zip.data(for: "ppt/presentation.xml"),
           let rels = try zip.data(for: "ppt/_rels/presentation.xml.rels") {
            let ids = attributes(of: "p:sldId", in: presentation).compactMap { $0["r:id"] }
            let targets = relationshipTargets(rels)
            slidePaths = ids.compactMap { targets[$0]?.target }.map { resolve($0, base: "ppt") }
        }
        if slidePaths.isEmpty {
            slidePaths = zip.entryNames
                .filter { $0.hasPrefix("ppt/slides/slide") && $0.hasSuffix(".xml") }
                .sorted { slideIndex($0) < slideIndex($1) }
        }

        var slides: [Slide] = []
        for (offset, path) in slidePaths.enumerated() {
            guard let xml = try zip.data(for: path) else { continue }
            let shapes = drawingShapes(xml)
            let titleShapes = shapes.filter { $0.placeholder == "title" || $0.placeholder == "ctrTitle" }
            let bodyShapes = shapes.filter { $0.placeholder != "title" && $0.placeholder != "ctrTitle" }
            let title = titleShapes.flatMap(\.paragraphs)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: " ")
            let body = bodyShapes.flatMap(\.paragraphs)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")

            var notes = ""
            let directory = (path as NSString).deletingLastPathComponent
            let file = (path as NSString).lastPathComponent
            if let rels = try zip.data(for: "\(directory)/_rels/\(file).rels"),
               let notesTarget = relationshipTargets(rels).values.first(where: { $0.type.hasSuffix("/notesSlide") }),
               let notesXML = try zip.data(for: resolve(notesTarget.target, base: directory)) {
                let excluded: Set<String> = ["sldImg", "sldNum", "hdr", "ftr", "dt"]
                let noteShapes = drawingShapes(notesXML).filter { !excluded.contains($0.placeholder ?? "body") }
                notes = noteShapes.flatMap(\.paragraphs).joined(separator: "\n\n")
            }

            slides.append(Slide(number: offset + 1, title: title.isEmpty ? nil : title, body: body, notes: notes))
        }
        return slides
    }

    // MARK: Helpers

    private static func slideIndex(_ path: String) -> Int {
        Int(path.filter(\.isNumber)) ?? 0
    }

    static func resolve(_ target: String, base: String) -> String {
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        var parts = base.split(separator: "/").map(String.init)
        for component in target.split(separator: "/") {
            if component == ".." {
                if !parts.isEmpty { parts.removeLast() }
            } else if component != "." {
                parts.append(String(component))
            }
        }
        return parts.joined(separator: "/")
    }

    private static func parse(_ data: Data, delegate: XMLParserDelegate) {
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.parse()
    }

    private static func attributes(of element: String, in data: Data) -> [[String: String]] {
        let collector = AttributeCollector(element: element)
        parse(data, delegate: collector)
        return collector.results
    }

    private static func relationshipTargets(_ data: Data) -> [String: (type: String, target: String)] {
        var result: [String: (type: String, target: String)] = [:]
        for attributes in attributes(of: "Relationship", in: data) {
            guard let id = attributes["Id"], let target = attributes["Target"] else { continue }
            result[id] = (attributes["Type"] ?? "", target)
        }
        return result
    }

    private static func drawingShapes(_ data: Data) -> [DrawingCollector.Shape] {
        let collector = DrawingCollector()
        parse(data, delegate: collector)
        return collector.allShapes
    }
}

// MARK: - XML delegates

private final class AttributeCollector: NSObject, XMLParserDelegate {
    let element: String
    var results: [[String: String]] = []

    init(element: String) {
        self.element = element
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == element { results.append(attributeDict) }
    }
}

private final class WordCollector: NSObject, XMLParserDelegate {
    var paragraphs: [String] = []
    private var current = ""
    private var depth = 0
    private var inText = false
    private var isHeading = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "w:p":
            depth += 1
            if depth == 1 {
                current = ""
                isHeading = false
            }
        case "w:pStyle":
            let style = (attributeDict["w:val"] ?? "").lowercased()
            // English "Heading1", German "berschrift1" (style id of "Überschrift 1"), "Title"/"Titel".
            if style.hasPrefix("heading") || style.contains("berschrift") || style == "title" || style == "titel" {
                isHeading = true
            }
        case "w:t":
            inText = true
        case "w:tab":
            if depth > 0 { current += "\t" }
        case "w:br", "w:cr":
            if depth > 0 { current += "\n" }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch elementName {
        case "w:t":
            inText = false
        case "w:p":
            depth -= 1
            if depth == 0 {
                let hasText = !current.trimmingCharacters(in: .whitespaces).isEmpty
                paragraphs.append(isHeading && hasText ? "# " + current : current)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { current += string }
    }
}

private final class DrawingCollector: NSObject, XMLParserDelegate {
    struct Shape {
        /// Placeholder type (`title`, `body`, `sldNum`, …) or nil for free shapes.
        var placeholder: String?
        var paragraphs: [String] = []
    }

    private var shapes: [Shape] = []
    private var looseParagraphs: [String] = []
    private var shape: Shape?
    private var paragraph: String?
    private var inText = false
    private var fieldDepth = 0

    var allShapes: [Shape] {
        looseParagraphs.isEmpty ? shapes : shapes + [Shape(placeholder: nil, paragraphs: looseParagraphs)]
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "p:sp":
            shape = Shape()
        case "p:ph":
            shape?.placeholder = attributeDict["type"] ?? "body"
        case "a:p":
            paragraph = ""
        case "a:t":
            inText = true
        case "a:br":
            paragraph? += "\n"
        case "a:fld":
            // Fields (slide numbers, dates) are generated, not written by the teacher.
            fieldDepth += 1
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        switch elementName {
        case "a:t":
            inText = false
        case "a:fld":
            fieldDepth = max(0, fieldDepth - 1)
        case "a:p":
            if let paragraph {
                if shape != nil {
                    shape?.paragraphs.append(paragraph)
                } else {
                    looseParagraphs.append(paragraph)
                }
            }
            paragraph = nil
        case "p:sp":
            if let shape { shapes.append(shape) }
            shape = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText, fieldDepth == 0 { paragraph? += string }
    }
}
