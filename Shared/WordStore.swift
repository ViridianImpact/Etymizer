import Foundation
import WidgetKit

// MARK: - Model

struct VocabWord: Codable, Identifiable {
    var id: String { word }
    let word: String
    let partOfSpeech: String
    let definition: String
    let synonyms: [String]
    let etymology: String
}

// MARK: - Shared store (bridges app <-> widget via App Group)

enum WordStore {

    // IMPORTANT: must match the App Group you create in Signing & Capabilities
    // for BOTH the app target and the widget target.
    static let appGroupID = "group.com.etymizer.shared"

    private static let cacheKey = "todaysWord"
    private static let cacheDateKey = "todaysWordDate"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // Load the bundled fallback list shipped inside the app bundle.
    static func loadWordBank() -> [VocabWord] {
        guard let url = Bundle.main.url(forResource: "WordBank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([VocabWord].self, from: data)
        else { return [] }
        return words
    }

    // Deterministic pick: same word for the whole calendar day, rotates daily.
    static func bundledWord(for date: Date = Date()) -> VocabWord? {
        let bank = loadWordBank()
        guard !bank.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return bank[day % bank.count]
    }

    // Read whatever the app last cached (enriched word, or bundled fallback).
    static func currentWord() -> VocabWord? {
        if let data = defaults?.data(forKey: cacheKey),
           let word = try? JSONDecoder().decode(VocabWord.self, from: data) {
            return word
        }
        return bundledWord()
    }

    // Called by the app after it picks/enriches the day's word.
    static func cache(_ word: VocabWord) {
        guard let data = try? JSONEncoder().encode(word) else { return }
        defaults?.set(data, forKey: cacheKey)
        defaults?.set(Date(), forKey: cacheDateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
