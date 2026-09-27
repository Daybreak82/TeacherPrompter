import Foundation
import PDFKit
import UniformTypeIdentifiers

enum DocumentExtractor {
    enum ExtractorError: Error {
        case unsupported(filename: String)
        case unreadable(filename: String)
    }

    static let docxType = UTType("org.openxmlformats.wordprocessingml.document")
    static let pptxType = UTType("org.openxmlformats.presentationml.presentation")
    static let markdownType = UTType("net.daringfireball.markdown") ?? UTType(filenameExtension: "md")

    static var supportedTypes: [UTType] {
        [.pdf, .plainText, .utf8PlainText, .text, markdownType, docxType, pptxType].compactMap { $0 }
    }

    /// Reads a user-selected file. Handles security-scoped URLs from the document picker.
    static func extract(from url: URL) throws -> ExtractedDocument {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        do {
            switch ext {
            case "pdf":
                return try extractPDF(url)
            case "docx":
                let text = try OOXMLExtractor.docxText(data: Data(contentsOf: url))
                return ExtractedDocument(filename: filename, kind: .docx, segments: [.text(text)])
            case "pptx":
                let slides = try OOXMLExtractor.pptxSlides(data: Data(contentsOf: url))
                let segments = slides.map {
                    ExtractedDocument.Segment.slide(number: $0.number, title: $0.title, body: $0.body, notes: $0.notes)
                }
                return ExtractedDocument(filename: filename, kind: .pptx, segments: segments)
            case "md", "markdown":
                return ExtractedDocument(filename: filename, kind: .markdown, segments: [.text(try readText(url))])
            default:
                if ext == "txt" || ext == "text" || UTType(filenameExtension: ext)?.conforms(to: .text) == true {
                    return ExtractedDocument(filename: filename, kind: .text, segments: [.text(try readText(url))])
                }
                throw ExtractorError.unsupported(filename: filename)
            }
        } catch let error as ExtractorError {
            throw error
        } catch {
            throw ExtractorError.unreadable(filename: filename)
        }
    }

    static func clipboard(_ text: String, name: String) -> ExtractedDocument {
        ExtractedDocument(filename: name, kind: .clipboard, segments: [.text(text)])
    }

    // MARK: Formats

    /// Landscape pages are treated as exported slides, portrait pages as running text.
    private static func extractPDF(_ url: URL) throws -> ExtractedDocument {
        guard let document = PDFDocument(url: url) else {
            throw ExtractorError.unreadable(filename: url.lastPathComponent)
        }
        var segments: [ExtractedDocument.Segment] = []
        var runningText: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = page.string ?? ""
            let bounds = page.bounds(for: .mediaBox)
            if bounds.width > bounds.height {
                if !runningText.isEmpty {
                    segments.append(.text(runningText.joined(separator: "\n\n")))
                    runningText.removeAll()
                }
                let lines = text.components(separatedBy: .newlines)
                let titleIndex = lines.firstIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                let title = titleIndex.map { lines[$0].trimmingCharacters(in: .whitespaces) }
                let body = titleIndex.map { lines[($0 + 1)...].joined(separator: "\n") } ?? ""
                segments.append(.slide(number: index + 1, title: title, body: body, notes: ""))
            } else {
                runningText.append(text)
            }
        }
        if !runningText.isEmpty {
            segments.append(.text(runningText.joined(separator: "\n\n")))
        }
        return ExtractedDocument(filename: url.lastPathComponent, kind: .pdf, segments: segments)
    }

    /// UTF-8 first (with or without BOM), then UTF-16, then Windows-1252 – typical for older
    /// German Windows text files – so that ä, ö, ü, ß survive.
    static func readText(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return decodeText(data)
    }

    static func decodeText(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        if let text = String(data: data, encoding: .windowsCP1252) {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }
}
