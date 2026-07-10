import WidgetKit
import SwiftUI

// MARK: - Timeline

struct WordEntry: TimelineEntry {
    let date: Date
    let word: VocabWord
}

struct WordProvider: TimelineProvider {

    private var placeholder: VocabWord {
            VocabWord(word: "petrichor",
                      partOfSpeech: "n.",
                      definition: "The pleasant, earthy smell produced when rain falls on dry soil.",
                      synonyms: ["earth-scent", "rain-smell"],
                      etymology: "Greek 'petra' (stone) + 'ichor' (fluid of the gods).")
        }

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), word: placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        let w = WordStore.currentWord() ?? placeholder
        completion(WordEntry(date: Date(), word: w))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
            let cal = Calendar.current
            let startOfToday = cal.startOfDay(for: Date())

            var entries: [WordEntry] = []

            // Build one entry per day for the next 7 days, each timestamped to that
            // day's midnight. iOS advances through them automatically — no app run,
            // no network, no refresh button needed.
            for offset in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: offset, to: startOfToday),
                      let bundled = WordStore.bundledWord(for: day) else { continue }

                // For TODAY only, prefer the app's enriched cache if it exists and
                // actually matches today's bundled pick (definition/synonyms upgrade).
                let word: VocabWord
                if offset == 0,
                   let cached = WordStore.currentWord(),
                   cached.word == bundled.word {
                    word = cached
                } else {
                    word = bundled
                }

                entries.append(WordEntry(date: day, word: word))
            }

            if entries.isEmpty {
                entries = [WordEntry(date: Date(), word: placeholder)]
            }

            // Reload the whole timeline after the last entry's day, as a backstop.
            let reloadAfter = cal.date(byAdding: .day, value: 7, to: startOfToday) ?? Date().addingTimeInterval(86_400)
            completion(Timeline(entries: entries, policy: .after(reloadAfter)))
        }
}

// MARK: - Views

struct WordWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WordEntry

    var body: some View {
            Group {
                switch family {
                case .systemMedium: mediumView
                case .accessoryRectangular: lockRectangularView
                case .accessoryInline: lockInlineView
                case .accessoryCircular: lockCircularView
                default: smallView
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }

    private var smallView: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.word.word)
                        .font(.system(.title2, design: .serif).bold())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(entry.word.partOfSpeech)
                        .font(.caption2.italic())
                        .foregroundStyle(.secondary)
                }
                Text(entry.word.definition)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumView: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.word.word)
                        .font(.system(.title, design: .serif).bold())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(entry.word.partOfSpeech)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }
                Text(entry.word.definition)
                .font(.subheadline)
                .lineLimit(3)
            if !entry.word.synonyms.isEmpty {
                Text(entry.word.synonyms.prefix(4).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

        // Lock screen widgets are monochrome — no color, no Spacer-driven layout.
        // Keep these dense and text-only.

    private var lockRectangularView: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.word.word) \(entry.word.partOfSpeech)")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.word.definition)
                    .font(.caption2)
                    .lineLimit(2)
            }
            .widgetAccentable()
        }

        private var lockInlineView: some View {
            Text("\(entry.word.word) — \(entry.word.definition)")
                .widgetAccentable()
        }

        private var lockCircularView: some View {
            Text(entry.word.word.prefix(2).uppercased())
                .font(.system(.title3, design: .serif).bold())
                .widgetAccentable()
        }
    }

    // MARK: - Widget

struct WordWidget: Widget {
    let kind = "WordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Etymizer")
        .description("A new word, definition, and synonyms each day.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
