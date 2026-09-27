import Foundation
import NaturalLanguage

/// Detects the content language of imported material. Detection never triggers translation.
enum LanguageDetector {
    static func detect(_ text: String) -> String? {
        let sample = String(text.prefix(8000))
        guard !sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        // Classroom material in this app is mostly German or English – a mild prior helps on short texts.
        recognizer.languageHints = [.german: 0.5, .english: 0.3]
        recognizer.processString(sample)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return language.rawValue
    }
}
