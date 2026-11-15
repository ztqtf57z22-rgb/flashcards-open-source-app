import AVFoundation
import Foundation
import NaturalLanguage
import Observation

/// Język, w którym lektor ma przeczytać tekst.
enum ClubSpeechLanguage: String, CaseIterable, Sendable {
    case english
    case polish

    var title: String {
        switch self {
        case .english: "Angielski"
        case .polish: "Polski"
        }
    }

    /// Preferowane warianty języka, od najlepszego (brytyjski angielski – jak w materiałach klubu).
    var preferredLocales: [String] {
        switch self {
        case .english: ["en-GB", "en-US", "en-AU", "en-IE", "en-IN", "en-ZA"]
        case .polish: ["pl-PL"]
        }
    }

    var languagePrefix: String {
        switch self {
        case .english: "en"
        case .polish: "pl"
        }
    }

    var voiceDefaultsKey: String {
        "club.speech.voice.\(self.rawValue)"
    }
}

/// Lektor klubu: czyta angielskie słowa angielskim głosem, a polskie – polskim.
///
/// Używa najlepszych głosów zainstalowanych na urządzeniu (Premium → Rozszerzony → standardowy).
/// Głosy Premium/Rozszerzone są darmowe; pobiera się je w Ustawieniach iOS (patrz ustawienia rodzica w klubie).
@MainActor
@Observable
final class ClubSpeaker {
    /// Tempo mowy względem domyślnego (0.6–1.0); wolniej = wyraźniej dla dziecka.
    var rateMultiplier: Double {
        didSet {
            UserDefaults.standard.set(self.rateMultiplier, forKey: Self.rateKey)
        }
    }

    private(set) var englishVoiceId: String?
    private(set) var polishVoiceId: String?

    private let synthesizer = AVSpeechSynthesizer()
    private static let rateKey = "club.speech.rate"

    init() {
        let storedRate = UserDefaults.standard.double(forKey: Self.rateKey)
        self.rateMultiplier = storedRate > 0 ? storedRate : 0.85
        self.englishVoiceId = UserDefaults.standard.string(forKey: ClubSpeechLanguage.english.voiceDefaultsKey)
        self.polishVoiceId = UserDefaults.standard.string(forKey: ClubSpeechLanguage.polish.voiceDefaultsKey)
    }

    // MARK: - Czytanie

    func speakEnglish(_ text: String) {
        self.speak(text, language: .english)
    }

    func speakPolish(_ text: String) {
        self.speak(text, language: .polish)
    }

    /// Sam rozpoznaje, czy tekst jest po polsku, czy po angielsku (np. odpowiedzi w quizie).
    func speakDetectingLanguage(_ text: String) {
        self.speak(text, language: clubDetectSpeechLanguage(text))
    }

    func speak(_ text: String, language: ClubSpeechLanguage) {
        let spoken = clubSpeakableText(text)
        guard spoken.isEmpty == false else { return }
        self.activateAudioSession()
        if self.synthesizer.isSpeaking {
            self.synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = self.voice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(self.rateMultiplier)
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        self.synthesizer.speak(utterance)
    }

    func stop() {
        self.synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Wybór głosu

    func voice(for language: ClubSpeechLanguage) -> AVSpeechSynthesisVoice? {
        let selectedId = language == .english ? self.englishVoiceId : self.polishVoiceId
        if let selectedId, let selected = AVSpeechSynthesisVoice(identifier: selectedId) {
            return selected
        }
        return Self.availableVoices(for: language).first
    }

    func selectVoice(identifier: String?, for language: ClubSpeechLanguage) {
        switch language {
        case .english: self.englishVoiceId = identifier
        case .polish: self.polishVoiceId = identifier
        }
        UserDefaults.standard.set(identifier, forKey: language.voiceDefaultsKey)
    }

    /// Głosy danego języka, najlepsze na początku (Premium, potem Rozszerzone, potem preferowany wariant języka).
    static func availableVoices(for language: ClubSpeechLanguage) -> [AVSpeechSynthesisVoice] {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language.languagePrefix) && $0.voiceTraits.contains(.isNoveltyVoice) == false
        }
        return voices.sorted { lhs, rhs in
            let lhsQuality = clubQualityRank(lhs.quality)
            let rhsQuality = clubQualityRank(rhs.quality)
            if lhsQuality != rhsQuality {
                return lhsQuality > rhsQuality
            }
            let lhsLocale = language.preferredLocales.firstIndex(of: lhs.language) ?? Int.max
            let rhsLocale = language.preferredLocales.firstIndex(of: rhs.language) ?? Int.max
            if lhsLocale != rhsLocale {
                return lhsLocale < rhsLocale
            }
            return lhs.name < rhs.name
        }
    }

    /// Czy dla języka jest zainstalowany głos lepszy niż standardowy.
    static func hasHighQualityVoice(for language: ClubSpeechLanguage) -> Bool {
        self.availableVoices(for: language).contains { $0.quality != .default }
    }

    /// Mowa ma być słyszalna także przy wyciszonym iPhonie (przełącznik z boku), a inne dźwięki na chwilę ściszone.
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }
}

func clubQualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
    switch quality {
    case .premium: 3
    case .enhanced: 2
    default: 1
    }
}

func clubQualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
    switch quality {
    case .premium: "Premium"
    case .enhanced: "Rozszerzony"
    default: "Standardowy"
    }
}

/// Tekst do przeczytania: bez emoji i znaków, które lektor czytałby dziwnie.
func clubSpeakableText(_ text: String) -> String {
    var result = ""
    for character in text {
        let isEmoji = character.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) || $0.value == 0xFE0F
        }
        if isEmoji == false {
            result.append(character)
        }
    }
    return result
        .replacingOccurrences(of: "___", with: " … ")
        .replacingOccurrences(of: " / ", with: ", ")
        .replacingOccurrences(of: "/", with: ", ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Rozpoznaje polski albo angielski. Polskie litery rozstrzygają od razu; inaczej decyduje model językowy iOS.
func clubDetectSpeechLanguage(_ text: String) -> ClubSpeechLanguage {
    let polishLetters = CharacterSet(charactersIn: "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ")
    if text.rangeOfCharacter(from: polishLetters) != nil {
        return .polish
    }
    let recognizer = NLLanguageRecognizer()
    recognizer.languageConstraints = [.english, .polish]
    recognizer.languageHints = [.english: 0.6, .polish: 0.4]
    recognizer.processString(text)
    return recognizer.dominantLanguage == .polish ? .polish : .english
}
