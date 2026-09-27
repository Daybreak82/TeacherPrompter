import Foundation

/// Enforces "the teacher owns the words" for every analyzer, rule-based or (later) AI:
/// a proposed block is accepted as *verbatim* only if its text occurs word-for-word in the
/// source material. Only whitespace is normalised for the comparison – never letters,
/// punctuation or quotes. Non-verbatim blocks are flagged in the import preview.
enum VerbatimGuard {
    static func normalize(_ string: String) -> String {
        string.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func isVerbatim(_ text: String, in corpus: String) -> Bool {
        let needle = normalize(text)
        return needle.isEmpty || corpus.contains(needle)
    }

    static func annotate(_ script: inout ParsedScript, sources: [String]) {
        let corpus = sources.map(normalize).joined(separator: "\n")
        for s in script.sections.indices {
            for b in script.sections[s].blocks.indices {
                let block = script.sections[s].blocks[b]
                script.sections[s].blocks[b].isVerbatim = isVerbatim(block.originalText, in: corpus)
            }
        }
    }
}
