import Foundation

// Enriches the day's bundled word with live definition + synonyms.
// Etymology always comes from the bundled list (free APIs don't reliably provide it).
// If the network fails, the bundled word is used as-is.

enum WordEnricher {

    // Free Dictionary API: no key required.
    private static let base = "https://api.dictionaryapi.dev/api/v2/entries/en/"

    struct DictEntry: Decodable {
        struct Meaning: Decodable {
            struct Def: Decodable {
                let definition: String
                let synonyms: [String]?
            }
            let partOfSpeech: String?
            let definitions: [Def]
            let synonyms: [String]?
        }
        let meanings: [Meaning]
    }

    /// Returns an enriched copy of `base` word, or the original on any failure.
    static func enrich(_ word: VocabWord) async -> VocabWord {
        guard let url = URL(string: base + word.word.lowercased()) else { return word }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return word }
            let entries = try JSONDecoder().decode([DictEntry].self, from: data)

            // Prefer the live definition if present.
            let liveDef = entries.first?.meanings.first?.definitions.first?.definition

            // Live part of speech, abbreviated to match the bundled style.
            let livePOS = entries.first?.meanings.first?.partOfSpeech
            let posMap = ["noun": "n.", "verb": "v.", "adjective": "adj.",
                          "adverb": "adv.", "pronoun": "pron.", "preposition": "prep.",
                          "conjunction": "conj.", "interjection": "interj."]
            let abbrevPOS = livePOS.flatMap { posMap[$0.lowercased()] } ?? livePOS

            // Gather synonyms from all meanings, dedup, cap at 5.
            var syns: [String] = []
            for entry in entries {
                for meaning in entry.meanings {
                    syns.append(contentsOf: meaning.synonyms ?? [])
                    for d in meaning.definitions { syns.append(contentsOf: d.synonyms ?? []) }
                }
            }
            let merged = Array(NSOrderedSet(array: syns + word.synonyms)).compactMap { $0 as? String }
            let finalSyns = Array(merged.prefix(5))

            return VocabWord(
                word: word.word,
                partOfSpeech: abbrevPOS ?? word.partOfSpeech,
                definition: liveDef ?? word.definition,
                synonyms: finalSyns.isEmpty ? word.synonyms : finalSyns,
                etymology: word.etymology   // always bundled
            )
        } catch {
            return word
        }
    }
}
