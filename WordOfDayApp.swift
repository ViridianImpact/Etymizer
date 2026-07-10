import SwiftUI
import AVFoundation

// MARK: - Pronunciation

enum Accent: String, CaseIterable, Identifiable {
    case us = "en-US"
    case uk = "en-GB"
    case au = "en-AU"
    case ie = "en-IE"
    case za = "en-ZA"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .us: return "American"
        case .uk: return "British"
        case .au: return "Australian"
        case .ie: return "Irish"
        case .za: return "South African"
        }
    }
}

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String, accent: Accent) {
        // Route audio so it plays even with the ringer/silent switch considerations.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: accent.rawValue)
        utterance.rate = 0.42          // a touch slower than default, for clarity
        utterance.pitchMultiplier = 1.0
        synth.speak(utterance)
    }
}

@main
struct WordOfDayApp: App {
    var body: some Scene {
        WindowGroup {
            WordDetailView()
        }
    }
}

struct WordDetailView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var word: VocabWord?
    @State private var loading = false
    @State private var accent: Accent = .us

    var body: some View {
        NavigationStack {
            ScrollView {
                if let w = word {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(w.word)
                                .font(.system(size: 40, weight: .bold, design: .serif))
                            Text(w.partOfSpeech)
                                .font(.title3.italic())
                                .foregroundStyle(.secondary)
                            Button {
                                Speaker.shared.say(w.word, accent: accent)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title2)
                            }
                            .accessibilityLabel("Hear pronunciation")
                        }

                        Picker("Accent", selection: $accent) {
                            ForEach(Accent.allCases) { a in
                                Text(a.label).tag(a)
                            }
                        }
                        .pickerStyle(.menu)

                        section("Definition", w.definition)

                        if !w.synonyms.isEmpty {
                            section("Synonyms", w.synonyms.joined(separator: " · "))
                        }

                        section("Etymology", w.etymology)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .navigationTitle("Etymizer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption).bold()
                .foregroundStyle(.secondary)
            Text(body)
                .font(.body)
        }
    }

    private func refresh() async {
            loading = true
            defer { loading = false }
            guard let base = WordStore.bundledWord(for: Date()) else { return }

            // If the cache already holds today's word, show it without re-fetching.
            if let cached = WordStore.currentWord(), cached.word == base.word {
                word = cached
            }

            let enriched = await WordEnricher.enrich(base)
            WordStore.cache(enriched)   // writes to shared container + reloads widget
            word = enriched
        }
}
