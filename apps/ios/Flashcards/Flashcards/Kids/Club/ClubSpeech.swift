import AVFoundation
import Foundation
import NaturalLanguage
import Observation
import UIKit

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
///
/// Odporność na „znikający lektor”: po szybkim przesuwaniu fiszek (zatrzymaj → od razu mów) AVSpeechSynthesizer
/// potrafi zawiesić się bez dźwięku. Dlatego przy przerwaniu bierzemy świeży syntezator, a strażnik sprawdza,
/// czy mowa naprawdę ruszyła – jeśli nie, powtarza zdanie na nowym syntezatorze.
@MainActor
@Observable
final class ClubSpeaker {
    /// Tempo mowy względem domyślnego (0.6–1.1); wolniej = wyraźniej dla dziecka.
    var rateMultiplier: Double {
        didSet {
            UserDefaults.standard.set(self.rateMultiplier, forKey: Self.rateKey)
        }
    }

    private(set) var englishVoiceId: String?
    private(set) var polishVoiceId: String?

    @ObservationIgnored private var synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = ClubSpeechDelegate()
    @ObservationIgnored private var pendingUtterance: AVSpeechUtterance?
    @ObservationIgnored private var startedUtterances: Set<ObjectIdentifier> = []
    @ObservationIgnored private var isAudioSessionReady: Bool = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    private static let rateKey = "club.speech.rate"
    /// Ile czekamy, aż mowa ruszy (pierwsze użycie głosu Premium potrafi chwilę się wczytywać).
    private static let startTimeout: Duration = .milliseconds(1500)

    init() {
        let storedRate = UserDefaults.standard.double(forKey: Self.rateKey)
        self.rateMultiplier = storedRate > 0 ? storedRate : 0.85
        self.englishVoiceId = UserDefaults.standard.string(forKey: ClubSpeechLanguage.english.voiceDefaultsKey)
        self.polishVoiceId = UserDefaults.standard.string(forKey: ClubSpeechLanguage.polish.voiceDefaultsKey)
        self.delegate.onStart = { [weak self] id in
            _ = self?.startedUtterances.insert(id)
        }
        self.synthesizer.delegate = self.delegate
        self.observeAudioSession()
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
        self.prepareAudioSession()

        // Przerywamy poprzednie słowo na NOWYM syntezatorze – stary po „stop” bywa niemy.
        if self.synthesizer.isSpeaking || self.synthesizer.isPaused || self.pendingUtterance != nil {
            self.synthesizer.stopSpeaking(at: .immediate)
            self.replaceSynthesizer()
        }

        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = self.voice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(self.rateMultiplier)
        utterance.pitchMultiplier = 1.0
        utterance.prefersAssistiveTechnologySettings = false
        self.start(utterance: utterance, isRetry: false)
    }

    func stop() {
        self.pendingUtterance = nil
        if self.synthesizer.isSpeaking || self.synthesizer.isPaused {
            self.synthesizer.stopSpeaking(at: .immediate)
            self.replaceSynthesizer()
        }
    }

    private func start(utterance: AVSpeechUtterance, isRetry: Bool) {
        self.pendingUtterance = utterance
        let id = ObjectIdentifier(utterance)
        self.synthesizer.speak(utterance)

        // Strażnik: jeśli mowa nie ruszyła, odtwarzamy zdanie jeszcze raz na świeżym syntezatorze.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.startTimeout)
            guard let self, let pending = self.pendingUtterance, ObjectIdentifier(pending) == id else { return }
            if self.startedUtterances.contains(id) {
                self.startedUtterances.remove(id)
                return
            }
            guard isRetry == false, let retry = pending.copy() as? AVSpeechUtterance else {
                self.pendingUtterance = nil
                return
            }
            self.synthesizer.stopSpeaking(at: .immediate)
            self.replaceSynthesizer()
            self.isAudioSessionReady = false
            self.prepareAudioSession()
            self.start(utterance: retry, isRetry: true)
        }
    }

    private func replaceSynthesizer() {
        self.synthesizer.delegate = nil
        self.synthesizer = AVSpeechSynthesizer()
        self.synthesizer.delegate = self.delegate
        self.startedUtterances.removeAll()
    }

    // MARK: - Sesja audio

    /// Mowa ma być słyszalna także przy wyciszonym iPhonie (przełącznik z boku), a inne dźwięki na chwilę ściszone.
    /// Ustawiamy sesję raz; ponownie dopiero po przerwaniu (telefon, alarm, Siri) lub zmianie słuchawek.
    private func prepareAudioSession() {
        guard self.isAudioSessionReady == false else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            self.isAudioSessionReady = true
        } catch {
            self.isAudioSessionReady = false
        }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            AVAudioSession.interruptionNotification,
            AVAudioSession.routeChangeNotification,
            AVAudioSession.mediaServicesWereResetNotification,
            UIApplication.didBecomeActiveNotification,
        ]
        for name in names {
            let resetsServices = name == AVAudioSession.mediaServicesWereResetNotification
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isAudioSessionReady = false
                    if resetsServices {
                        self.replaceSynthesizer()
                    }
                }
            }
            self.observers.append(observer)
        }
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

}

/// Delegat syntezatora: melduje, że zdanie naprawdę zaczęło być czytane (dla strażnika w ClubSpeaker).
final class ClubSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onStart: (@MainActor (ObjectIdentifier) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        let onStart = self.onStart
        Task { @MainActor in
            onStart?(id)
        }
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
